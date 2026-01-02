import SwiftUI
import SwiftData
import Combine
import FirebaseFirestore

/// ViewModel for managing health data across the app with real-time sync
@MainActor
class HealthDataViewModel: ObservableObject {
    private let modelContext: ModelContext
    
    @Published var reports: [MedicalReportModel] = []
    @Published var labResults: [LabResultModel] = []
    @Published var medications: [MedicationModel] = []
    @Published var timelineEntries: [TimelineEntryModel] = []
    @Published var graphData: [GraphDataModel] = []
    
    // Real-time listeners
    private var reportListener: ListenerRegistration?
    private var labListener: ListenerRegistration?
    private var medicationListener: ListenerRegistration?
    private var timelineListener: ListenerRegistration?
    private var graphListener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    private let auth = FirebaseAuthService.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupRealtimeListeners()
    }
    
    // MARK: - Real-Time Listeners
    
    private func setupRealtimeListeners() {
        guard let uid = auth.getCurrentUserID() else { return }
        
        // Reports listener
        reportListener = db.collection("users")
            .document(uid)
            .collection("reports")
            .order(by: "uploadDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.reports = documents.compactMap { FirestoreMappers.fromFirestore($0.data()) }
                }
            }
        
        // Lab results listener
        labListener = db.collection("users")
            .document(uid)
            .collection("lab_results")
            .order(by: "testDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.labResults = documents.compactMap { FirestoreMappers.fromFirestore($0.data()) }
                }
            }
        
        // Medications listener
        medicationListener = db.collection("users")
            .document(uid)
            .collection("medications")
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.medications = documents.compactMap { FirestoreMappers.fromFirestore($0.data()) }
                }
            }
        
        // Timeline listener
        timelineListener = db.collection("users")
            .document(uid)
            .collection("timeline")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.timelineEntries = documents.compactMap { FirestoreMappers.fromFirestore($0.data()) }
                }
            }
        
        // Graph data listener
        graphListener = db.collection("users")
            .document(uid)
            .collection("graphData")
            .order(by: "date", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    self.graphData = documents.compactMap { GraphDataModel.fromFirestore($0.data()) }
                }
            }
    }
    
    // MARK: - Computed Properties
    
    /// Get latest lab result for a specific test
    func latestLabResult(for testName: String) -> LabResultModel? {
        labResults.first { $0.testName == testName }
    }
    
    /// Get lab results by category
    func labResults(for category: String) -> [LabResultModel] {
        labResults.filter { $0.category == category }
    }
    
    /// Get health summary statistics
    var healthSummary: HealthSummary {
        HealthSummary(
            totalReports: reports.count,
            totalLabTests: labResults.count,
            activeMedications: medications.count,
            abnormalResults: labResults.filter { $0.status != "Normal" && $0.status != "Optimal" }.count
        )
    }
    
    /// Get recent activity (last 7 days)
    var recentActivity: [TimelineEntryModel] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return timelineEntries.filter { $0.date >= sevenDaysAgo }
    }
    
    // MARK: - Cleanup
    
    deinit {
        reportListener?.remove()
        labListener?.remove()
        medicationListener?.remove()
        timelineListener?.remove()
        graphListener?.remove()
    }
}

// MARK: - Supporting Types

struct HealthSummary {
    let totalReports: Int
    let totalLabTests: Int
    let activeMedications: Int
    let abnormalResults: Int
}

