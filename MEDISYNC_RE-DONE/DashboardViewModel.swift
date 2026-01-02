// DashboardViewModel.swift
import Foundation
import SwiftData
import Combine
import FirebaseFirestore

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recentReports: [MedicalReportModel] = []
    @Published var activeMedications: [MedicationModel] = []
    @Published var labResults: [LabResultModel] = []
    @Published var labTrends: [LabTrendSummary] = []
    @Published var healthAlerts: [HealthAlert] = []
    @Published var medicationSummary: MedicationAdherenceSummary?
    @Published var diagnosisSummary: DiagnosisSummary?
    @Published var timelineSummary: TimelineSummary?
    @Published var healthScore: Int = 0 // Default to 0 (No Data)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userRole: UserRole = .patient
    @Published var canEdit: Bool = true
    
    // MARK: - Dependencies
    private let authService = FirebaseAuthService.shared
    private let roleService = UserRoleService.shared
    private let dataEngine = DashboardDataEngine.shared
    private let db = Firestore.firestore()
    
    // Listeners stored as nonisolated to allow cleanup from deinit
    nonisolated(unsafe) var reportListener: ListenerRegistration?
    nonisolated(unsafe) var medicationListener: ListenerRegistration?
    nonisolated(unsafe) var labListener: ListenerRegistration?
    nonisolated(unsafe) var timelineListener: ListenerRegistration?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Listeners will be started when loadDashboardData is called
    }
    
    // MARK: - Data Loading with Real-Time Listeners
    
    func loadDashboardData(context: ModelContext, patientUid: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        // Determine which patient's data to load
        let targetUid = patientUid ?? authService.getCurrentUserID() ?? ""
        
        // Check permissions
        do {
            userRole = try await roleService.getCurrentUserRole()
            canEdit = try await roleService.canWritePatientData(patientUid: targetUid)
            
            // Setup real-time listeners
            setupRealtimeListeners(uid: targetUid, context: context)
            
        } catch {
            if let firestoreError = error as? FirestoreError {
                errorMessage = firestoreError.userMessage
            } else {
                errorMessage = "Failed to load dashboard: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Real-Time Listener Setup (CRITICAL FIX)
    
    private func setupRealtimeListeners(uid: String, context: ModelContext) {
        // Remove existing listeners
        stopListening()
        
        // Listen to medical reports
        reportListener = db.collection("users")
            .document(uid)
            .collection("reports")
            .order(by: "uploadDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Report listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    // Convert Firestore docs to models
                    let reports = documents.compactMap { doc -> MedicalReportModel? in
                        FirestoreMappers.fromFirestore(doc.data())
                    }
                    
                    // Update published property (triggers UI update)
                    self.recentReports = Array(reports.prefix(10))
                    
                    // Sync to local SwiftData
                    await self.syncReportsToLocal(reports, context: context)
                    
                    // Re-analyze data
                    await self.analyzeMedicalData(context: context)
                }
            }
        
        // Listen to medications
        medicationListener = db.collection("users")
            .document(uid)
            .collection("medications")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Medication listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let medications = documents.compactMap { doc -> MedicationModel? in
                        FirestoreMappers.fromFirestore(doc.data())
                    }
                    
                    self.activeMedications = medications
                    await self.syncMedicationsToLocal(medications, context: context)
                    await self.analyzeMedicalData(context: context)
                }
            }
        
        // Listen to lab results
        labListener = db.collection("users")
            .document(uid)
            .collection("lab_results")
            .order(by: "testDate", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Lab listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let labs = documents.compactMap { doc -> LabResultModel? in
                        FirestoreMappers.fromFirestore(doc.data())
                    }
                    
                    self.labResults = labs
                    await self.syncLabsToLocal(labs, context: context)
                    await self.analyzeMedicalData(context: context)
                }
            }
        
        // Listen to timeline entries
        timelineListener = db.collection("users")
            .document(uid)
            .collection("timeline")
            .order(by: "date", descending: true)
            .limit(to: 30)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Timeline listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    let entries = documents.compactMap { doc -> TimelineEntryModel? in
                        FirestoreMappers.fromFirestore(doc.data())
                    }
                    
                    await self.syncTimelineToLocal(entries, context: context)
                }
            }
    }
    
    /// Stop all real-time listeners
    nonisolated func stopListening() {
        reportListener?.remove()
        medicationListener?.remove()
        labListener?.remove() // Corrected from labResultListener to labListener
        timelineListener?.remove()
    }
    
    // MARK: - Local Sync Methods
    
    private func syncReportsToLocal(_ reports: [MedicalReportModel], context: ModelContext) async {
        let descriptor = FetchDescriptor<MedicalReportModel>()
        let existingReports = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingReports.map { $0.id })
        
        for report in reports {
            if !existingIds.contains(report.id) {
                context.insert(report)
            }
        }
        
        try? context.save()
    }
    
    private func syncMedicationsToLocal(_ medications: [MedicationModel], context: ModelContext) async {
        let descriptor = FetchDescriptor<MedicationModel>()
        let existingMeds = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingMeds.map { $0.id })
        
        for med in medications {
            if !existingIds.contains(med.id) {
                context.insert(med)
            }
        }
        
        try? context.save()
    }
    
    private func syncLabsToLocal(_ labs: [LabResultModel], context: ModelContext) async {
        let descriptor = FetchDescriptor<LabResultModel>()
        let existingLabs = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingLabs.map { $0.id })
        
        for lab in labs {
            if !existingIds.contains(lab.id) {
                context.insert(lab)
            }
        }
        
        try? context.save()
    }
    
    private func syncTimelineToLocal(_ entries: [TimelineEntryModel], context: ModelContext) async {
        let descriptor = FetchDescriptor<TimelineEntryModel>()
        let existingEntries = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingEntries.map { $0.id })
        
        for entry in entries {
            if !existingIds.contains(entry.id) {
                context.insert(entry)
            }
        }
        
        try? context.save()
    }
    
    // MARK: - Medical Data Analysis
    
    private func analyzeMedicalData(context: ModelContext) async {
        // Fetch all data for analysis
        let reports = (try? context.fetch(FetchDescriptor<MedicalReportModel>())) ?? []
        let medications = (try? context.fetch(FetchDescriptor<MedicationModel>())) ?? []
        let labResults = (try? context.fetch(FetchDescriptor<LabResultModel>())) ?? []
        let timelineEntries = (try? context.fetch(FetchDescriptor<TimelineEntryModel>())) ?? []
        
        // Fetch HealthKit data
        let healthMetrics = await HealthKitManager.shared.fetchHealthData()
        
        // Generate comprehensive dashboard summary
        let summary = dataEngine.generateDashboardSummary(
            reports: reports,
            medications: medications,
            labResults: labResults,
            timelineEntries: timelineEntries,
            healthMetrics: healthMetrics
        )
        
        // Update published properties
        labTrends = summary.labTrends
        medicationSummary = summary.medicationSummary
        diagnosisSummary = summary.diagnosisSummary
        timelineSummary = summary.timelineSummary
        
        // Combine all alerts
        healthAlerts = summary.alertSummary.criticalAlerts + summary.alertSummary.warnings
        
        // Calculate health score based on data
        healthScore = calculateHealthScore(summary: summary, hasData: !reports.isEmpty || !labResults.isEmpty || !healthMetrics.isEmpty)
    }
    
    private func calculateHealthScore(summary: (
        labTrends: [LabTrendSummary],
        medicationSummary: MedicationAdherenceSummary,
        diagnosisSummary: DiagnosisSummary,
        timelineSummary: TimelineSummary,
        alertSummary: AlertSummary
    ), hasData: Bool) -> Int {
        // If no data at all, return 0
        guard hasData else { return 0 }
        
        var score = 100
        
        // Deduct for out-of-range labs
        let outOfRangeLabs = summary.labTrends.filter { $0.isOutOfRange }.count
        score -= outOfRangeLabs * 5
        
        // Deduct for critical alerts
        score -= summary.alertSummary.criticalAlerts.count * 10
        
        // Deduct for warnings
        score -= summary.alertSummary.warnings.count * 3
        
        // Bonus for good medication adherence (only if we have adherence data)
        if summary.medicationSummary.adherenceScore > 90 {
            score += 5
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - Public Methods
    
    /// Refresh dashboard data
    func refresh(context: ModelContext) async {
        await loadDashboardData(context: context)
    }
    
    /// Get recent lab trends for a specific parameter
    func getLabTrend(for parameter: String) -> LabTrendSummary? {
        return labTrends.first { $0.parameter == parameter }
    }
    
    /// Get critical alerts only
    func getCriticalAlerts() -> [HealthAlert] {
        return healthAlerts.filter { $0.severity == .critical || $0.severity == .high }
    }
    
    // MARK: - Role-Based Actions
    
    func canUploadDocuments() -> Bool {
        return userRole == .patient || (userRole == .provider && canEdit)
    }
    
    func canDeleteReports() -> Bool {
        return userRole == .patient
    }
    
    func canEditMedications() -> Bool {
        return canEdit
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopListening()
    }
}
