// FirestoreService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firebase Errors

enum FirestoreError: LocalizedError {
    case permissionDenied
    case unauthenticated
    case notFound
    case invalidData
    case networkError
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Access denied – you do not have permission to view this medical record."
        case .unauthenticated:
            return "Please sign in to access your medical records."
        case .notFound:
            return "The requested medical record was not found."
        case .invalidData:
            return "Invalid data format. Please try again."
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .unknown(let message):
            return "An error occurred: \(message)"
        }
    }
    
    var userMessage: String {
        return errorDescription ?? "An unknown error occurred."
    }
    
    static func from(_ error: Error) -> FirestoreError {
        let nsError = error as NSError
        
        // Check for Firestore-specific error codes
        if nsError.domain == "FIRFirestoreErrorDomain" {
            switch nsError.code {
            case 7: // PERMISSION_DENIED
                return .permissionDenied
            case 16: // UNAUTHENTICATED
                return .unauthenticated
            case 5: // NOT_FOUND
                return .notFound
            case 3: // INVALID_ARGUMENT
                return .invalidData
            case 14: // UNAVAILABLE
                return .networkError
            default:
                return .unknown(error.localizedDescription)
            }
        }
        
        return .unknown(error.localizedDescription)
    }
}

final class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private init() {}

    // Helper to get the current user's ID
    func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }

    // Create or set a document with a dictionary for a specific user
    func setDocument(userId: String, collection: String, id: String, data: [String: Any], merge: Bool = false, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).collection(collection).document(id).setData(data, merge: merge) { error in
            if let error = error {
                completion(FirestoreError.from(error))
            } else {
                completion(nil)
            }
        }
    }

    // Update fields of an existing document for a specific user
    func updateDocument(userId: String, collection: String, id: String, fields: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).collection(collection).document(id).updateData(fields) { error in
            if let error = error {
                completion(FirestoreError.from(error))
            } else {
                completion(nil)
            }
        }
    }

    // Get a single document for a specific user
    func getDocument<T: Decodable>(userId: String, collection: String, id: String, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        db.collection("users").document(userId).collection(collection).document(id).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(FirestoreError.from(error)))
                return
            }
            guard let snapshot = snapshot, snapshot.exists, let data = try? snapshot.data(as: T.self) else {
                completion(.failure(FirestoreError.notFound))
                return
            }
            completion(.success(data))
        }
    }

    // Get all documents in a collection for a specific user
    func getDocuments<T: Decodable>(userId: String, collection: String, as type: T.Type, completion: @escaping (Result<[T], Error>) -> Void) {
        db.collection("users").document(userId).collection(collection).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(FirestoreError.from(error)))
                return
            }
            guard let snapshot = snapshot else {
                completion(.failure(FirestoreError.notFound))
                return
            }
            let documents = snapshot.documents.compactMap { try? $0.data(as: T.self) }
            completion(.success(documents))
        }
    }

    // Delete a document for a specific user
    func deleteDocument(userId: String, collection: String, id: String, completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).collection(collection).document(id).delete { error in
            if let error = error {
                completion(FirestoreError.from(error))
            } else {
                completion(nil)
            }
        }
    }

    // Add a real-time listener for a collection
    func addRealtimeListener<T: Decodable>(userId: String, collection: String, as type: T.Type, onChange: @escaping ([T]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId).collection(collection).addSnapshotListener { snapshot, error in
            if let error = error {
                print("Listener error: \(FirestoreError.from(error).localizedDescription)")
                return
            }
            guard let snapshot = snapshot else { return }
            let documents = snapshot.documents.compactMap { try? $0.data(as: T.self) }
            onChange(documents)
        }
    }
}
