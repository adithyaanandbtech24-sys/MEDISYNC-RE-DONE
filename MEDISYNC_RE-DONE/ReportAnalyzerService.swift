import Foundation
import SwiftData

/// Offline report analyzer that generates intelligent summaries without external APIs
class ReportAnalyzerService {
    
    // MARK: - Analysis Result
    struct AnalysisResult {
        let reportType: String
        let summary: String
        let highlights: [Highlight]
        let parameterCount: Int
        let testDate: Date
        let labResults: [LabResultModel]
        
        struct Highlight {
            let parameter: String
            let value: Double
            let unit: String
            let status: String
            let severity: MedicalStandardProvider.StandardRange.Severity
            let message: String
        }
        
        /// Generate a natural language report summary
        func generateChatbotMessage() -> String {
            var message = "📊 **Report Analysis Complete**\n\n"
            message += "**Report Type:** \(reportType)\n"
            message += "**Date:** \(testDate.formatted(date: .abbreviated, time: .omitted))\n"
            message += "**Parameters Found:** \(parameterCount)\n\n"
            
            if !highlights.isEmpty {
                message += "**Key Findings:**\n"
                
                // Critical items first
                let critical = highlights.filter { $0.severity == .critical }
                let abnormal = highlights.filter { $0.severity == .abnormal }
                let borderline = highlights.filter { $0.severity == .borderline }
                let normal = highlights.filter { $0.severity == .normal }
                
                if !critical.isEmpty {
                    message += "\n🔴 **Critical:**\n"
                    for item in critical {
                        message += "• \(item.parameter): \(String(format: "%.1f", item.value)) \(item.unit) - \(item.message)\n"
                    }
                }
                
                if !abnormal.isEmpty {
                    message += "\n⚠️ **Abnormal:**\n"
                    for item in abnormal {
                        message += "• \(item.parameter): \(String(format: "%.1f", item.value)) \(item.unit) - \(item.message)\n"
                    }
                }
                
                if !borderline.isEmpty {
                    message += "\n⚡ **Borderline:**\n"
                    for item in borderline {
                        message += "• \(item.parameter): \(String(format: "%.1f", item.value)) \(item.unit) - \(item.message)\n"
                    }
                }
                
                if !normal.isEmpty && critical.isEmpty && abnormal.isEmpty {
                    message += "\n✅ **Normal Parameters:**\n"
                    for item in normal.prefix(5) {
                        message += "• \(item.parameter): \(String(format: "%.1f", item.value)) \(item.unit)\n"
                    }
                    if normal.count > 5 {
                        message += "• ... and \(normal.count - 5) more normal results\n"
                    }
                }
            } else {
                message += "✅ All parameters appear to be within normal ranges.\n"
            }
            
            return message
        }
    }
    
    private let standardProvider: MedicalStandardProvider
    
    init(userProfile: MedicalStandardProvider.UserProfile) {
        self.standardProvider = MedicalStandardProvider(userProfile: userProfile)
    }
    
    // MARK: - Analysis Methods
    
    /// Analyze a medical report from OCR text
    func analyzeReport(ocrText: String, testDate: Date = Date()) -> AnalysisResult {
        // Step 1: Parse lab results
        let labResults = MedicalDataParser.parseLabResults(from: ocrText)
        
        // Step 2: Detect report type
        let reportType = MedicalDataParser.detectReportType(from: ocrText)
        
        // Step 3: Analyze each result against standards
        var highlights: [AnalysisResult.Highlight] = []
        
        for result in labResults {
            if let standard = standardProvider.getStandard(for: result.testName) {
                let assessment = standard.assess(value: result.value)
                
                // Generate intelligent message
                let message = generateMessage(
                    parameter: result.testName,
                    value: result.value,
                    unit: result.unit,
                    status: assessment.status,
                    standard: standard
                )
                
                let highlight = AnalysisResult.Highlight(
                    parameter: result.testName,
                    value: result.value,
                    unit: result.unit,
                    status: assessment.status,
                    severity: assessment.severity,
                    message: message
                )
                
                // Only highlight non-normal values
                if assessment.severity != .normal {
                    highlights.append(highlight)
                }
            }
        }
        
        // Step 4: Generate summary
        let summary = generateSummary(
            reportType: reportType,
            labResults: labResults,
            highlights: highlights
        )
        
        return AnalysisResult(
            reportType: reportType,
            summary: summary,
            highlights: highlights,
            parameterCount: labResults.count,
            testDate: testDate,
            labResults: labResults
        )
    }
    
    /// Compare with previous results
    func compareWithHistory(
        current: AnalysisResult,
        previousResults: [GraphDataModel]
    ) -> [String] {
        var comparisons: [String] = []
        
        for labResult in current.labResults {
            // Find previous values for this parameter
            let historical = previousResults.filter { point in
                point.parameter.lowercased() == labResult.testName.lowercased()
            }.sorted { $0.date < $1.date }
            
            if let lastValue = historical.last {
                let change = labResult.value - lastValue.value
                let percentChange = (change / lastValue.value) * 100
                
                if abs(percentChange) > 10 { // Significant change
                    let direction = change > 0 ? "increased" : "decreased"
                    let comparison = "\(labResult.testName) has \(direction) by \(String(format: "%.1f", abs(percentChange)))% since \(lastValue.date.formatted(date: .abbreviated, time: .omitted))"
                    comparisons.append(comparison)
                }
            }
        }
        
        return comparisons
    }
    
    // MARK: - Helper Methods
    
    private func generateMessage(
        parameter: String,
        value: Double,
        unit: String,
        status: String,
        standard: MedicalStandardProvider.StandardRange
    ) -> String {
        let normalRange = "\(String(format: "%.1f", standard.min))-\(String(format: "%.1f", standard.max)) \(standard.unit)"
        
        switch status {
        case "Critically Low":
            return "This is significantly below the normal range (\(normalRange)). Please consult your doctor immediately."
        case "Critically High":
            return "This is significantly above the normal range (\(normalRange)). Please consult your doctor immediately."
        case "Low":
            return "Below normal range (\(normalRange)). Monitor and discuss with your doctor."
        case "High":
            return "Above normal range (\(normalRange)). Monitor and discuss with your doctor."
        case "Slightly Below Normal":
            return "Just below the normal range (\(normalRange)). Keep an eye on it."
        case "Slightly Above Normal":
            return "Just above the normal range (\(normalRange)). Keep an eye on it."
        default:
            return "Within normal range (\(normalRange))."
        }
    }
    
    private func generateSummary(
        reportType: String,
        labResults: [LabResultModel],
        highlights: [AnalysisResult.Highlight]
    ) -> String {
        var summary = "This \(reportType) contains \(labResults.count) test parameter(s). "
        
        let criticalCount = highlights.filter { $0.severity == .critical }.count
        let abnormalCount = highlights.filter { $0.severity == .abnormal }.count
        let borderlineCount = highlights.filter { $0.severity == .borderline }.count
        
        if criticalCount > 0 {
            summary += "\(criticalCount) critical finding(s) require immediate attention. "
        }
        if abnormalCount > 0 {
            summary += "\(abnormalCount) abnormal result(s) detected. "
        }
        if borderlineCount > 0 {
            summary += "\(borderlineCount) borderline result(s) to monitor. "
        }
        if criticalCount == 0 && abnormalCount == 0 {
            summary += "All major parameters are within acceptable ranges. "
        }
        
        return summary
    }
}

// MARK: - Supporting Models

struct LabResultModel: Identifiable, Codable {
    let id: String
    let testName: String
    let value: Double
    let unit: String
    let normalRange: String
    let status: String
    let category: String
    let date: Date
    
    init(
        id: String = UUID().uuidString,
        testName: String,
        value: Double,
        unit: String,
        normalRange: String,
        status: String,
        category: String,
        date: Date = Date()
    ) {
        self.id = id
        self.testName = testName
        self.value = value
        self.unit = unit
        self.normalRange = normalRange
        self.status = status
        self.category = category
        self.date = date
    }
}

struct MedicationModel: Identifiable, Codable {
    let id: String
    let name: String
    let dosage: String
    let frequency: String
    
    init(
        id: String = UUID().uuidString,
        name: String,
        dosage: String,
        frequency: String
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
    }
}
