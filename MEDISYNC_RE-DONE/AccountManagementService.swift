// AccountManagementService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for managing account relationships and access
@MainActor
final class AccountManagementService {
    static let shared = AccountManagementService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let roleService = UserRoleService.shared
    
    private init() {}
    
    // MARK: - Family Member Management
    
    /// Add family member by email
    /// - Parameters:
    ///   - email: Family member's email address
    ///   - name: Display name
    ///   - relationship: Relationship to patient
    func addFamilyMemberByEmail(
        email: String,
        name: String,
        relationship: String
    ) async throws -> String {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Find user by email (requires Cloud Function in production)
        // For now, we'll use a simplified approach
        let usersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()
        
        guard let familyUserDoc = usersQuery.documents.first else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User with email \(email) not found"])
        }
        
        let familyUid = familyUserDoc.documentID
        
        // Grant access
        try await roleService.assignFamilyMember(
            patientUid: currentUid,
            familyUid: familyUid,
            familyName: name,
            relationship: relationship
        )
        
        return familyUid
    }
    
    /// Remove family member access
    func removeFamilyMember(familyUid: String) async throws {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await roleService.removeFamilyMember(
            patientUid: currentUid,
            familyUid: familyUid
        )
    }
    
    /// Get list of family members
    func getFamilyMembers() async throws -> [FamilyMember] {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let familyData = try await roleService.getFamilyMembers(patientUid: currentUid)
        
        return familyData.compactMap { data in
            guard let userId = data["userId"] as? String,
                  let name = data["name"] as? String,
                  let relationship = data["relationship"] as? String,
                  let grantedAt = data["grantedAt"] as? Timestamp else {
                return nil
            }
            
            return FamilyMember(
                userId: userId,
                name: name,
                relationship: relationship,
                grantedAt: grantedAt.dateValue()
            )
        }
    }
    
    // MARK: - Provider Management
    
    /// Assign provider to current patient
    func assignProvider(providerEmail: String) async throws -> String {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Find provider by email
        let providersQuery = try await db.collection("users")
            .whereField("email", isEqualTo: providerEmail)
            .whereField("role", isEqualTo: "PROVIDER")
            .limit(to: 1)
            .getDocuments()
        
        guard let providerDoc = providersQuery.documents.first else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Provider with email \(providerEmail) not found"])
        }
        
        let providerUid = providerDoc.documentID
        
        // Grant provider access
        try await roleService.assignProviderToPatient(
            providerUid: providerUid,
            patientUid: currentUid,
            permissions: ["read", "write"]
        )
        
        return providerUid
    }
    
    /// Remove provider access
    func removeProvider(providerUid: String) async throws {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        try await roleService.removeProviderFromPatient(
            providerUid: providerUid,
            patientUid: currentUid
        )
    }
    
    // MARK: - Provider Patient Management
    
    /// Get list of patients (for providers)
    func getProviderPatients() async throws -> [PatientInfo] {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Verify user is a provider
        let role = try await roleService.getCurrentUserRole()
        guard role == .provider else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Only providers can access patient list"])
        }
        
        let patientsData = try await roleService.getProviderPatients(providerUid: currentUid)
        
        var patients: [PatientInfo] = []
        
        for data in patientsData {
            guard let patientId = data["patientId"] as? String else { continue }
            
            // Fetch patient profile
            if let profile = try? await roleService.getUserProfile(uid: patientId) {
                let patient = PatientInfo(
                    userId: patientId,
                    displayName: profile["displayName"] as? String ?? "Unknown",
                    email: profile["email"] as? String ?? "",
                    assignedAt: (data["grantedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
                patients.append(patient)
            }
        }
        
        return patients
    }
    
    /// Switch active patient (for providers)
    func switchActivePatient(patientUid: String) async throws {
        guard let currentUid = auth.currentUser?.uid else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Verify provider has access
        let hasAccess = try await roleService.checkIfProviderHasAccess(
            providerUid: currentUid,
            patientUid: patientUid
        )
        
        guard hasAccess else {
            throw NSError(domain: "AccountManagement", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "You don't have access to this patient"])
        }
        
        // Update active patient
        roleService.activePatientId = patientUid
    }
}

// MARK: - Supporting Models

struct FamilyMember {
    let userId: String
    let name: String
    let relationship: String
    let grantedAt: Date
}

struct PatientInfo {
    let userId: String
    let displayName: String
    let email: String
    let assignedAt: Date
}
