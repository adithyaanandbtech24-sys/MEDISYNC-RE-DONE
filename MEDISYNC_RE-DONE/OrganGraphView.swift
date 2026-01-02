// OrganGraphView.swift
import SwiftUI
import SwiftData
import Charts

struct OrganGraphView: View {
    let organName: String
    let organColor: Color
    var compact: Bool = false // For mini-graphs in dashboard cards
    
    @Query private var allGraphData: [GraphDataModel]
    @Environment(\.modelContext) private var modelContext
    
    // Filtered data for this organ
    private var graphData: [GraphDataModel] {
        allGraphData.filter { point in
            let pointOrgan = point.organ.lowercased()
            let viewOrgan = organName.lowercased()
            
            // Handle exact match
            if pointOrgan == viewOrgan { return true }
            
            // Handle singular/plural (e.g. "kidney" matches "kidneys")
            if viewOrgan.contains(pointOrgan) || pointOrgan.contains(viewOrgan) {
                return true
            }
            
            return false
        }
        .sorted { $0.date < $1.date }
    }
    
    private var latestValue: Double? {
        graphData.last?.value
    }
    
    private var latestUnit: String {
        graphData.last?.unit ?? ""
    }
    
    private var latestParameter: String {
        graphData.last?.parameter ?? organName
    }
    
    // Comparison logic
    private var comparisonText: String {
        guard let value = latestValue,
              let standard = IndianMedicalStandards.getStandard(for: latestParameter) else {
            return "No standard data"
        }
        
        if value < standard.min {
            return "Below Average (\(Int(standard.min))-\(Int(standard.max)))"
        } else if value > standard.max {
            return "Above Average (\(Int(standard.min))-\(Int(standard.max)))"
        } else {
            return "Normal (\(Int(standard.min))-\(Int(standard.max)))"
        }
    }
    
    var body: some View {
        if compact {
            // Compact Mode - Mini graph for dashboard cards
            compactGraphView
        } else {
            // Full Mode - Detailed view
            fullGraphView
        }
    }
    
    // MARK: - Compact View
    private var compactGraphView: some View {
        VStack(spacing: 0) {
            if !graphData.isEmpty {
                Chart {
                    ForEach(graphData) { point in
                        // Smooth Line with white stroke for contrast
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(.white.opacity(0.9))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        
                        // Subtle gradient fill
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                
            } else {
                // Minimal empty state for compact mode
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
    
    // MARK: - Full View
    private var fullGraphView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(organName)
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    if let value = latestValue {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.0f", value))
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(.black)
                            
                            Text(latestUnit)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                        }
                        
                        Text(comparisonText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Icon
                Circle()
                    .fill(organColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: getOrganIcon(organName))
                            .font(.system(size: 20))
                            .foregroundColor(organColor)
                    )
            }
            .padding(.horizontal)
            
            // Graph Section
            if !graphData.isEmpty {
                Chart {
                    ForEach(graphData) { point in
                        // Smooth Line
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(organColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        // Gradient Area
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [organColor.opacity(0.4), organColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        // Normal Range Reference Line (if available)
                        if let standard = IndianMedicalStandards.getStandard(for: point.parameter) {
                            RuleMark(y: .value("Avg", (standard.min + standard.max) / 2))
                                .foregroundStyle(.gray.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        }
                    }
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .padding(.horizontal)
                
            } else {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No Data Available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Upload medical reports to see trends")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            // Recent History List
            if !graphData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(graphData.suffix(3).reversed()) { point in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                Text(point.date.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(point.value)) \(point.unit)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if let _ = IndianMedicalStandards.getStandard(for: point.parameter) {
                                    Text(IndianMedicalStandards.isNormal(value: point.value, parameter: point.parameter) ? "Normal" : "Abnormal")
                                        .font(.caption2)
                                        .foregroundColor(IndianMedicalStandards.isNormal(value: point.value, parameter: point.parameter) ? .green : .red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(IndianMedicalStandards.isNormal(value: point.value, parameter: point.parameter) ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                        )
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.vertical)
        .background(Color(red: 0.98, green: 0.98, blue: 0.99))
    }
    
    // MARK: - Helper Functions
    
    private func getOrganIcon(_ organ: String) -> String {
        switch organ {
        case "Heart": return "heart.fill"
        case "Lungs": return "lungs.fill"
        case "Kidneys": return "drop.fill"
        case "Liver": return "cross.case.fill"
        case "Brain": return "brain.head.profile"
        case "Pancreas": return "circle.grid.cross.fill"
        case "Blood": return "drop.triangle.fill"
        case "Thyroid": return "staroflife.fill"
        default: return "waveform.path.ecg"
        }
    }
}
