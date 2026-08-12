// HealthKitManager.swift
// Alma App — leitura de HR, HRV, passos e sono via HealthKit.
//
// Extraido de MainTabView.swift em 2026-04 para respeitar separacao de responsabilidades.
// StressLevel + HealthKitManager devem viver aqui, nao na View de tabs.

import SwiftUI
import HealthKit

// [2026-08-07] `sleepAsleepStates` vivia aqui e sumiu com a unificação dos dois
// leitores: quem decide o que é sono agora é `traduzirAmostraDeSono` +
// `NoiteDeSono.montar`, em Shared/Corpo/PontuacaoDeSono.swift, para os dois
// caminhos. Ter a lista de estados em dois lugares foi o que deixou as telas
// discordarem sobre a mesma noite.

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

// MARK: - MindfulSessionWriter [Build 84 — 2026-07-29]
// Grava sessões de meditação concluídas como Mindful Minutes no app Saúde.
// Separado do HealthKitManager (que é @MainActor e vive como @StateObject nas
// views) para poder ser chamado do GuidedMeditationEngine sem depender de
// instância. Falha em silêncio: escrever no Health nunca pode quebrar a
// experiência de meditação.
enum MindfulSessionWriter {

    private static let store = HKHealthStore()

    /// Grava uma sessão de atenção plena que TERMINOU AGORA com a duração dada.
    /// Pede autorização de escrita se ainda não foi decidida; respeita recusa.
    static func saveSessionEndingNow(durationSeconds: Int) async {
        guard HKHealthStore.isHealthDataAvailable(),
              durationSeconds > 0,
              let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }

        // Garante que a permissão foi ao menos perguntada (no-op se já decidida)
        if store.authorizationStatus(for: mindfulType) == .notDetermined {
            try? await store.requestAuthorization(toShare: [mindfulType], read: [])
        }

        guard store.authorizationStatus(for: mindfulType) == .sharingAuthorized else {
            #if DEBUG
            print("MindfulSessionWriter: escrita não autorizada — sessão não gravada")
            #endif
            return
        }

        let end = Date()
        let start = end.addingTimeInterval(-Double(durationSeconds))
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        do {
            try await store.save(sample)
            #if DEBUG
            print("MindfulSessionWriter: ✅ \(durationSeconds / 60) min gravados no Saúde")
            #endif
        } catch {
            #if DEBUG
            print("MindfulSessionWriter: falha ao gravar no Saúde: \(error)")
            #endif
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
        #if DEBUG
        // Captura de telas de validação: sem o diálogo do sistema por cima.
        if DebugContextDump.suprimirPermissoes { return false }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        var types: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        ]

        // [Build 85 / 2.0 — 2026-07-31] Tipos novos para o contexto de saúde da
        // Alma. Quem já autorizou vê a folha do iOS só para estes — sem repetir
        // o que já foi concedido.
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        // Mindful minutes: o Alma já ESCREVE (build 84); agora também lê, para
        // saber se a pessoa já parou para respirar hoje — inclusive sessões
        // feitas em outros apps.
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }

        // [Build 84 — 2026-07-29] Escrita de Mindful Minutes: sessões de
        // meditação concluídas viram HKCategorySample(.mindfulSession) no app
        // Saúde. Pedida na mesma folha de permissão das leituras.
        var shareTypes: Set<HKSampleType> = []
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            shareTypes.insert(mindful)
        }

        do {
            try await self.store.requestAuthorization(toShare: shareTypes, read: types)
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

    // MARK: - Leituras para o contexto de saúde da IA [Build 85 / 2.0]

    /// Minutos de exercício de hoje (anel verde da Apple). `nil` quando não há
    /// dado ou autorização — a UI e o contexto distinguem "zero" de "sem dado".
    nonisolated func exerciseMinutesToday() async -> Int? {
        #if DEBUG
        if SementeDeSaude.ligada { return SementeDeSaude.exercicioMinutos }
        #endif
        guard HKHealthStore.isHealthDataAvailable(),
              HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) != nil else { return nil }
        let minutes = await fetchTodaySum(.appleExerciseTime, unit: .minute())
        return minutes > 0 ? Int(minutes.rounded()) : nil
    }

    /// Minutos de atenção plena de hoje, somando TODAS as fontes do Saúde
    /// (Alma, Corpo & Alma, Apple Watch, outros apps).
    nonisolated func mindfulMinutesToday() async -> Int? {
        #if DEBUG
        if SementeDeSaude.ligada { return SementeDeSaude.mindfulMinutos }
        #endif
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return nil }

        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let seconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let minutes = Int((seconds / 60).rounded())
                continuation.resume(returning: minutes > 0 ? minutes : nil)
            }
            self.store.execute(q)
        }
    }

    /// Passos de hoje (`nil` quando não há dado/autorização).
    nonisolated func stepsToday() async -> Int? {
        #if DEBUG
        if SementeDeSaude.ligada { return SementeDeSaude.passos }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let steps = await fetchTodaySum(.stepCount, unit: .count())
        return steps > 0 ? Int(steps) : nil
    }

    /// Horas de sono da noite passada (`nil` quando não há dado/autorização).
    nonisolated func lastNightSleepHours() async -> Double? {
        #if DEBUG
        if SementeDeSaude.ligada { return SementeDeSaude.sonoHoras }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let hours = await fetchYesterdaySleepHours()
        return hours > 0 ? hours : nil
    }

    /// A noite passada COM os estágios, quando o aparelho os grava.
    ///
    /// [2026-08-04] Existe para a pontuação de sono. Usa a mesma janela de
    /// `fetchYesterdaySleepHours` — se as duas divergissem, o card e a linha da
    /// IA falariam de madrugadas diferentes. A montagem é da função pura
    /// `NoiteDeSono.montar`, compartilhada com o módulo Corpo.
    nonisolated func lastNightSleep() async -> NoiteDeSono? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let cal = Calendar.current
        let now = Date()
        // [2026-08-07] Era o mesmo cálculo de janela escrito à mão aqui, uma
        // terceira vez. Três cópias que coincidiam por sorte; agora é uma só.
        let janela = janelaDaNoitePassada(agora: now, calendario: cal)

        if let noite = await sleepStages(from: janela.inicio, to: janela.fim) { return noite }
        // Mesmo fallback de 48 h da duração: quem dormiu fora da janela típica.
        let fallback = cal.date(byAdding: .hour, value: -48, to: now) ?? now
        return await sleepStages(from: fallback, to: now)
    }

    nonisolated private func sleepStages(from start: Date, to end: Date) async -> NoiteDeSono? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { (cont: CheckedContinuation<NoiteDeSono?, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let cats = (samples ?? []).compactMap { $0 as? HKCategorySample }
                cont.resume(returning: NoiteDeSono.montar(cats.compactMap(traduzirAmostraDeSono)))
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

    /// Horas de sono numa janela, com sobreposição contada UMA vez.
    ///
    /// [2026-08-07] Esta função tinha a própria soma — `reduce` cru sobre as
    /// durações — enquanto o leitor do Corpo montava a noite por
    /// `NoiteDeSono.montar`. Duas contas diferentes para o mesmo dado: era por
    /// isso que a aba Saúde dizia 9h21 e a outra tela dizia 11h30 para a mesma
    /// madrugada de 6h50. Consertar só um dos lados deixaria as telas
    /// discordando com números novos.
    ///
    /// Agora as duas passam pela MESMA função pura. A regra de sono do app vive
    /// num lugar só, e "as duas telas mostram o mesmo número" virou invariante
    /// verificável — ver o harness em `_validacao_20260807/`.
    ///
    /// O fallback de `inBed` continua: fontes como **Garmin** (via Garmin
    /// Connect) gravam o sono só como "na cama", e sem ele o card zera mesmo
    /// havendo dado. Quem aplica esse fallback agora é `montar`, que devolve a
    /// duração de `naCama` quando não há nenhum estágio de sono.
    nonisolated private func sleepHours(from start: Date, to end: Date) async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: pred,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let cats = (samples ?? []).compactMap { $0 as? HKCategorySample }
                let noite = NoiteDeSono.montar(cats.compactMap(traduzirAmostraDeSono))
                cont.resume(returning: noite?.totalDormido ?? 0)
            }
            self.store.execute(q)
        }
    }

    /// Media de uma quantity. Tenta hoje primeiro; se vier 0 (sem dados ainda),
    /// amplia para os últimos 7 dias — essencial para HRV (gravado durante o sono,
    /// tipicamente entre 0h-6h) e FC quando o relógio ainda não sincronizou hoje.
    nonisolated private func fetchAverageQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let today = await averageQuery(type, unit: unit,
                                       from: Calendar.current.startOfDay(for: Date()),
                                       to: Date())
        if today > 0 { return today }
        // Fallback: últimos 7 dias (HRV típico vem do sono de ontem à noite;
        // FC pode não ter amostras de hoje cedo da manhã)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return await averageQuery(type, unit: unit, from: weekAgo, to: Date())
    }

    /// HKStatisticsQuery .discreteAverage numa janela arbitrária.
    /// Separado de fetchAverageQuantity para permitir chamadas com ranges distintos.
    nonisolated private func averageQuery(_ type: HKQuantityType, unit: HKUnit,
                                          from start: Date, to end: Date) async -> Double {
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred,
                                      options: .discreteAverage) { _, stats, _ in
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
        // [2026-08-07] Janela vinda da MESMA função pura que o leitor do Corpo
        // usa (`janelaDaNoitePassada`). Antes era calculada à mão aqui — e o
        // leitor do Corpo calculava de outro jeito (30 h rolantes), que foi
        // metade da razão de as duas telas discordarem sobre a mesma noite.
        let janela = janelaDaNoitePassada(agora: now, calendario: cal)

        // `sleepHours(from:to:)` monta a noite por `NoiteDeSono.montar`, que já
        // une sobreposição e já cai para "na cama" quando não há estágio algum.
        let primary = await sleepHours(from: janela.inicio, to: janela.fim)
        if primary > 0 { return primary }

        // Fallback: últimas 48h (cobre quem dormiu/sincronizou fora da janela típica).
        let fallbackStart = cal.date(byAdding: .hour, value: -48, to: now) ?? now
        return await sleepHours(from: fallbackStart, to: now)
    }
}

