import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// Local Color Definitions
private let appPurple = Color(red: 0.8, green: 0.7, blue: 1.0)
private let vibrantPurple = Color(red: 0.65, green: 0.55, blue: 0.95)

struct PostLoginSetupView: View {
    // MARK: - Navigation State
    enum SetupPhase {
        case dataCollection
        case welcome
        case profile
    }
    
    @State private var currentPhase: SetupPhase = .dataCollection
    @State private var step = 1 // 1: Health, 2: Consent
    @ObservedObject private var appManager = AppManager.shared
    
    // MARK: - Phase 1 Data (Medical & Consent)
    @State private var knownConditions: Set<String> = []
    @State private var customCondition = ""
    @State private var showCustomConditionInput = false
    @State private var currentMedications = ""
    @State private var hasAgreed = false
    @State private var enableAI = true // AI preference checkbox
    
    let commonConditions = ["Diabetes", "Hypertension", "Asthma", "Thyroid", "Cholesterol", "Anxiety"]
    
    // MARK: - Phase 3 Data (Profile)
    @State private var userName: String = ""
    @State private var dateOfBirth = Date()
    @State private var gender: String = "Male"
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profilePhotoData: Data? = nil
    
    let genderOptions = ["Male", "Female", "Other"]
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Unified Background
            LinearGradient(
                colors: [Color.indigo, vibrantPurple, appPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.1))
            
            switch currentPhase {
            case .dataCollection:
                dataCollectionView
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            case .welcome:
                WelcomeAnimationView {
                    withAnimation(.easeIn(duration: 0.5)) {
                        currentPhase = .profile
                    }
                }
                .transition(.opacity)
            case .profile:
                profileSetupView
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: currentPhase)
    }
    
    // MARK: - Phase 1: Data Collection View
    var dataCollectionView: some View {
        ZStack {
            // Back Button
            Button(action: {
                if step > 1 {
                    withAnimation { step -= 1 }
                } else {
                    appManager.backToAuth()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.leading, 24)
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .zIndex(10)
            
            VStack {
                // Header (Progress)
                HStack(spacing: 6) {
                    ForEach(1...2, id: \.self) { s in
                        Capsule()
                            .fill(s <= step ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 48)
                .padding(.bottom, 24)
                
                // Content Card
                VStack(spacing: 0) {
                    TabView(selection: $step) {
                        stepHealthView.tag(1)
                        stepConsentView.tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut, value: step)
                    
                    // Navigation Bar inside card
                    HStack {
                         Text("Step \(step) of 2")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button(action: nextStep) {
                            Text(step == 2 ? "I Agree" : "Next")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(vibrantPurple)
                                .cornerRadius(16)
                                .shadow(color: vibrantPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(step == 2 && !hasAgreed)
                        .opacity((step == 2 && !hasAgreed) ? 0.6 : 1.0)
                    }
                    .padding(24)
                    .background(Color.gray.opacity(0.02))
                }
                .background(Color.white)
                .cornerRadius(28)
                .padding(.horizontal, 24)
                .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 15)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Step 1: Health Context
    var stepHealthView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                 VStack(alignment: .leading, spacing: 10) {
                    Text("Medical History")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text("Your history helps our AI provide safer, more accurate summaries.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    Label("Conditions", systemImage: "stethoscope")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 10) {
                        ForEach(commonConditions, id: \.self) { condition in
                            ConditionButton(
                                title: condition,
                                isSelected: knownConditions.contains(condition),
                                action: { toggleCondition(condition) }
                            )
                        }
                        
                        // Display even custom ones that are already added
                        ForEach(Array(knownConditions).filter { !commonConditions.contains($0) }, id: \.self) { condition in
                            ConditionButton(
                                title: condition,
                                isSelected: true,
                                action: { toggleCondition(condition) }
                            )
                        }
                        
                        Button(action: { withAnimation { showCustomConditionInput.toggle() } }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.08))
                            .foregroundColor(vibrantPurple)
                            .cornerRadius(20)
                        }
                    }
                    
                    if showCustomConditionInput {
                        HStack {
                            TextField("Enter condition...", text: $customCondition)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(10)
                            
                            Button("Add") {
                                if !customCondition.isEmpty {
                                    knownConditions.insert(customCondition)
                                    customCondition = ""
                                    withAnimation { showCustomConditionInput = false }
                                }
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(vibrantPurple)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Current Medications", systemImage: "pills.fill")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    TextField("None, or list them here (e.g. Aspirin)", text: $currentMedications)
                        .padding()
                        .background(Color.gray.opacity(0.03))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                }
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
    }
    
    // MARK: - Step 2: Consent
    var stepConsentView: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
               Text("Privacy & Security")
                   .font(.system(.title2, design: .rounded))
                   .fontWeight(.bold)
                   .foregroundColor(.black)
               
               Text("Your health data is sensitive. We treat it with the respect it deserves.")
                   .font(.subheadline)
                   .foregroundColor(.secondary)
                   .fixedSize(horizontal: false, vertical: true)
           }
            
            VStack(alignment: .leading, spacing: 16) {
                InfoBox(
                    icon: "checkmark.shield.fill",
                    color: .blue,
                    text: "MediSync helps visualize trends but does not replace professional medical advice."
                )
                
                InfoBox(
                    icon: "lock.fill",
                    color: .green,
                    text: "Your data is encrypted and stored securely."
                )
            }
            
            Spacer()
            
            Toggle(isOn: $enableAI) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(vibrantPurple)
                    Text("Enable AI-powered insights")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.black)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
            .padding(16)
            .background(Color.gray.opacity(0.03))
            .cornerRadius(16)
            
            Toggle(isOn: $hasAgreed) {
                Text("I understand and agree")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.black)
            }
            .toggleStyle(SwitchToggleStyle(tint: vibrantPurple))
            .padding(16)
            .background(Color.gray.opacity(0.03))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(hasAgreed ? vibrantPurple.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            
            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Phase 3: Profile Setup View
    var profileSetupView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Let's Get to Know You")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.top, 60)
            .padding(.bottom, 30)
            
            // White Card
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    // Photo Picker
                    VStack(spacing: 12) {
                        if let profilePhotoData, let uiImage = UIImage(data: profilePhotoData) {
                             Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(vibrantPurple, lineWidth: 4))
                                .shadow(radius: 8)
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(vibrantPurple.opacity(0.6))
                        }
                        
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text(profilePhotoData == nil ? "Add Photo" : "Change Photo")
                                .font(.subheadline.bold())
                                .foregroundColor(vibrantPurple)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(vibrantPurple.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .onChange(of: selectedItem) { oldValue, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    profilePhotoData = data
                                }
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Fields
                    VStack(alignment: .leading, spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            TextField("Enter your name", text: $userName)
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                        }
                        
                        // DOB
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            
                            ZStack(alignment: .leading) {
                                // Background & Custom Text
                                HStack {
                                    Text(dateOfBirth, style: .date)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "calendar")
                                        .foregroundColor(vibrantPurple)
                                }
                                .padding()
                                .frame(height: 54) // Match height of standard text fields
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(12)
                                
                                // Tappable DatePicker overlay
                                DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                                    .labelsHidden()
                                    .scaleEffect(x: 4.0, y: 1.5, anchor: .center) // Make it fill the area
                                    .opacity(0.015) // Keep it almost invisible but clickable
                                    .frame(maxWidth: .infinity, maxHeight: 54)
                            }
                        }
                        
                        // Gender
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                            Picker("Gender", selection: $gender) {
                                ForEach(genderOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // Height & Weight
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Height (cm)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                TextField("e.g. 175", text: $height)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weight (kg)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)
                                TextField("e.g. 70", text: $weight)
                                    .keyboardType(.numberPad)
                                    .padding()
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Complete Button
                    Button(action: completeSetup) {
                        Text("Complete Setup")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(vibrantPurple)
                            .cornerRadius(16)
                            .shadow(color: vibrantPurple.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .disabled(userName.isEmpty)
                    .opacity(userName.isEmpty ? 0.6 : 1.0)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.white)
            .cornerRadius(30, corners: [.topLeft, .topRight])
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    // MARK: - Actions
    
    func nextStep() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            // Transition to Welcome
             withAnimation {
                currentPhase = .welcome
            }
        }
    }
    
    func toggleCondition(_ condition: String) {
        if knownConditions.contains(condition) {
            knownConditions.remove(condition)
        } else {
            knownConditions.insert(condition)
        }
    }
    
    func completeSetup() {
        // Calculate Age & Profile Values
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        let age = ageComponents.year ?? 0
        
        let hVal = Double(height)
        let wVal = Double(weight)

        // Check for existing user and handle data isolation
        let descriptor = FetchDescriptor<UserProfileModel>()
        if let existingProfile = try? modelContext.fetch(descriptor).first {
            if existingProfile.name.lowercased() != userName.lowercased() {
                print("👤 [PostLoginSetupView] New user detected: \(userName). Clearing previous data for \(existingProfile.name).")
                modelContext.clearAllData()
            } else {
                print("👤 [PostLoginSetupView] Existing user re-login: \(userName). Preserving data.")
                // Update the existing profile instead of creating a new one
                modelContext.delete(existingProfile)
            }
        } else {
            // First time user, but ensure fresh slate from any dummy data
            modelContext.clearAllData()
        }
        
        // Save User Profile
        let profile = UserProfileModel(
            name: userName,
            age: age,
            gender: gender.lowercased(),
            height: hVal,
            weight: wVal,
            profilePhotoData: profilePhotoData,
            enableAI: enableAI
        )
        modelContext.insert(profile)
        
        // 1. Save Conditions (as a Medical Report)
        if !knownConditions.isEmpty {
            let conditionsList = knownConditions.joined(separator: ", ")
            let summaryReport = MedicalReportModel(
                title: "Onboarding Health Profile",
                reportType: "Health Summary",
                organ: "General",
                extractedText: "Patient reported the following existing conditions: \(conditionsList).",
                aiInsights: "Patient history includes: \(conditionsList). Monitor for related complications."
            )
            modelContext.insert(summaryReport)
        }
        
        // 2. Save Medications
        if !currentMedications.isEmpty {
            let meds = currentMedications.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for medName in meds {
                if !medName.isEmpty {
                    let medication = MedicationModel(
                        name: medName,
                        dosage: "As directed", // Placeholder
                        frequency: "Daily",    // Placeholder
                        startDate: Date(),
                        isActive: true,
                        source: "Self-reported (Onboarding)"
                    )
                    modelContext.insert(medication)
                }
            }
        }
        
        try? modelContext.save()
        
        appManager.completeSetup()
    }
}

// MARK: - Helper Components

struct WelcomeAnimationView: View {
    let onComplete: () -> Void
    @State private var opacity = 0.0
    @State private var scale = 0.8
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 80))
                    .foregroundColor(vibrantPurple)
                
                Text("Welcome to MediSync")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text("Your personal health companion")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // Wait and then vanish - Shortened timing for better flow
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

struct ConditionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? vibrantPurple.opacity(0.15) : Color.gray.opacity(0.06))
                .foregroundColor(isSelected ? vibrantPurple : .black.opacity(0.7))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? vibrantPurple.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct InfoBox: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.05))
        .cornerRadius(16)
    }
}

// Extension for partial corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(SetupRoundedCorner(radius: radius, corners: corners))
    }
}

struct SetupRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
