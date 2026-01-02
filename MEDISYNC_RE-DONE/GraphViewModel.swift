// GraphViewModel.swift
import Foundation
import SwiftUI
import SwiftData
import FirebaseFirestore
import Combine

/// ViewModel for managing organ-specific graph data with real-time Firestore listeners
@MainActor
class GraphViewModel: ObservableObject {
    @Published var graphData: [GraphDataModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    var listener: ListenerRegistration? // Changed from private to allow extension access
    private let auth = FirebaseAuthService.shared
    private let db = Firestore.firestore()
    
    // MARK: - Real-Time Listener Setup
    
    /// Start listening to graph data for a specific organ
    func listen(to organ: String, context: ModelContext) {
        // Remove existing listener
        listener?.remove()
        
        guard let uid = auth.getCurrentUserID() else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        
        // Set up real-time listener
        listener = db.collection("users")
            .document(uid)
            .collection("graphData")
            .whereField("organ", isEqualTo: organ)
            .order(by: "date")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to load graph data: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                Task { @MainActor in
                    // Convert Firestore documents to models
                    let newData = documents.compactMap { doc -> GraphDataModel? in
                        GraphDataModel.fromFirestore(doc.data())
                    }
                    
                    // Update published property (triggers UI update)
                    self.graphData = newData
                    
                    // Sync to local SwiftData
                    await self.syncToLocalStorage(newData, context: context)
                    
                    self.isLoading = false
                }
            }
    }
    
    /// Listen to all graph data (for dashboard overview)
    func listenToAll(context: ModelContext) {
        listener?.remove()
        
        guard let uid = auth.getCurrentUserID() else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        
        listener = db.collection("users")
            .document(uid)
            .collection("graphData")
            .order(by: "date", descending: true)
            .limit(to: 100) // Limit to recent 100 points
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to load graph data: \(error.localizedDescription)"
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                Task { @MainActor in
                    let newData = documents.compactMap { GraphDataModel.fromFirestore($0.data()) }
                    self.graphData = newData
                    await self.syncToLocalStorage(newData, context: context)
                    self.isLoading = false
                }
            }
    }
    
    // MARK: - Data Synchronization
    
    private func syncToLocalStorage(_ data: [GraphDataModel], context: ModelContext) async {
        // Fetch existing data from SwiftData
        let descriptor = FetchDescriptor<GraphDataModel>()
        let existingData = (try? context.fetch(descriptor)) ?? []
        let existingIds = Set(existingData.map { $0.id })
        
        // Insert new data points
        for point in data {
            if !existingIds.contains(point.id) {
                context.insert(point)
            }
        }
        
        try? context.save()
    }
    
    // MARK: - Computed Properties
    
    /// Get graph points suitable for Swift Charts
    var chartPoints: [GraphPoint] {
        return graphData.map { GraphPoint(from: $0) }
    }
    
    /// Get latest value
    var latestValue: Double? {
        return graphData.last?.value
    }
    
    /// Get trend (comparing latest to previous)
    var trend: TrendDirection {
        guard graphData.count >= 2 else { return .unknown }
        let latest = graphData[graphData.count - 1].value
        let previous = graphData[graphData.count - 2].value
        
        let change = latest - previous
        let percentChange = abs(change / previous) * 100
        
        if percentChange < 5 {
            return .stable
        } else if change > 0 {
            return .improving
        } else {
            return .declining
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        listener?.remove()
    }
}
