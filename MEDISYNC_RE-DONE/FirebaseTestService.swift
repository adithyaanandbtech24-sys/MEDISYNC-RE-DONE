// FirebaseTestService.swift
import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

/// Simple test service to verify Firebase connectivity
final class FirebaseTestService {
    static let shared = FirebaseTestService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Firestore Tests
    
    /// Test writing a document to Firestore
    func testFirestoreWrite() async throws -> String {
        let testData: [String: Any] = [
            "testField": "Hello Firebase",
            "timestamp": Timestamp(date: Date()),
            "number": 42
        ]
        
        let docRef = db.collection("test").document("connectivity_test")
        try await docRef.setData(testData)
        
        return "✅ Firestore write successful! Check Firebase Console under 'test/connectivity_test'"
    }
    
    /// Test reading a document from Firestore
    func testFirestoreRead() async throws -> String {
        let docRef = db.collection("test").document("connectivity_test")
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists, let data = snapshot.data() else {
            throw NSError(domain: "FirebaseTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document not found. Run testFirestoreWrite() first."])
        }
        
        let testField = data["testField"] as? String ?? "N/A"
        return "✅ Firestore read successful! Data: \(testField)"
    }
    
    // MARK: - Storage Tests
    
    /// Test uploading an image to Firebase Storage
    func testStorageUpload() async throws -> String {
        // Create a simple test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.blue.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let image = testImage, let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "FirebaseTest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create test image"])
        }
        
        let storageRef = storage.reference().child("test/test_image.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return "✅ Storage upload successful! URL: \(downloadURL.absoluteString)"
    }
    
    /// Test downloading a file from Firebase Storage
    func testStorageDownload() async throws -> String {
        let storageRef = storage.reference().child("test/test_image.jpg")
        
        // Download to memory
        let maxSize: Int64 = 1 * 1024 * 1024 // 1MB
        let data = try await storageRef.data(maxSize: maxSize)
        
        return "✅ Storage download successful! Downloaded \(data.count) bytes"
    }
    
    // MARK: - Run All Tests
    
    /// Run all connectivity tests
    func runAllTests() async -> [String] {
        var results: [String] = []
        
        // Test 1: Firestore Write
        do {
            let result = try await testFirestoreWrite()
            results.append(result)
        } catch {
            results.append("❌ Firestore write failed: \(error.localizedDescription)")
        }
        
        // Test 2: Firestore Read
        do {
            let result = try await testFirestoreRead()
            results.append(result)
        } catch {
            results.append("❌ Firestore read failed: \(error.localizedDescription)")
        }
        
        // Test 3: Storage Upload
        do {
            let result = try await testStorageUpload()
            results.append(result)
        } catch {
            results.append("❌ Storage upload failed: \(error.localizedDescription)")
        }
        
        // Test 4: Storage Download
        do {
            let result = try await testStorageDownload()
            results.append(result)
        } catch {
            results.append("❌ Storage download failed: \(error.localizedDescription)")
        }
        
        return results
    }
}
