import Foundation
import HealthKit
import SwiftUI
import Combine

// MARK: - Health Kit Manager

@MainActor
final class HealthKitManager: NSObject, ObservableObject {
    @Published var heartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var sleepHours: Double = 0
    @Published var steps: Int = 0
    @Published var stressLevel: StressLevel = .unknown
    @Published var isAuthorized: Bool = false

    private let healthStore = HKHealthStore()
    private let dataSampleTypes: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []

        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }

        return types
    }()

    override init() {
        super.init()
        checkHealthKitAvailability()
    }

    // MARK: - Public Methods

    /// Requests HealthKit authorization from the user
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: dataSampleTypes)
            await checkAuthorizationStatus()
            return isAuthorized
        } catch {
            return false
        }
    }

    /// Loads all health metrics concurrently
    func loadAll() async {
        async let heartRateTask = fetchLatestHeartRate()
        async let hrvTask = fetchLatestHRV()
        async let sleepTask = fetchTodaysSleep()
        async let stepsTask = fetchTodaysSteps()

        let (hr, heartRateVariability, sleep, stepCount) = await (
            heartRateTask,
            hrvTask,
            sleepTask,
            stepsTask
        )

        self.heartRate = hr
        self.hrv = heartRateVariability
        self.sleepHours = sleep
        self.steps = stepCount
        self.stressLevel = calculateStressLevel(
            heartRate: hr,
            sleepHours: sleep
        )
    }

    // MARK: - Private Methods

    private func checkHealthKitAvailability() {
        if HKHealthStore.isHealthDataAvailable() {
            Task {
                await checkAuthorizationStatus()
            }
        }
    }

    private func checkAuthorizationStatus() async {
        var allAuthorized = true

        for sampleType in dataSampleTypes {
            let status = healthStore.authorizationStatus(for: sampleType)
            if status != .sharingAuthorized {
                allAuthorized = false
                break
            }
        }

        self.isAuthorized = allAuthorized
    }

    private func fetchLatestHeartRate() async -> Double {
        return await fetchLatestQuantity(
            identifier: .heartRate,
            unit: HKUnit.count().unitDivided(by: HKUnit.minute())
        )
    }

    private func fetchLatestHRV() async -> Double {
        return await fetchLatestQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.millisecond()
        )
    }

    private func fetchTodaysSteps() async -> Int {
        let unit = HKUnit.count()
        let value = await fetchLatestQuantity(
            identifier: .stepCount,
            unit: unit
        )
        return Int(value)
    }

    private func fetchTodaysSleep() async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let sleepSamples = samples as? [HKCategorySample] ?? []
                let totalSleep = sleepSamples.reduce(0.0) { total, sample in
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    return total + duration / 3600 // Convert to hours
                }
                continuation.resume(returning: totalSleep)
            }

            healthStore.execute(query)
        }
    }

    private func fetchLatestQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: quantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in }

        return await withCheckedContinuation { continuation in
            let updatedQuery = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: 0)
                }
            }

            healthStore.execute(updatedQuery)
        }
    }

    private func calculateStressLevel(heartRate: Double, sleepHours: Double) -> StressLevel {
        if heartRate > 100 || sleepHours < 5 {
            return .elevated
        } else if heartRate > 80 || sleepHours < 7 {
            return .moderate
        } else if sleepHours >= 7 && heartRate <= 80 {
            return .calm
        } else {
            return .unknown
        }
    }
}

// MARK: - Stress Level

enum StressLevel: Equatable {
    case calm
    case moderate
    case elevated
    case unknown

    var label: String {
        switch self {
        case .calm:
            return "Calmo"
        case .moderate:
            return "Moderado"
        case .elevated:
            return "Elevado"
        case .unknown:
            return "Desconhecido"
        }
    }

    var color: Color {
        switch self {
        case .calm:
            return Color.green
        case .moderate:
            return Color.yellow
        case .elevated:
            return Color.red
        case .unknown:
            return Color.gray
        }
    }

    var icon: String {
        switch self {
        case .calm:
            return "leaf.fill"
        case .moderate:
            return "bolt.fill"
        case .elevated:
            return "flame.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Health Metric View

struct HealthMetric: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AlmaTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)

                    Spacer()
                }
            }

            Text(label)
                .font(.caption)
                .foregroundColor(AlmaTheme.textSecondary)
        }
        .padding(12)
        .background(AlmaTheme.card)
        .cornerRadius(AlmaTheme.radius)
    }
}

// MARK: - Health Summary Card

struct HealthSummaryCard: View {
    @ObservedObject var healthKitManager: HealthKitManager

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saúde Apple")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AlmaTheme.textPrimary)

                    Text("Seus dados de saúde")
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)
                }

                Spacer()

                // Stress Level Badge
                HStack(spacing: 6) {
                    Image(systemName: healthKitManager.stressLevel.icon)
                        .font(.system(size: 14))

                    Text(healthKitManager.stressLevel.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(healthKitManager.stressLevel.color)
                .cornerRadius(6)
            }

            if healthKitManager.isAuthorized {
                // Metrics Grid
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        HealthMetric(
                            icon: "heart.fill",
                            color: .red,
                            value: String(format: "%.0f", healthKitManager.heartRate),
                            unit: "bpm",
                            label: "Frequência Cardíaca"
                        )

                        HealthMetric(
                            icon: "waveform.path",
                            color: .purple,
                            value: String(format: "%.0f", healthKitManager.hrv),
                            unit: "ms",
                            label: "HRV"
                        )
                    }

                    HStack(spacing: 12) {
                        HealthMetric(
                            icon: "moon.stars.fill",
                            color: .indigo,
                            value: String(format: "%.1f", healthKitManager.sleepHours),
                            unit: "h",
                            label: "Sono"
                        )

                        HealthMetric(
                            icon: "figure.walk",
                            color: .blue,
                            value: String(format: "%d", healthKitManager.steps),
                            unit: "passos",
                            label: "Passos"
                        )
                    }
                }

                // Refresh Button
                Button(action: {
                    Task {
                        await healthKitManager.loadAll()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Atualizar")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AlmaTheme.accent)
                    .cornerRadius(AlmaTheme.radius)
                }
            } else {
                // Authorization Required
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Conecte sua saúde")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(AlmaTheme.textPrimary)

                            Text("Sincronize seu Apple Health para insights personalizados")
                                .font(.caption)
                                .foregroundColor(AlmaTheme.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }

                    Button(action: {
                        Task {
                            await healthKitManager.requestAuthorization()
                        }
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                            Text("Conectar Apple Health")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AlmaTheme.accent)
                        .cornerRadius(AlmaTheme.radius)
                    }
                }
                .padding(12)
                .background(AlmaTheme.card.opacity(0.5))
                .cornerRadius(AlmaTheme.radius)
            }
        }
        .padding(12)
        .background(AlmaTheme.card)
        .cornerRadius(AlmaTheme.radius)
        .onAppear {
            Task {
                if healthKitManager.isAuthorized {
                    await healthKitManager.loadAll()
                }
            }
        }
    }
}

#Preview {
    VStack {
        HealthSummaryCard(healthKitManager: HealthKitManager())
    }
    .padding()
    .background(AlmaTheme.background)
}
