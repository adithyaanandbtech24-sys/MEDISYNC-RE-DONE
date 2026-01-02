// UploadDocumentView.swift
import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct UploadDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = UploadDocumentViewModel()
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var showPDFPicker = false
    @State private var documentTitle = ""
    
    var onUploadSuccess: (() -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Document Title")
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            TextField("e.g., Blood Test Nov 2024", text: $documentTitle)
                                .textFieldStyle(.roundedBorder)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Upload Options
                        VStack(spacing: 16) {
                            Text("Select Upload Method")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            // Image Upload Button
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upload Image")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Select from photo library")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.uploadBlue, Color.uploadBlue.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.uploadBlue.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal)
                            
                            // PDF Upload Button
                            Button {
                                showPDFPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Upload PDF")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Select PDF document")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.uploadPurple, Color.uploadPurple.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color.uploadPurple.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Preview Area
                        if let image = viewModel.selectedImage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Preview")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                                    .shadow(radius: 4)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Upload Progress
                        if viewModel.isUploading {
                            VStack(spacing: 12) {
                                ProgressView(value: viewModel.uploadProgress)
                                    .progressViewStyle(.linear)
                                    .tint(.appBlue)
                                
                                Text("Uploading... \(Int(viewModel.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Status Messages
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        if let success = viewModel.successMessage {
                            Text(success)
                                .font(.callout)
                                .foregroundColor(.green)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        
                        // Upload Button
                        if viewModel.selectedImage != nil && !documentTitle.isEmpty {
                            Button {
                                Task {
                                    await viewModel.uploadDocument(context: modelContext)
                                    if viewModel.successMessage != nil {
                                        // Auto-dismiss after 1.5 seconds on success
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            dismiss()
                                            onUploadSuccess?()
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Upload Document")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(16)
                            }
                            .disabled(viewModel.isUploading)
                            .opacity(viewModel.isUploading ? 0.6 : 1.0)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Upload Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPDFPicker) {
                DocumentPicker { url in
                    documentTitle = url.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
                    Task {
                        await viewModel.uploadPDF(url: url, context: modelContext)
                        if viewModel.successMessage != nil {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                                onUploadSuccess?()
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedImage) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.selectImage(image)
                        viewModel.documentTitle = documentTitle
                    }
                }
            }
            .onChange(of: documentTitle) { _, newTitle in
                viewModel.documentTitle = newTitle
            }
        }
    }
}

// MARK: - Document Picker for PDFs

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            onPick(url)
        }
    }
}
