import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PDFKit)
import PDFKit
#endif

/// Service for extracting text from medical documents using Vision framework
class OCRService {
    // MARK: - Singleton
    static let shared = OCRService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    #if canImport(UIKit)
    /// Extract text from image using Vision OCR
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if recognizedText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: recognizedText)
                }
            }
            
            // Configure for accurate medical text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    #endif
    
    /// Extract specific medical values from text
    func extractMedicalValues(from text: String) -> [String: String] {
        var values: [String: String] = [:]
        
        // Common medical patterns
        let patterns: [String: String] = [
            "cholesterol": #"cholesterol[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#,
            "glucose": #"glucose[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#,
            "hemoglobin": #"hemoglobin[:\s]+(\d+\.?\d*)\s*(g/dL)?"#,
            "blood_pressure": #"(\d{2,3})/(\d{2,3})\s*mmHg"#,
            "heart_rate": #"heart rate[:\s]+(\d+)\s*bpm"#,
            "vitamin_d": #"vitamin\s*d[:\s]+(\d+\.?\d*)\s*(ng/mL)?"#
        ]
        
        for (key, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    if let valueRange = Range(match.range(at: 1), in: text) {
                        values[key] = String(text[valueRange])
                    }
                }
            }
        }
        
        return values
    }
    
    /// Detect report type from extracted text
    func detectReportType(from text: String) -> String {
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("blood test") || lowercasedText.contains("cbc") || lowercasedText.contains("hemoglobin") {
            return "Blood Test"
        } else if lowercasedText.contains("x-ray") || lowercasedText.contains("radiograph") {
            return "X-Ray"
        } else if lowercasedText.contains("mri") || lowercasedText.contains("magnetic resonance") {
            return "MRI"
        } else if lowercasedText.contains("prescription") || lowercasedText.contains("rx:") {
            return "Prescription"
        } else if lowercasedText.contains("lab") || lowercasedText.contains("laboratory") {
            return "Lab Report"
        } else {
            return "General Report"
        }
    }
    
    #if canImport(PDFKit)
    /// Extract text from PDF document
    func extractText(from pdfURL: URL) async throws -> String {
        guard let document = PDFDocument(url: pdfURL) else {
            throw OCRError.invalidPDF
        }
        
        guard document.pageCount > 0 else {
            throw OCRError.noTextFound
        }
        
        var extractedText = ""
        
        // Extract text from each page
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else {
                continue
            }
            
            extractedText += pageText
            extractedText += "\n\n" // Separate pages
        }
        
        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OCRError.noTextFound
        }
        
        return extractedText
    }
    #endif
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case invalidPDF
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .invalidPDF:
            return "Invalid PDF format or unable to read PDF"
        case .noTextFound:
            return "No text found in document"
        case .processingFailed:
            return "OCR processing failed"
        }
    }
}
