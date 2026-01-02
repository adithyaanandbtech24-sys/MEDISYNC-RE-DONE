// FirebaseSyncService.swift
import Foundation
import SwiftData
import FirebaseFirestore
import Combine

@MainActor
final class FirebaseSyncService: ObservableObject {
    static let shared = FirebaseSyncService()
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    
    private let firestore = FirestoreService.shared
    private let auth = FirebaseAuthService.shared
    private var listeners: [ListenerRegistration] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start real-time listeners for all collections
    func startListening() {
        guard let userId = auth.getCurrentUserID() else { return }
        
        // Listen to medical reports
        let reportsListener = Firestore.firestore()
            .collection("users").document(userId).collection("medical_reports")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    await self?.handleRemoteReports(documents)
                }
            }
        listeners.append(reportsListener)
        
        // Listen to medications
        let medsListener = Firestore.firestore()
            .collection("users").document(userId).collection("medications")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    await self?.handleRemoteMedications(documents)
                }
            }
        listeners.append(medsListener)
        
        // Listen to lab results
        let labsListener = Firestore.firestore()
            .collection("users").document(userId).collection("lab_results")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    await self?.handleRemoteLabResults(documents)
                }
            }
        listeners.append(labsListener)
        
        // Listen to timeline entries
        let timelineListener = Firestore.firestore()
            .collection("users").document(userId).collection("timeline_entries")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                Task { @MainActor in
                    await self?.handleRemoteTimelineEntries(documents)
                }
            }
        listeners.append(timelineListener)
    }
    
    /// Stop all real-time listeners
    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    /// Sync all pending entities to Firestore
    func syncAll(context: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }
        
        await syncMedicalReports(context: context)
        await syncMedications(context: context)
        await syncLabResults(context: context)
        await syncTimelineEntries(context: context)
        
        lastSyncDate = Date()
    }
    
    /// Sync medical reports only
    func syncMedicalReports(context: ModelContext) async {
        guard let userId = auth.getCurrentUserID() else { return }
        
        // Fetch pending reports
        let descriptor = FetchDescriptor<MedicalReportModel>(
            predicate: #Predicate { $0.syncState == "pending" }
        )
        
        guard let pendingReports = try? context.fetch(descriptor) else { return }
        
        for report in pendingReports {
            do {
                let data = FirestoreMappers.toFirestore(report)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    firestore.setDocument(
                        userId: userId,
                        collection: "medical_reports",
                        id: report.id,
                        data: data
                    ) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                report.syncState = "synced"
            } catch {
                report.syncState = "failed"
                print("Failed to sync report \(report.id): \(error)")
            }
        }
        
        try? context.save()
    }
    
    /// Sync medications only
    func syncMedications(context: ModelContext) async {
        guard let userId = auth.getCurrentUserID() else { return }
        
        let descriptor = FetchDescriptor<MedicationModel>(
            predicate: #Predicate { $0.syncState == "pending" }
        )
        
        guard let pendingMeds = try? context.fetch(descriptor) else { return }
        
        for med in pendingMeds {
            do {
                let data = FirestoreMappers.toFirestore(med)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    firestore.setDocument(
                        userId: userId,
                        collection: "medications",
                        id: med.id,
                        data: data
                    ) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                med.syncState = "synced"
            } catch {
                med.syncState = "failed"
                print("Failed to sync medication \(med.id): \(error)")
            }
        }
        
        try? context.save()
    }
    
    /// Sync lab results
    func syncLabResults(context: ModelContext) async {
        guard let userId = auth.getCurrentUserID() else { return }
        
        let descriptor = FetchDescriptor<LabResultModel>(
            predicate: #Predicate { $0.syncState == "pending" }
        )
        
        guard let pendingLabs = try? context.fetch(descriptor) else { return }
        
        for lab in pendingLabs {
            do {
                let data = FirestoreMappers.toFirestore(lab)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    firestore.setDocument(
                        userId: userId,
                        collection: "lab_results",
                        id: lab.id,
                        data: data
                    ) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                lab.syncState = "synced"
            } catch {
                lab.syncState = "failed"
                print("Failed to sync lab result \(lab.id): \(error)")
            }
        }
        
        try? context.save()
    }
    
    /// Sync timeline entries
    func syncTimelineEntries(context: ModelContext) async {
        guard let userId = auth.getCurrentUserID() else { return }
        
        let descriptor = FetchDescriptor<TimelineEntryModel>(
            predicate: #Predicate { $0.syncState == "pending" }
        )
        
        guard let pendingEntries = try? context.fetch(descriptor) else { return }
        
        for entry in pendingEntries {
            do {
                let data = FirestoreMappers.toFirestore(entry)
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    firestore.setDocument(
                        userId: userId,
                        collection: "timeline_entries",
                        id: entry.id,
                        data: data
                    ) { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
                entry.syncState = "synced"
            } catch {
                entry.syncState = "failed"
                print("Failed to sync timeline entry \(entry.id): \(error)")
            }
        }
        
        try? context.save()
    }
    
    // MARK: - Remote Change Handlers (Server Wins Conflict Resolution)
    
    private func handleRemoteReports(_ docs: [DocumentSnapshot]) async {
        // In production, would upsert to SwiftData with server-wins conflict resolution
        print("Received \(docs.count) remote reports")
    }
    
    private func handleRemoteMedications(_ docs: [DocumentSnapshot]) async {
        print("Received \(docs.count) remote medications")
    }
    
    private func handleRemoteLabResults(_ docs: [DocumentSnapshot]) async {
        print("Received \(docs.count) remote lab results")
    }
    
    private func handleRemoteTimelineEntries(_ docs: [DocumentSnapshot]) async {
        print("Received \(docs.count) remote timeline entries")
    }
    
    // MARK: - Individual Sync Methods
    
    func syncReport(_ report: MedicalReportModel) async throws {
        guard let userId = auth.getCurrentUserID() else {
            throw FirebaseError.notAuthenticated
        }
        
        let data = FirestoreMappers.toFirestore(report)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.setDocument(
                userId: userId,
                collection: "medical_reports",
                id: report.id,
                data: data
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func syncMedication(_ medication: MedicationModel) async throws {
        guard let userId = auth.getCurrentUserID() else {
            throw FirebaseError.notAuthenticated
        }
        
        let data = FirestoreMappers.toFirestore(medication)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestore.setDocument(
                userId: userId,
                collection: "medications",
                id: medication.id,
                data: data
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}


