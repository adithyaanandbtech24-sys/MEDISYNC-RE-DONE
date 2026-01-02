// FirebaseAuthService.swift
import Foundation
import FirebaseAuth
import Combine

final class FirebaseAuthService: ObservableObject {
    static let shared = FirebaseAuthService()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: FirebaseAuth.User?
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State
    
    func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }
    
    var currentUserID: String? {
        return Auth.auth().currentUser?.uid
    }
    
    func getCurrentUserID() -> String? {
        return currentUserID
    }
    
    func getCurrentUser() -> FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> String {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user.uid
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // MARK: - Anonymous Sign In (for testing)
    
    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }
    
    /// Ensures a user is signed in, creating an anonymous account if needed
    /// Falls back to a local "guest" ID if Firebase Auth fails (e.g. if Anonymous Auth is disabled in console)
    func ensureAnonymousUser() async throws -> String {
        if let uid = currentUserID {
            return uid
        }
        
        do {
            return try await signInAnonymously()
        } catch {
            print("⚠️ [FirebaseAuthService] Anonymous sign-in failed: \(error.localizedDescription)")
            print("⚠️ [FirebaseAuthService] Falling back to local guest mode for development.")
            // Return a consistent guest ID for development/testing
            return "guest_user_id"
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
