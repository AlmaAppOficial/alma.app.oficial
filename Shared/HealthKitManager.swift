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

// MARK: - StressLevel (apresentação)
//
// [2026-08-13] Os CASOS do enum mudaram para Shared/RegrasDeSaude.swift, junto
// com a regra que decide qual deles vale. Aqui ficou só o que precisa de
// SwiftUI. A separação não é estética: enquanto a regra morava neste arquivo,
// ela só rodava dentro do app com HealthKit disponível — logo, nunca foi
// exercitada, e por isso o "Relaxado" sem HRV sobreviveu tanto tempo.
extension StressLevel {

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
    /// Passos de hoje. `nil` = sem dado de hoje (ver `RegrasDeSaude.passosDeHoje`).
    @Published var steps: Int?
    /// Nível de stress. `nil` = sem HRV, e então a interface não afirma nada
    /// (ver `RegrasDeSaude.nivelDeStress`). Era `= .low` — um valor padrão que
    /// a Início exibia como "Relaxado" para quem nunca teve HRV medido.
    @Published var stressLevel: StressLevel?

    /// Passos formatados para exibição com separador de milhar (ex: "8.543").
    /// `nil` quando não há dado — quem exibe mostra "—".
    var stepsFormatted: String? {
        guard let steps else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    private let store = HKHealthStore()
    private var stepObserver: HKObserverQuery?
    /// [2026-08-31] Observers dos demais tipos exibidos (sono, HRV, FC).
    /// Ver `iniciarObservadores()` — decisão do Assis de reler os dados de
    /// saúde sempre, não só na primeira abertura.
    private var outrosObservadores: [HKObserverQuery] = []
    /// Tipos com releitura em voo. Sincronização do relógio dispara VÁRIAS
    /// notificações seguidas do mesmo tipo; isto colapsa a rajada numa
    /// leitura só (cuidado nº 3 da decisão: nunca a mesma leitura duas vezes).
    private var releituraEmVoo: Set<String> = []

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

        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completou, error in
            // [2026-08-31] O completionHandler TEM de ser chamado — sem isso o
            // HealthKit trata a entrega como pendente e re-entrega (e penaliza
            // a fila de background delivery, que os passos usam). O parâmetro
            // era descartado com `_` desde a primeira versão deste observer.
            defer { completou() }
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                // [2026-08-13] Continua não regredindo para "sem dado" quando
                // uma notificação do observer chega vazia — `??` faz o mesmo
                // que o `> 0 ? : ` fazia, agora com Optional.
                self.steps = await self.fetchTodaySteps() ?? self.steps
            }
        }
        stepObserver = observer
        store.execute(observer)

        // Habilita entrega em background para passos (melhor precisão)
        store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }

    // MARK: - Observers de sono, HRV e FC [2026-08-31]
    //
    // Decisão do Assis (31/08): *"toda vez que abrir o app acho melhor reler
    // tudo"*. O gatilho de primeiro plano (MainTabView) cobre a reabertura;
    // estes observers cobrem o caso que ele NÃO alcança — o dado que chega com
    // o app JÁ aberto. Foi exatamente o print das 10:36: o relógio sincronizou
    // sono e HRV depois da carga única da `.task` da Início, e o Insights
    // ficou em "—" enquanto o Corpo (que relê) mostrava 7h e 26 ms.
    //
    // Custo: três consultas longevas DENTRO do processo — o HealthKit empurra
    // a notificação; não há polling. `enableBackgroundDelivery` fica só nos
    // passos, que já a tinham: a UI não precisa acordar o app em segundo
    // plano para estar certa quando for vista (o gatilho de foreground faz
    // essa metade). Nenhuma permissão nova: são os mesmos tipos já lidos.
    //
    // Semântica de atualização: a MESMA do observer de passos — só substitui
    // quando a releitura traz valor (> 0). Notificação com consulta vazia não
    // regride a tela para "—"; a verdade completa (incluindo ausência) volta
    // a valer no próximo `loadAll()`. E nada aqui LIMPA valor antes de buscar:
    // o anterior fica na tela até o novo chegar (cuidado nº 1 — sem piscar).
    func iniciarObservadores() {
        startStepObserver()

        outrosObservadores.forEach { store.stop($0) }
        outrosObservadores.removeAll()

        observar(HKCategoryType.categoryType(forIdentifier: .sleepAnalysis), chave: "sono") { [weak self] in
            await self?.recarregarSono()
        }
        observar(HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN), chave: "hrv") { [weak self] in
            await self?.recarregarHRV()
        }
        observar(HKQuantityType.quantityType(forIdentifier: .heartRate), chave: "fc") { [weak self] in
            await self?.recarregarFC()
        }
    }

    private func observar(_ tipo: HKSampleType?, chave: String, releitura: @escaping () async -> Void) {
        guard HKHealthStore.isHealthDataAvailable(), let tipo else { return }
        let q = HKObserverQuery(sampleType: tipo, predicate: nil) { [weak self] _, completou, error in
            defer { completou() }
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.releituraEmVoo.contains(chave) else { return }
                self.releituraEmVoo.insert(chave)
                await releitura()
                self.releituraEmVoo.remove(chave)
            }
        }
        outrosObservadores.append(q)
        store.execute(q)
    }

    /// Sono: as duas janelas que as telas usam (noite passada + últimas 24 h).
    private func recarregarSono() async {
        let noite = await fetchYesterdaySleepHours()
        if noite > 0 { yesterdaySleepHours = noite }
        let ultimas24h = await fetchSleepHours()
        if ultimas24h > 0 { sleepHours = ultimas24h }
    }

    /// HRV: último + média — e o nível de stress, que deriva dos dois.
    private func recarregarHRV() async {
        let ultimo = await fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        if ultimo > 0 { hrv = ultimo }
        let media = await fetchAverageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        if media > 0 { averageHRV = media }
        // Recalcula só quando há resposta — sem HRV novo, o rótulo não some.
        if let novo = RegrasDeSaude.nivelDeStress(hrvMedio: averageHRV, hrvUltimo: hrv) {
            stressLevel = novo
        }
    }

    /// FC: último + média do dia.
    private func recarregarFC() async {
        let ultimo = await fetchLatestQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        if ultimo > 0 { heartRate = ultimo }
        let media = await fetchAverageQuantity(.heartRate, unit: HKUnit(from: "count/min"))
        if media > 0 { averageHeartRate = media }
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

        // Stress level usa MEDIA do HRV quando disponivel (mais robusto que ultimo valor).
        // [2026-08-13] A escada de `if` que vivia aqui terminava em
        // `else { stressLevel = .low }` — sem HRV, "Relaxado". A decisão virou
        // uma função pura e opcional; ver RegrasDeSaude.nivelDeStress.
        stressLevel = RegrasDeSaude.nivelDeStress(hrvMedio: averageHRV, hrvUltimo: hrv)

        // Inicia os observers em tempo real (idempotente — para os anteriores
        // se existirem). [2026-08-31] Era só o de passos; agora sono, HRV e FC
        // também avisam quando mudam — ver `iniciarObservadores()`.
        iniciarObservadores()
    }

    /// Passos de HOJE. `nil` quando não há dado de hoje.
    ///
    /// [2026-08-13] Aqui morava um fallback para ONTEM: quando a soma de hoje
    /// vinha 0, o método consultava o dia anterior e devolvia aquele número —
    /// que a Início exibia sob o título "Saúde hoje". A justificativa original
    /// ("evita exibir 0 cedo de manhã antes do relógio sincronizar") deixou de
    /// valer quando a tela passou a mostrar "—" para ausência: o fallback
    /// deixou de proteger de um zero feio e passou a produzir um número falso.
    ///
    /// Pior, `stepsToday()` — a fonte do contexto de saúde do chat — nunca teve
    /// esse fallback. O app afirmava um número na tela e, no mesmo instante,
    /// conversava como se não tivesse o dado. Agora os dois passam pela mesma
    /// regra pura e não têm como divergir. Ver `RegrasDeSaude.passosDeHoje`.
    nonisolated private func fetchTodaySteps() async -> Int? {
        RegrasDeSaude.passosDeHoje(somaDeHoje: await fetchTodaySum(.stepCount, unit: .count()))
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
    /// Mesma regra que a Início usa — de propósito. Ver `fetchTodaySteps()`.
    nonisolated func stepsToday() async -> Int? {
        #if DEBUG
        if SementeDeSaude.ligada { return SementeDeSaude.passos }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        return await fetchTodaySteps()
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

