import Foundation
import UIKit
import PDFKit
import SwiftData

/// Parser for extracting medical data from OCR text
class MedicalDataParser {
    
    // MARK: - Lab Results Parsing
    
    /// Parse lab results from OCR text
    static func parseLabResults(from text: String) -> [LabResultModel] {
        var results: [LabResultModel] = []
        
        // Comprehensive lab test patterns - expanded coverage
        let patterns: [(name: String, pattern: String, unit: String, category: String, normalRange: String)] = [
            // Blood Count (CBC)
            ("Hemoglobin", #"(?:hemoglobin|hb|hgb)[:\s]+(\d+\.?\d*)\s*(?:g/dL|g/dl|gm/dl)?"#, "g/dL", "Blood Count", "12-16 g/dL"),
            ("WBC", #"(?:wbc|white\s*blood\s*cell)[:\s]+(\d+\.?\d*)\s*(?:×10³/µL|thousand/cumm|/cmm)?"#, "×10³/µL", "Blood Count", "4-11 ×10³/µL"),
            ("RBC", #"(?:rbc|red\s*blood\s*cell)[:\s]+(\d+\.?\d*)\s*(?:million/µL|mill/cumm)?"#, "million/µL", "Blood Count", "4.5-5.5 million/µL"),
            ("Platelets", #"(?:platelet[s]?|plt)[:\s]+(\d+\.?\d*)\s*(?:×10³/µL|thousand/cumm|/cmm)?"#, "×10³/µL", "Blood Count", "150-400 ×10³/µL"),
            ("Hematocrit", #"(?:hematocrit|hct|pcv)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "37-47%"),
            ("MCV", #"(?:mcv|mean\s*corpuscular\s*volume)[:\s]+(\d+\.?\d*)\s*(?:fL|fl)?"#, "fL", "Blood Count", "80-100 fL"),
            ("MCH", #"(?:mch|mean\s*corpuscular\s*hb)[:\s]+(\d+\.?\d*)\s*(?:pg)?"#, "pg", "Blood Count", "27-33 pg"),
            ("MCHC", #"(?:mchc)[:\s]+(\d+\.?\d*)\s*(?:g/dL)?"#, "g/dL", "Blood Count", "32-36 g/dL"),
            
            // WBC Differential
            ("Neutrophils", #"(?:neutrophil[s]?|neut)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "40-70%"),
            ("Lymphocytes", #"(?:lymphocyte[s]?|lymph)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "20-40%"),
            ("Monocytes", #"(?:monocyte[s]?|mono)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "2-8%"),
            ("Eosinophils", #"(?:eosinophil[s]?|eos?)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "1-4%"),
            ("Basophils", #"(?:basophil[s]?|baso)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Blood Count", "0-1%"),
            
            // Lipid Panel
            ("Total Cholesterol", #"(?:total\s+)?cholesterol[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Lipid Panel", "< 200 mg/dL"),
            ("LDL", #"(?:ldl|low\s*density)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Lipid Panel", "< 100 mg/dL"),
            ("HDL", #"(?:hdl|high\s*density)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Lipid Panel", "> 40 mg/dL"),
            ("Triglycerides", #"(?:triglyceride[s]?|tg)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Lipid Panel", "< 150 mg/dL"),
            ("VLDL", #"(?:vldl)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Lipid Panel", "< 30 mg/dL"),
            
            // Glucose & Diabetes
            ("Fasting Glucose", #"(?:fasting\s+)?(?:glucose|sugar|blood\s+sugar)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Glucose", "70-100 mg/dL"),
            ("Random Glucose", #"(?:random|pp|post\s*prandial)\s*(?:glucose|sugar)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Glucose", "< 140 mg/dL"),
            ("HbA1c", #"(?:hba1c|a1c|glycated\s*hb)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Glucose", "< 5.7%"),
            
            // Liver Function Tests
            ("ALT", #"(?:alt|sgpt|alanine)[:\s]+(\d+\.?\d*)\s*(?:U/L|u/l|IU/L)?"#, "U/L", "Liver", "7-56 U/L"),
            ("AST", #"(?:ast|sgot|aspartate)[:\s]+(\d+\.?\d*)\s*(?:U/L|u/l|IU/L)?"#, "U/L", "Liver", "10-40 U/L"),
            ("Total Bilirubin", #"(?:total\s+)?bilirubin[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Liver", "0.1-1.2 mg/dL"),
            ("Direct Bilirubin", #"(?:direct|conjugated)\s*bilirubin[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Liver", "0-0.3 mg/dL"),
            ("ALP", #"(?:alp|alkaline\s*phosphatase)[:\s]+(\d+\.?\d*)\s*(?:U/L|u/l|IU/L)?"#, "U/L", "Liver", "44-147 U/L"),
            ("GGT", #"(?:ggt|gamma\s*gt)[:\s]+(\d+\.?\d*)\s*(?:U/L|u/l)?"#, "U/L", "Liver", "0-51 U/L"),
            ("Albumin", #"(?:albumin)[:\s]+(\d+\.?\d*)\s*(?:g/dL|g/dl)?"#, "g/dL", "Liver", "3.5-5.5 g/dL"),
            ("Total Protein", #"(?:total\s+)?protein[:\s]+(\d+\.?\d*)\s*(?:g/dL|g/dl)?"#, "g/dL", "Liver", "6.0-8.3 g/dL"),
            
            // Kidney Function Tests
            ("Creatinine", #"(?:creatinine|creat)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Kidney", "0.6-1.2 mg/dL"),
            ("eGFR", #"(?:egfr|gfr)[:\s]+(\d+\.?\d*)\s*(?:mL/min|ml/min)?"#, "mL/min/1.73m²", "Kidney", "> 60 mL/min"),
            ("BUN", #"(?:bun|blood\s*urea)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Kidney", "7-20 mg/dL"),
            ("Uric Acid", #"(?:uric\s*acid)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Kidney", "3.4-7.0 mg/dL"),
            
            // Electrolytes
            ("Sodium", #"(?:sodium|na)[:\s]+(\d+\.?\d*)\s*(?:mEq/L|meq/l|mmol/L)?"#, "mEq/L", "Electrolytes", "136-145 mEq/L"),
            ("Potassium", #"(?:potassium|k)[:\s]+(\d+\.?\d*)\s*(?:mEq/L|meq/l|mmol/L)?"#, "mEq/L", "Electrolytes", "3.5-5.0 mEq/L"),
            ("Chloride", #"(?:chloride|cl)[:\s]+(\d+\.?\d*)\s*(?:mEq/L|meq/l|mmol/L)?"#, "mEq/L", "Electrolytes", "96-106 mEq/L"),
            ("Calcium", #"(?:calcium|ca)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Electrolytes", "8.5-10.5 mg/dL"),
            ("Magnesium", #"(?:magnesium|mg)[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl|mEq/L)?"#, "mg/dL", "Electrolytes", "1.7-2.2 mg/dL"),
            
            // Vitamins & Minerals
            ("Vitamin D", #"(?:vitamin\s*d|vit\s*d|25\s*oh\s*d)[:\s]+(\d+\.?\d*)\s*(?:ng/mL|ng/ml)?"#, "ng/mL", "Vitamins", "30-100 ng/mL"),
            ("Vitamin B12", #"(?:vitamin\s*b12|vit\s*b12|b12)[:\s]+(\d+\.?\d*)\s*(?:pg/mL|pg/ml)?"#, "pg/mL", "Vitamins", "200-900 pg/mL"),
            ("Folate", #"(?:folate|folic\s*acid)[:\s]+(\d+\.?\d*)\s*(?:ng/mL|ng/ml)?"#, "ng/mL", "Vitamins", "2.7-17.0 ng/mL"),
            ("Iron", #"(?:iron|serum\s*iron)[:\s]+(\d+\.?\d*)\s*(?:µg/dL|ug/dl)?"#, "µg/dL", "Vitamins", "60-170 µg/dL"),
            ("Ferritin", #"(?:ferritin)[:\s]+(\d+\.?\d*)\s*(?:ng/mL|ng/ml)?"#, "ng/mL", "Vitamins", "12-300 ng/mL"),
            
            // Thyroid Function
            ("TSH", #"(?:tsh|thyroid\s*stimulating)[:\s]+(\d+\.?\d*)\s*(?:mIU/L|uIU/ml)?"#, "mIU/L", "Thyroid", "0.4-4.0 mIU/L"),
            ("T3", #"(?:^|\s)t3[:\s]+(\d+\.?\d*)\s*(?:ng/dL|ng/dl)?"#, "ng/dL", "Thyroid", "80-200 ng/dL"),
            ("T4", #"(?:^|\s)t4[:\s]+(\d+\.?\d*)\s*(?:µg/dL|ug/dl)?"#, "µg/dL", "Thyroid", "5-12 µg/dL"),
            ("Free T3", #"(?:free\s*t3|ft3)[:\s]+(\d+\.?\d*)\s*(?:pg/mL|pg/ml)?"#, "pg/mL", "Thyroid", "2.0-4.4 pg/mL"),
            ("Free T4", #"(?:free\s*t4|ft4)[:\s]+(\d+\.?\d*)\s*(?:ng/dL|ng/dl)?"#, "ng/dL", "Thyroid", "0.8-1.8 ng/dL"),
            
            // Cardiac Markers
            ("Troponin", #"(?:troponin|trop)[:\s]+(\d+\.?\d*)\s*(?:ng/mL|ng/ml)?"#, "ng/mL", "Cardiac", "< 0.04 ng/mL"),
            ("CK-MB", #"(?:ck-mb|ckmb)[:\s]+(\d+\.?\d*)\s*(?:ng/mL|ng/ml|U/L)?"#, "ng/mL", "Cardiac", "< 5.0 ng/mL"),
            ("BNP", #"(?:bnp|b-type)[:\s]+(\d+\.?\d*)\s*(?:pg/mL|pg/ml)?"#, "pg/mL", "Cardiac", "< 100 pg/mL"),
            
            // Inflammatory Markers
            ("CRP", #"(?:crp|c-reactive)[:\s]+(\d+\.?\d*)\s*(?:mg/L|mg/l)?"#, "mg/L", "Inflammatory", "< 3.0 mg/L"),
            ("ESR", #"(?:esr|sed\s*rate)[:\s]+(\d+\.?\d*)\s*(?:mm/hr|mm/h)?"#, "mm/hr", "Inflammatory", "< 20 mm/hr"),
            
            // Urine Tests
            ("Urine Protein", #"(?:urine\s*)?protein[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Urinalysis", "< 10 mg/dL"),
            ("Urine Glucose", #"(?:urine\s*)?glucose[:\s]+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#, "mg/dL", "Urinalysis", "< 15 mg/dL"),
            
            // Vitals (often in reports)
            ("Heart Rate", #"(?:heart\s*rate|pulse|hr)[:\s]+(\d+\.?\d*)\s*(?:bpm|/min)?"#, "BPM", "Vitals", "60-100 BPM"),
            ("Systolic BP", #"(?:bp|blood\s*pressure)[:\s]+(\d+)\/\d+\s*(?:mmHg)?"#, "mmHg", "Vitals", "90-120 mmHg"),
            ("Diastolic BP", #"(?:bp|blood\s*pressure)[:\s]+\d+\/(\d+)\s*(?:mmHg)?"#, "mmHg", "Vitals", "60-80 mmHg"),
            ("SpO2", #"(?:spo2|oxygen\s*sat|o2\s*sat)[:\s]+(\d+\.?\d*)\s*%?"#, "%", "Vitals", "95-100%"),
            ("Temperature", #"(?:temp|temperature)[:\s]+(\d+\.?\d*)\s*(?:°f|f|fahrenheit)?"#, "°F", "Vitals", "97.0-99.0°F")
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
                        parameter: name,
                        value: value,
                        unit: unit,
                        normalRange: normalRange,
                        status: status,
                        testDate: Date(),
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
                        frequency: frequency,
                        startDate: Date(),
                        isActive: true
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
                        frequency: "As prescribed",
                        startDate: Date(),
                        isActive: true
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
