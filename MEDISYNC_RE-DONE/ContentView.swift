import SwiftUI
import SwiftData
import PhotosUI
import Foundation
import Combine





// MARK: - Main Entry Point
struct RootContentView: View {
    @State private var selectedTab: Tab = .home
    @State private var showUploadSheet = false
    @State private var buttonOffset: CGSize = .zero
    @State private var lastButtonOffset: CGSize = .zero
    
    init() {
        // Hide default TabBar to use our custom one
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(Tab.home)
                
                ChatbotView()
                    .tag(Tab.grid)
                
                TimelineAnalysisView()
                    .tag(Tab.stats)
                

                
                DoctorConnectView()
                    .tag(Tab.doctor)
            }
            
            // Custom Floating Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 20)
            
            // Floating Upload Button
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showUploadSheet.toggle() }) {
                            Image(systemName: "doc.viewfinder")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .offset(x: buttonOffset.width, y: buttonOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    buttonOffset = CGSize(
                                        width: lastButtonOffset.width + value.translation.width,
                                        height: lastButtonOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastButtonOffset = buttonOffset
                                }
                        )
                        .padding(.bottom, 100)
                        .padding(.trailing, 20)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showUploadSheet) {
            UploadDocumentView()
        }
    }
}

// MARK: - 1. Dashboard View
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicalReportModel.uploadDate, order: .reverse) private var reports: [MedicalReportModel]
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    @Query(sort: \MedicationModel.startDate, order: .reverse) private var medications: [MedicationModel]
    @Query(sort: \OrganTrendModel.date, order: .reverse) private var organTrends: [OrganTrendModel]
    
    @State private var selectedMedication: MedicationModel?
    @State private var selectedOrgan: String?
    @State private var showOrganDetail = false
    @State private var showMoreOrgans = false
    @State private var showSearch = false
    @State private var searchText = ""
    
    // Computed properties for dashboard data - only show uploaded medications
    private var activeMedications: [MedicationModel] {
        let uploadedMeds = MedicationManager.shared.getUploadedMedications(context: modelContext)
        return uploadedMeds.filter { $0.isActive }
    }
    
    private var allUploadedMedications: [MedicationModel] {
        MedicationManager.shared.getUploadedMedications(context: modelContext)
    }
    
    private var recentReports: [MedicalReportModel] {
        Array(reports.prefix(5))
    }
    
    private var abnormalLabResults: [LabResultModel] {
        labResults.filter { $0.status != "Normal" && $0.status != "Optimal" }
    }
    
    private var healthScore: Int {
        // Calculate health score based on lab results
        let normalCount = labResults.filter { $0.status == "Normal" || $0.status == "Optimal" }.count
        let totalCount = max(labResults.count, 1)
        return Int((Double(normalCount) / Double(totalCount)) * 100)
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {

                VStack(spacing: 2) {
                    // Header
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .foregroundColor(.gray)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hello, Anand")
                                .font(.system(size: 18, weight: .bold))
                            Text("Welcome to, MediSync.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Test Data Button (Developer Tool)
                        Button(action: {
                            ReportService.shared.generateSampleData(context: modelContext)
                        }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                                .padding(10)
                                .overlay(Circle().stroke(Color.green.opacity(0.3), lineWidth: 1))
                        }
                        
                        Button(action: {
                            showSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                                .padding(10)
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Daily Challenge Card (Health Overview)
                    ZStack {

                        // Purple card background ONLY
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.appPurple)
                            .frame(height: 180)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
                            .padding(.horizontal)

                        // Content text pinned left side
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health Overview")
                                .font(.title3).bold()
                                .foregroundColor(.white)

                            Text("Start your Journey!")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))

                            Spacer().frame(height: 10)

                            Text("Personalised to you")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: -12) {
                                ForEach(0..<3) { _ in
                                    Circle()
                                        .fill(Color.white.opacity(0.25))
                                        .frame(width: 30, height: 30)
                                        .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                                }

                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 30, height: 30)
                                    .overlay(Text("+4")
                                        .font(.caption2)
                                        .foregroundColor(.white))
                            }
                            .padding(.top, 6)
                        }
                        .padding(.leading, 40)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 180)

                        // MONSTER — large and OUTSIDE card boundaries
                        Image("HealthOverviewPerson")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 350)   // Bigger to match actual mockup
                            .offset(x: 90, y: -30) // Positioned ABOVE the card
                            .zIndex(10)          // MUST be in front of card
                    }
                    .padding(.top, -210)
                    
                    // Calendar Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(getWeekDates(), id: \.self) { date in
                                CalendarDayView(
                                    day: getDayName(date),
                                    date: getDateNumber(date),
                                    isSelected: Calendar.current.isDateInToday(date)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, -220)
                    
                    // MARK: - VITALS SECTION (Organs)
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Vitals & Lab Results")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        HStack(alignment: .top, spacing: 15) {
                            // Left Large Card - Lungs with Chart
                            Button(action: {
                                selectedOrgan = "Lungs"
                                showOrganDetail = true
                            }) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Lungs")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                            
                                            Text("Respiratory Health")
                                                .font(.caption)
                                                .foregroundColor(.black.opacity(0.6))
                                        }
                                        Spacer()
                                    }
                                    
                                    // Mini Graph
                                    OrganGraphView(
                                        organName: "Lungs",
                                        organColor: Color(red: 0.98, green: 0.75, blue: 0.45),
                                        compact: true
                                    )
                                    .frame(height: 100)
                                    .padding(.top, 8)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 260)
                                .background(Color(red: 0.98, green: 0.75, blue: 0.45))
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            // Right Column
                            VStack(spacing: 15) {
                                // Heart Card with Wave Chart
                                
                                Button(action: {
                                    selectedOrgan = "Heart"
                                    showOrganDetail = true
                                }) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Heart")
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.black)
                                                
                                                Text("Cardiovascular")
                                                    .font(.caption)
                                                    .foregroundColor(.black.opacity(0.6))
                                            }
                                            Spacer()
                                        }
                                        
                                        // Mini Graph
                                        OrganGraphView(
                                            organName: "Heart",
                                            organColor: Color(red: 0.8, green: 0.9, blue: 1.0),
                                            compact: true
                                        )
                                        .frame(height: 60)
                                        .padding(.top, 4)
                                    }
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 140)
                                    .background(Color(red: 0.8, green: 0.9, blue: 1.0))
                                    .cornerRadius(25)
                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                
                                // More Organs Card (Pink - Expandable)
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        showMoreOrgans.toggle()
                                    }
                                }) {
                                    VStack(spacing: 0) {
                                        if showMoreOrgans {
                                            // Expanded view with all organs
                                            VStack(spacing: 10) {
                                                HStack(spacing: 10) {
                                                    SmallOrganButton(icon: "drop.fill", name: "Kidneys", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Kidneys"
                                                        showOrganDetail = true
                                                    }
                                                    SmallOrganButton(icon: "cross.case.fill", name: "Liver", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Liver"
                                                        showOrganDetail = true
                                                    }
                                                    SmallOrganButton(icon: "eye.fill", name: "Eyes", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Eyes"
                                                        showOrganDetail = true
                                                    }
                                                }
                                                HStack(spacing: 10) {
                                                    SmallOrganButton(icon: "ear.fill", name: "Ears", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Ears"
                                                        showOrganDetail = true
                                                    }
                                                    SmallOrganButton(icon: "brain.head.profile", name: "Brain", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Brain"
                                                        showOrganDetail = true
                                                    }
                                                    SmallOrganButton(icon: "figure.stand", name: "Bones", color: .white.opacity(0.5)) {
                                                        selectedOrgan = "Bones"
                                                        showOrganDetail = true
                                                    }
                                                }
                                            }
                                            .padding(12)
                                            .transition(.scale.combined(with: .opacity))
                                        } else {
                                            // Collapsed view with icons
                                            HStack(spacing: 15) {
                                                Circle()
                                                    .fill(Color.white.opacity(0.5))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Image(systemName: "drop.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                    )
                                                Circle()
                                                    .fill(Color.white.opacity(0.5))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Image(systemName: "cross.case.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                    )
                                                Circle()
                                                    .fill(Color.white.opacity(0.5))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Image(systemName: "ellipsis")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 18)
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: showMoreOrgans ? nil : 105) // Increased height
                                    .background(Color.appPink)
                                    .cornerRadius(20)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, -100)
                    
                    // MARK: - MEDICATIONS SECTION
                    VStack(alignment: .leading, spacing: 15) {
                        Spacer()
                        Text("Active Medications")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if activeMedications.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text("Upload medical documents to see medications")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Text("Medications will appear here automatically when you upload prescriptions or medical reports")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.vertical, 30)
                        } else {
                            ForEach(activeMedications) { medication in
                                Button(action: {
                                    selectedMedication = medication
                                }) {
                                    HStack(spacing: 15) {
                                        // Clean pill icon
                                        Image(systemName: "pills.circle.fill")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.purple.opacity(0.7))
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(medication.name)
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.purple)
                                            
                                            Text("\(medication.dosage) • \(medication.frequency)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            if let instructions = medication.instructions {
                                                if !instructions.isEmpty {
                                                    Text(instructions)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                        .lineLimit(2)
                                                }
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(20)
                                    .background(Color(red: 0.92, green: 0.90, blue: 0.98))
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.top, -20)
                    
                    // MARK: - PAST MEDICATIONS SECTION
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Past Medications")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        let pastUploadedMedications = allUploadedMedications.filter { !$0.isActive }
                        
                        if pastUploadedMedications.isEmpty {
                            VStack(spacing: 8) {
                                Text("No past medications")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Text("Past medications from uploaded documents will appear here")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.vertical, 20)
                        } else {
                            ForEach(pastUploadedMedications) { medication in
                                HStack(spacing: 15) {
                                    // Clean pill icon - grayed out
                                    Image(systemName: "pills.circle")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray.opacity(0.4))
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(medication.name)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.gray)
                                        
                                        Text("\(medication.dosage)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray.opacity(0.7))
                                        
                                        if let endDate = medication.endDate {
                                            Text("Last used: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(20)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(20)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer().frame(height: 100) // Bottom padding
                .onAppear {
                    MedicationManager.shared.initializeMedications(context: modelContext)
                }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedMedication) { medication in
                MedicationDetailView(medication: medication)
            }
            .sheet(isPresented: $showOrganDetail) {
                if let organ = selectedOrgan {
                    OrganDetailView(
                        organName: organ,
                        organIcon: getOrganIcon(organ),
                        organColor: getOrganColor(organ)
                    )
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView(searchText: $searchText, labResults: labResults, medications: medications)
                    .modelContext(modelContext)
            }
        }
    }
    
    // Helper functions for organ details
    func getOrganIcon(_ organ: String) -> String {
        switch organ {
        case "Lungs": return "lungs.fill"
        case "Heart": return "heart.fill"
        case "Kidneys": return "drop.fill"
        case "Liver": return "cross.case.fill"
        case "Eyes": return "eye.fill"
        case "Ears": return "ear.fill"
        case "Brain": return "brain.head.profile"
        case "Bones": return "figure.stand"
        default: return "heart.fill"
        }
    }
    
    func getOrganColor(_ organ: String) -> Color {
        switch organ {
        case "Lungs": return Color.appYellow
        case "Heart": return Color.appBlue
        case "Kidneys": return Color.appBlue
        case "Liver": return Color.appOrange
        case "Eyes": return Color.appGreen
        case "Ears": return Color.appLightBlue
        case "Brain": return Color.appPurple
        case "Bones": return Color.appOrange
        default: return Color.appPurple
        }
    }
    
    // Helper functions for dynamic calendar
    func getWeekDates() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Get Sunday of current week
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return []
        }
        
        // Generate 7 days starting from Sunday
        var dates: [Date] = []
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                dates.append(date)
            }
        }
        return dates
    }
    
    func getDayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    func getDateNumber(_ date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }
}

// MARK: - Organ Detail View
struct OrganDetailView: View {
    let organName: String
    let organIcon: String
    let organColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text(organName)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.clear)
                }
                .padding()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Organ Icon
                        ZStack {
                            Circle()
                                .fill(organColor.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: organIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .foregroundColor(organColor)
                        }
                        .padding(.top, 20)
                        
                        // NEW: Real-Time Graph Section
                        OrganGraphView(
                            organName: organName,
                            organColor: organColor
                        )
                        .padding(.bottom, 20)
                        
                        // Lab Results Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Lab Results & Parameters")
                                .font(.title3)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                            
                            // Dynamic content based on organ
                            ForEach(getLabResults(), id: \.id) { result in
                                TimelineItemCard(result: result, backgroundColor: Color.clear)
                            }
                        }
                        
                        Spacer().frame(height: 30)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // Fetch all lab results from SwiftData and filter for the current organ
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var allLabResults: [LabResultModel]
    
    func getLabResults() -> [LabResultModel] {
        // Filter results where the category or test name matches the organ name
        allLabResults.filter { $0.category.contains(organName) || $0.testName.contains(organName) }
    }
}

// MARK: - Lab Result Model
struct LabResult {
    let name: String
    let value: String
    let range: String
    let status: LabStatus
}

enum LabStatus {
    case normal, warning, critical
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Lab Result Card
struct LabResultCard: View {
    let result: LabResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.name)
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Normal range: \(result.range)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 5) {
                Text(result.value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(result.status.color)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(result.status.color)
                        .frame(width: 8, height: 8)
                    Text(result.status == .normal ? "Normal" : result.status == .warning ? "Warning" : "Critical")
                        .font(.caption2)
                        .foregroundColor(result.status.color)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

// MARK: - Medication Detail Popup View
struct MedicationDetailView: View {
    let medication: MedicationModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Close Button & Image Area
                ZStack(alignment: .topTrailing) {
                    
                    // Simulated Large 3D Pill
                    VStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.appPink.opacity(0.2))
                                .frame(width: 150, height: 150)
                                .blur(radius: 20)
                            
                            Image(systemName: "pills.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .foregroundColor(.appPink)
                                .rotationEffect(.degrees(-10))
                                .shadow(color: .appPink.opacity(0.5), radius: 10, x: 0, y: 10)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    }
                    .padding()
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Title Header
                        VStack(alignment: .leading, spacing: 5) {
                            Text(medication.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.3))
                            
                            Text("Medication • \(medication.dosage)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        // Stats Row
                        HStack(spacing: 15) {
                            HStack {
                                Image(systemName: "pill.fill")
                                    .foregroundColor(.pink)
                                VStack(alignment: .leading) {
                                    Text(medication.dosage)
                                        .fontWeight(.bold)
                                    Text("Dosage")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(15)
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text(medication.frequency)
                                        .fontWeight(.bold)
                                    Text("Frequency")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(15)
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("About Drug")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.3))
                            
                            if let notes = medication.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            } else {
                                Text("No additional notes provided for this medication.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Side Effects Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Possible Side Effects")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.3))
                            
                            Text(medication.sideEffects ?? "No side effects information available.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(15)
                        }
                        
                        // Alternatives Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Possible Alternatives")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.2, green: 0.15, blue: 0.3))
                            
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .resizable()
                                    .frame(width: 20, height: 18)
                                    .foregroundColor(.blue)
                                    .padding(10)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.05), radius: 2)
                                
                                Text(medication.alternatives ?? "No alternatives listed.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.appPurple.opacity(0.15))
                            .cornerRadius(20)
                        }
                        
                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 25)
                }
            }
        }
    }
}

struct CalendarDayView: View {
    let day: String
    let date: String
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text(day)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
            Text(date)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isSelected ? .white : .black)
        }
        .frame(width: 60, height: 85)
        .background(isSelected ? Color.black : Color.white)
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.gray.opacity(0.2), lineWidth: isSelected ? 0 : 1)
        )
    }
}

struct SocialIcon: View {
    let icon: String
    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.5))
            .frame(width: 35, height: 35)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Organ Card Component
struct OrganCard: View {
    let organName: String
    let organIcon: String
    let organColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(organColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: organIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(organColor)
                }
                
                // Organ Name
                Text(organName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Small Organ Button (for expandable card)
struct SmallOrganButton: View {
    let icon: String
    let name: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 45, height: 45)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )
                
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 5. Upload handled by UploadDocumentView.swift (separate file)


struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.black.opacity(0.6))
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80)
        .background(color)
        .cornerRadius(15)
    }
}

struct ProfileListItem: View {
    let icon: String
    let title: String
    let subtitle: String
    var showDivider: Bool = true
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - 2. AI Chatbot View
struct ChatbotView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIChatMessage.timestamp, order: .forward) private var chatHistory: [AIChatMessage]
    
    @State private var messageText = ""
    @State private var isTyping = false
    @State private var errorMessage: String?
    @State private var showReminderSheet = false
    
    let suggestedPrompts = [
        "Explain my lab results",
        "Medication reminders",
        "Diet recommendations",
        "Exercise tips"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.6, green: 0.4, blue: 0.9),
                        Color(red: 0.5, green: 0.3, blue: 0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                    
                    Text("AI Health Assistant")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Powered by Advanced Medical AI")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                .padding(.bottom, 15)
            }
            .frame(height: 120)
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Show chat history from SwiftData
                        ForEach(chatHistory) { message in
                            ChatBubble(message: ChatMessage(
                                text: message.text,
                                isUser: message.isUser
                            ))
                                .id(message.id)
                        }
                        
                        // Typing Indicator
                        if isTyping {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        
                        // Show error if any
                        if let error = errorMessage {
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        // Suggested Prompts (show when few messages)
                        if chatHistory.count <= 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested Questions")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(suggestedPrompts, id: \.self) { prompt in
                                            Button(action: {
                                                sendMessage(prompt)
                                            }) {
                                                Text(prompt)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.1))
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                    .onChange(of: chatHistory.count) { _, _ in
                        if let lastMessage = chatHistory.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                    
                    TextField("Ask me anything about your health...", text: $messageText)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(25)
                
                Button(action: {
                    if !messageText.isEmpty {
                        sendMessage(messageText)
                        messageText = ""
                    }
                }) {
                    Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(messageText.isEmpty ? .gray : Color(red: 0.6, green: 0.4, blue: 0.9))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .padding(.bottom, 80) // Extra padding for tab bar
            .background(Color.white)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.99).ignoresSafeArea())
        .sheet(isPresented: $showReminderSheet) {
            ReminderSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DocumentUploaded"))) { _ in
            sendMessage("Please analyze the recently uploaded document and provide a summary including CRITICAL POINTS, Improvement values, Lab results, and recommended medications.")
        }
    }
    
    func sendMessage(_ text: String) {
        isTyping = true
        errorMessage = nil
        
        Task {
            do {
                // Call real ChatService
                let (_, _) = try await ChatService.shared.sendAndReceive(
                    userMessage: text,
                    context: modelContext
                )
                
                await MainActor.run {
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    errorMessage = error.localizedDescription
                    print("❌ [ChatbotView] Error: \(error)")
                }
            }
        }
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - Chat Bubble Component
struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(message.isUser ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        message.isUser ?
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.6, green: 0.4, blue: 0.9),
                                Color(red: 0.5, green: 0.3, blue: 0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.white]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                Text(timeString(from: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
    
    func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onAppear {
            animationPhase = 1
        }
    }
}

// MARK: - Reminder Sheet
struct ReminderSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var medicationName = ""
    @State private var reminderTime = Date()
    @StateObject private var reminderManager = MedicationReminderManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Medication Details")) {
                    TextField("Medication Name", text: $medicationName)
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
                
                Section {
                    Button(action: {
                        let calendar = Calendar.current
                        let hour = calendar.component(.hour, from: reminderTime)
                        let minute = calendar.component(.minute, from: reminderTime)
                        
                        reminderManager.scheduleReminder(
                            title: "Medication Reminder",
                            body: "It's time to take \(medicationName)",
                            hour: hour,
                            minute: minute
                        )
                        
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Set Reminder")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.appPurple)
                }
            }
            .navigationTitle("Set Reminder")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 3. Doctor Connect View
struct DoctorConnectView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var demoManager = DemoDataManager.shared
    @State private var showDemoWarning = false
    
    @State private var doctorLink: String?
    @State private var familyLink: String?
    @State private var doctorLinkExpiry: Date?
    @State private var familyLinkExpiry: Date?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect & Share")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Share your health data securely with doctors and family")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 60)
                
                // Doctor Connect Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "stethoscope.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0))
                        
                        Text("Doctor Connect")
                            .font(.system(size: 20, weight: .bold))
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ShareLinkCard(
                        title: "Share with Doctor",
                        description: "Generate a secure link for your healthcare provider",
                        iconName: "link.circle.fill",
                        iconColor: Color(red: 0.3, green: 0.6, blue: 1.0),
                        gradientColors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 0.9)],
                        link: $doctorLink,
                        linkExpiry: $doctorLinkExpiry,
                        expiryHours: 24
                    )
                    
                    // Active Doctor Connections
                    if doctorLink != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Connections")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ConnectionItem(
                                name: "Dr. Sarah Johnson",
                                specialty: "Cardiologist",
                                connectedDate: "Connected 2 days ago",
                                iconColor: Color(red: 0.3, green: 0.6, blue: 1.0)
                            )
                        }
                    }
                }
                
                // Divider
                Divider()
                    .padding(.horizontal)
                
                // Family Connect Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.6))
                        
                        Text("Family Connect")
                            .font(.system(size: 20, weight: .bold))
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ShareLinkCard(
                        title: "Share with Family",
                        description: "Let family members track your health progress",
                        iconName: "heart.circle.fill",
                        iconColor: Color(red: 1.0, green: 0.4, blue: 0.6),
                        gradientColors: [Color(red: 1.0, green: 0.4, blue: 0.6), Color(red: 0.9, green: 0.3, blue: 0.5)],
                        link: $familyLink,
                        linkExpiry: $familyLinkExpiry,
                        expiryHours: 48
                    )
                    
                    // Active Family Connections
                    if familyLink != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Connections")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ConnectionItem(
                                name: "Mom",
                                specialty: "Family Member",
                                connectedDate: "Connected 5 days ago",
                                iconColor: Color(red: 1.0, green: 0.4, blue: 0.6)
                            )
                            
                            ConnectionItem(
                                name: "Dad",
                                specialty: "Family Member",
                                connectedDate: "Connected 1 week ago",
                                iconColor: Color(red: 1.0, green: 0.4, blue: 0.6)
                            )
                        }
                    }
                }
                
                // Info Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                        Text("Security & Privacy")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(icon: "lock.fill", text: "All links are encrypted end-to-end")
                        InfoRow(icon: "clock.fill", text: "Links expire automatically after set time")
                        InfoRow(icon: "eye.slash.fill", text: "You control what data is shared")
                        InfoRow(icon: "xmark.circle.fill", text: "Revoke access anytime")
                    }
                }
                .padding(20)
                .background(Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.bottom, 100)
        }
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
    }
}

// MARK: - Share Link Card Component
struct ShareLinkCard: View {
    let title: String
    let description: String
    let iconName: String
    let iconColor: Color
    let gradientColors: [Color]
    @Binding var link: String?
    @Binding var linkExpiry: Date?
    let expiryHours: Int
    
    @State private var showCopiedAlert = false
    @State private var timeRemaining: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Card Header
            HStack {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Link Display or Generate Button
            if let link = link, let _ = linkExpiry {
                VStack(spacing: 12) {
                    // Link Box
                    HStack {
                        Text(link)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(action: {
                            #if os(iOS)
                            UIPasteboard.general.string = link
                            #endif
                            showCopiedAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopiedAlert = false
                            }
                        }) {
                            Image(systemName: showCopiedAlert ? "checkmark.circle.fill" : "doc.on.doc.fill")
                                .foregroundColor(showCopiedAlert ? .green : iconColor)
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Expiry Timer
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text("Expires in \(timeRemaining)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button(action: {
                            self.link = nil
                            self.linkExpiry = nil
                        }) {
                            Text("Revoke")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .onAppear {
                        updateTimeRemaining()
                    }
                    
                    // Share Button
                    Button(action: {
                        shareLink(link)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Link")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: gradientColors),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
            } else {
                // Generate Link Button
                Button(action: {
                    generateLink()
                }) {
                    HStack {
                        Image(systemName: "link.badge.plus")
                        Text("Generate Secure Link")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
    
    func generateLink() {
        let randomID = UUID().uuidString.prefix(8)
        link = "medisync.app/share/\(randomID)"
        linkExpiry = Date().addingTimeInterval(TimeInterval(expiryHours * 3600))
        updateTimeRemaining()
    }
    
    func updateTimeRemaining() {
        guard let expiry = linkExpiry else { return }
        let remaining = expiry.timeIntervalSinceNow
        
        if remaining > 0 {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            timeRemaining = "\(hours)h \(minutes)m"
        } else {
            timeRemaining = "Expired"
            link = nil
            linkExpiry = nil
        }
    }
    
    func shareLink(_ link: String) {
        #if os(iOS)
        let activityVC = UIActivityViewController(
            activityItems: ["Join me on MediSync to track my health: \(link)"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

// MARK: - Connection Item Component
struct ConnectionItem: View {
    let name: String
    let specialty: String
    let connectedDate: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                Text(specialty)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Text(connectedDate)
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Info Row Component
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.9))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - 4. Timeline Analysis View
struct TimelineAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MedicalReportModel.uploadDate, order: .reverse) private var reports: [MedicalReportModel]
    @Query(sort: \LabResultModel.testDate, order: .reverse) private var labResults: [LabResultModel]
    
    // Helper to get trend status
    func getStatus(for organ: String) -> (String, Color) {
        // In a real app, this would calculate based on the trend of the last few data points
        // For now, we'll check the latest lab result status
        let organLabs = labResults.filter { $0.category.contains(organ) || $0.testName.contains(organ) }
        if let latest = organLabs.first {
            if latest.status == "Critical" { return ("Critical", .red) }
            if latest.status == "Abnormal" { return ("Attention", .orange) }
        }
        return ("Stable", Color(red: 0.4, green: 0.8, blue: 0.6))
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Health Timeline")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(reports.isEmpty ? "Upload your first medical report to get started" : "Comprehensive analysis of your organ health trends over time")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Heart Health Card
                    OrganTimelineCard(
                        organName: "Heart",
                        icon: "heart.fill",
                        iconColor: Color(red: 1.0, green: 0.4, blue: 0.5),
                        status: getStatus(for: "Heart").0,
                        statusColor: getStatus(for: "Heart").1,
                        graphType: .wave,
                        labResults: labResults.filter { $0.category == "Heart" || $0.testName.contains("Heart") || $0.testName.contains("Blood Pressure") }
                    )
                    
                    // Kidney Function Card
                    OrganTimelineCard(
                        organName: "Kidneys",
                        icon: "drop.fill",
                        iconColor: Color(red: 0.5, green: 0.4, blue: 0.9),
                        status: getStatus(for: "Kidney").0,
                        statusColor: getStatus(for: "Kidney").1,
                        graphType: .lineWithDots,
                        labResults: labResults.filter { $0.category == "Kidney" || $0.testName.contains("Creatinine") || $0.testName.contains("GFR") }
                    )
                    
                    // Lung Capacity Card
                    OrganTimelineCard(
                        organName: "Lungs",
                        icon: "lungs.fill",
                        iconColor: Color(red: 0.3, green: 0.8, blue: 0.8),
                        status: getStatus(for: "Lung").0,
                        statusColor: getStatus(for: "Lung").1,
                        graphType: .area,
                        labResults: labResults.filter { $0.category == "Lungs" || $0.testName.contains("SpO2") || $0.testName.contains("Respiratory") }
                    )
                    
                    // Liver Function Card
                    OrganTimelineCard(
                        organName: "Liver",
                        icon: "cross.case.fill",
                        iconColor: Color(red: 1.0, green: 0.6, blue: 0.3),
                        status: getStatus(for: "Liver").0,
                        statusColor: getStatus(for: "Liver").1,
                        graphType: .bar,
                        labResults: labResults.filter { $0.category == "Liver" || $0.testName.contains("ALT") || $0.testName.contains("AST") }
                    )
                }
                .padding(.bottom, 100)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
}

// MARK: - Organ Timeline Card
struct OrganTimelineCard: View {
    let organName: String
    let icon: String
    let iconColor: Color
    let status: String
    let statusColor: Color
    let graphType: GraphType
    let labResults: [LabResultModel]
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var showDetailPopup = false
    
    enum GraphType {
        case wave, lineWithDots, area, bar
    }
    
    enum TimePeriod: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }
    
    // Extract data points for the graph
    var dataPoints: [Double] {
        // Sort by date ascending
        let sorted = labResults.sorted { $0.testDate < $1.testDate }
        // Extract numeric values (simple parsing for now)
        let values = sorted.map { $0.value }
        
        if values.isEmpty { return [0.5, 0.5, 0.5, 0.5, 0.5] } // Placeholder flat line if no data
        
        // Normalize to 0.0 - 1.0 range for drawing
        let min = values.min() ?? 0
        let max = values.max() ?? 1
        let range = max - min
        
        if range == 0 { return values.map { _ in 0.5 } }
        
        return values.map { ($0 - min) / range }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                
                Text(organName)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundColor(statusColor)
                    Text(status)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }
            
            // Time Period Toggle
            TimePeriodToggle(selectedPeriod: $selectedPeriod)
            
            // Graph
            ZStack {
                if labResults.isEmpty {
                    Text("No data available")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(height: 180)
                } else {
                    switch graphType {
                    case .wave:
                        HeartWaveGraph(color: iconColor, dataPoints: dataPoints)
                    case .lineWithDots:
                        KidneyLineGraph(color: iconColor, dataPoints: dataPoints)
                    case .area:
                        LungAreaGraph(color: iconColor, dataPoints: dataPoints)
                    case .bar:
                        LiverBarGraph(color: iconColor, dataPoints: dataPoints)
                    }
                }
            }
            .frame(height: 180)
            
            // Timeline Labels (Simplified)
            HStack {
                Text("Past")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("Present")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
        .onTapGesture {
            showDetailPopup = true
        }
        .sheet(isPresented: $showDetailPopup) {
            OrganDetailPopup(
                organName: organName,
                icon: icon,
                iconColor: iconColor,
                graphType: graphType,
                labResults: labResults
            )
        }
    }
}

// MARK: - Time Period Toggle
struct TimePeriodToggle: View {
    @Binding var selectedPeriod: OrganTimelineCard.TimePeriod
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(OrganTimelineCard.TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(selectedPeriod == period ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedPeriod == period ?
                            Color.black : Color.gray.opacity(0.1)
                        )
                        .cornerRadius(selectedPeriod == period ? 15 : 0)
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - Timeline Item Card
struct TimelineItemCard: View {
    let result: LabResultModel
    let backgroundColor: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(result.testDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(result.value.formatted())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    Text(result.unit)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                Text(result.testName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Status Indicator
            Text(result.status)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(result.status == "Normal" ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (result.status == "Normal" ? Color.green : Color.orange).opacity(0.1)
                )
                .cornerRadius(8)
        }
        .padding(18)
        .background(backgroundColor.opacity(0.3))
        .cornerRadius(15)
    }
}

// MARK: - Organ Detail Popup
struct OrganDetailPopup: View {
    @Environment(\.presentationMode) var presentationMode
    let organName: String
    let icon: String
    let iconColor: Color
    let graphType: OrganTimelineCard.GraphType
    let labResults: [LabResultModel]
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(iconColor)
                        
                        Text(organName)
                            .font(.system(size: 24, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Current Value Display
                    if let latest = labResults.sorted(by: { $0.testDate < $1.testDate }).last {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Latest Reading")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(latest.value.formatted())
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(iconColor)
                                Text(latest.unit)
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                            }
                            Text(latest.testName)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Timeline Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("History")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(Array(labResults.sorted(by: { $0.testDate > $1.testDate }).enumerated()), id: \.element.id) { index, result in
                            TimelineItemCard(
                                result: result,
                                backgroundColor: cardColor(for: index)
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
    }
    
    func cardColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.8, blue: 0.9),  // Pink
            Color(red: 0.8, green: 0.95, blue: 0.9), // Green
            Color(red: 1.0, green: 0.95, blue: 0.85), // Beige
            Color(red: 0.9, green: 0.9, blue: 1.0),  // Light Purple
            Color(red: 1.0, green: 0.9, blue: 0.8)   // Peach
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Heart Wave Graph
struct HeartWaveGraph: View {
    let color: Color
    let dataPoints: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .bottom) {
                // Gradient Fill
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, point) in dataPoints.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                        let y = height * (1 - point) // Invert Y because 0 is top
                        
                        if index == 0 {
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            let prevX = width * CGFloat(index - 1) / CGFloat(max(dataPoints.count - 1, 1))
                            let prevY = height * (1 - dataPoints[index - 1])
                            let controlX = (prevX + x) / 2
                            path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: controlX, y: prevY), control2: CGPoint(x: controlX, y: y))
                        }
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Stroke Line
                Path { path in
                    for (index, point) in dataPoints.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                        let y = height * (1 - point)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            let prevX = width * CGFloat(index - 1) / CGFloat(max(dataPoints.count - 1, 1))
                            let prevY = height * (1 - dataPoints[index - 1])
                            let controlX = (prevX + x) / 2
                            path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: controlX, y: prevY), control2: CGPoint(x: controlX, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Kidney Line Graph with Dots
struct KidneyLineGraph: View {
    let color: Color
    let dataPoints: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .bottom) {
                // Line
                Path { path in
                    for (index, point) in dataPoints.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                        let y = height * (1 - point)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // Dots
                ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                    let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                    let y = height * (1 - point)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Lung Area Graph
struct LungAreaGraph: View {
    let color: Color
    let dataPoints: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack(alignment: .bottom) {
                // Area
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    for (index, point) in dataPoints.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                        let y = height * (1 - point)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.2))
                
                // Top Line
                Path { path in
                    for (index, point) in dataPoints.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                        let y = height * (1 - point)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
        }
    }
}

// MARK: - Liver Bar Graph
struct LiverBarGraph: View {
    let color: Color
    let dataPoints: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barWidth = width / CGFloat(dataPoints.count * 2)
            
            ZStack(alignment: .bottom) {
                // Indian Average Reference Line (24 U/L ALT)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.52))
                    path.addLine(to: CGPoint(x: width, y: height * 0.52))
                }
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
                
                // Bars (User Data)
                HStack(alignment: .bottom, spacing: barWidth) {
                    ForEach(0..<dataPoints.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [color, color.opacity(0.5)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: height * CGFloat(dataPoints[index]))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

// MARK: - Brain Multi-Line Graph
struct BrainMultiLineGraph: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Indian Average Reference Line (87% cognitive baseline)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width, y: height * 0.63))
                }
                .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
                
                // Line 1 (User Data - Primary Metric)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.6))
                    path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.55))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.48))
                    path.addLine(to: CGPoint(x: width, y: height * 0.45))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                
                // Line 2 (User Data - Secondary Metric)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.7))
                    path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.68))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.65))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width, y: height * 0.6))
                }
                .stroke(color.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 3]))
            }
        }
    }
}

// MARK: - Eye Dual-Axis Graph
struct EyeDualAxisGraph: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Indian Average Reference Lines
                // Visual Acuity Baseline (20/20)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.50))
                    path.addLine(to: CGPoint(x: width, y: height * 0.50))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 3]))
                
                // Pressure Baseline (14 mmHg)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.64))
                    path.addLine(to: CGPoint(x: width, y: height * 0.64))
                }
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 3]))
                
                // Line 1 (User Data - Visual Acuity)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.48))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.5))
                    path.addLine(to: CGPoint(x: width, y: height * 0.49))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                
                // Line 2 (User Data - Pressure)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.65))
                    path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.63))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.64))
                    path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.62))
                    path.addLine(to: CGPoint(x: width, y: height * 0.63))
                }
                .stroke(Color(red: 0.3, green: 0.7, blue: 0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}


// MARK: - Search View
struct SearchView: View {
    @Binding var searchText: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    let labResults: [LabResultModel]
    let medications: [MedicationModel]
    
    private var searchResults: [(category: String, items: [String])] {
        guard !searchText.isEmpty else { return [] }
        
        var results: [(category: String, items: [String])] = []
        
        // Search in sections/pages
        let pages = ["Dashboard", "Vitals & Lab Results", "Active Medications", "Past Medications", "Chatbot", "Timeline Analysis", "Knowledge Graph", "Doctor Connect"]
        let matchedPages = pages.filter { $0.lowercased().contains(searchText.lowercased()) }
        if !matchedPages.isEmpty {
            results.append(("Pages", matchedPages))
        }
        
        // Search in lab results
        let matchedLabs = labResults.filter { 
            $0.testName.lowercased().contains(searchText.lowercased()) ||
            "\(String(format: "%.1f", $0.value))".lowercased().contains(searchText.lowercased()) ||
            $0.category.lowercased().contains(searchText.lowercased())
        }.map { "\($0.testName): \($0.value)" }
        if !matchedLabs.isEmpty {
            results.append(("Lab Results", Array(matchedLabs.prefix(5))))
        }
        
        // Search in medications (only uploaded medications)
        let uploadedMedications = MedicationManager.shared.getUploadedMedications(context: modelContext)
        let matchedMeds = uploadedMedications.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.dosage.lowercased().contains(searchText.lowercased())
        }.map { "\($0.name) - \($0.dosage)" }
        if !matchedMeds.isEmpty {
            results.append(("Medications", Array(matchedMeds.prefix(5))))
        }
        
        // Search in organs
        let organs = ["Lungs", "Heart", "Kidneys", "Liver", "Eyes", "Ears", "Brain", "Bones"]
        let matchedOrgans = organs.filter { $0.lowercased().contains(searchText.lowercased()) }
        if !matchedOrgans.isEmpty {
            results.append(("Organs", matchedOrgans))
        }
        
        return results
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search pages, labs, medications...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding()
                
                // Results
                if searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("Search for anything in MediSync")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Try searching for pages, organs, lab results, or medications")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No results found")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(searchResults, id: \.category) { result in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(result.category)
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                        .padding(.horizontal)
                                    
                                    ForEach(result.items, id: \.self) { item in
                                        HStack {
                                            Image(systemName: getCategoryIcon(result.category))
                                                .foregroundColor(.gray)
                                            Text(item)
                                                .font(.subheadline)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(10)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Search")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            #else
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            #endif
        }
    }
    
    private func getCategoryIcon(_ category: String) -> String {
        switch category {
        case "Pages": return "doc.text"
        case "Lab Results": return "chart.bar"
        case "Medications": return "pills"
        case "Organs": return "heart"
        default: return "magnifyingglass"
        }
    }
}




// MARK: - Custom Tab Bar
enum Tab: String, CaseIterable {
    case home = "house"
    case grid = "message.fill"
    case stats = "chart.bar"
    case doctor = "stethoscope"
}

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = tab
                    }
                }) {
                    ZStack {
                        if selectedTab == tab {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 45, height: 45)
                                .matchedGeometryEffect(id: "TabCircle", in: namespace)
                        }
                        
                        Image(systemName: tab.rawValue)
                            .font(.system(size: 20))
                            .foregroundColor(selectedTab == tab ? .black : .gray)
                    }
                }
                Spacer()
            }
        }
        .frame(height: 70)
        .background(Color.tabBarBlack)
        .cornerRadius(35)
        .padding(.horizontal, 25)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    @Namespace private var namespace
}

// MARK: - Preview
struct RootContentView_Previews: PreviewProvider {
    static var previews: some View {
        RootContentView()
    }
}
