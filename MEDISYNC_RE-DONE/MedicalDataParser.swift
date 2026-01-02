import Foundation
import UIKit
import PDFKit

/// Parser for extracting medical data from OCR text
class MedicalDataParser {
    
    // MARK: - Lab Results Parsing
    
    /// Parse lab results from OCR text
    static func parseLabResults(from text: String) -> [LabResultModel] {
        var results: [LabResultModel] = []
        
        // Common lab test patterns
        let patterns: [(name: String, pattern: String, unit: String, category: String, normalRange: String)] = [
            // Blood Tests
            ("Hemoglobin", #"hemoglobin[:\s]+(\d+\.?\d*)\s*(g/dL)?"#, "g/dL", "Blood", "12-16 g/dL"),
            ("WBC", #"wbc[:\s]+(\d+\.?\d*)\s*(×10³/µL)?"#, "×10³/µL", "Blood", "4-11 ×10³/µL"),
            ("RBC", #"rbc[:\s]+(\d+\.?\d*)\s*(million/µL)?"#, "million/µL", "Blood", "4.5-5.5 million/µL"),
            ("Platelets", #"platelet[s]?[:\s]+(\d+\.?\d*)\s*(×10³/µL)?"#, "×10³/µL", "Blood", "150-400 ×10³/µL"),
            
            // Cholesterol
            ("Total Cholesterol", #"(?:total\s+)?cholesterol[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Lipid", "< 200 mg/dL"),
            ("LDL", #"ldl[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Lipid", "< 100 mg/dL"),
            ("HDL", #"hdl[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Lipid", "> 40 mg/dL"),
            ("Triglycerides", #"triglyceride[s]?[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Lipid", "< 150 mg/dL"),
            
            // Glucose
            ("Fasting Glucose", #"(?:fasting\s+)?glucose[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Glucose", "70-100 mg/dL"),
            ("HbA1c", #"hba1c[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Glucose", "< 5.7%"),
            
            // Liver Function
            ("ALT", #"alt[:\s]+(\d+\.?\d*)\s*(U/L)?"#, "U/L", "Liver", "7-56 U/L"),
            ("AST", #"ast[:\s]+(\d+\.?\d*)\s*(U/L)?"#, "U/L", "Liver", "10-40 U/L"),
            ("Bilirubin", #"bilirubin[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Liver", "0.1-1.2 mg/dL"),
            
            // Kidney Function
            ("Creatinine", #"creatinine[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Kidney", "0.6-1.2 mg/dL"),
            ("eGFR", #"egfr[:\s]+(\d+\.?\d*)\s*(mL/min)?"#, "mL/min/1.73m²", "Kidney", "> 60 mL/min"),
            ("BUN", #"bun[:\s]+(\d+\.?\d*)\s*(mg/dL)?"#, "mg/dL", "Kidney", "7-20 mg/dL"),
            
            // Vitamins
            ("Vitamin D", #"vitamin\s*d[:\s]+(\d+\.?\d*)\s*(ng/mL)?"#, "ng/mL", "Vitamin", "30-100 ng/mL"),
            ("Vitamin B12", #"vitamin\s*b12[:\s]+(\d+\.?\d*)\s*(pg/mL)?"#, "pg/mL", "Vitamin", "200-900 pg/mL"),
            
            // Thyroid
            ("TSH", #"tsh[:\s]+(\d+\.?\d*)\s*(mIU/L)?"#, "mIU/L", "Thyroid", "0.4-4.0 mIU/L"),
            ("T3", #"t3[:\s]+(\d+\.?\d*)\s*(ng/dL)?"#, "ng/dL", "Thyroid", "80-200 ng/dL"),
            ("T4", #"t4[:\s]+(\d+\.?\d*)\s*(µg/dL)?"#, "µg/dL", "Thyroid", "5-12 µg/dL")
        ]
        
        for (name, pattern, unit, category, normalRange) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let valueRange = Range(match.range(at: 1), in: text),
                   let value = Double(text[valueRange]) {
                    
                    let status = determineStatus(value: value, testName: name, normalRange: normalRange)
                    
                    let labResult = LabResultModel(
                        testName: name,
                        value: value,
                        unit: unit,
                        normalRange: normalRange,
                        status: status,
                        category: category
                    )
                    results.append(labResult)
                }
            }
        }
        
        return results
    }
    
    // MARK: - Medication Parsing
    
    /// Parse medications from OCR text
    static func parseMedications(from text: String) -> [MedicationModel] {
        var medications: [MedicationModel] = []
        
        // Common medication patterns
        let medicationPattern = #"(?:rx:|medication:|drug:)\s*([a-z]+)\s+(\d+\s*mg)\s+(\d+\s*(?:times?|x)\s*(?:daily|per day|a day))"#
        
        if let regex = try? NSRegularExpression(pattern: medicationPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: text),
                   let dosageRange = Range(match.range(at: 2), in: text),
                   let frequencyRange = Range(match.range(at: 3), in: text) {
                    
                    let name = String(text[nameRange]).capitalized
                    let dosage = String(text[dosageRange])
                    let frequency = String(text[frequencyRange])
                    
                    let medication = MedicationModel(
                        name: name,
                        dosage: dosage,
                        frequency: frequency
                    )
                    medications.append(medication)
                }
            }
        }
        
        // Common medication names (fallback)
        let commonMeds = ["aspirin", "metformin", "lisinopril", "atorvastatin", "levothyroxine", "amlodipine"]
        for med in commonMeds {
            if text.lowercased().contains(med) {
                // Try to find dosage near the medication name
                let pattern = "\(med)\\s+(\\d+\\s*mg)"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                   let dosageRange = Range(match.range(at: 1), in: text) {
                    
                    let dosage = String(text[dosageRange])
                    let medication = MedicationModel(
                        name: med.capitalized,
                        dosage: dosage,
                        frequency: "As prescribed"
                    )
                    medications.append(medication)
                }
            }
        }
        
        return medications
    }
    
    // MARK: - Report Type Detection
    
    /// Detect report type from text
    static func detectReportType(from text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("blood test") || lowercased.contains("cbc") || lowercased.contains("complete blood count") {
            return "Blood Test"
        } else if lowercased.contains("lipid panel") || lowercased.contains("cholesterol") {
            return "Lipid Panel"
        } else if lowercased.contains("liver function") || lowercased.contains("lft") {
            return "Liver Function Test"
        } else if lowercased.contains("kidney function") || lowercased.contains("kft") {
            return "Kidney Function Test"
        } else if lowercased.contains("x-ray") || lowercased.contains("radiograph") {
            return "X-Ray"
        } else if lowercased.contains("mri") || lowercased.contains("magnetic resonance") {
            return "MRI"
        } else if lowercased.contains("ct scan") || lowercased.contains("computed tomography") {
            return "CT Scan"
        } else if lowercased.contains("prescription") || lowercased.contains("rx:") {
            return "Prescription"
        } else if lowercased.contains("discharge summary") {
            return "Discharge Summary"
        } else {
            return "Medical Report"
        }
    }
    
    // MARK: - Helper Methods
    
    private static func determineStatus(value: Double, testName: String, normalRange: String) -> String {
        // Simple status determination based on common ranges
        switch testName {
        case "Total Cholesterol":
            return value < 200 ? "Normal" : value < 240 ? "Borderline High" : "High"
        case "LDL":
            return value < 100 ? "Optimal" : value < 130 ? "Near Optimal" : "High"
        case "HDL":
            return value > 60 ? "Optimal" : value > 40 ? "Normal" : "Low"
        case "Fasting Glucose":
            return value < 100 ? "Normal" : value < 126 ? "Prediabetes" : "Diabetes Range"
        case "HbA1c":
            return value < 5.7 ? "Normal" : value < 6.5 ? "Prediabetes" : "Diabetes Range"
        case "Hemoglobin":
            return (value >= 12 && value <= 16) ? "Normal" : value < 12 ? "Low" : "High"
        case "eGFR":
            return value >= 60 ? "Normal" : value >= 30 ? "Moderate Decrease" : "Severe Decrease"
        case "Vitamin D":
            return value >= 30 ? "Sufficient" : value >= 20 ? "Insufficient" : "Deficient"
        default:
            return "Normal" // Default status
        }
    }
}
