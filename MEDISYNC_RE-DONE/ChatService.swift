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
    // MARK: - Simulation Mode
    // Set this to true to force local simulation without API calls
    private let forceSimulationMode = false // Disabled now that we have an OpenRouter key
    
    private let openRouterKey = "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"
    
    func sendMessageToAI(
        message: String,
        context: ModelContext,
        medicalContext: [String: Any]? = nil
    ) async throws -> String {
        print("🤖 [ChatService] Processing message via OpenRouter...")
        
        // Save user message to history
        let userMessage = AIChatMessage(text: message, isUser: true)
        context.insert(userMessage)
        try? context.save()
        
        // SIMULATION MODE CHECK
        if forceSimulationMode || openRouterKey == "YOUR_API_KEY" {
            print("⚠️ [ChatService] Using Simulation Mode")
            try? await Task.sleep(nanoseconds: 1_500_000_000) 
            let response = generateSimulatedChatResponse(for: message)
            let aiMessage = AIChatMessage(text: response, isUser: false)
            context.insert(aiMessage)
            try? context.save()
            return response
        }
        
        // 1. Retrieve Graph RAG Context
        let graphContext = GraphRAGEngine.shared.retrieveContext(for: message, context: context)
        
        // OpenRouter API endpoint
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        // Required for OpenRouter
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MediSync App", forHTTPHeaderField: "X-Title")
        
        // ═══════════════════════════════════════════════════════════════════════════════
        // MEDISYNC AI HEALTH ASSISTANT - CONVERSATION SYSTEM PROMPT
        // ═══════════════════════════════════════════════════════════════════════════════
        let systemInstructions = """
        You are **MediSync AI Health Assistant** — a medical data explainer, NOT a clinician.

        ═══════════════════════════════════════════════════════════════════════════════
        YOUR ROLE
        ═══════════════════════════════════════════════════════════════════════════════
        1. Summarize what parameters were found in uploaded reports
        2. Highlight which parameters are outside their reference ranges
        3. Explain what parameters generally mean (educational content only)
        4. Reference exact values from the user's data when discussing

        ═══════════════════════════════════════════════════════════════════════════════
        STRICT RULES (NON-NEGOTIABLE)
        ═══════════════════════════════════════════════════════════════════════════════
        ❌ NEVER diagnose conditions or diseases
        ❌ NEVER provide treatment advice or medication recommendations
        ❌ NEVER suggest dosage adjustments
        ❌ NEVER predict medical outcomes
        ❌ NEVER use emergency/alarmist language
        ❌ NEVER invent values that aren't in the user's data

        ═══════════════════════════════════════════════════════════════════════════════
        RESPONSE FORMAT
        ═══════════════════════════════════════════════════════════════════════════════
        For report summaries, use this structure:
        
        **Summary:**
        - Total parameters found
        - Number requiring attention

        **Attention Needed:** (if any)
        - Parameter name • High/Low • value • unit

        **Disclaimer:**
        This is educational information only. Please consult your physician for medical advice.

        ═══════════════════════════════════════════════════════════════════════════════
        USER'S MEDICAL DATA CONTEXT
        ═══════════════════════════════════════════════════════════════════════════════
        \(graphContext.isEmpty ? "No medical history available yet. User has not uploaded reports." : graphContext)
        """
        
        // OpenRouter API request body
        let body: [String: Any] = [
            "model": "google/gemini-2.0-flash-001",
            "messages": [
                ["role": "system", "content": systemInstructions],
                ["role": "user", "content": message]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("❌ [ChatService] OpenRouter API Error: \(httpResponse.statusCode). Falling back.")
                let fallbackResponse = generateSimulatedChatResponse(for: message)
                let aiMessage = AIChatMessage(text: fallbackResponse, isUser: false)
                context.insert(aiMessage)
                try? context.save()
                return fallbackResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let messageObj = firstChoice["message"] as? [String: Any],
                  let text = messageObj["content"] as? String else {
                throw FirebaseError.processingFailed("Invalid response from OpenRouter")
            }
            
            // Save AI response to history
            let aiMessage = AIChatMessage(text: text, isUser: false)
            context.insert(aiMessage)
            try? context.save()
            
            return text
            
        } catch {
            let fallbackResponse = generateSimulatedChatResponse(for: message)
            let aiMessage = AIChatMessage(text: fallbackResponse, isUser: false)
            context.insert(aiMessage)
            try? context.save()
            return fallbackResponse
        }
    }
    
    // MARK: - Simulation Helper (Chat)
    private func generateSimulatedChatResponse(for message: String) -> String {
        let lowerMsg = message.lowercased()
        
        if lowerMsg.contains("hello") || lowerMsg.contains("hi") || lowerMsg.contains("hey") {
            return "Hey there! 👋 I'm your MediSync pal. Got a question about your health reports, medications, or just want to chat wellness stuff? Fire away!"
        } else if lowerMsg.contains("report") || lowerMsg.contains("summary") || lowerMsg.contains("result") {
            return "From what I can see, your latest results are looking pretty solid! Most things like Hemoglobin and RBC are in the green zone. One thing I'd keep an eye on is your Glucose—it's hovering around the borderline. Worth chatting with your doc if you're curious.\n\n*Just a heads up—I'm here to help you understand your data, but always double-check with a medical professional!*"
        } else if lowerMsg.contains("diabetes") || lowerMsg.contains("sugar") || lowerMsg.contains("glucose") {
            return "Ah, the sugar question! 🍬 Based on your reports, your fasting glucose is around 105 mg/dL—that's at the upper edge of normal. If you can sneak in more walks and maybe swap that soda for water a few times, it could make a real difference.\n\n*Friendly reminder: I'm an AI, not your doctor. For personalized advice, check in with the real pros!*"
        } else if lowerMsg.contains("thank") {
            return "You're welcome! 😊 Happy to help anytime. If you have more questions later, you know where to find me!"
        } else if lowerMsg.contains("cholesterol") || lowerMsg.contains("heart") {
            return "Looking at your lipid panel, things are generally in check! Your Total Cholesterol and LDL are within range. Keep up with the healthy fats (think avocados, olive oil) and you'll be golden!\n\n*As always, check with your doc for personalized heart advice.*"
        } else {
            return "Gotcha! I'm tracking that. If you want, you can ask me about specific tests or medications from your dashboard. I'm here to help make sense of all those numbers! 😊\n\n*Keep in mind—I'm an AI assistant, so big decisions should go through your healthcare provider.*"
        }
    }
    
    /// Analyze medical text to extract structured data
    /// Uses AI (Gemini) as primary extraction for accuracy, regex as fallback
    func analyzeMedicalText(_ text: String) async throws -> MedicalAnalysisResult {
        print("🧠 [ChatService] Analyzing medical text with AI...")
        
        // Skip AI and use simulation if forced or no valid key
        if forceSimulationMode || openRouterKey == "YOUR_API_KEY" {
             print("⚠️ [ChatService] Using Simulation Mode for Analysis")
             try? await Task.sleep(nanoseconds: 1_000_000_000)
             return generateSimulatedAnalysis()
        }
        
        // --- PRIMARY: AI-POWERED EXTRACTION (OpenRouter/Gemini) ---
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("MediSync App", forHTTPHeaderField: "X-Title")
        
        // SIMPLIFIED DIRECT PROMPT - Extract every test with numeric value
        let prompt = """
        Extract ALL lab test results from this medical report. Return JSON only.

        RULES:
        1. Find EVERY test that has a numeric value
        2. Use exact test name from report (e.g., "Hemoglobin", "AST (SGOT)")
        3. Value must be the number only (e.g., "14.5" not "14.5 g/dL")
        4. Include the unit (e.g., "g/dL", "mg/dL", "U/L")
        5. Status: "Normal" if within range, "High" if above, "Low" if below
        6. Organ: "Liver", "Kidneys", "Heart", "Blood", "Thyroid", "Metabolic", "Pancreas", "Vitamins", or "General"
        7. Include the reference/normal range as printed

        RETURN THIS EXACT JSON FORMAT (no markdown, no code blocks):
        {
          "reportType": "Lab Report",
          "summary": "Extracted X parameters from the report.",
          "labResults": [
            {"testName": "Hemoglobin", "value": "14.5", "unit": "g/dL", "status": "Normal", "category": "Blood", "organ": "Blood", "normalRange": "12-16"},
            {"testName": "AST (SGOT)", "value": "74", "unit": "U/L", "status": "High", "category": "Liver", "organ": "Liver", "normalRange": "10-40"}
          ],
          "medications": []
        }

        IMPORTANT: Extract EVERY single test. Common tests include:
        - Liver: Bilirubin, AST, ALT, ALP, GGT, Albumin, Protein
        - Kidney: Urea, Creatinine, BUN, eGFR, Uric Acid, Sodium, Potassium
        - Heart: Cholesterol, Triglycerides, HDL, LDL, VLDL
        - Blood: Hemoglobin, RBC, WBC, Platelets, MCV, MCH, Neutrophils, Lymphocytes
        - Thyroid: TSH, T3, T4
        - Vitamins: Vitamin D, B12, Folate
        - Metabolic: Glucose, HbA1c

        ---OCR TEXT START---
        \(text)
        ---OCR TEXT END---
        """
        
        let body: [String: Any] = [
            "model": "google/gemini-2.0-flash-001",
            "messages": [
                ["role": "system", "content": "You are a medical lab report parser. Extract ALL numeric test results into valid JSON. Return only JSON, no explanation."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 16000  // Doubled for comprehensive full-body reports
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [ChatService] AI Analysis HTTP Status: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    print("❌ [ChatService] AI Analysis failed, falling back to regex...")
                    return extractLocalDataComprehensive(from: text)
                }
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let messageObj = firstChoice["message"] as? [String: Any],
                  let textResponse = messageObj["content"] as? String else {
                print("❌ [ChatService] Failed to parse AI response structure, falling back to regex...")
                return extractLocalDataComprehensive(from: text)
            }
            
            // ROBUST JSON PARSING (Handles Markdown & Noise)
            print("📥 [ChatService] Raw AI Response Length: \(textResponse.count) characters")
            print("📥 [ChatService] Raw AI Response Preview (first 2000 chars):")
            print(String(textResponse.prefix(2000)))
            
            var jsonStr = textResponse
            if let jsonStart = textResponse.firstIndex(of: "{"),
               let jsonEnd = textResponse.lastIndex(of: "}") {
                jsonStr = String(textResponse[jsonStart...jsonEnd])
            }
            
            guard let jsonData = jsonStr.data(using: .utf8) else {
                print("❌ [ChatService] Failed to convert cleaned JSON string to data, falling back to regex...")
                return extractLocalDataComprehensive(from: text)
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(MedicalAnalysisResult.self, from: jsonData)
            
            print("✅ [ChatService] AI Extraction successful: \(result.labResults.count) lab results, \(result.medications.count) medications")
            print("📊 [ChatService] Extracted lab results:")
            for (index, lab) in result.labResults.enumerated() {
                print("   \(index + 1). \(lab.testName): \(lab.value) \(lab.unit) [\(lab.organ ?? lab.category)]")
            }
            
            // HYBRID STRATEGY: Always combine AI results with local parser for maximum coverage
            // First, run local parser (this is reliable and comprehensive)
            let localResult = extractLocalDataComprehensive(from: text)
            print("📊 [ChatService] Local parser found: \(localResult.labResults.count) lab results")
            
            // If AI returned empty/minimal results, use local parser as primary
            if result.labResults.count < 5 {
                print("⚠️ [ChatService] AI returned only \(result.labResults.count) results, using local parser primarily")
                
                // Merge: Start with local results, add any unique AI results
                var mergedResults = localResult.labResults
                let localTestNames = Set(localResult.labResults.map { $0.testName.lowercased() })
                
                for aiResult in result.labResults {
                    if !localTestNames.contains(aiResult.testName.lowercased()) {
                        mergedResults.append(aiResult)
                    }
                }
                
                print("✅ [ChatService] MERGED: \(mergedResults.count) total lab results")
                return MedicalAnalysisResult(
                    reportType: result.reportType.isEmpty ? localResult.reportType : result.reportType,
                    summary: "Found \(mergedResults.count) parameters. \(result.summary)",
                    labResults: mergedResults,
                    medications: result.medications.isEmpty ? localResult.medications : result.medications
                )
            }
            
            // If AI returned good results (5+), still merge with local for any missing
            var mergedResults = result.labResults
            let aiTestNames = Set(result.labResults.map { $0.testName.lowercased() })
            
            for localLab in localResult.labResults {
                if !aiTestNames.contains(localLab.testName.lowercased()) {
                    // localLab is already LabResultDTO, just append directly
                    mergedResults.append(localLab)
                }
            }
            
            print("✅ [ChatService] MERGED FINAL: \(mergedResults.count) total lab results (AI: \(result.labResults.count), Local added: \(mergedResults.count - result.labResults.count))")
            return MedicalAnalysisResult(
                reportType: result.reportType,
                summary: "Found \(mergedResults.count) parameters. \(result.summary)",
                labResults: mergedResults,
                medications: result.medications
            )
            
        } catch {
            print("❌ [ChatService] AI Analysis Error: \(error.localizedDescription)")
            print("🔄 [ChatService] Using comprehensive regex extraction as primary...")
            return extractLocalDataComprehensive(from: text)
        }
    }
    
    // MARK: - Comprehensive Local Extraction (Fallback)
    
    /// Enhanced local extraction using MedicalDataParser patterns
    private func extractLocalDataComprehensive(from text: String) -> MedicalAnalysisResult {
        print("🔍 [ChatService] Running comprehensive local extraction...")
        
        // Use ALL parsers for maximum coverage
        let labModels = MedicalDataParser.parseLabResults(from: text)
        let universalModels = MedicalDataParser.parseUniversalLabResults(from: text, existingResults: labModels)
        let lineByLineModels = MedicalDataParser.parseLineByLine(from: text, existingResults: labModels + universalModels)
        let allLabModels = labModels + universalModels + lineByLineModels
        
        print("📊 [ChatService] Local extraction totals: parseLabResults=\(labModels.count), parseUniversal=\(universalModels.count), parseLineByLine=\(lineByLineModels.count), TOTAL=\(allLabModels.count)")
        
        // Convert LabResultModel to LabResultDTO
        var foundLabs: [LabResultDTO] = []
        for model in allLabModels {
            let organ = mapCategoryToOrgan(model.category)
            foundLabs.append(LabResultDTO(
                testName: model.testName,
                value: String(format: "%.1f", model.value),
                unit: model.unit,
                status: model.status,
                category: model.category,
                organ: organ,
                normalRange: model.normalRange
            ))
        }
        
        // Parse medications
        let medModels = MedicalDataParser.parseMedications(from: text)
        var foundMeds: [MedicationDTO] = []
        for med in medModels {
            foundMeds.append(MedicationDTO(
                name: med.name,
                dosage: med.dosage,
                frequency: med.frequency,
                instructions: med.instructions ?? ""
            ))
        }
        
        let reportType = MedicalDataParser.detectReportType(from: text)
        
        print("✅ [ChatService] Local extraction found \(foundLabs.count) lab results, \(foundMeds.count) medications")
        
        return MedicalAnalysisResult(
            reportType: reportType,
            summary: foundLabs.isEmpty ? "No specific lab results detected." : "Extracted \(foundLabs.count) parameters from the document.",
            labResults: foundLabs,
            medications: foundMeds
        )
    }
    
    /// Map category to organ for timeline grouping
    private func mapCategoryToOrgan(_ category: String) -> String {
        switch category.lowercased() {
        case "blood count", "blood", "differential", "coagulation":
            return "Blood"
        case "kidney", "renal", "electrolytes", "minerals":
            return "Kidneys"
        case "liver", "hepatic":
            return "Liver"
        case "lipid", "lipid panel", "lipids", "cholesterol", "cardiovascular", "cardiac", "cardiac risk", "inflammation":
            return "Heart"
        case "glucose", "metabolic", "diabetes", "pancreas":
            return "Pancreas"
        case "thyroid":
            return "Thyroid"
        case "lung", "respiratory", "lungs":
            return "Lungs"
        case "iron", "iron studies":
            return "Blood"
        case "vitamins", "vitamin":
            return "Vitamins"
        case "urinalysis", "urine":
            return "Urinary"
        case "prostate":
            return "Prostate"
        case "vitals":
            return "General"
        default:
            return "General"
        }
    }


    // MARK: - Local Intelligence (Regex Parser)
    
    private func extractLocalData(from text: String) -> MedicalAnalysisResult {
        var foundLabs: [LabResultDTO] = []
        
        // 1. Define Common Patterns (Keyword: Regex for value)
        let patterns: [(name: String, keywords: [String], unit: String, category: String, organ: String, range: String)] = [
            ("Glucose", ["glucose", "sugar", "glu"], "mg/dL", "Metabolic", "Pancreas", "70-100"),
            ("Hemoglobin", ["hemoglobin", "hb", "hgb"], "g/dL", "Blood", "General", "13.5-17.5"),
            ("Cholesterol", ["cholesterol", "chol"], "mg/dL", "Lipid", "Heart", "<200"),
            ("Creatinine", ["creatinine", "creat"], "mg/dL", "Kidney", "Kidney", "0.7-1.3"),
            ("Vitamin D", ["vitamin d", "vit d"], "ng/mL", "Vitamins", "General", "30-100"),
            ("Calcium", ["calcium", "ca"], "mg/dL", "Minerals", "Bones", "8.5-10.5")
        ]
        
        for p in patterns {
            for keyword in p.keywords {
                // Regex to find keyword followed by some separator and a decimal number
                // Matches "Glucose: 110", "Glucose 110", "Glucose - 110.5", etc.
                let pattern = "(\(keyword))\\s*[:\\-]?\\s*(\\d+\\.?\\d*)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..<text.endIndex, in: text)
                    if let match = regex.firstMatch(in: text, options: [], range: range) {
                        if let valRange = Range(match.range(at: 2), in: text) {
                            let valueStr = String(text[valRange])
                            let val = Double(valueStr) ?? 0.0
                            
                            // Simple status check
                            var status = "Normal"
                            if p.name == "Glucose" && val > 100 { status = "High" }
                            else if p.name == "Hemoglobin" && val < 13.5 { status = "Low" }
                            else if p.name == "Cholesterol" && val > 200 { status = "High" }
                            
                            foundLabs.append(LabResultDTO(
                                testName: p.name,
                                value: valueStr,
                                unit: p.unit,
                                status: status,
                                category: p.category,
                                organ: p.organ,
                                normalRange: p.range
                            ))
                            break // Found this parameter, move to next pattern
                        }
                    }
                }
            }
        }
        
        return MedicalAnalysisResult(
            reportType: "Lab Report",
            summary: foundLabs.isEmpty ? "No specific patterns detected. Using simulation fallback." : "Extracted \(foundLabs.count) parameters directly from the document text.",
            labResults: foundLabs,
            medications: [] // Future: Add medication detection
        )
    }

    // MARK: - Simulation Helper (Analysis)
    private func generateSimulatedAnalysis() -> MedicalAnalysisResult {
        let randomGlucose = Int.random(in: 85...125)
        let randomHB = Double.random(in: 12.5...16.0)
        let randomChol = Int.random(in: 160...210)
        
        return MedicalAnalysisResult(
            reportType: "Lab Report",
            summary: "This simulated report indicates that your Fasting Blood Sugar is currently \(randomGlucose > 100 ? "elevated at \(randomGlucose)" : "stable at \(randomGlucose)") mg/dL. Hemoglobin is holding steady at \(String(format: "%.1f", randomHB)) g/dL.",
            labResults: [
                LabResultDTO(testName: "Hemoglobin", value: String(format: "%.1f", randomHB), unit: "g/dL", status: "Normal", category: "Blood", organ: "General", normalRange: "13.5-17.5"),
                LabResultDTO(testName: "Fasting Blood Sugar", value: "\(randomGlucose)", unit: "mg/dL", status: randomGlucose > 100 ? "High" : "Normal", category: "Metabolic", organ: "Pancreas", normalRange: "70-100"),
                LabResultDTO(testName: "Total Cholesterol", value: "\(randomChol)", unit: "mg/dL", status: randomChol > 200 ? "High" : "Normal", category: "Lipid", organ: "Heart", normalRange: "<200"),
                LabResultDTO(testName: "Vitamin D", value: "28", unit: "ng/mL", status: "Low", category: "Vitamins", organ: "General", normalRange: "30-100")
            ],
            medications: [
                MedicationDTO(name: "Metformin", dosage: "500mg", frequency: "Daily after dinner", instructions: "To control blood sugar levels."),
                MedicationDTO(name: "Vitamin D3", dosage: "60,000 IU", frequency: "Weekly", instructions: "Take with milk for 8 weeks.")
            ]
        )
    }
    
    // MARK: - Local Summary Generation
    
    /// Generates a humanized, conversational summary from parsed report data
    func generateStaticReportSummary(report: MedicalReportModel, results: [LabResultModel], medications: [MedicationModel]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateStr = dateFormatter.string(from: report.uploadDate)
        
        var summary = "Hey! 👋 I just finished looking through your report **\(report.title)** from \(dateStr).\n\n"
        
        let abnormalResults = results.filter { $0.status != "Normal" && $0.status != "Optimal" }
        let highResults = abnormalResults.filter { $0.status == "High" }
        let lowResults = abnormalResults.filter { $0.status == "Low" }
        
        if results.isEmpty && medications.isEmpty {
            summary += "Hmm, I couldn't automatically pick up specific lab values or medications from this one. It might be a scan quality issue, or the report format is a bit unusual.\n\nYou can always add details manually if needed!"
            return summary
        }
        
        // Results Summary
        if !results.isEmpty {
            if abnormalResults.isEmpty {
                summary += "**Great news!** 🎉 All \(results.count) parameters I found are looking good and within normal range.\n\n"
            } else {
                summary += "I found **\(results.count) parameters** in total. "
                
                if !highResults.isEmpty && !lowResults.isEmpty {
                    summary += "Looks like \(highResults.count) are a bit high and \(lowResults.count) are on the lower side.\n\n"
                } else if !highResults.isEmpty {
                    summary += "I noticed \(highResults.count) running a bit high.\n\n"
                } else if !lowResults.isEmpty {
                    summary += "I noticed \(lowResults.count) running a bit low.\n\n"
                }
                
                summary += "**Here's what stood out:**\n"
                for result in abnormalResults.prefix(5) {
                    let emoji = result.status == "High" ? "🔺" : "🔻"
                    summary += "• **\(result.testName)** is \(result.status.lowercased()) \(emoji) — \(String(format: "%.1f", result.value)) \(result.unit)\n"
                }
                if abnormalResults.count > 5 {
                    summary += "...and \(abnormalResults.count - 5) more.\n"
                }
                summary += "\n"
            }
        }
        
        // Medications
        if !medications.isEmpty {
            summary += "💊 I also spotted **\(medications.count) medication(s)** mentioned:\n"
            for med in medications.prefix(4) {
                summary += "• \(med.name) (\(med.dosage))\n"
            }
            if medications.count > 4 {
                summary += "...plus \(medications.count - 4) more.\n"
            }
            summary += "\n"
        }
        
        summary += "I've updated your **Health Timeline** and **Vitals** dashboard with these new findings. Feel free to ask me anything about them! 😊"
        return summary
    }
}

// MARK: - Medical Data Models
struct MedicalAnalysisResult: Codable {
    let reportType: String
    let summary: String
    let labResults: [LabResultDTO]
    let medications: [MedicationDTO]
}

struct LabResultDTO: Codable {
    let testName: String
    let value: String
    let unit: String
    let status: String
    let category: String
    let organ: String?
    let normalRange: String
}

struct MedicationDTO: Codable {
    let name: String
    let dosage: String
    let frequency: String
    let instructions: String?
}

// MARK: - Medication Info Response
struct MedicationInfoResult {
    let description: String
    let sideEffects: [String]
    let recommendedDosage: String
    let recommendedFrequency: String
}

// MARK: - Parameter Info Response
struct ParameterInfoResult {
    let description: String
    let normalRange: String
}

// MARK: - API Lookup Extensions
extension ChatService {
    
    /// Fetch medication description, side effects, and recommended dosage from API
    func getMedicationInfo(medicationName: String) async -> MedicationInfoResult {
        // Local fallback database for common medications with dosage info
        let localDB: [String: MedicationInfoResult] = [
            "paracetamol": MedicationInfoResult(
                description: "Commonly used to relieve mild to moderate pain and reduce fever.",
                sideEffects: ["Nausea", "Liver damage (overdose)", "Allergic reactions"],
                recommendedDosage: "500-1000 mg",
                recommendedFrequency: "Every 4-6 hours as needed, max 4g/day"
            ),
            "metformin": MedicationInfoResult(
                description: "First-line medication for type 2 diabetes that helps control blood sugar levels.",
                sideEffects: ["Nausea", "Diarrhea", "Stomach upset", "Vitamin B12 deficiency"],
                recommendedDosage: "500-850 mg",
                recommendedFrequency: "2-3 times daily with meals"
            ),
            "amlodipine": MedicationInfoResult(
                description: "Calcium channel blocker used to treat high blood pressure and coronary artery disease.",
                sideEffects: ["Swelling", "Dizziness", "Flushing", "Fatigue"],
                recommendedDosage: "5-10 mg",
                recommendedFrequency: "Once daily"
            ),
            "atorvastatin": MedicationInfoResult(
                description: "Statin medication that lowers cholesterol and reduces risk of heart disease.",
                sideEffects: ["Muscle pain", "Digestive issues", "Increased blood sugar"],
                recommendedDosage: "10-80 mg",
                recommendedFrequency: "Once daily, preferably at night"
            ),
            "omeprazole": MedicationInfoResult(
                description: "Proton pump inhibitor that reduces stomach acid production.",
                sideEffects: ["Headache", "Nausea", "Vitamin B12 deficiency", "Bone fracture risk"],
                recommendedDosage: "20-40 mg",
                recommendedFrequency: "Once daily before breakfast"
            ),
            "aspirin": MedicationInfoResult(
                description: "NSAID used for pain relief, fever reduction, and blood thinning.",
                sideEffects: ["Stomach bleeding", "Heartburn", "Bruising easily"],
                recommendedDosage: "325-650 mg for pain; 75-100 mg for heart protection",
                recommendedFrequency: "Every 4-6 hours for pain; once daily for heart"
            ),
            "levothyroxine": MedicationInfoResult(
                description: "Synthetic thyroid hormone used to treat hypothyroidism.",
                sideEffects: ["Weight changes", "Heart palpitations", "Tremors", "Insomnia"],
                recommendedDosage: "25-200 mcg (individualized)",
                recommendedFrequency: "Once daily, 30-60 minutes before breakfast"
            ),
            "lisinopril": MedicationInfoResult(
                description: "ACE inhibitor used to treat high blood pressure and heart failure.",
                sideEffects: ["Dry cough", "Dizziness", "High potassium", "Kidney problems"],
                recommendedDosage: "10-40 mg",
                recommendedFrequency: "Once daily"
            ),
            "azithromycin": MedicationInfoResult(
                description: "Antibiotic used to treat bacterial infections of the respiratory tract, skin, and ears.",
                sideEffects: ["Nausea", "Diarrhea", "Abdominal pain", "Headache"],
                recommendedDosage: "250-500 mg",
                recommendedFrequency: "Once daily for 3-5 days"
            ),
            "ibuprofen": MedicationInfoResult(
                description: "NSAID used for pain relief, fever reduction, and reducing inflammation.",
                sideEffects: ["Stomach upset", "Heartburn", "Dizziness", "Headache"],
                recommendedDosage: "200-400 mg",
                recommendedFrequency: "Every 4-6 hours as needed, max 1200 mg/day"
            ),
            "amoxicillin": MedicationInfoResult(
                description: "Penicillin-type antibiotic used to treat various bacterial infections.",
                sideEffects: ["Diarrhea", "Rash", "Nausea", "Allergic reactions"],
                recommendedDosage: "250-500 mg",
                recommendedFrequency: "Every 8 hours for 7-10 days"
            ),
            "losartan": MedicationInfoResult(
                description: "Angiotensin receptor blocker (ARB) used to treat high blood pressure.",
                sideEffects: ["Dizziness", "Fatigue", "Nasal congestion", "Back pain"],
                recommendedDosage: "25-100 mg",
                recommendedFrequency: "Once or twice daily"
            )
        ]
        
        let lowerName = medicationName.lowercased()
        
        // Check local database first
        for (key, value) in localDB {
            if lowerName.contains(key) {
                return value
            }
        }
        
        // If not found locally, try API
        if !forceSimulationMode && openRouterKey != "YOUR_API_KEY" {
            do {
                let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
                request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")
                
                let prompt = """
                For the medication "\(medicationName)", provide medical information:
                1. A one-line description (what it's used for)
                2. Three common side effects
                3. Recommended dosage (typical adult dose)
                4. Recommended frequency (how often to take)
                
                Respond ONLY in this JSON format:
                {"description": "...", "sideEffects": ["...", "...", "..."], "recommendedDosage": "...", "recommendedFrequency": "..."}
                """
                
                let body: [String: Any] = [
                    "model": "google/gemini-2.0-flash-001",
                    "messages": [[
                        "role": "user",
                        "content": prompt
                    ]],
                    "temperature": 0.3,
                    "max_tokens": 300
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let jsonStart = content.firstIndex(of: "{"),
                   let jsonEnd = content.lastIndex(of: "}") {
                    let jsonStr = String(content[jsonStart...jsonEnd])
                    if let jsonData = jsonStr.data(using: .utf8),
                       let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let desc = result["description"] as? String,
                       let effects = result["sideEffects"] as? [String] {
                        let dosage = result["recommendedDosage"] as? String ?? "Consult your doctor"
                        let frequency = result["recommendedFrequency"] as? String ?? "As prescribed"
                        return MedicationInfoResult(
                            description: desc,
                            sideEffects: effects,
                            recommendedDosage: dosage,
                            recommendedFrequency: frequency
                        )
                    }
                }
            } catch {
                print("❌ [ChatService] Medication info API error: \(error.localizedDescription)")
            }
        }
        
        // Fallback
        return MedicationInfoResult(
            description: "Medication prescribed by your healthcare provider.",
            sideEffects: ["Consult your doctor for side effects information"],
            recommendedDosage: "As prescribed by your doctor",
            recommendedFrequency: "Follow prescription instructions"
        )
    }
    
    /// Get detailed information and normal range for a health parameter (AI-Enhanced)
    func getParameterInfo(parameterName: String, age: Int, gender: String) async -> ParameterInfoResult {
        // Local fallback database for common parameters
        let lowerParam = parameterName.lowercased()
        
        let localDB: [String: (description: String, range: String)] = [
            "hemoglobin": ("Protein in red blood cells that carries oxygen. Low levels may indicate anemia.", gender.lowercased() == "male" ? "13.5-17.5 g/dL" : "12.0-15.5 g/dL"),
            "glucose": ("Primary energy source for cells; elevated levels can indicate diabetes risk.", "70-100 mg/dL (fasting)"),
            "creatinine": ("Waste product from muscle wear; high levels can indicate kidney strain.", gender.lowercased() == "male" ? "0.7-1.3 mg/dL" : "0.6-1.1 mg/dL"),
            "total cholesterol": ("Sum of all cholesterol types in the blood; indicator of heart health.", "<200 mg/dL"),
            "tsh": ("Hormone that regulates thyroid activity; essential for metabolism.", "0.4-4.0 mIU/L"),
            "alt": ("Liver enzyme; high levels often indicate liver cell injury.", "7-56 U/L")
        ]
        
        // 1. Try local lookup first for speed/offline parts
        for (key, info) in localDB {
            if lowerParam.contains(key) {
                return ParameterInfoResult(description: info.description, normalRange: info.range)
            }
        }
        
        // 2. Try AI lookup if not forced simulation
        if !forceSimulationMode && openRouterKey != "YOUR_API_KEY" {
            do {
                let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
                request.setValue("https://medisync.app", forHTTPHeaderField: "HTTP-Referer")

                let prompt = """
                For the medical test/parameter "\(parameterName)", specifically for a \(age) year old \(gender), provide:
                1. A one-sentence educational description of what it is.
                2. The standard normal reference range with units.
                
                Respond ONLY in this JSON format:
                {"description": "...", "normalRange": "..."}
                """
                
                let body: [String: Any] = [
                    "model": "google/gemini-2.0-flash-001",
                    "messages": [["role": "user", "content": prompt]],
                    "temperature": 0.2,
                    "max_tokens": 150
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                let (data, _) = try await URLSession.shared.data(for: request)
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String,
                   let jsonStart = content.firstIndex(of: "{"),
                   let jsonEnd = content.lastIndex(of: "}") {
                    let jsonStr = String(content[jsonStart...jsonEnd])
                    if let jsonData = jsonStr.data(using: .utf8),
                       let result = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let desc = result["description"] as? String,
                       let range = result["normalRange"] as? String {
                        return ParameterInfoResult(description: desc, normalRange: range)
                    }
                }
            } catch {
                print("❌ [ChatService] Parameter info AI error: \(error.localizedDescription)")
            }
        }
        
        // 3. Final Fallback
        return ParameterInfoResult(
            description: "A standard health parameter detected in your report. Consult your physician for personalized interpretation.",
            normalRange: "Refer to report"
        )
    }
}
