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
    @Published var heartRate: Double = 0              // ultimo valor do dia
    @Published var averageHeartRate: Double = 0       // media do dia (mostrada como "Freq. media")
    @Published var hrv: Double = 0                    // ultimo valor do dia
    @Published var averageHRV: Double = 0             // media do dia
    @Published var sleepHours: Double = 0             // ultimas 24h (compatibilidade)
    @Published var yesterdaySleepHours: Double = 0    // noite passada: ontem 18h -> hoje 12h
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
        async let avgHR = fetchAverageQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        async let hrvVal = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let avgHrv = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let stepsVal = fetchTodaySum(.stepCount, unit: .count())
        async let sleep = fetchSleepHours()
        async let yesterdaySleep = fetchYesterdaySleepHours()

        heartRate = await hr
        averageHeartRate = await avgHR
        hrv = await hrvVal
        averageHRV = await avgHrv
        steps = Int(await stepsVal)
        sleepHours = await sleep
        yesterdaySleepHours = await yesterdaySleep

        // Stress level usa MEDIA do HRV quando disponivel (mais robusto que ultimo valor)
        let hrvForStress = averageHRV > 0 ? averageHRV : hrv
        if hrvForStress > 50 {
            stressLevel = .low
        } else if hrvForStress > 30 {
            stressLevel = .moderate
        } else if hrvForStress > 0 {
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

    /// Media de uma quantity ao longo do dia atual (ex: BPM medio).
    /// Usa HKStatisticsQuery com .discreteAverage.
    nonisolated private func fetchAverageQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .discreteAverage) { _, stats, _ in
                let value = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    /// Sono da NOITE PASSADA — janela de ontem 18:00 ate hoje 12:00.
    /// Soma duracao apenas de amostras com sleep state asleep* (nao "in bed").
    /// Se nao houver dados na janela, faz fallback pra ultima sessao de sono detectada nas ultimas 48h.
    nonisolated private func fetchYesterdaySleepHours() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let cal = Calendar.current
        let now = Date()
        // Inicio: ontem as 18:00
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let startOfYesterdayEvening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        // Fim: hoje as 12:00 (ou agora se for de manha cedo)
        let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let end = noonToday < now ? noonToday : now

        let pred = HKQuery.predicateForSamples(withStart: startOfYesterdayEvening, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let hours = await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let cats = (samples ?? []).compactMap { $0 as? HKCategorySample }
                // Considera apenas estados de sono real (nao "in bed")
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let total = cats
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total / 3600.0)
            }
            self.store.execute(q)
        }

        // Fallback: se nao achou nada na janela ontem-noite, tenta ultimas 48h
        if hours > 0 { return hours }
        let fallbackStart = cal.date(byAdding: .hour, value: -48, to: now)!
        let predFallback = HKQuery.predicateForSamples(withStart: fallbackStart, end: now)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: predFallback, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let cats = (samples ?? []).compactMap { $0 as? HKCategorySample }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let total = cats
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                cont.resume(returning: total / 3600.0)
            }
            self.store.execute(q)
        }
    }
}

