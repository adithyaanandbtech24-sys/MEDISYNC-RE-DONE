// StorageService.swift
import Foundation
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(UIKit)
import UIKit
#endif

final class StorageService {
    static let shared = StorageService()
    
    #if canImport(FirebaseStorage)
    private let storage = Storage.storage()
    #endif
    
    private init() {}

    /// Upload a PDF file to Firebase Storage under the user's folder.
    /// - Parameters:
    ///   - userId: Current user's UID.
    ///   - reportId: Identifier for the report (used as folder name).
    ///   - fileURL: Local URL of the PDF.
    ///   - progressHandler: Called with a 0‑1 progress value.
    /// - Returns: Download URL string.
    func uploadPDF(userId: String, reportId: String, fileURL: URL, progressHandler: @escaping (Double) -> Void) async throws -> String {
        let storageRef = storage.reference().child("users/\(userId)/reports/\(reportId)/document.pdf")
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        return try await uploadFile(to: storageRef, fileURL: fileURL, metadata: metadata, progressHandler: progressHandler)
    }

    /// Upload an image (UIImage) to local storage (development mode).
    func uploadImage(userId: String, reportId: String, image: UIImage, progressHandler: @escaping (Double) -> Void) async throws -> String {
        // For development: Save to local documents directory instead of Firebase
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert image to JPEG data"])
        }
        
        // Create local directory structure
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userPath = documentsPath.appendingPathComponent("users/\(userId)/reports/\(reportId)")
        
        try FileManager.default.createDirectory(at: userPath, withIntermediateDirectories: true)
        
        let imagePath = userPath.appendingPathComponent("image.jpg")
        
        // Save image data
        try data.write(to: imagePath)
        
        // Simulate progress
        progressHandler(1.0)
        
        // Return local file path as URL string
        return imagePath.absoluteString
    }

    /// Delete a file at the given path.
    func deleteFile(at path: String) async throws {
        let ref = storage.reference(withPath: path)
        try await ref.delete()
    }

    /// Retrieve a download URL for a given storage path.
    func getDownloadURL(for path: String) async throws -> URL {
        let ref = storage.reference(withPath: path)
        return try await ref.downloadURL()
    }

    // MARK: - Private helpers
    private func uploadFile(to ref: StorageReference, fileURL: URL, metadata: StorageMetadata, progressHandler: @escaping (Double) -> Void) async throws -> String {
        let uploadTask = ref.putFile(from: fileURL, metadata: metadata)
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask.observe(.progress) { snapshot in
                let percent = Double(snapshot.progress?.fractionCompleted ?? 0)
                progressHandler(percent)
            }
            uploadTask.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else if let url = url { continuation.resume(returning: url.absoluteString) }
                }
            }
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error { continuation.resume(throwing: error) }
            }
        }
    }

    private func uploadData(to ref: StorageReference, data: Data, metadata: StorageMetadata, progressHandler: @escaping (Double) -> Void) async throws -> String {
        let uploadTask = ref.putData(data, metadata: metadata)
        return try await withCheckedThrowingContinuation { continuation in
            uploadTask.observe(.progress) { snapshot in
                let percent = Double(snapshot.progress?.fractionCompleted ?? 0)
                progressHandler(percent)
            }
            uploadTask.observe(.success) { _ in
                ref.downloadURL { url, error in
                    if let error = error { continuation.resume(throwing: error) }
                    else if let url = url { continuation.resume(returning: url.absoluteString) }
                }
            }
            uploadTask.observe(.failure) { snapshot in
                if let error = snapshot.error { continuation.resume(throwing: error) }
            }
        }
    }
}
