import SwiftUI
import HealthKit

// MARK: - HealthSummaryCard
struct HealthSummaryCard: View {
    
    // recebe o manager do MainTabView em vez de criar um novo
    @EnvironmentObject private var hk: HealthKitManager
    @State private var authorized = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("Saúde hoje")
                    .font(.headline)
                Spacer()
                Text(hk.stressLevel.label)
                    .font(.caption)
                    .fontWeight(.medium)  // .500 não existe em SwiftUI — usa .medium
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(hk.stressLevel.color.opacity(0.15))
                    .foregroundColor(hk.stressLevel.color)
                    .cornerRadius(20)
            }
            
            if authorized {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    HealthMetric(icon: "heart.fill",    color: .red,
                                 value: "\(Int(hk.heartRate))",
                                 unit: "bpm",   label: "Frequência")
                    HealthMetric(icon: "waveform.path", color: .purple,
                                 value: "\(Int(hk.hrv))",
                                 unit: "ms",    label: "HRV")
                    HealthMetric(icon: "moon.fill",     color: .indigo,
                                 value: String(format: "%.1f", hk.sleepHours),
                                 unit: "h",     label: "Sono")
                    HealthMetric(icon: "figure.walk",   color: .green,
                                 value: "\(hk.steps)",
                                 unit: "passos", label: "Passos")
                }
            } else {
                Button(action: {
                    Task {
                        authorized = await hk.requestAuthorization()
                        if authorized { await hk.loadAll() }
                    }
                }) {
                    Label("Ligar Apple Watch", systemImage: "applewatch")
                        .frame(maxWidth:
