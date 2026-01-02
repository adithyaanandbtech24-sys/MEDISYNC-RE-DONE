// UserRoleService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// User roles in the system
enum UserRole: String, Codable {
    case patient = "PATIENT"
    case family = "FAMILY"
    case provider = "PROVIDER"
}

/// Service for managing user roles and access permissions
@MainActor
final class UserRoleService {
    static let shared = UserRoleService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    // Published properties for reactive UI
    @Published var currentUserRole: UserRole?
    @Published var activePatientId: String? // For providers switching between patients
    
    private init() {}
    
    // MARK: - Role Management
    
    /// Fetch user's role from Firestore
    func fetchUserRole(uid: String) async throws -> UserRole {
        let doc = try await db.collection("roles").document(uid).getDocument()
        
        guard let data = doc.data(),
              let roleString = data["role"] as? String,
              let role = UserRole(rawValue: roleString) else {
            // Default to PATIENT if no role set
            return .patient
        }
        
        return role
    }
    
    /// Set user's role (typically done on signup or by admin)
    func setUserRole(uid: String, role: UserRole) async throws {
        try await db.collection("roles").document(uid).setData([
            "role": role.rawValue,
            "createdAt": Timestamp(date: Date())
        ])
        
        // Update local cache
        if uid == auth.currentUser?.uid {
            currentUserRole = role
        }
    }
    
    /// Get current user's role
    func getCurrentUserRole() async throws -> UserRole {
        guard let uid = auth.currentUser?.uid else {
            throw NSError(domain: "UserRoleService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        if let cachedRole = currentUserRole {
            return cachedRole
        }
        
        let role = try await fetchUserRole(uid: uid)
        currentUserRole = role
        return role
    }
    
    // MARK: - Family Access Management
    
    /// Assign family member access to a patient
    /// - Parameters:
    ///   - patientUid: The patient's user ID
    ///   - familyUid: The family member's user ID
    ///   - familyName: Display name of family member
    ///   - relationship: Relationship to patient (e.g., "Spouse", "Child")
    func assignFamilyMember(
        patientUid: String,
        familyUid: String,
        familyName: String,
        relationship: String
    ) async throws {
        // Add family member to patient's family collection
        try await db.collection("users")
            .document(patientUid)
            .collection("family")
            .document(familyUid)
            .setData([
                "userId": familyUid,
                "name": familyName,
                "relationship": relationship,
                "grantedAt": Timestamp(date: Date()),
                "permissions": ["read"]
            ])
        
        // Set family member's role if not already set
        let familyRole = try? await fetchUserRole(uid: familyUid)
        if familyRole == nil {
            try await setUserRole(uid: familyUid, role: .family)
        }
    }
    
    /// Remove family member access
    func removeFamilyMember(patientUid: String, familyUid: String) async throws {
        try await db.collection("users")
            .document(patientUid)
            .collection("family")
            .document(familyUid)
            .delete()
    }
    
    /// Check if a family member has access to a patient's data
    func checkIfFamilyHasAccess(patientUid: String, familyUid: String) async throws -> Bool {
        let doc = try await db.collection("users")
            .document(patientUid)
            .collection("family")
            .document(familyUid)
            .getDocument()
        
        return doc.exists
    }
    
    /// Get all family members for a patient
    func getFamilyMembers(patientUid: String) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("users")
            .document(patientUid)
            .collection("family")
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    // MARK: - Provider Access Management
    
    /// Assign provider to a patient
    /// - Parameters:
    ///   - providerUid: The provider's user ID
    ///   - patientUid: The patient's user ID
    ///   - permissions: Array of permissions (e.g., ["read", "write"])
    func assignProviderToPatient(
        providerUid: String,
        patientUid: String,
        permissions: [String] = ["read", "write"]
    ) async throws {
        // Add patient to provider's patient list
        try await db.collection("providers")
            .document(providerUid)
            .collection("patients")
            .document(patientUid)
            .setData([
                "patientId": patientUid,
                "grantedAt": Timestamp(date: Date()),
                "permissions": permissions
            ])
        
        // Set provider's role if not already set
        let providerRole = try? await fetchUserRole(uid: providerUid)
        if providerRole == nil {
            try await setUserRole(uid: providerUid, role: .provider)
        }
    }
    
    /// Remove provider access to a patient
    func removeProviderFromPatient(providerUid: String, patientUid: String) async throws {
        try await db.collection("providers")
            .document(providerUid)
            .collection("patients")
            .document(patientUid)
            .delete()
    }
    
    /// Check if a provider has access to a patient's data
    func checkIfProviderHasAccess(providerUid: String, patientUid: String) async throws -> Bool {
        let doc = try await db.collection("providers")
            .document(providerUid)
            .collection("patients")
            .document(patientUid)
            .getDocument()
        
        return doc.exists
    }
    
    /// Get all patients assigned to a provider
    func getProviderPatients(providerUid: String) async throws -> [[String: Any]] {
        let snapshot = try await db.collection("providers")
            .document(providerUid)
            .collection("patients")
            .getDocuments()
        
        return snapshot.documents.map { $0.data() }
    }
    
    // MARK: - Access Control Helpers
    
    /// Check if current user can read data for a specific patient
    func canReadPatientData(patientUid: String) async throws -> Bool {
        guard let currentUid = auth.currentUser?.uid else {
            return false
        }
        
        // Owner can always read
        if currentUid == patientUid {
            return true
        }
        
        let role = try await getCurrentUserRole()
        
        switch role {
        case .patient:
            // Patients can only read their own data
            return currentUid == patientUid
            
        case .family:
            // Check if family member has access
            return try await checkIfFamilyHasAccess(patientUid: patientUid, familyUid: currentUid)
            
        case .provider:
            // Check if provider has access
            return try await checkIfProviderHasAccess(providerUid: currentUid, patientUid: patientUid)
        }
    }
    
    /// Check if current user can write data for a specific patient
    func canWritePatientData(patientUid: String) async throws -> Bool {
        guard let currentUid = auth.currentUser?.uid else {
            return false
        }
        
        // Owner can always write
        if currentUid == patientUid {
            return true
        }
        
        let role = try await getCurrentUserRole()
        
        switch role {
        case .patient:
            // Patients can only write their own data
            return currentUid == patientUid
            
        case .family:
            // Family members have read-only access
            return false
            
        case .provider:
            // Check if provider has write permission
            return try await checkIfProviderHasAccess(providerUid: currentUid, patientUid: patientUid)
        }
    }
    
    // MARK: - User Profile Management
    
    /// Create or update user profile
    func updateUserProfile(
        uid: String,
        displayName: String,
        email: String,
        role: UserRole
    ) async throws {
        try await db.collection("users").document(uid).setData([
            "displayName": displayName,
            "email": email,
            "role": role.rawValue,
            "createdAt": Timestamp(date: Date())
        ], merge: true)
        
        // Also update roles collection
        try await setUserRole(uid: uid, role: role)
    }
    
    /// Get user profile
    func getUserProfile(uid: String) async throws -> [String: Any] {
        let doc = try await db.collection("users").document(uid).getDocument()
        
        guard let data = doc.data() else {
            throw NSError(domain: "UserRoleService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        
        return data
    }
}
