import SwiftUI
import Combine
import FirebaseAuth

enum AppFlowState {
    case prologue
    case auth
    case setup
    case main
}

@MainActor
final class AppManager: ObservableObject {
    static let shared = AppManager()
    
    // Published State
    @Published var appState: AppFlowState = .prologue
    @Published var isGuestMode: Bool = false
    
    // Guest Limits
    @AppStorage("guestUploadCount") var guestUploadCount: Int = 0
    private let guestUploadLimit = 3
    
    // Demo Mode (For "Any Email" login with unlimited uploads)
    @Published var isDemoMode: Bool = false
    
    @AppStorage("hasSeenPrologue") private var hasSeenPrologue: Bool = false
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        determineInitialState()
        
        // Listen for auth changes to handle transitions
        FirebaseAuthService.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.handleAuthChange(isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Logic
    
    func determineInitialState() {
        if !hasSeenPrologue {
            appState = .prologue
        } else if FirebaseAuthService.shared.isAuthenticated {
            // Check if setup is needed (could be improved with a flag on user profile)
            if hasCompletedSetup {
                appState = .main
            } else {
                appState = .setup
            }
        } else {
            // FORCE PROLOGUE for debugging/testing availability if not logged in
            // This ensures if the user skipped it somehow or state got messy, they see it now.
            // In a strict prod app we might keep .auth, but for this fix:
            hasSeenPrologue = false // RESET STATE
            appState = .prologue
        }
    }
    
    private func handleAuthChange(isAuthenticated: Bool) {
        if isAuthenticated {
            let user = Auth.auth().currentUser
            // If the user is authenticated but NOT anonymous, they are definitely NOT a guest
            if let user = user, !user.isAnonymous {
                isGuestMode = false
            } else if let user = user, user.isAnonymous {
                // If they are anonymous, they are likely in Guest mode
                isGuestMode = true
            }
            
            if hasCompletedSetup {
                appState = .main
            } else {
                appState = .setup
            }
        } else if !isGuestMode {
            // FORCE RESET FOR PROLOGUE DEBUGGING
            hasSeenPrologue = false
            appState = .prologue
        }
    }
    
    // MARK: - Actions
    
    func completePrologue() {
        hasSeenPrologue = true
        appState = .auth
    }
    
    func enterGuestMode() {
        isGuestMode = true
        isDemoMode = false
        // Guests must also go through setup now
        appState = .setup
    }
    
    func enterDemoMode() {
        // "Fake" Authenticated User
        isGuestMode = false // Unlimited uploads
        isDemoMode = true
        appState = .setup
    }
    
    func completeSetup() {
        hasCompletedSetup = true
        appState = .main
    }
    
    func signOut() {
        try? FirebaseAuthService.shared.signOut()
        isGuestMode = false
        appState = .auth
        // Note: We don't reset 'hasSeenPrologue'
    }
    
    func backToPrologue() {
        hasSeenPrologue = false
        appState = .prologue
    }
    
    func backToAuth() {
        isGuestMode = false
        appState = .auth
    }
    
    // MARK: - Guest Logic
    
    func canUploadInGuestMode() -> Bool {
        if !isGuestMode { return true }
        return guestUploadCount < guestUploadLimit
    }
    
    func incrementGuestUploadCount() {
        if isGuestMode {
            guestUploadCount += 1
        }
    }
    
    func checkGuestLimit() throws {
        if isGuestMode && guestUploadCount >= guestUploadLimit {
            throw AppError.guestLimitReached
        }
    }
}


enum AppError: LocalizedError {
    case guestLimitReached
    
    var errorDescription: String? {
        switch self {
        case .guestLimitReached:
            return "Guest upload limit reached."
        }
    }
}
