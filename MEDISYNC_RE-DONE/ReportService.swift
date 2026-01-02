// ReportService.swift
import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
import VisionKit

/// Service for processing medical reports with OCR and ML
@MainActor
final class ReportService {
    static let shared = ReportService()
    
    private let storage = StorageService.shared
    private let firestore = FirestoreService.shared
    private let auth = FirebaseAuthService.shared
    private let ocrService = OCRService.shared
    private let mlService = MLService.shared
    
    private init() {}
    
    // MARK: - Document Processing Pipeline
    
    /// Process and upload an image-based medical report
    func processImageReport(
        image: UIImage,
        title: String,
        context: ModelContext
    ) async throws -> MedicalReportModel {
        print("📤 [ReportService] Starting image report processing...")
        
        // Ensure user is authenticated (creates anonymous user if needed)
        let userId = try await auth.ensureAnonymousUser()
        print("✅ [ReportService] User authenticated: \(userId)")
        
        let reportId = UUID().uuidString
        
        // 1. Upload image to Storage FIRST (fast)
        print("📁 [ReportService] Uploading image...")
        let imageURL = try await storage.uploadImage(
            userId: userId,
            reportId: reportId,
            image: image
        ) { progress in
            print("Upload progress: \(Int(progress * 100))%")
        }
        print("✅ [ReportService] Image uploaded: \(imageURL)")
        
        // 2. Create local SwiftData model immediately (so user sees it)
        let report = MedicalReportModel(
            id: reportId,
            title: title,
            uploadDate: Date(),
            reportType: "Lab Report",
            organ: "General",
            imageURL: imageURL,
            pdfURL: nil,
            extractedText: "Processing...",
            aiInsights: "Analysis in progress..."
        )
        
        context.insert(report)
        try context.save()
        print("✅ [ReportService] Report saved to SwiftData")
        
        // 3. Process OCR and ML in background (async, don't wait)
        Task {@MainActor in
            do {
                print("🔍 [ReportService] ========== STARTING BACKGROUND PROCESSING ==========")
                print("🔍 [ReportService] Report ID: \(reportId)")
                print("🔍 [ReportService] Starting OCR extraction...")
                
                let extractedText = try await ocrService.extractText(from: image)
                print("✅ [ReportService] OCR complete!")
                print("📝 [ReportService] Extracted text length: \(extractedText.count) characters")
                print("📝 [ReportService] First 200 chars: \(extractedText.prefix(200))")
                
                if extractedText.isEmpty {
                    throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text extracted from image"])
                }
                
                print("🤖 [ReportService] Starting AI analysis with Gemini...")
                let analysisResult = try await ChatService.shared.analyzeMedicalText(extractedText)
                print("✅ [ReportService] AI analysis complete")
                
                // Update the report with extracted data
                report.extractedText = extractedText
                report.reportType = analysisResult.reportType
                report.organ = "General" // You might want to infer this from the analysis or keep it general
                report.aiInsights = analysisResult.summary
                print("✅ [ReportService] Report updated with AI data")
                
                // Extract and create graph data points
                print("📊 [ReportService] Creating graph data...")
                let graphDataPoints = extractGraphData(from: analysisResult, reportId: reportId, context: context)
                print("✅ [ReportService] Created \(graphDataPoints.count) graph data points")
                
                // Extract and create medications
                print("💊 [ReportService] Extracting medications...")
                let medications = extractMedications(from: analysisResult, context: context)
                print("✅ [ReportService] Created \(medications.count) medications")
                
                try context.save()
                print("✅ [ReportService] ========== ALL DATA SAVED SUCCESSFULLY! ==========")
            } catch {
                print("❌ [ReportService] ========== BACKGROUND PROCESSING FAILED ==========")
                print("❌ [ReportService] Error: \(error)")
                report.extractedText = "Analysis failed: \(error.localizedDescription)"
                report.aiInsights = "Analysis unavailable"
                try? context.save()
            }
        }
        
        return report
    }
    
    /// Extract graph data points and lab results from AI analysis
    private func extractGraphData(from analysis: ChatService.MedicalAnalysisResult, reportId: String, context: ModelContext) -> [GraphDataModel] {
        var graphPoints: [GraphDataModel] = []
        let reportDate = Date()
        
        for result in analysis.labResults {
            // Try to parse value as Double
            // Handle cases like "< 0.5" or "120-130" by taking the first number
            let valueString = result.value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
            guard let value = Double(valueString) else { continue }
            
            // Map category to organ name
            let metricOrgan = mapCategoryToOrgan(result.category)
            
            // Create GraphDataModel for trend visualization
            let graphPoint = GraphDataModel(
                organ: metricOrgan,
                parameter: result.testName,
                value: value,
                unit: result.unit,
                date: reportDate,
                reportId: reportId
            )
            context.insert(graphPoint)
            graphPoints.append(graphPoint)
            
            // Create LabResultModel for detailed lab tracking
            let labResult = LabResultModel(
                testName: result.testName,
                parameter: result.testName,
                value: value,
                unit: result.unit,
                normalRange: result.normalRange,
                status: result.status,
                testDate: reportDate,
                category: result.category
            )
            context.insert(labResult)
        }
        
        return graphPoints
    }
    
    /// Extract medications from AI analysis
    private func extractMedications(from analysis: ChatService.MedicalAnalysisResult, context: ModelContext) -> [MedicationModel] {
        var medications: [MedicationModel] = []
        
        for med in analysis.medications {
            let medication = MedicationModel(
                name: med.name,
                dosage: med.dosage,
                frequency: med.frequency,
                instructions: med.instructions,
                startDate: Date(),
                prescribedBy: "From Document Analysis",
                isActive: true
            )
            context.insert(medication)
            medications.append(medication)
        }
        
        return medications
    }
    
    /// Process and upload a PDF medical report
    func processPDFReport(
        fileURL: URL,
        title: String,
        context: ModelContext
    ) async throws -> MedicalReportModel {
        print("📤 [ReportService] ========== STARTING PDF PROCESSING ==========")
        print("📤 [ReportService] File URL: \(fileURL)")
        print("📤 [ReportService] Title: \(title)")
        print("📤 [ReportService] URL is file URL: \(fileURL.isFileURL)")
        print("📤 [ReportService] File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
        
        // Ensure user is authenticated (creates anonymous user if needed)
        let userId = try await auth.ensureAnonymousUser()
        print("✅ [ReportService] User authenticated: \(userId)")
        
        let reportId = UUID().uuidString
        
        // 1. Save PDF to local storage FIRST (fast)
        print("📁 [ReportService] Saving PDF locally...")
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let userPath = documentsPath.appendingPathComponent("users/\(userId)/reports/\(reportId)")
        
        print("📁 [ReportService] Creating directory: \(userPath.path)")
        try FileManager.default.createDirectory(at: userPath, withIntermediateDirectories: true)
        
        let pdfPath = userPath.appendingPathComponent("document.pdf")
        print("📁 [ReportService] Copying from: \(fileURL.path)")
        print("📁 [ReportService] Copying to: \(pdfPath.path)")
        
        do {
            try FileManager.default.copyItem(at: fileURL, to: pdfPath)
            print("✅ [ReportService] PDF copied successfully")
        } catch {
            print("❌ [ReportService] Failed to copy PDF: \(error)")
            throw error
        }
        
        let pdfURL = pdfPath.absoluteString
        print("✅ [ReportService] PDF saved: \(pdfURL)")
        
        // 2. Create local SwiftData model immediately (so user sees it)
        let report = MedicalReportModel(
            id: reportId,
            title: title,
            uploadDate: Date(),
            reportType: "PDF Report",
            organ: "General",
            imageURL: nil,
            pdfURL: pdfURL,
            extractedText: "Processing...",
            aiInsights: "Analysis in progress..."
        )
        
        context.insert(report)
        try context.save()
        print("✅ [ReportService] Report saved to SwiftData")
        
        // 3. Process OCR and ML in background (async, don't wait)
        Task {@MainActor in
            do {
                print("🔍 [ReportService] ========== STARTING PDF BACKGROUND PROCESSING ==========")
                print("🔍 [ReportService] Report ID: \(reportId)")
                print("🔍 [ReportService] Starting PDF OCR extraction...")
                
                let extractedText = try await ocrService.extractText(from: fileURL)
                print("✅ [ReportService] PDF OCR complete!")
                print("📝 [ReportService] Extracted text length: \(extractedText.count) characters")
                print("📝 [ReportService] First 200 chars: \(extractedText.prefix(200))")
                
                if extractedText.isEmpty {
                    throw NSError(domain: "OCRService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No text extracted from PDF"])
                }
                
                print("🤖 [ReportService] Starting AI analysis with Gemini...")
                let analysisResult = try await ChatService.shared.analyzeMedicalText(extractedText)
                print("✅ [ReportService] AI analysis complete")
                
                // Update the report with extracted data
                report.extractedText = extractedText
                report.reportType = analysisResult.reportType
                report.organ = "General"
                report.aiInsights = analysisResult.summary
                print("✅ [ReportService] Report updated with AI data")
                
                // Extract and create graph data points
                print("📊 [ReportService] Creating graph data...")
                let graphDataPoints = extractGraphData(from: analysisResult, reportId: reportId, context: context)
                print("✅ [ReportService] Created \(graphDataPoints.count) graph data points")
                
                // Extract and create medications
                print("💊 [ReportService] Extracting medications...")
                let medications = extractMedications(from: analysisResult, context: context)
                print("✅ [ReportService] Created \(medications.count) medications")
                
                try context.save()
                print("✅ [ReportService] ========== ALL PDF DATA SAVED SUCCESSFULLY! ==========")
            } catch {
                print("❌ [ReportService] ========== PDF BACKGROUND PROCESSING FAILED ==========")
                print("❌ [ReportService] Error: \(error)")
                report.extractedText = "Analysis failed: \(error.localizedDescription)"
                report.aiInsights = "Analysis unavailable"
                try? context.save()
            }
        }
        
        
        return report
    }
    
    // MARK: - Helper Functions
    
    /// Map metric category to organ name for graph organization
    private func mapCategoryToOrgan(_ category: String) -> String {
        switch category.lowercased() {
        case "blood":
            return "Blood"
        case "kidney", "renal":
            return "Kidneys"
        case "liver", "hepatic":
            return "Liver"
        case "lipids", "cholesterol", "cardiovascular":
            return "Heart"
        case "metabolic", "diabetes", "glucose":
            return "Pancreas"
        case "thyroid":
            return "Thyroid"
        case "lung", "respiratory":
            return "Lungs"
        case "cardiac", "heart":
            return "Heart"
        case "vitamins", "minerals":
            return "General"
        default:
            return "General"
        }
    }
    
    // MARK: - Test Data Generation
    
    /// Generate sample health data for testing graphs
    func generateSampleData(context: ModelContext) {
        print("🧪 [ReportService] Generating sample health data for testing...")
        
        let calendar = Calendar.current
        let now = Date()
        
        // Generate Heart data (last 7 days)
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            
            // Heart Rate
            let heartRate = GraphDataModel(
                organ: "Heart",
                parameter: "Heart Rate",
                value: Double.random(in: 65...85),
                unit: "BPM",
                date: date
            )
            context.insert(heartRate)
            
            // Blood Pressure Systolic
            let bpSystolic = GraphDataModel(
                organ: "Heart",
                parameter: "Blood Pressure Systolic",
                value: Double.random(in: 110...125),
                unit: "mmHg",
                date: date
            )
            context.insert(bpSystolic)
        }
        
        // Generate Lungs data (last 7 days)
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            
            // SpO2
            let spo2 = GraphDataModel(
                organ: "Lungs",
                parameter: "SpO2",
                value: Double.random(in: 96...99),
                unit: "%",
                date: date
            )
            context.insert(spo2)
            
            // Respiratory Rate
            let respRate = GraphDataModel(
                organ: "Lungs",
                parameter: "Respiratory Rate",
                value: Double.random(in: 14...18),
                unit: "breaths/min",
                date: date
            )
            context.insert(respRate)
        }
        
        // Generate Kidney data
        for dayOffset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -dayOffset * 2, to: now)!
            
            let creatinine = GraphDataModel(
                organ: "Kidneys",
                parameter: "Creatinine",
                value: Double.random(in: 0.8...1.1),
                unit: "mg/dL",
                date: date
            )
            context.insert(creatinine)
            
            let egfr = GraphDataModel(
                organ: "Kidneys",
                parameter: "eGFR",
                value: Double.random(in: 95...110),
                unit: "mL/min",
                date: date
            )
            context.insert(egfr)
        }
        
        // Generate Liver data
        for dayOffset in 0..<4 {
            let date = calendar.date(byAdding: .day, value: -dayOffset * 3, to: now)!
            
            let alt = GraphDataModel(
                organ: "Liver",
                parameter: "ALT",
                value: Double.random(in: 20...35),
                unit: "U/L",
                date: date
            )
            context.insert(alt)
            
            let ast = GraphDataModel(
                organ: "Liver",
                parameter: "AST",
                value: Double.random(in: 18...32),
                unit: "U/L",
                date: date
            )
            context.insert(ast)
        }
        
        try? context.save()
        print("✅ [ReportService] Sample data generated successfully!")
    }
}
