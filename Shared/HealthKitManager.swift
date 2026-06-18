// HealthKitManager.swift
// Alma App — leitura de HR, HRV, passos e sono via HealthKit.
//
// Extraido de MainTabView.swift em 2026-04 para respeitar separacao de responsabilidades.
// StressLevel + HealthKitManager devem viver aqui, nao na View de tabs.

import SwiftUI
import HealthKit

/// Estados de sono REAL (não "na cama"). Constante de nível de arquivo (nonisolated)
/// para poder ser lida dentro dos closures Sendable do HKSampleQuery — uma `static`
/// dentro da classe `@MainActor` não pode (erro de isolamento no Swift 6).
private let sleepAsleepStates: Set<Int> = [
    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
    HKCategoryValueSleepAnalysis.asleepREM.rawValue
]

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

    /// Passos formatados para exibição com separador de milhar (ex: "8.543")
    var stepsFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private let store = HKHealthStore()
    private var stepObserver: HKObserverQuery?

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

    /// Registra um HKObserverQuery para passos — atualiza `steps` automaticamente
    /// sempre que novos dados chegam do Apple Watch ou iPhone (sem precisar reabrir o app).
    @MainActor
    func startStepObserver() {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        // Cancela observer anterior se existir
        if let existing = stepObserver {
            store.stop(existing)
        }

        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let today = await self.fetchTodaySteps()
                self.steps = today > 0 ? today : self.steps
            }
        }
        stepObserver = observer
        store.execute(observer)

        // Habilita entrega em background para passos (melhor precisão)
        store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }

    @MainActor
    func loadAll() async {
        async let hr = fetchLatestQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        async let avgHR = fetchAverageQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        async let hrvVal = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let avgHrv = fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let stepsVal = fetchTodaySteps()
        async let sleep = fetchSleepHours()
        async let yesterdaySleep = fetchYesterdaySleepHours()

        heartRate = await hr
        averageHeartRate = await avgHR
        hrv = await hrvVal
        averageHRV = await avgHrv
        steps = await stepsVal
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

        // Inicia observer de passos em tempo real (idempotente — para o anterior se existir)
        startStepObserver()
    }

    /// Passos de hoje com fallback para ontem.
    /// - Se hoje tiver dado → retorna hoje.
    /// - Se hoje for 0 (ex: primeiro uso do dia, relógio recém-sincronizado) → retorna ontem como estimativa.
    nonisolated private func fetchTodaySteps() async -> Int {
        let today = await fetchTodaySum(.stepCount, unit: .count())
        if today > 0 { return Int(today) }

        // Fallback: ontem (evita exibir 0 cedo de manhã antes do relógio sincronizar)
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let startYesterday = cal.startOfDay(for: yesterday)
        let endYesterday   = cal.startOfDay(for: Date())
        let yesterdaySteps = await fetchRangeSum(.stepCount, unit: .count(), from: startYesterday, to: endYesterday)
        return Int(yesterdaySteps)
    }

    /// Valor MAIS RECENTE de uma quantity. Tenta hoje; se não houver amostra hoje,
    /// amplia a janela para os últimos 7 dias. Fontes como Garmin (via Garmin Connect)
    /// sincronizam em lotes e gravam HRV de forma esparsa — então "hoje" costuma vir
    /// vazio mesmo havendo dado recente. Melhor mostrar o último valor do que 0.
    nonisolated private func fetchLatestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        if let today = await latestSample(id, unit: unit, since: Calendar.current.startOfDay(for: Date())) {
            return today
        }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return await latestSample(id, unit: unit, since: weekAgo) ?? 0
    }

    /// Última amostra desde [start]. Retorna `nil` quando não há nenhuma — distingue
    /// "sem dado" de "valor zero".
    nonisolated private func latestSample(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since start: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    nonisolated private func fetchTodaySum(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let start = Calendar.current.startOfDay(for: Date())
        return await fetchRangeSum(id, unit: unit, from: start, to: Date())
    }

    nonisolated private func fetchRangeSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(q)
        }
    }

    nonisolated private func fetchSleepHours() async -> Double {
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        return await sleepHours(from: start, to: Date())
    }

    /// Horas de sono numa janela. Primeiro soma estados `asleep*`; se vier 0, faz
    /// fallback para amostras `inBed`. Esse fallback é essencial para fontes como
    /// **Garmin** (via Garmin Connect), que em várias versões gravam o sono apenas
    /// como `inBed` no app Saúde — sem ele, o card zera mesmo havendo dado.
    nonisolated private func sleepHours(from start: Date, to end: Date) async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let cats = (samples ?? []).compactMap { $0 as? HKCategorySample }
                func sum(_ states: Set<Int>) -> Double {
                    cats.filter { states.contains($0.value) }
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600.0
                }
                let asleep = sum(sleepAsleepStates)
                if asleep > 0 {
                    cont.resume(returning: asleep)
                } else {
                    // Fallback: contar "na cama" (alguns exports, p.ex. Garmin, só gravam isso).
                    cont.resume(returning: sum([HKCategoryValueSleepAnalysis.inBed.rawValue]))
                }
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
        let cal = Calendar.current
        let now = Date()
        // Início: ontem às 18:00
        let yesterday = cal.date(byAdding: .day, value: -1, to: now) ?? now
        let startOfYesterdayEvening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        // Fim: hoje às 12:00 (ou agora se for de manhã cedo)
        let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        let end = noonToday < now ? noonToday : now

        // Janela "noite passada". sleepHours(from:to:) já tenta asleep* e cai pra inBed.
        let primary = await sleepHours(from: startOfYesterdayEvening, to: end)
        if primary > 0 { return primary }

        // Fallback: últimas 48h (cobre quem dormiu/sincronizou fora da janela típica).
        let fallbackStart = cal.date(byAdding: .hour, value: -48, to: now) ?? now
        return await sleepHours(from: fallbackStart, to: now)
    }
}

