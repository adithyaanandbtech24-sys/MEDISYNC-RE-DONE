// FirestoreMappers.swift
import Foundation
import SwiftData
#if canImport(FirebaseFirestore)
import FirebaseFirestore

/// Bidirectional mappers between SwiftData models and Firestore dictionaries
enum FirestoreMappers {
    
    // MARK: - MedicalReportModel
    
    static func toFirestore(_ report: MedicalReportModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": report.id,
            "title": report.title,
            "uploadDate": Timestamp(date: report.uploadDate),
            "reportType": report.reportType,
            "organ": report.organ
        ]
        
        if let imageURL = report.imageURL {
            dict["imageURL"] = imageURL
        }
        if let pdfURL = report.pdfURL {
            dict["pdfURL"] = pdfURL
        }
        // Exclude extractedText for HIPAA compliance - keep only in local SwiftData
        if let aiInsights = report.aiInsights {
            dict["aiInsights"] = aiInsights
        }
        
        return dict
    }
    
    static func fromFirestore(_ data: [String: Any]) -> MedicalReportModel? {
        guard let id = data["id"] as? String,
              let title = data["title"] as? String,
              let uploadTimestamp = data["uploadDate"] as? Timestamp,
              let reportType = data["reportType"] as? String,
              let organ = data["organ"] as? String else {
            return nil
        }
        
        let report = MedicalReportModel(
            id: id,
            title: title,
            uploadDate: uploadTimestamp.dateValue(),
            reportType: reportType,
            organ: organ,
            imageURL: data["imageURL"] as? String,
            pdfURL: data["pdfURL"] as? String,
            extractedText: nil, // Not synced from cloud
            aiInsights: data["aiInsights"] as? String
        )
        
        return report
    }
    
    // MARK: - LabResultModel
    
    static func toFirestore(_ lab: LabResultModel) -> [String: Any] {
        return [
            "id": lab.id,
            "testName": lab.testName,
            "parameter": lab.parameter,
            "value": lab.value,
            "unit": lab.unit,
            "normalRange": lab.normalRange,
            "status": lab.status,
            "testDate": Timestamp(date: lab.testDate),
            "category": lab.category
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> LabResultModel? {
        guard let id = data["id"] as? String,
              let testName = data["testName"] as? String,
              let parameter = data["parameter"] as? String,
              let value = data["value"] as? Double,
              let unit = data["unit"] as? String,
              let normalRange = data["normalRange"] as? String,
              let status = data["status"] as? String,
              let testTimestamp = data["testDate"] as? Timestamp,
              let category = data["category"] as? String else {
            return nil
        }
        
        return LabResultModel(
            id: id,
            testName: testName,
            parameter: parameter,
            value: value,
            unit: unit,
            normalRange: normalRange,
            status: status,
            testDate: testTimestamp.dateValue(),
            category: category
        )
    }
    
    // MARK: - MedicationModel
    
    static func toFirestore(_ medication: MedicationModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": medication.id,
            "name": medication.name,
            "dosage": medication.dosage,
            "frequency": medication.frequency,
            "startDate": Timestamp(date: medication.startDate),
            "isActive": medication.isActive
        ]
        
        if let endDate = medication.endDate {
            dict["endDate"] = Timestamp(date: endDate)
        }
        if let instructions = medication.instructions {
            dict["instructions"] = instructions
        }
        
        return dict
    }
    
    static func fromFirestore(_ data: [String: Any]) -> MedicationModel? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String,
              let dosage = data["dosage"] as? String,
              let frequency = data["frequency"] as? String,
              let startTimestamp = data["startDate"] as? Timestamp,
              let isActive = data["isActive"] as? Bool else {
            return nil
        }
        
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()
        
        return MedicationModel(
            id: id,
            name: name,
            dosage: dosage,
            frequency: frequency,
            instructions: data["instructions"] as? String,
            startDate: startTimestamp.dateValue(),
            endDate: endDate,
            isActive: isActive
        )
    }
    
    // MARK: - TimelineEntryModel
    
    static func toFirestore(_ entry: TimelineEntryModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": entry.id,
            "date": Timestamp(date: entry.date),
            "type": entry.type,
            "title": entry.title,
            "summary": entry.summary,
            "iconName": entry.iconName,
            "color": entry.color
        ]
        
        if let relatedReportId = entry.relatedReportId {
            dict["relatedReportId"] = relatedReportId
        }
        
        return dict
    }
    
    static func fromFirestore(_ data: [String: Any]) -> TimelineEntryModel? {
        guard let id = data["id"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let type = data["type"] as? String,
              let title = data["title"] as? String,
              let summary = data["summary"] as? String,
              let iconName = data["iconName"] as? String,
              let color = data["color"] as? String else {
            return nil
        }
        
        return TimelineEntryModel(
            id: id,
            date: dateTimestamp.dateValue(),
            type: type,
            title: title,
            summary: summary,
            relatedReportId: data["relatedReportId"] as? String,
            iconName: iconName,
            color: color
        )
    }
    
    // MARK: - AIChatMessage
    
    static func toFirestore(_ message: AIChatMessage) -> [String: Any] {
        return [
            "id": message.id,
            "text": message.text,
            "isUser": message.isUser,
            "timestamp": Timestamp(date: message.timestamp)
        ]
    }
    
    static func fromFirestore(_ data: [String: Any]) -> AIChatMessage? {
        guard let id = data["id"] as? String,
              let text = data["text"] as? String,
              let isUser = data["isUser"] as? Bool,
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        
        return AIChatMessage(
            id: id,
            text: text,
            isUser: isUser,
            timestamp: timestamp.dateValue()
        )
    }
    
    // MARK: - GraphDataModel
    
    static func toFirestore(_ data: GraphDataModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": data.id,
            "organ": data.organ,
            "parameter": data.parameter,
            "value": data.value,
            "unit": data.unit,
            "date": Timestamp(date: data.date)
        ]
        
        if let reportId = data.reportId {
            dict["reportId"] = reportId
        }
        
        return dict
    }
    
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
