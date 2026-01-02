import Foundation

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case uploadFailed(String)
    case processingFailed(String)
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
