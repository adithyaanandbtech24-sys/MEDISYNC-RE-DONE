import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import FirebaseCore
import Firebase
import FirebaseAnalytics
// MARK: - App Delegate for Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Auto sign-in anonymously for testing/demo
        Task {
            let auth = FirebaseAuthService.shared
            if auth.getCurrentUserID() == nil {
                do {
                    let uid = try await auth.signInAnonymously()
                    print("✅ Signed in anonymously with UID: \(uid)")
                } catch {
                    print("❌ Anonymous sign-in failed: \(error)")
                }
            }
        }
        
        return true
    }
}

// MARK: - Main App

@main
struct MediSyncApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Create a shared model container
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MedicalReportModel.self,
            LabResultModel.self,
            MedicationModel.self,
            OrganTrendModel.self,
            TimelineEntryModel.self,
            AIChatMessage.self,
            HealthMetricModel.self,
            GraphDataModel.self  // NEW: For time-series graph data
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            RootContentView()
        }
        .modelContainer(MediSyncApp.sharedModelContainer)
    }
}
