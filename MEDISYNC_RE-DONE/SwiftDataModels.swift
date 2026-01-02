import Foundation
import SwiftData

// MARK: - Medical Report Model
@Model
final class MedicalReportModel {
    @Attribute(.unique) var id: String
    var title: String
    var uploadDate: Date
    var reportType: String
    var organ: String // e.g., "Heart", "Kidney", "Liver"
    var imageURL: String?
    var pdfURL: String?
    var extractedText: String?
    var aiInsights: String?
    var syncState: String = "pending" // "pending", "synced", "failed"
    
    // Relationships
    @Relationship(deleteRule: .cascade) var labResults: [LabResultModel]?
    @Relationship(deleteRule: .cascade) var medications: [MedicationModel]?
    
    init(id: String = UUID().uuidString,
         title: String,
         uploadDate: Date = Date(),
         reportType: String,
         organ: String = "General",
         imageURL: String? = nil,
         pdfURL: String? = nil,
         extractedText: String? = nil,
         aiInsights: String? = nil) {
        self.id = id
        self.title = title
        self.uploadDate = uploadDate
        self.reportType = reportType
        self.organ = organ
        self.imageURL = imageURL
        self.pdfURL = pdfURL
        self.extractedText = extractedText
        self.aiInsights = aiInsights
        self.syncState = "pending"
    }
}

// MARK: - Lab Result Model
@Model
final class LabResultModel {
    @Attribute(.unique) var id: String
    var testName: String
    var parameter: String // e.g., "Hemoglobin", "Cholesterol"
    var value: Double
    var unit: String
    var normalRange: String
    var status: String // "Normal", "High", "Low"
    var testDate: Date
    var category: String // "Blood", "Urine", "Liver", etc.
    var syncState: String = "pending"
    
    init(id: String = UUID().uuidString,
         testName: String,
         parameter: String? = nil,
         value: Double,
         unit: String,
         normalRange: String,
         status: String,
         testDate: Date = Date(),
         category: String) {
        self.id = id
        self.testName = testName
        self.parameter = parameter ?? testName
        self.value = value
        self.unit = unit
        self.normalRange = normalRange
        self.status = status
        self.testDate = testDate
        self.category = category
        self.syncState = "pending"
    }
}

// MARK: - Medication Model
@Model
final class MedicationModel {
    @Attribute(.unique) var id: String
    var name: String
    var dosage: String
    var frequency: String
    var instructions: String?
    var startDate: Date
    var endDate: Date?
    var prescribedBy: String?
    var notes: String?
    var sideEffects: String?
    var alternatives: String?
    var isActive: Bool
    var syncState: String = "pending"
    
    init(id: String = UUID().uuidString,
         name: String,
         dosage: String,
         frequency: String,
         instructions: String? = nil,
         startDate: Date = Date(),
         endDate: Date? = nil,
         prescribedBy: String? = nil,
         notes: String? = nil,
         sideEffects: String? = nil,
         alternatives: String? = nil,
         isActive: Bool = true) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.instructions = instructions
        self.startDate = startDate
        self.endDate = endDate
        self.prescribedBy = prescribedBy
        self.notes = notes
        self.sideEffects = sideEffects
        self.alternatives = alternatives
        self.isActive = isActive
        self.syncState = "pending"
    }
}

// MARK: - Organ Trend Model (for Timeline)
@Model
final class OrganTrendModel {
    @Attribute(.unique) var id: String
    var organ: String // "Heart", "Kidney", "Lungs", etc.
    var parameter: String // "Heart Rate", "eGFR", "SpO2"
    var value: Double
    var unit: String
    var date: Date
    var trend: String // "improving", "stable", "declining"
    var comparisonValue: Double? // Previous value for comparison
    
    init(id: String = UUID().uuidString,
         organ: String,
         parameter: String,
         value: Double,
         unit: String,
         date: Date = Date(),
         trend: String = "stable",
         comparisonValue: Double? = nil) {
        self.id = id
        self.organ = organ
        self.parameter = parameter
        self.value = value
        self.unit = unit
        self.date = date
        self.trend = trend
        self.comparisonValue = comparisonValue
    }
}

// MARK: - Timeline Entry Model
@Model
final class TimelineEntryModel {
    @Attribute(.unique) var id: String
    var date: Date
    var type: String // "Report", "Lab", "Medication", "Appointment"
    var title: String
    var summary: String // Renamed from 'description' to avoid SwiftData conflict
    var relatedReportId: String?
    var iconName: String
    var color: String // Hex color string
    var syncState: String = "pending"
    
    init(id: String = UUID().uuidString,
         date: Date = Date(),
         type: String,
         title: String,
         summary: String,
         relatedReportId: String? = nil,
         iconName: String,
         color: String) {
        self.id = id
        self.date = date
        self.type = type
        self.title = title
        self.summary = summary
        self.relatedReportId = relatedReportId
        self.iconName = iconName
        self.color = color
        self.syncState = "pending"
    }
}

// MARK: - Chat Message Model
// MARK: - Chat Message Model
@Model
final class AIChatMessage {
    @Attribute(.unique) var id: String
    var text: String
    var isUser: Bool
    var timestamp: Date
    
    init(id: String = UUID().uuidString, text: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

// MARK: - Sample Data Insertion
extension ModelContext {
    
    /// Insert sample medical data for testing
    func insertSampleData() {
        // Sample Medical Report
        let bloodTestReport = MedicalReportModel(
            title: "Complete Blood Count",
            reportType: "Blood Test",
            organ: "Blood",
            extractedText: "Hemoglobin: 14.2 g/dL\nWBC: 7.5 ×10³/µL\nPlatelets: 250 ×10³/µL",
            aiInsights: "Your blood test results are within normal range. Hemoglobin levels are excellent."
        )
        insert(bloodTestReport)
        
        // Sample Lab Results
        let hemoglobin = LabResultModel(
            testName: "Hemoglobin",
            parameter: "Hemoglobin",
            value: 14.2,
            unit: "g/dL",
            normalRange: "12-16 g/dL",
            status: "Normal",
            category: "Blood"
        )
        insert(hemoglobin)
        
        let cholesterol = LabResultModel(
            testName: "Total Cholesterol",
            parameter: "Cholesterol",
            value: 185,
            unit: "mg/dL",
            normalRange: "< 200 mg/dL",
            status: "Normal",
            category: "Lipid"
        )
        insert(cholesterol)
        
        let glucose = LabResultModel(
            testName: "Fasting Glucose",
            parameter: "Glucose",
            value: 95,
            unit: "mg/dL",
            normalRange: "70-100 mg/dL",
            status: "Normal",
            category: "Glucose"
        )
        insert(glucose)
        
        // Link lab results to report
        bloodTestReport.labResults = [hemoglobin, cholesterol, glucose]
        
        // Sample Medications
        let aspirin = MedicationModel(
            name: "Aspirin",
            dosage: "75 mg",
            frequency: "Once daily",
            instructions: "Take with food in the morning",
            prescribedBy: "Dr. Sarah Johnson",
            sideEffects: "Nausea, stomach pain, heartburn",
            alternatives: "Ibuprofen, Naproxen"
        )
        insert(aspirin)
        
        let metformin = MedicationModel(
            name: "Metformin",
            dosage: "500 mg",
            frequency: "Twice daily",
            instructions: "Take with meals",
            prescribedBy: "Dr. Sarah Johnson",
            sideEffects: "Nausea, vomiting, stomach upset",
            alternatives: "Insulin, Sulfonylureas"
        )
        insert(metformin)
        
        // Sample Organ Trends
        let heartTrend = OrganTrendModel(
            organ: "Heart",
            parameter: "Heart Rate",
            value: 72,
            unit: "bpm",
            trend: "stable",
            comparisonValue: 74
        )
        insert(heartTrend)
        
        let kidneyTrend = OrganTrendModel(
            organ: "Kidney",
            parameter: "eGFR",
            value: 95,
            unit: "mL/min",
            trend: "stable",
            comparisonValue: 93
        )
        insert(kidneyTrend)
        
        let lungsTrend = OrganTrendModel(
            organ: "Lungs",
            parameter: "SpO2",
            value: 98,
            unit: "%",
            trend: "stable",
            comparisonValue: 98
        )
        insert(lungsTrend)
        
        // Sample Timeline Entries
        let reportEntry = TimelineEntryModel(
            type: "Report",
            title: "Blood Test Results",
            summary: "Complete blood count with 3 lab results",
            relatedReportId: bloodTestReport.id,
            iconName: "drop.fill",
            color: "#FF6B6B"
        )
        insert(reportEntry)
        
        let medicationEntry = TimelineEntryModel(
            date: Date().addingTimeInterval(-86400), // Yesterday
            type: "Medication",
            title: "Started Aspirin",
            summary: "75 mg once daily",
            iconName: "pills.fill",
            color: "#95E1D3"
        )
        insert(medicationEntry)
        
        // Save all changes
        try? save()
    }
    
    /// Clear all sample data
    func clearAllData() {
        // Delete all records
        try? delete(model: MedicalReportModel.self)
        try? delete(model: LabResultModel.self)
        try? delete(model: MedicationModel.self)
        try? delete(model: OrganTrendModel.self)
        try? delete(model: TimelineEntryModel.self)
        
        try? save()
    }
}
// MARK: - Health Metric Model (Persisted)
@Model
final class HealthMetricModel {
    @Attribute(.unique) var id: String
    var date: Date
    var type: String // "Heart Rate", "Steps", "Sleep", "Oxygen Saturation"
    var value: Double
    var unit: String
    var source: String // "HealthKit", "Manual"
    
    init(id: String = UUID().uuidString,
         date: Date,
         type: String,
         value: Double,
         unit: String,
         source: String = "HealthKit") {
        self.id = id
        self.date = date
        self.type = type
        self.value = value
        self.unit = unit
        self.source = source
    }
}

// MARK: - Shared Enums

enum TrendDirection: String, Codable {
    case improving = "improving"
    case stable = "stable"
    case declining = "declining"
    case unknown = "unknown"
}

enum EventSeverity: String, Codable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"
}
