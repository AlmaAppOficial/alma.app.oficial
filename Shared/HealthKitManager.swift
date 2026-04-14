// HealthKitManager.swift
// Alma App — leitura de HR, HRV, passos e sono via HealthKit.
//
// Extraido de MainTabView.swift em 2026-04 para respeitar separacao de responsabilidades.
// StressLevel + HealthKitManager devem viver aqui, nao na View de tabs.

import SwiftUI
import HealthKit

// MARK: - StressLevel
enum StressLevel {
    case low, moderate, high

    var label: String {
        switch self {
        case .low:      return "Relaxado"
        case .moderate: return "Moderado"
        case .high:     return "Elevado"
        }
    }

    var color: Color {
        switch self {
        case .low:      return .green
        case .moderate: return .orange
        case .high:     return .red
        }
    }

    var icon: String {
        switch self {
        case .low:      return "leaf.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "flame.fill"
        }
    }
}

// MARK: - HealthKitManager
@MainActor
class HealthKitManager: ObservableObject {
    @Published var heartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var sleepHours: Double = 0
    @Published var steps: Int = 0
    @Published var stressLevel: StressLevel = .low

    private let store = HKHealthStore()

    nonisolated func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let types: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        do {
            try await self.store.requestAuthorization(toShare: [], read: types)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func loadAll() async {
        async let hr = fetchLatestQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        async let hrvVal = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let stepsVal = fetchTodaySum(.stepCount, unit: .count())
        async let sleep = fetchSleepHours()

        heartRate = await hr
        hrv = await hrvVal
        steps = Int(await stepsVal)
        sleepHours = await sleep

        // Calculate stress from HRV
        if hrv > 50 {
            stressLevel = .low
        } else if hrv > 30 {
            stressLevel = .moderate
        } else if hrv > 0 {
            stressLevel = .high
        } else {
            stressLevel = .low  // default when no data
        }
    }

    nonisolated private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let pred = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    nonisolated private func fetchTodaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    nonisolated private func fetchSleepHours() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let total = (samples ?? []).reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                continuation.resume(returning: total / 3600.0)
            }
            self.store.execute(q)
        }
    }
}

