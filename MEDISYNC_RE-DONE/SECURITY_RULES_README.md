# Firebase Security Rules - Quick Reference

## 🚀 Deploy Rules

```bash
firebase deploy --only firestore:rules,storage:rules
```

## 👥 Set User Role (on signup)

```swift
Firestore.firestore().collection("roles").document(userId).setData([
    "role": "PATIENT"
])
```

## 👨‍👩‍👧 Grant Family Access

```swift
// Patient grants family member read access
db.collection("users").document(patientId)
  .collection("family").document(familyId).setData([
    "userId": familyId,
    "name": "John Doe",
    "relationship": "Spouse",
    "grantedAt": Timestamp(date: Date())
])
```

## 🏥 Grant Provider Access

```swift
// Patient grants provider access
db.collection("providers").document(providerId)
  .collection("patients").document(patientId).setData([
    "patientId": patientId,
    "grantedAt": Timestamp(date: Date()),
    "permissions": ["read", "write"]
])
```

## ✅ Security Features

- ✅ User data isolation
- ✅ Role-based access (PATIENT, FAMILY, PROVIDER)
- ✅ Field validation
- ✅ PHI protection
- ✅ File size/type validation (10MB, PDF/JPEG/PNG)
- ✅ User-friendly error messages

## 🧪 Test Access

```swift
// Should succeed - own data
db.collection("users").document(myUid).collection("medical_reports").getDocuments()

// Should fail - other user's data
db.collection("users").document(otherUid).collection("medical_reports").getDocuments()
```

## 🛡️ Error Handling

FirestoreService now returns user-friendly errors:
- "Access denied – you do not have permission..."
- "Please sign in to access your medical records."
- "Network error. Please check your connection..."
