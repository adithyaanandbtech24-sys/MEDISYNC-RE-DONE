import Foundation

/// Provides dynamic medical standards based on user demographics
class MedicalStandardProvider {
    
    // MARK: - User Profile
    struct UserProfile {
        let age: Int
        let gender: Gender
        let height: Double? // cm
        let weight: Double? // kg
        
        enum Gender {
            case male
            case female
            case other
        }
        
        var bmi: Double? {
            guard let height = height, let weight = weight, height > 0 else { return nil }
            let heightInMeters = height / 100.0
            return weight / (heightInMeters * heightInMeters)
        }
    }
    
    // MARK: - Standard Range
    struct StandardRange {
        let min: Double
        let max: Double
        let unit: String
        let description: String
        let severity: Severity
        
        enum Severity {
            case normal
            case borderline
            case abnormal
            case critical
        }
        
        func assess(value: Double) -> (status: String, severity: Severity) {
            if value < min {
                let percentBelow = ((min - value) / min) * 100
                if percentBelow > 30 {
                    return ("Critically Low", .critical)
                } else if percentBelow > 15 {
                    return ("Low", .abnormal)
                } else {
                    return ("Slightly Below Normal", .borderline)
                }
            } else if value > max {
                let percentAbove = ((value - max) / max) * 100
                if percentAbove > 30 {
                    return ("Critically High", .critical)
                } else if percentAbove > 15 {
                    return ("High", .abnormal)
                } else {
                    return ("Slightly Above Normal", .borderline)
                }
            } else {
                return ("Normal", .normal)
            }
        }
    }
    
    private let userProfile: UserProfile
    
    init(userProfile: UserProfile) {
        self.userProfile = userProfile
    }
    
    // MARK: - Get Standards
    
    func getStandard(for parameter: String) -> StandardRange? {
        let normalizedParam = parameter.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Blood Count
        if normalizedParam.contains("hemoglobin") || normalizedParam.contains("hb") {
            return hemoglobinRange
        } else if normalizedParam.contains("wbc") || normalizedParam.contains("white blood") {
            return wbcRange
        } else if normalizedParam.contains("rbc") || normalizedParam.contains("red blood") {
            return rbcRange
        } else if normalizedParam.contains("platelet") {
            return plateletRange
        }
        
        // Lipid Panel
        else if normalizedParam.contains("cholesterol") && !normalizedParam.contains("ldl") && !normalizedParam.contains("hdl") {
            return totalCholesterolRange
        } else if normalizedParam.contains("ldl") {
            return ldlRange
        } else if normalizedParam.contains("hdl") {
            return hdlRange
        } else if normalizedParam.contains("triglyceride") {
            return triglycerideRange
        }
        
        // Glucose & Diabetes
        else if normalizedParam.contains("glucose") && normalizedParam.contains("fasting") {
            return fastingGlucoseRange
        } else if normalizedParam.contains("hba1c") || normalizedParam.contains("a1c") {
            return hba1cRange
        }
        
        // Liver Function
        else if normalizedParam.contains("alt") || normalizedParam.contains("sgpt") {
            return altRange
        } else if normalizedParam.contains("ast") || normalizedParam.contains("sgot") {
            return astRange
        } else if normalizedParam.contains("bilirubin") && normalizedParam.contains("total") {
            return bilirubinRange
        }
        
        // Kidney Function
        else if normalizedParam.contains("creatinine") {
            return creatinineRange
        } else if normalizedParam.contains("egfr") {
            return egfrRange
        } else if normalizedParam.contains("bun") || normalizedParam.contains("urea") {
            return bunRange
        }
        
        // Vitals
        else if normalizedParam.contains("heart rate") || normalizedParam.contains("pulse") {
            return heartRateRange
        } else if normalizedParam.contains("blood pressure") && normalizedParam.contains("systolic") {
            return systolicBPRange
        } else if normalizedParam.contains("blood pressure") && normalizedParam.contains("diastolic") {
            return diastolicBPRange
        } else if normalizedParam.contains("spo2") || normalizedParam.contains("oxygen") {
            return spo2Range
        }
        
        // Thyroid
        else if normalizedParam.contains("tsh") {
            return tshRange
        } else if normalizedParam.contains("t3") {
            return t3Range
        } else if normalizedParam.contains("t4") {
            return t4Range
        }
        
        // Vitamins
        else if normalizedParam.contains("vitamin d") || normalizedParam.contains("vit d") {
            return vitaminDRange
        } else if normalizedParam.contains("vitamin b12") || normalizedParam.contains("b12") {
            return vitaminB12Range
        }
        
        return nil
    }
    
    // MARK: - Range Definitions
    
    private var hemoglobinRange: StandardRange {
        switch userProfile.gender {
        case .male:
            return StandardRange(min: 13.0, max: 17.0, unit: "g/dL", description: "Normal Hemoglobin (Male)", severity: .normal)
        case .female:
            return StandardRange(min: 12.0, max: 15.0, unit: "g/dL", description: "Normal Hemoglobin (Female)", severity: .normal)
        case .other:
            return StandardRange(min: 12.0, max: 16.0, unit: "g/dL", description: "Normal Hemoglobin", severity: .normal)
        }
    }
    
    private var wbcRange: StandardRange {
        StandardRange(min: 4.0, max: 11.0, unit: "×10³/µL", description: "Normal White Blood Cell Count", severity: .normal)
    }
    
    private var rbcRange: StandardRange {
        switch userProfile.gender {
        case .male:
            return StandardRange(min: 4.7, max: 6.1, unit: "million/µL", description: "Normal RBC (Male)", severity: .normal)
        case .female:
            return StandardRange(min: 4.2, max: 5.4, unit: "million/µL", description: "Normal RBC (Female)", severity: .normal)
        case .other:
            return StandardRange(min: 4.2, max: 5.8, unit: "million/µL", description: "Normal RBC", severity: .normal)
        }
    }
    
    private var plateletRange: StandardRange {
        StandardRange(min: 150, max: 400, unit: "×10³/µL", description: "Normal Platelet Count", severity: .normal)
    }
    
    private var totalCholesterolRange: StandardRange {
        StandardRange(min: 125, max: 200, unit: "mg/dL", description: "Desirable Total Cholesterol", severity: .normal)
    }
    
    private var ldlRange: StandardRange {
        StandardRange(min: 0, max: 100, unit: "mg/dL", description: "Optimal LDL", severity: .normal)
    }
    
    private var hdlRange: StandardRange {
        StandardRange(min: 40, max: 100, unit: "mg/dL", description: "Healthy HDL", severity: .normal)
    }
    
    private var triglycerideRange: StandardRange {
        StandardRange(min: 0, max: 150, unit: "mg/dL", description: "Normal Triglycerides", severity: .normal)
    }
    
    private var fastingGlucoseRange: StandardRange {
        StandardRange(min: 70, max: 100, unit: "mg/dL", description: "Normal Fasting Glucose", severity: .normal)
    }
    
    private var hba1cRange: StandardRange {
        StandardRange(min: 4.0, max: 5.6, unit: "%", description: "Normal HbA1c", severity: .normal)
    }
    
    private var altRange: StandardRange {
        StandardRange(min: 7, max: 56, unit: "U/L", description: "Normal ALT", severity: .normal)
    }
    
    private var astRange: StandardRange {
        StandardRange(min: 10, max: 40, unit: "U/L", description: "Normal AST", severity: .normal)
    }
    
    private var bilirubinRange: StandardRange {
        StandardRange(min: 0.1, max: 1.2, unit: "mg/dL", description: "Normal Total Bilirubin", severity: .normal)
    }
    
    private var creatinineRange: StandardRange {
        switch userProfile.gender {
        case .male:
            return StandardRange(min: 0.7, max: 1.3, unit: "mg/dL", description: "Normal Creatinine (Male)", severity: .normal)
        case .female:
            return StandardRange(min: 0.6, max: 1.1, unit: "mg/dL", description: "Normal Creatinine (Female)", severity: .normal)
        case .other:
            return StandardRange(min: 0.6, max: 1.2, unit: "mg/dL", description: "Normal Creatinine", severity: .normal)
        }
    }
    
    private var egfrRange: StandardRange {
        if userProfile.age >= 60 {
            return StandardRange(min: 60, max: 89, unit: "mL/min/1.73m²", description: "Normal eGFR (60+)", severity: .normal)
        } else {
            return StandardRange(min: 90, max: 120, unit: "mL/min/1.73m²", description: "Normal eGFR", severity: .normal)
        }
    }
    
    private var bunRange: StandardRange {
        StandardRange(min: 7, max: 20, unit: "mg/dL", description: "Normal BUN", severity: .normal)
    }
    
    private var heartRateRange: StandardRange {
        if userProfile.age < 18 {
            return StandardRange(min: 70, max: 100, unit: "BPM", description: "Normal Heart Rate (Youth)", severity: .normal)
        } else if userProfile.age >= 60 {
            return StandardRange(min: 60, max: 90, unit: "BPM", description: "Normal Heart Rate (Senior)", severity: .normal)
        } else {
            return StandardRange(min: 60, max: 100, unit: "BPM", description: "Normal Resting Heart Rate", severity: .normal)
        }
    }
    
    private var systolicBPRange: StandardRange {
        StandardRange(min: 90, max: 120, unit: "mmHg", description: "Normal Systolic Blood Pressure", severity: .normal)
    }
    
    private var diastolicBPRange: StandardRange {
        StandardRange(min: 60, max: 80, unit: "mmHg", description: "Normal Diastolic Blood Pressure", severity: .normal)
    }
    
    private var spo2Range: StandardRange {
        StandardRange(min: 95, max: 100, unit: "%", description: "Normal Oxygen Saturation", severity: .normal)
    }
    
    private var tshRange: StandardRange {
        StandardRange(min: 0.4, max: 4.0, unit: "mIU/L", description: "Normal TSH", severity: .normal)
    }
    
    private var t3Range: StandardRange {
        StandardRange(min: 80, max: 200, unit: "ng/dL", description: "Normal T3", severity: .normal)
    }
    
    private var t4Range: StandardRange {
        StandardRange(min: 5.0, max: 12.0, unit: "µg/dL", description: "Normal T4", severity: .normal)
    }
    
    private var vitaminDRange: StandardRange {
        StandardRange(min: 30, max: 100, unit: "ng/mL", description: "Sufficient Vitamin D", severity: .normal)
    }
    
    private var vitaminB12Range: StandardRange {
        StandardRange(min: 200, max: 900, unit: "pg/mL", description: "Normal Vitamin B12", severity: .normal)
    }
}
