// MLService.swift
import Foundation
import CoreML

/// Service for machine learning-based health metric extraction and analysis
class MLService {
    // MARK: - Singleton
    static let shared = MLService()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Extract health metrics from text using ML
    func extractMetrics(from text: String) async throws -> [String: Any] {
        var result: [String: Any] = [:]
        var labResults: [[String: Any]] = []
        
        // Parse numerical values with context
        let parsedValues = parseHealthValues(from: text)
        
        // Convert each parsed value to a normalized lab result
        for (key, value) in parsedValues {
            let normalizedMetric = normalizeMetric(key: key, value: value)
            
            // Create individual lab result entry
            let labResult: [String: Any] = [
                "name": normalizedMetric.name,
                "value": normalizedMetric.value,
                "unit": normalizedMetric.unit,
                "status": normalizedMetric.status,
                "normalRange": normalizedMetric.normalRange,
                "category": normalizedMetric.category
            ]
            labResults.append(labResult)
        }
        
        // Compile all metrics
        result["metrics"] = labResults
        result["reportType"] = detectReportType(from: text)
        result["organ"] = detectOrgan(from: text)
        result["insights"] = generateInsights(from: parsedValues)
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func parseHealthValues(from text: String) -> [String: Double] {
        var values: [String: Double] = [:]
        
        print("🔍 [MLService] Starting NARRATIVE parsing...")
        print("📝 [MLService] Text length: \(text.count) characters")
        print("📝 [MLService] Sample text: \(text.prefix(300))")
        
        // NARRATIVE PARSING: Look for "test_name value unit" patterns anywhere in text
        // Example: "hemoglobin 12.8 g/dL" or "WBC 9.2" or "fasting glucose 148 mg/dL"
        
        let narrativePatterns: [(String, String)] = [
            // VITAL SIGNS - Critical for dashboard graphs
            ("heart_rate", #"(?:heart rate|hr|pulse|pulse rate)\s*:?\s*(\d+\.?\d*)\s*(?:bpm|beats|/min)?"#),
            ("spo2", #"(?:spo2|sp o2|oxygen saturation|o2 sat)\s*:?\s*(\d+\.?\d*)\s*%?"#),
            ("respiratory_rate", #"(?:respiratory rate|rr|respiration|breathing rate)\s*:?\s*(\d+\.?\d*)\s*(?:/min|breaths)?"#),
            ("blood_pressure_systolic", #"(?:blood pressure|bp)\s*:?\s*(\d{2,3})/\d{2,3}"#),
            ("blood_pressure_diastolic", #"(?:blood pressure|bp)\s*:?\s*\d{2,3}/(\d{2,3})"#),
            ("temperature", #"(?:temp|temperature)\s*:?\s*(\d+\.?\d*)\s*(?:°F|F|celsius|°C)?"#),
            
            // Blood tests - narrative format
            ("hemoglobin", #"(?:hemoglobin|hgb|hb)\s+(\d+\.?\d*)\s*(?:g/dL|g/dl|gm/dl)?"#),
            ("hematocrit", #"(?:hematocrit|hct)\s+(\d+\.?\d*)\s*%?"#),
            ("rbc", #"(?:rbc|red blood cell)\s+(\d+\.?\d*)"#),
            ("wbc", #"(?:wbc|white blood cell)\s+(\d+\.?\d*)"#),
            ("platelets", #"(?:platelet|plt)\s+(\d+\.?\d*)"#),
            
            // Glucose & Diabetes
            ("glucose", #"(?:fasting\s+)?(?:glucose|blood sugar)\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            ("hba1c", #"(?:hba1c|a1c|glycated hemoglobin)\s+(\d+\.?\d*)\s*%?"#),
            ("fasting_insulin", #"(?:fasting\s+)?insulin\s+(\d+\.?\d*)"#),
            
            // Lipid Panel
            ("cholesterol", #"(?:total\s+)?cholesterol\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            ("ldl", #"ldl\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            ("hdl", #"hdl\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            ("triglycerides", #"triglycerides?\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            
            // Kidney Function
            ("creatinine", #"creatinine\s+(\d+\.?\d*)\s*(?:mg/dL|mg/dl)?"#),
            ("bun", #"(?:bun|blood urea nitrogen)\s+(\d+\.?\d*)"#),
            ("egfr", #"(?:egfr|gfr)\s+(\d+\.?\d*)"#),
            
            // Liver Function
            ("alt", #"(?:alt|sgpt)\s+(\d+\.?\d*)"#),
            ("ast", #"(?:ast|sgot)\s+(\d+\.?\d*)"#),
            ("alp", #"(?:alp|alkaline phosphatase)\s+(\d+\.?\d*)"#),
            ("bilirubin", #"(?:total\s+)?bilirubin\s+(\d+\.?\d*)"#),
            ("albumin", #"albumin\s+(\d+\.?\d*)"#),
            
            // Thyroid
            ("tsh", #"tsh\s+(\d+\.?\d*)"#),
            ("t3", #"t3\s+(\d+\.?\d*)"#),
            ("t4", #"(?:free\s+)?t4\s+(\d+\.?\d*)"#),
            
            // Electrolytes
            ("sodium", #"sodium\s+(\d+\.?\d*)"#),
            ("potassium", #"potassium\s+(\d+\.?\d*)"#),
            ("calcium", #"calcium\s+(\d+\.?\d*)"#),
            
            // Vitamins
            ("vitamin_d", #"vitamin\s*d\s+(\d+\.?\d*)"#),
            ("vitamin_b12", #"(?:vitamin\s*)?b12\s+(\d+\.?\d*)"#),
            
            // Iron
            ("iron", #"(?:serum\s+)?iron\s+(\d+\.?\d*)"#),
            ("ferritin", #"ferritin\s+(\d+\.?\d*)"#),
            
            // Cardiac
            ("troponin", #"troponin\s+(\d+\.?\d*)"#),
            ("bnp", #"bnp\s+(\d+\.?\d*)"#),
            
            // Inflammation
            ("crp", #"(?:crp|c-reactive protein)\s+(\d+\.?\d*)"#),
            ("esr", #"esr\s+(\d+\.?\d*)"#)
        ]
        
        print("🔍 [MLService] Testing \(narrativePatterns.count) narrative patterns...")
        var matchCount = 0
        
        for (key, pattern) in narrativePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                
                for match in matches {
                    if let valueRange = Range(match.range(at: 1), in: text),
                       let value = Double(text[valueRange]) {
                        values[key] = value
                        matchCount += 1
                        print("✅ [MLService] Found \(key): \(value)")
                        break // Take first match for each test
                    }
                }
            }
        }
        
        print("📊 [MLService] Total matches found: \(matchCount)")
        if matchCount == 0 {
            print("⚠️ [MLService] NO METRICS FOUND! Dumping full text for analysis:")
            print("📝 [MLService] Full text:\n\(text)")
        }
        
        return values
    }
    
    private func normalizeMetric(key: String, value: Double) -> NormalizedMetric {
        switch key {
        // Complete Blood Count
        case "hemoglobin":
            return NormalizedMetric(
                name: "Hemoglobin",
                value: value,
                unit: "g/dL",
                status: value >= 12 && value <= 16 ? "Normal" : value < 12 ? "Low" : "High",
                normalRange: "12-16 g/dL",
                category: "Blood"
            )
        case "hematocrit":
            return NormalizedMetric(
                name: "Hematocrit",
                value: value,
                unit: "%",
                status: value >= 36 && value <= 48 ? "Normal" : value < 36 ? "Low" : "High",
                normalRange: "36-48%",
                category: "Blood"
            )
        case "rbc":
            return NormalizedMetric(
                name: "RBC Count",
                value: value,
                unit: "M/μL",
                status: value >= 4.2 && value <= 5.4 ? "Normal" : value < 4.2 ? "Low" : "High",
                normalRange: "4.2-5.4 M/μL",
                category: "Blood"
            )
        case "wbc":
            return NormalizedMetric(
                name: "WBC Count",
                value: value,
                unit: "K/μL",
                status: value >= 4.5 && value <= 11.0 ? "Normal" : value < 4.5 ? "Low" : "High",
                normalRange: "4.5-11.0 K/μL",
                category: "Blood"
            )
        case "platelets":
            return NormalizedMetric(
                name: "Platelets",
                value: value,
                unit: "K/μL",
                status: value >= 150 && value <= 400 ? "Normal" : value < 150 ? "Low" : "High",
                normalRange: "150-400 K/μL",
                category: "Blood"
            )
            
        // Liver Function
        case "alt":
            return NormalizedMetric(
                name: "ALT (SGPT)",
                value: value,
                unit: "U/L",
                status: value <= 40 ? "Normal" : value <= 80 ? "Borderline High" : "High",
                normalRange: "<40 U/L",
                category: "Liver"
            )
        case "ast":
            return NormalizedMetric(
                name: "AST (SGOT)",
                value: value,
                unit: "U/L",
                status: value <= 40 ? "Normal" : value <= 80 ? "Borderline High" : "High",
                normalRange: "<40 U/L",
                category: "Liver"
            )
        case "bilirubin_total":
            return NormalizedMetric(
                name: "Total Bilirubin",
                value: value,
                unit: "mg/dL",
                status: value <= 1.2 ? "Normal" : "High",
                normalRange: "0.1-1.2 mg/dL",
                category: "Liver"
            )
            
        // Kidney Function
        case "creatinine":
            return NormalizedMetric(
                name: "Creatinine",
                value: value,
                unit: "mg/dL",
                status: value >= 0.6 && value <= 1.2 ? "Normal" : value < 0.6 ? "Low" : "High",
                normalRange: "0.6-1.2 mg/dL",
                category: "Kidney"
            )
        case "bun":
            return NormalizedMetric(
                name: "BUN",
                value: value,
                unit: "mg/dL",
                status: value >= 7 && value <= 20 ? "Normal" : value < 7 ? "Low" : "High",
                normalRange: "7-20 mg/dL",
                category: "Kidney"
            )
        case "egfr":
            return NormalizedMetric(
                name: "eGFR",
                value: value,
                unit: "mL/min",
                status: value >= 90 ? "Normal" : value >= 60 ? "Mildly Decreased" : "Decreased",
                normalRange: ">90 mL/min",
                category: "Kidney"
            )
            
        // Lipid Panel
        case "cholesterol":
            return NormalizedMetric(
                name: "Total Cholesterol",
                value: value,
                unit: "mg/dL",
                status: value < 200 ? "Normal" : value < 240 ? "Borderline High" : "High",
                normalRange: "<200 mg/dL",
                category: "Lipids"
            )
        case "hdl":
            return NormalizedMetric(
                name: "HDL Cholesterol",
                value: value,
                unit: "mg/dL",
                status: value >= 40 ? "Normal" : "Low",
                normalRange: ">40 mg/dL",
                category: "Lipids"
            )
        case "ldl":
            return NormalizedMetric(
                name: "LDL Cholesterol",
                value: value,
                unit: "mg/dL",
                status: value < 100 ? "Optimal" : value < 130 ? "Near Optimal" : value < 160 ? "Borderline High" : "High",
                normalRange: "<100 mg/dL",
                category: "Lipids"
            )
        case "triglycerides":
            return NormalizedMetric(
                name: "Triglycerides",
                value: value,
                unit: "mg/dL",
                status: value < 150 ? "Normal" : value < 200 ? "Borderline High" : "High",
                normalRange: "<150 mg/dL",
                category: "Lipids"
            )
            
        // Thyroid
        case "tsh":
            return NormalizedMetric(
                name: "TSH",
                value: value,
                unit: "μIU/mL",
                status: value >= 0.4 && value <= 4.0 ? "Normal" : value < 0.4 ? "Low" : "High",
                normalRange: "0.4-4.0 μIU/mL",
                category: "Thyroid"
            )
            
        // Glucose
        case "glucose":
            return NormalizedMetric(
                name: "Blood Glucose",
                value: value,
                unit: "mg/dL",
                status: value < 100 ? "Normal" : value < 126 ? "Prediabetes" : "Diabetes Range",
                normalRange: "70-100 mg/dL",
                category: "Metabolic"
            )
        case "hba1c":
            return NormalizedMetric(
                name: "HbA1c",
                value: value,
                unit: "%",
                status: value < 5.7 ? "Normal" : value < 6.5 ? "Prediabetes" : "Diabetes Range",
                normalRange: "<5.7%",
                category: "Metabolic"
            )
            
        // Vitamins
        case "vitamin_d":
            return NormalizedMetric(
                name: "Vitamin D",
                value: value,
                unit: "ng/mL",
                status: value >= 30 ? "Sufficient" : value >= 20 ? "Insufficient" : "Deficient",
                normalRange: ">30 ng/mL",
                category: "Vitamins"
            )
        case "vitamin_b12":
            return NormalizedMetric(
                name: "Vitamin B12",
                value: value,
                unit: "pg/mL",
                status: value >= 200 ? "Normal" : "Low",
                normalRange: ">200 pg/mL",
                category: "Vitamins"
            )
            
        // VITAL SIGNS - Enhanced
        case "heart_rate":
            return NormalizedMetric(
                name: "Heart Rate",
                value: value,
                unit: "BPM",
                status: value >= 60 && value <= 100 ? "Normal" : value < 60 ? "Low" : "High",
                normalRange: "60-100 BPM",
                category: "Cardiac"
            )
        case "spo2":
            return NormalizedMetric(
                name: "SpO2",
                value: value,
                unit: "%",
                status: value >= 95 ? "Normal" : value >= 90 ? "Low" : "Critical",
                normalRange: "95-100%",
                category: "Respiratory"
            )
        case "respiratory_rate":
            return NormalizedMetric(
                name: "Respiratory Rate",
                value: value,
                unit: "breaths/min",
                status: value >= 12 && value <= 20 ? "Normal" : value < 12 ? "Low" : "High",
                normalRange: "12-20 breaths/min",
                category: "Respiratory"
            )
        case "blood_pressure_systolic":
            return NormalizedMetric(
                name: "Blood Pressure Systolic",
                value: value,
                unit: "mmHg",
                status: value >= 90 && value <= 120 ? "Normal" : value < 90 ? "Low" : "High",
                normalRange: "90-120 mmHg",
                category: "Cardiovascular"
            )
        case "blood_pressure_diastolic":
            return NormalizedMetric(
                name: "Blood Pressure Diastolic",
                value: value,
                unit: "mmHg",
                status: value >= 60 && value <= 80 ? "Normal" : value < 60 ? "Low" : "High",
                normalRange: "60-80 mmHg",
                category: "Cardiovascular"
            )
        case "temperature":
            return NormalizedMetric(
                name: "Temperature",
                value: value,
                unit: "°F",
                status: value >= 97.0 && value <= 99.0 ? "Normal" : value < 97.0 ? "Low" : "Fever",
                normalRange: "97-99°F",
                category: "General"
            )
            
        default:
            return NormalizedMetric(
                name: key.capitalized.replacingOccurrences(of: "_", with: " "),
                value: value,
                unit: "",
                status: "Unknown",
                normalRange: "N/A",
                category: "General"
            )
        }
    }
    
    private func detectOrgan(from text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("heart") || lowercased.contains("cardiac") || lowercased.contains("ecg") || lowercased.contains("ekg") {
            return "Heart"
        } else if lowercased.contains("kidney") || lowercased.contains("renal") || lowercased.contains("creatinine") || lowercased.contains("bun") {
            return "Kidney"
        } else if lowercased.contains("liver") || lowercased.contains("hepatic") || lowercased.contains("alt") || lowercased.contains("ast") {
            return "Liver"
        } else if lowercased.contains("lung") || lowercased.contains("pulmonary") || lowercased.contains("respiratory") {
            return "Lungs"
        } else if lowercased.contains("thyroid") || lowercased.contains("tsh") {
            return "Thyroid"
        } else if lowercased.contains("blood") || lowercased.contains("cbc") || lowercased.contains("hemoglobin") {
            return "Blood"
        } else {
            return "General"
        }
    }
    
    private func detectReportType(from text: String) -> String {
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("blood test") || lowercasedText.contains("cbc") || lowercasedText.contains("hemoglobin") {
            return "Blood Test"
        } else if lowercasedText.contains("lipid panel") || lowercasedText.contains("cholesterol") {
            return "Lipid Panel"
        } else if lowercasedText.contains("liver function") || lowercasedText.contains("lft") {
            return "Liver Function Test"
        } else if lowercasedText.contains("kidney function") || lowercasedText.contains("kft") || lowercasedText.contains("renal") {
            return "Kidney Function Test"
        } else if lowercasedText.contains("thyroid") || lowercasedText.contains("tsh") {
            return "Thyroid Panel"
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
    
    private func generateInsights(from values: [String: Double]) -> String {
        var insights: [String] = []
        
        // Cholesterol
        if let cholesterol = values["cholesterol"], cholesterol > 200 {
            insights.append("Cholesterol levels are elevated. Consider dietary modifications and increased physical activity.")
        }
        
        // Glucose/Diabetes
        if let glucose = values["glucose"], glucose > 100 {
            insights.append("Blood glucose is above normal. Monitor sugar intake and consult your doctor.")
        }
        if let hba1c = values["hba1c"], hba1c >= 5.7 {
            insights.append("HbA1c indicates prediabetes or diabetes. Lifestyle changes and medical supervision recommended.")
        }
        
        // Liver
        if let alt = values["alt"], alt > 40 {
            insights.append("Elevated liver enzymes detected. Avoid alcohol and consult your physician.")
        }
        
        // Kidney
        if let creatinine = values["creatinine"], creatinine > 1.2 {
            insights.append("Elevated creatinine suggests possible kidney stress. Stay hydrated and follow up with your doctor.")
        }
        if let egfr = values["egfr"], egfr < 60 {
            insights.append("Reduced kidney function detected. Regular monitoring and nephrology consultation recommended.")
        }
        
        // Vitamins
        if let vitaminD = values["vitamin_d"], vitaminD < 20 {
            insights.append("Vitamin D deficiency detected. Consider supplementation and increased sun exposure.")
        }
        if let vitaminB12 = values["vitamin_b12"], vitaminB12 < 200 {
            insights.append("Low Vitamin B12. Consider supplementation or dietary changes.")
        }
        
        // Thyroid
        if let tsh = values["tsh"] {
            if tsh > 4.0 {
                insights.append("Elevated TSH may indicate hypothyroidism. Endocrinology consultation recommended.")
            } else if tsh < 0.4 {
                insights.append("Low TSH may indicate hyperthyroidism. Further thyroid testing advised.")
            }
        }
        
        // Blood Count
        if let wbc = values["wbc"] {
            if wbc > 11.0 {
                insights.append("Elevated white blood cell count may indicate infection or inflammation.")
            } else if wbc < 4.5 {
                insights.append("Low white blood cell count. Monitor for immune system concerns.")
            }
        }
        
        return insights.isEmpty ? "All monitored metrics appear within acceptable ranges." : insights.joined(separator: " ")
    }
}

// MARK: - Supporting Types

struct NormalizedMetric {
    let name: String
    let value: Double
    let unit: String
    let status: String
    let normalRange: String
    let category: String
}
