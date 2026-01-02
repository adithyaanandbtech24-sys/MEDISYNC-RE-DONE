// UploadDocumentViewModel.swift
import SwiftUI
import SwiftData
import PhotosUI
import Combine

@MainActor
class UploadDocumentViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var documentTitle: String = ""
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canUpload: Bool = true
    
    private let reportService = ReportService.shared
    private let roleService = UserRoleService.shared
    private let authService = FirebaseAuthService.shared
    
    // MARK: - Initialization
    
    func checkUploadPermissions(patientUid: String? = nil) async {
        do {
            let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
            userRole = try await roleService.getCurrentUserRole()
            canUpload = try await roleService.canWritePatientData(patientUid: targetUid)
            
            if !canUpload {
                errorMessage = "You don't have permission to upload documents for this patient."
            }
        } catch {
            errorMessage = "Failed to check permissions: \(error.localizedDescription)"
            canUpload = false
        }
    }
    
    // MARK: - Image Selection
    
    func selectImage(_ image: UIImage) {
        selectedImage = image
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Upload
    
    func uploadDocument(context: ModelContext) async {
        guard canUpload else {
            errorMessage = "You don't have permission to upload documents."
            return
        }
        
        guard let image = selectedImage else {
            errorMessage = "Please select an image first"
            return
        }
        
        guard !documentTitle.isEmpty else {
            errorMessage = "Please enter a document title"
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        
        do {
            // Process and upload the document
            _ = try await reportService.processImageReport(
                image: image,
                title: documentTitle,
                context: context
            )
            
            uploadProgress = 1.0
            successMessage = "Document uploaded successfully!"
            
            // Clear form
            selectedImage = nil
            documentTitle = ""
            
        } catch {
            if let firestoreError = error as? FirestoreError {
                errorMessage = firestoreError.localizedDescription
            } else {
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
        
        isUploading = false
    }
    
    func uploadPDF(url: URL, context: ModelContext) async {
        guard canUpload else {
            errorMessage = "You don't have permission to upload documents."
            return
        }
        
        guard !documentTitle.isEmpty else {
            errorMessage = "Please enter a document title"
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadProgress = 0.0
        
        do {
            // Process and upload PDF
            _ = try await reportService.processPDFReport(
                fileURL: url,
                title: documentTitle,
                context: context
            )
            
            uploadProgress = 1.0
            successMessage = "PDF uploaded successfully!"
            
            // Clear form
            documentTitle = ""
            
        } catch {
            if let firestoreError = error as? FirestoreError {
                errorMessage = firestoreError.localizedDescription
            } else {
                errorMessage = "Upload failed: \(error.localizedDescription)"
            }
        }
        
        isUploading = false
    }
    
    // MARK: - Role-Based Checks
    
    func canUploadForPatient() -> Bool {
        return userRole == .patient || (userRole == .provider && canUpload)
    }
}
