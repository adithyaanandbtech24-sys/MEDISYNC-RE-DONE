// MedicationManager.swift
import SwiftUI
import SwiftData
import Foundation
import UserNotifications
import Combine

/// Manages medication data to ensure only uploaded medications are shown
@MainActor
class MedicationManager {
    static let shared = MedicationManager()
    
    private init() {}
    
    /// Clear all existing medications (removes demo data)
    func clearAllMedications(context: ModelContext) {
        context.clearAllMedications()
        print("✅ [MedicationManager] All medications cleared. Only medications from uploaded documents will be shown.")
    }
    
    /// Check if medications exist and clear demo data if needed
    func initializeMedications(context: ModelContext) {
        let existingMedications = context.fetchAllMedications()
        
        if !existingMedications.isEmpty {
            print("ℹ️ [MedicationManager] Found \(existingMedications.count) existing medications")
            
            // Check if any medications appear to be demo data (generic names without specific sources)
            let demoMedicationNames = ["Aspirin", "Metformin", "Lisinopril", "Atorvastatin"]
            let hasDemoData = existingMedications.contains { med in
                demoMedicationNames.contains(med.name) && 
                (med.prescribedBy == nil || med.prescribedBy == "Dr. Unknown" || med.prescribedBy == "Dr. Sarah Johnson")
            }
            
            if hasDemoData {
                print("🗑️ [MedicationManager] Clearing demo medications found")
                clearAllMedications(context: context)
            } else {
                print("✅ [MedicationManager] No demo data found. Keeping existing medications.")
            }
        } else {
            print("ℹ️ [MedicationManager] No existing medications found.")
        }
    }
    
    /// Get medications that were added through document uploads
    func getUploadedMedications(context: ModelContext) -> [MedicationModel] {
        let allMedications = context.fetchAllMedications()
        
        // Filter to only show medications that have been properly processed
        // These medications will have metadata indicating they came from document analysis
        let uploadedMedications = allMedications.filter { medication in
            // Keep medications that have:
            // 1. prescribedBy indicating document analysis
            // 2. instructions indicating document extraction
            // 3. Recent start dates (within last 2 years)
            
            let isFromDocumentAnalysis = medication.prescribedBy == "From Document Analysis"
            let hasDocumentInstructions = medication.instructions?.contains("Extracted from uploaded document") == true
            
            let recentStartDate = Calendar.current.dateComponents([.day], 
                                                                from: medication.startDate, 
                                                                to: Date()).day ?? 0 < 730 // Less than 2 years old
            
            return isFromDocumentAnalysis || hasDocumentInstructions || recentStartDate
        }
        
        return uploadedMedications.sorted { $0.startDate > $1.startDate }
    }
    
    /// Alternative: Get all medications but mark demo ones
    func getMedicationsWithDemo标记(context: ModelContext) -> (medications: [MedicationModel], hasDemoData: Bool) {
        let allMedications = context.fetchAllMedications()
        
        let demoMedicationNames = ["Aspirin", "Metformin", "Lisinopril", "Atorvastatin"]
        var hasDemoData = false
        
        let markedMedications = allMedications.map { medication in
            let isDemo = demoMedicationNames.contains(medication.name) && 
                        (medication.prescribedBy == nil || 
                         medication.prescribedBy == "Dr. Unknown" || 
                         medication.prescribedBy == "Dr. Sarah Johnson")
            
            if isDemo {
                hasDemoData = true
            }
            
            return medication
        }
        
        return (medications: markedMedications, hasDemoData: hasDemoData)
    }
}

// MARK: - Medication Reminder Manager
class MedicationReminderManager: ObservableObject {
    static let shared = MedicationReminderManager()
    
    @Published var permissionGranted = false
    
    init() {
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                if let error = error {
                    print("Notification permission error: \(error)")
                }
            }
        }
    }
    
    func scheduleReminder(title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}