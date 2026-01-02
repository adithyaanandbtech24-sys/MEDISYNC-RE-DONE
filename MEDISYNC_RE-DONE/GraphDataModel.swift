// GraphDataModel.swift
import Foundation
import SwiftData
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Model for time-series graph data points
@Model
final class GraphDataModel {
    @Attribute(.unique) var id: String
    var organ: String // "Heart", "Lungs", "Kidneys", "Liver", "Blood", etc.
    var parameter: String // "Heart Rate", "SpO2", "eGFR", "ALT", "Hemoglobin", etc.
    var value: Double
    var unit: String
    var date: Date
    var reportId: String? // Link to source MedicalReportModel
    var syncState: String = "synced"
    
    init(id: String = UUID().uuidString,
         organ: String,
         parameter: String,
         value: Double,
         unit: String,
         date: Date = Date(),
         reportId: String? = nil) {
        self.id = id
        self.organ = organ
        self.parameter = parameter
        self.value = value
        self.unit = unit
        self.date = date
        self.reportId = reportId
        self.syncState = "synced"
    }
}

// MARK: - Firestore Codable Support

#if canImport(FirebaseFirestore)
extension GraphDataModel {
    /// Convert to Firestore dictionary
    func toFirestore() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "organ": organ,
            "parameter": parameter,
            "value": value,
            "unit": unit,
            "date": Timestamp(date: date)
        ]
        
        if let reportId = reportId {
            dict["reportId"] = reportId
        }
        
        return dict
    }
    
    /// Create from Firestore dictionary
    static func fromFirestore(_ data: [String: Any]) -> GraphDataModel? {
        guard let id = data["id"] as? String,
              let organ = data["organ"] as? String,
              let parameter = data["parameter"] as? String,
              let value = data["value"] as? Double,
              let unit = data["unit"] as? String,
              let timestamp = data["date"] as? Timestamp else {
            return nil
        }
        
        return GraphDataModel(
            id: id,
            organ: organ,
            parameter: parameter,
            value: value,
            unit: unit,
            date: timestamp.dateValue(),
            reportId: data["reportId"] as? String
        )
    }
}
#endif

// MARK: - Helper Types

struct GraphPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    
    init(from model: GraphDataModel) {
        self.id = model.id
        self.date = model.date
        self.value = model.value
    }
}

// MARK: - Indian Medical Standards Helper
struct IndianMedicalStandards {
    struct Range {
        let min: Double
        let max: Double
        let unit: String
        let description: String
    }
    
    static let standards: [String: Range] = [
        // Heart
        "Heart Rate": Range(min: 60, max: 100, unit: "BPM", description: "Normal Resting Heart Rate"),
        "Blood Pressure Systolic": Range(min: 90, max: 120, unit: "mmHg", description: "Normal Systolic"),
        "Blood Pressure Diastolic": Range(min: 60, max: 80, unit: "mmHg", description: "Normal Diastolic"),
        
        // Lungs
        "SpO2": Range(min: 95, max: 100, unit: "%", description: "Normal Oxygen Saturation"),
        "Respiratory Rate": Range(min: 12, max: 20, unit: "breaths/min", description: "Normal Respiratory Rate"),
        
        // Kidneys
        "Creatinine": Range(min: 0.6, max: 1.2, unit: "mg/dL", description: "Normal Serum Creatinine"),
        "eGFR": Range(min: 90, max: 120, unit: "mL/min", description: "Normal Kidney Function"),
        
        // Liver
        "ALT": Range(min: 7, max: 55, unit: "U/L", description: "Normal ALT Level"),
        "AST": Range(min: 8, max: 48, unit: "U/L", description: "Normal AST Level"),
        
        // Blood
        "Hemoglobin": Range(min: 13.0, max: 17.0, unit: "g/dL", description: "Male Normal Range (Female: 12-15)"),
        "Glucose Fasting": Range(min: 70, max: 100, unit: "mg/dL", description: "Normal Fasting Glucose")
    ]
    
    static func getStandard(for parameter: String) -> Range? {
        return standards[parameter]
    }
    
    static func isNormal(value: Double, parameter: String) -> Bool {
        guard let range = standards[parameter] else { return true } // Assume normal if unknown
        return value >= range.min && value <= range.max
    }
}
