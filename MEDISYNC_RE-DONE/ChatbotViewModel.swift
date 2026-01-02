// ChatbotViewModel.swift
import Foundation
import SwiftData
import Combine

@MainActor
class ChatbotViewModel: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var errorMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canChat: Bool = true
    
    // MARK: - Dependencies
    private let chatService = ChatService.shared
    private let roleService = UserRoleService.shared
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Public Methods
    
    func checkChatPermissions(patientUid: String? = nil) async {
        do {
            let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
            userRole = try await roleService.getCurrentUserRole()
            
            // Only patients can chat (providers can read but not send)
            canChat = userRole == .patient && targetUid == authService.getCurrentUserID()
            
            if !canChat && userRole == .provider {
                errorMessage = "Providers can view chat history but cannot send messages as the patient."
            } else if !canChat {
                errorMessage = "You don't have permission to chat."
            }
        } catch {
            errorMessage = "Failed to check permissions: \(error.localizedDescription)"
            canChat = false
        }
    }
    
    func loadChatHistory(context: ModelContext) async {
        do {
            // Load from Firestore and local SwiftData
            let firestoreMessages = try await chatService.loadChatHistory(context: context)
            
            // Also load from local SwiftData
            let descriptor = FetchDescriptor<AIChatMessage>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            let localMessages = try context.fetch(descriptor)
            
            // Merge and deduplicate
            let allMessages = Array(Set(firestoreMessages + localMessages))
                .sorted { $0.timestamp < $1.timestamp }
            
            messages = allMessages
            
        } catch {
            if let firestoreError = error as? FirestoreError {
                errorMessage = firestoreError.localizedDescription
            } else {
                errorMessage = "Failed to load chat history: \(error.localizedDescription)"
            }
        }
    }
    
    func sendMessage(_ text: String, context: ModelContext) async {
        guard canChat else {
            errorMessage = "You don't have permission to send messages."
            return
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isTyping = true
        errorMessage = nil
        
        do {
            let (userMsg, aiMsg) = try await chatService.sendAndReceive(
                userMessage: text,
                context: context
            )
            
            // Update local messages array
            messages.append(userMsg)
            messages.append(aiMsg)
            
        } catch {
            if let firestoreError = error as? FirestoreError {
                errorMessage = firestoreError.localizedDescription
            } else {
                errorMessage = "Failed to send message: \(error.localizedDescription)"
            }
        }
        
        isTyping = false
    }
    
    // MARK: - Role-Based Checks
    
    func canSendMessages() -> Bool {
        return canChat && userRole == .patient
    }
    
    func canViewHistory() -> Bool {
        // Patients and providers can view, family cannot
        return userRole == .patient || userRole == .provider
    }
}
