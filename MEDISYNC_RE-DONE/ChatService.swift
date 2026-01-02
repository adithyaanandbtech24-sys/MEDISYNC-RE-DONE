// ChatService.swift
import Foundation
import SwiftData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Service for AI chatbot functionality
@MainActor
final class ChatService {
    static let shared = ChatService()
    
    private let firestore = FirestoreService.shared
    private let auth = FirebaseAuthService.shared
    
    // MARK: - AI Message Handling
    
    /// Send message to AI backend
    /// - Parameters:
    ///   - message: User's message text
    ///   - medicalContext: User's medical history for context (optional)
    /// - Returns: AI response text
    // WARNING: Storing API keys in client-side code is not secure for production apps.
    // However, this is required for the Firebase Free (Spark) plan which doesn't support Cloud Functions.
    private let geminiAPIKey = "AIzaSyDMgjDbskP62L1qY-iDHlvVzm1qLSj3xtE"
    
    func sendMessageToAI(
        message: String,
        context: ModelContext,
        medicalContext: [String: Any]? = nil
    ) async throws -> String {
        print("🤖 [ChatService] Sending message to Gemini (Client-Side)...")
        
        guard geminiAPIKey != "YOUR_API_KEY" else {
            print("❌ [ChatService] Error: API Key not set")
            throw FirebaseError.processingFailed("Please add your Gemini API Key in ChatService.swift")
        }
        
        // 1. Retrieve Graph RAG Context
        print("🔍 [ChatService] Retrieving Graph RAG context...")
        let graphContext = GraphRAGEngine.shared.retrieveContext(for: message, context: context)
        
        // Gemini API endpoint
        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=\(geminiAPIKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // System instructions
        let systemInstructions = """
        You are a helpful medical information assistant for the MediSync app.
        - Do NOT provide medical diagnoses or prescriptions.
        - Always recommend consulting a doctor for medical advice.
        - Explain medical concepts in simple, easy-to-understand language.
        - Be empathetic, supportive, and concise in your responses.
        
        User's Medical Context:
        \(graphContext.isEmpty ? "No medical history available." : graphContext)
        """
        
        // Gemini API request body
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemInstructions)\n\nUser Question: \(message)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 500
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [ChatService] Gemini API Error: \(errorText)")
                throw FirebaseError.processingFailed("Gemini API Error: \(httpResponse.statusCode)")
            }
            
            // Parse response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let text = firstPart["text"] as? String else {
                throw FirebaseError.processingFailed("Invalid response from Gemini AI")
            }
            
            print("✅ [ChatService] Gemini Reply received: \(text.prefix(50))...")
            return text
            
        } catch {
            print("❌ [ChatService] Network Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Store chat message in Firestore
    func storeMessage(
        _ message: AIChatMessage,
        context: ModelContext
    ) async throws {
        // Ensure user is authenticated
        let userId = try await auth.ensureAnonymousUser()
        
        // Store in SwiftData
        context.insert(message)
        try context.save()
        
        // Skip Firestore sync if using guest ID (local mode)
        if userId == "guest_user_id" {
            print("⚠️ [ChatService] Guest mode: Skipping Firestore sync")
            return
        }
        
        // Sync to Firestore
        #if canImport(FirebaseFirestore)
        let firestoreData = FirestoreMappers.toFirestore(message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.setDocument(
                userId: userId,
                collection: "chat_messages",
                id: message.id,
                data: firestoreData
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        #else
        print("⚠️ [ChatService] FirebaseFirestore not available: Skipping Firestore sync")
        #endif
    }
    
    /// Load chat history from Firestore
    func loadChatHistory(context: ModelContext) async throws -> [AIChatMessage] {
        // Ensure user is authenticated
        let userId = try await auth.ensureAnonymousUser()
        
        // If guest mode, return empty list (or local SwiftData query if we implemented it)
        // Since we're using SwiftData @Query in the view, this is mostly for initial sync
        if userId == "guest_user_id" {
            print("⚠️ [ChatService] Guest mode: Skipping Firestore load")
            return []
        }
        
        #if canImport(FirebaseFirestore)
        // Fetch from Firestore directly
        return try await withCheckedThrowingContinuation { continuation in
            let db = Firestore.firestore()
            db.collection("users").document(userId).collection("chat_messages")
                .order(by: "timestamp", descending: false)
                .getDocuments { snapshot, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let messages = documents.compactMap { doc -> AIChatMessage? in
                        let data = doc.data()
                        return FirestoreMappers.fromFirestore(data)
                    }
                    
                    continuation.resume(returning: messages)
                }
        }
        #else
        return []
        #endif
    }
    
    /// Send user message and get AI response
    func sendAndReceive(
        userMessage: String,
        context: ModelContext
    ) async throws -> (userMsg: AIChatMessage, aiMsg: AIChatMessage) {
        // Create user message
        let userMsg = AIChatMessage(
            id: UUID().uuidString,
            text: userMessage,
            isUser: true,
            timestamp: Date()
        )
        
        // Store user message
        try await storeMessage(userMsg, context: context)
        
        // Get AI response from Cloud Function
        let aiResponse = try await sendMessageToAI(message: userMessage, context: context)
        
        // Create AI message
        let aiMsg = AIChatMessage(
            id: UUID().uuidString,
            text: aiResponse,
            isUser: false,
            timestamp: Date()
        )
        
        // Store AI message
        try await storeMessage(aiMsg, context: context)
        
        return (userMsg, aiMsg)
    }

    
    // MARK: - Medical Analysis
    
    struct MedicalAnalysisResult: Codable {
        let reportType: String
        let summary: String
        let labResults: [LabResultDTO]
        let medications: [MedicationDTO]
    }

    struct LabResultDTO: Codable {
        let testName: String
        let value: String // Changed to String to handle ranges or "<" values, will parse to Double later if needed
        let unit: String
        let status: String
        let category: String
        let normalRange: String
    }

    struct MedicationDTO: Codable {
        let name: String
        let dosage: String
        let frequency: String
        let instructions: String?
    }
    
    /// Analyze medical text to extract structured data
    func analyzeMedicalText(_ text: String) async throws -> MedicalAnalysisResult {
        print("🧠 [ChatService] Analyzing medical text with Gemini...")
        
        let url = URL(string: "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=\(geminiAPIKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Analyze the following medical text deeply and extract structured data.
        Return ONLY a valid JSON object with the following structure:
        {
            "reportType": "Type of report (e.g., Blood Test, Prescription, MRI, etc.)",
            "summary": "A concise, professional summary of the key findings (2-3 sentences).",
            "labResults": [
                {
                    "testName": "Name of the test (e.g., Hemoglobin)",
                    "value": "The numeric value or result string",
                    "unit": "The unit of measurement (e.g., g/dL)",
                    "status": "Normal, High, Low, or Abnormal",
                    "category": "Category (e.g., Blood, Lipid, Liver, Kidney, etc.)",
                    "normalRange": "The reference range provided"
                }
            ],
            "medications": [
                {
                    "name": "Name of the medication",
                    "dosage": "Dosage (e.g., 500mg)",
                    "frequency": "Frequency (e.g., Twice daily)",
                    "instructions": "Any specific instructions found"
                }
            ]
        }
        
        If a value is missing, use an empty string or null.
        Ensure "value" in labResults is just the number if possible, or the string representation if it's qualitative.
        
        Medical Text:
        \(text)
        """
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2, // Low temperature for consistent extraction
                "response_mime_type": "application/json"
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [ChatService] Analysis Error: \(errorText)")
                throw FirebaseError.processingFailed("Analysis failed: \(httpResponse.statusCode)")
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let textResponse = firstPart["text"] as? String,
                  let data = textResponse.data(using: .utf8) else {
                throw FirebaseError.processingFailed("Invalid analysis response")
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(MedicalAnalysisResult.self, from: data)
            
        } catch {
            print("❌ [ChatService] Analysis Network Error: \(error.localizedDescription)")
            throw error
        }
    }
}
