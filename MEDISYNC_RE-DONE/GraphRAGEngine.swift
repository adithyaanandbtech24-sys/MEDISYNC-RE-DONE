import Foundation
import SwiftData

/// A "Lite" Graph RAG engine that treats SwiftData models as nodes and their relationships as edges.
/// It performs keyword-based retrieval and traverses relationships to build a rich context for the AI.
@MainActor
final class GraphRAGEngine {
    static let shared = GraphRAGEngine()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Retrieves relevant medical context based on the user's query.
    /// - Parameters:
    ///   - query: The user's chat message.
    ///   - context: The SwiftData ModelContext to search within.
    /// - Returns: A formatted string containing relevant medical facts.
    func retrieveContext(for query: String, context: ModelContext) -> String {
        let keywords = extractKeywords(from: query)
        guard !keywords.isEmpty else { return "" }
        
        var contextParts: [String] = []
        
        // 1. Search Nodes (Keyword Match)
        let relevantLabs = findRelevantLabs(keywords: keywords, context: context)
        let relevantMeds = findRelevantMeds(keywords: keywords, context: context)
        let relevantReports = findRelevantReports(keywords: keywords, context: context)
        
        // 2. Traverse & Format (Graph Traversal)
        
        // Labs -> Report Context
        if !relevantLabs.isEmpty {
            contextParts.append("--- RELEVANT LAB RESULTS ---")
            for lab in relevantLabs {
                var entry = "- \(lab.testName): \(lab.value) \(lab.unit) (\(lab.status)) on \(formatDate(lab.testDate))"
                // Edge Traversal: Lab -> Report
                // Note: We don't have a direct back-link in the model definition shown previously unless we query it,
                // but usually relationships are bidirectional if defined.
                // Assuming we can't easily get the parent report without a query or if it's not set, we skip.
                // However, let's check if we can add more context from the lab itself.
                entry += ". Normal Range: \(lab.normalRange)."
                contextParts.append(entry)
            }
        }
        
        // Medications
        if !relevantMeds.isEmpty {
            contextParts.append("\n--- RELEVANT MEDICATIONS ---")
            for med in relevantMeds {
                var entry = "- \(med.name): \(med.dosage), \(med.frequency)."
                if let instructions = med.instructions {
                    entry += " Instructions: \(instructions)."
                }
                if med.isActive {
                    entry += " (Active)"
                } else {
                    entry += " (Inactive, ended \(formatDate(med.endDate ?? Date())))"
                }
                contextParts.append(entry)
            }
        }
        
        // Reports -> Insights
        if !relevantReports.isEmpty {
            contextParts.append("\n--- RELEVANT REPORTS ---")
            for report in relevantReports {
                var entry = "- Report: \(report.title) (\(formatDate(report.uploadDate)))"
                if let insights = report.aiInsights {
                    entry += "\n  Summary: \(insights)"
                }
                // Edge Traversal: Report -> Labs
                if let labs = report.labResults, !labs.isEmpty {
                    let labNames = labs.map { $0.testName }.joined(separator: ", ")
                    entry += "\n  Contains labs: \(labNames)"
                }
                contextParts.append(entry)
            }
        }
        
        if contextParts.isEmpty {
            return ""
        }
        
        return """
        CONTEXT FROM MEDICAL RECORDS:
        \(contextParts.joined(separator: "\n"))
        
        INSTRUCTIONS: Use the above context to answer the user's question accurately. Cite specific dates and values where possible.
        """
    }
    
    // MARK: - Helper Methods
    
    private func extractKeywords(from query: String) -> [String] {
        // Simple stop-word removal and tokenization
        let stopWords: Set<String> = ["the", "is", "at", "which", "on", "a", "an", "and", "or", "but", "in", "with", "to", "of", "my", "me", "i", "what", "how", "when", "where", "does", "do", "did", "can", "could", "should", "would"]
        
        let words = query.lowercased().components(separatedBy: .punctuationCharacters).joined().components(separatedBy: .whitespaces)
        return words.filter { !stopWords.contains($0) && $0.count > 2 }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Search Methods
    
    private func findRelevantLabs(keywords: [String], context: ModelContext) -> [LabResultModel] {
        // Fetch all labs (inefficient for huge datasets, but fine for local device)
        // SwiftData predicates with dynamic arrays are tricky, so we filter in memory for this "Lite" version.
        guard let allLabs = try? context.fetch(FetchDescriptor<LabResultModel>()) else { return [] }
        
        return allLabs.filter { lab in
            let content = "\(lab.testName) \(lab.parameter) \(lab.category)".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
    
    private func findRelevantMeds(keywords: [String], context: ModelContext) -> [MedicationModel] {
        guard let allMeds = try? context.fetch(FetchDescriptor<MedicationModel>()) else { return [] }
        
        return allMeds.filter { med in
            let content = "\(med.name) \(med.notes ?? "") \(med.prescribedBy ?? "")".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
    
    private func findRelevantReports(keywords: [String], context: ModelContext) -> [MedicalReportModel] {
        guard let allReports = try? context.fetch(FetchDescriptor<MedicalReportModel>()) else { return [] }
        
        return allReports.filter { report in
            let content = "\(report.title) \(report.organ) \(report.reportType) \(report.aiInsights ?? "")".lowercased()
            return keywords.contains { content.contains($0) }
        }
    }
}
