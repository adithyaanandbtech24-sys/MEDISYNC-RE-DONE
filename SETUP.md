# MediSync - Firebase Setup Instructions

## Quick Start

### 1. Add Firebase Packages

In Xcode:
1. File → Add Package Dependencies
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: Latest (11.x or higher)
4. Select Products:
   - ✅ FirebaseFirestore
   - ✅ FirebaseAuth
   - ✅ FirebaseStorage
5. Add to Target: `MEDISYNC_RE-DONE`

---

### 2. UpdateSwiftData Schema

Add `GraphDataModel` to your SwiftData container initialization:

```swift
// In MEDISYNC_RE_DONEApp.swift
import SwiftData

@main
struct MEDISYNC_RE_DONEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            MedicalReportModel.self,
            LabResultModel.self,
            MedicationModel.self,
            OrganTrendModel.self,
            TimelineEntryModel.self,
            AIChatMessage.self,
            HealthMetricModel.self,
            GraphDataModel.self  // ← ADD THIS
        ])
    }
}
```

---

### 3. Integrate Upload UI

Update your main `ContentView.swift` or wherever the upload sheet is shown:

```swift
// Replace existing UploadDocumentView() call with the new implementation
.sheet(isPresented: $showUploadSheet) {
    UploadDocumentView()
}
```

The new `UploadDocumentView` includes both image and PDF uploading.

---

### 4. Add Graph Views to Organ Details

Update `OrganDetailView` in `ContentView.swift` to include graphs:

```swift
struct OrganDetailView: View {
    let organName: String
    let organIcon: String
    let organColor: Color
    
    var body: some View {
        ScrollView {
            VStack {
                // Existing organ icon and header...
                
                // ADD THIS:
                OrganGraphView(
                    organName: organName,
                    organColor: organColor
                )
                
                // Existing lab results...
            }
        }
    }
}
```

---

### 5. Test Real-Time Sync

Run app → Upload report → Check Firebase Console → Data appears immediately

**Expected Behavior**:
- Upload shows progress 0% → 100%
- Dashboard updates within 1-2 seconds (no refresh needed)
- Graphs show new data points automatically
- Timeline updates across all tabs

---

## Firestore Collections

Ensure these collections exist in Firebase:

```
users/
  {uid}/
    reports/          ← Medical reports
    graphData/        ← Graph time-series data
    lab_results/      ← Lab test results
    medications/      ← Active prescriptions
    timeline/         ← Activity timeline
```

---

## Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null 
                        && request.auth.uid == userId;
    }
  }
}
```

---

## Troubleshooting

### "No such module 'FirebaseFirestore'"
- **Fix**: Add Firebase SDK packages (see Step 1 above)

### Build errors after adding GraphDataModel
- **Fix**: Clean build folder (Cmd+Shift+K), rebuild

### Data not syncing
- **Check**: Firebase Console → Firestore for data
- **Check**: Network tab in Xcode debugger
- **Verify**: User is authenticated

### Graphs not updating
- **Check**: OrganGraphView is using `@StateObject private var viewModel`
- **Check**: Listener is started in `onAppear`
- **Verify**: GraphData exists in Firestore under correct organ name

---

## Implementation Complete

✅ Real-time Firestore listeners
✅ Graph data extraction from reports
✅ Swift Charts visualization
✅ Upload UI with progress tracking
✅ Reactive ViewModels with @StateObject

All code ready to run after Firebase packages are added!
