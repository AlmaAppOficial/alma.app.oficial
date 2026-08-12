//
//  HealthManager.swift
//  Corpo & Alma
//
//  Integração com HealthKit — passos, frequência cardíaca, sono e peso reais.
//  Os dados do Apple Watch chegam aqui automaticamente via app Saúde.
//  Tudo é opcional: sem permissão, o app segue com os valores de exemplo.
//

import Foundation
import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class HealthManager: ObservableObject {

    // ═══════════════════════════════════════════════════════════════════════
    // [2026-08-05 — build 93] O BUG DA ABERTURA FRIA
    //
    // `isAuthorized` era estado só de memória, nascia `false` e só virava
    // `true` dentro do callback de `requestAuthorization`. `refresh()` só era
    // chamado ali dentro, no `if success`. Consequência: TODA abertura do app
    // começava "não autorizada" e não buscava nada. A pessoa que já tinha
    // concedido a permissão semanas atrás via, toda vez que abria o Corpo:
    // "Desconectado" no card do relógio, "Desconectado" nos ajustes, e
    // passos/calorias/sono zerados — até tocar de novo em "Conectar".
    //
    // O conserto tem três pernas:
    //   1. quando a autorização acontece, uma marca vai para o disco;
    //   2. na inicialização, se a marca existe, já nascemos autorizados e
    //      buscamos os dados na hora, sem esperar toque nenhum;
    //   3. qualquer leitura que volte COM dado liga a marca — porque dado no
    //      HealthKit é prova de autorização, e cobre quem já tinha concedido
    //      antes desta versão existir (a marca não estaria no disco para eles).
    // ═══════════════════════════════════════════════════════════════════════

    /// Marca de "esta instalação já obteve autorização de leitura".
    static let chaveAutorizado = "corpo.saude.autorizado"

    @Published var isAuthorized: Bool
    @Published var steps: Double?
    @Published var restingHeartRate: Double?
    @Published var sleepHours: Double?
    /// [2026-08-04] A noite passada com os estágios, quando o aparelho os grava.
    /// `nil` = não há dado. A tela decide o que mostrar; ela nunca preenche
    /// buraco com número. Ver `PontuacaoDeSono`.
    @Published var noiteDeSono: NoiteDeSono?
    @Published var bodyMass: Double?
    @Published var oxygen: Double?      // SpO2 em %
    @Published var hrv: Double?         // variabilidade (ms)
    @Published var activeCalories: Double?  // kcal ativas queimadas hoje

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    private let defaults: UserDefaults

    /// Quantas vezes `refresh()` foi chamado. Existe para a asserção A27c
    /// poder provar o ELO "marca no disco → busca na partida" — que é
    /// exatamente o elo que faltava e produziu o bug. Sem isto, a asserção só
    /// conseguiria provar a peça (`isAuthorized` certo) e ficaria cega para
    /// alguém apagar a chamada de `refresh()` do init.
    private(set) var buscasDisparadas = 0

    /// Perna 2 do conserto: a marca do disco decide como nascemos, e se ela
    /// existe a busca sai na frente — sem esperar toque em "Conectar".
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAuthorized = defaults.bool(forKey: Self.chaveAutorizado)
        if self.isAuthorized { refresh() }
    }

    /// Perna 1 e 3: liga a marca e a persiste. Só LIGA, nunca desliga — ver
    /// `requestAuthorization` para o porquê.
    func marcarAutorizado() {
        if !isAuthorized { isAuthorized = true }
        defaults.set(true, forKey: Self.chaveAutorizado)
    }

    /// HealthKit disponível neste dispositivo?
    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Heurística simples: se já temos FC/sono via Saúde, há um relógio alimentando os dados.
    var watchConnected: Bool {
        isAuthorized && (restingHeartRate != nil || sleepHours != nil)
    }

    // MARK: - Como a tela pode falar sobre a conexão
    //
    // [2026-08-05 — build 93] REGRA DE PRODUTO: consulta vazia NÃO é
    // desconexão. Para tipos de LEITURA o HealthKit se recusa, por projeto, a
    // dizer se houve concessão — `authorizationStatus(for:)` devolve
    // `.sharingDenied` tanto para "a pessoa negou" quanto para "a pessoa
    // permitiu e não há amostra". Isso é deliberado da Apple: revelar a
    // diferença já vazaria informação de saúde (não ter dado de sono é um
    // dado sobre você).
    //
    // Logo, escrever "Desconectado" porque a consulta voltou vazia é o app
    // afirmar uma coisa que ele não tem como saber — e é a afirmação errada
    // com mais frequência, porque o caso comum é justamente "autorizado, sem
    // amostra hoje". "Desconectado" fica reservado para o único caso em que
    // temos certeza: nunca obtivemos autorização nesta instalação.

    enum EstadoDaSaude: Equatable {
        case indisponivel        // aparelho sem HealthKit
        case naoConectado        // nunca autorizamos aqui — é o único "Desconectado" honesto
        case conectadoSemDados   // autorizado, nenhuma amostra veio
        case conectadoComDados
    }

    /// Alguma das leituras voltou com valor?
    var temAlgumDado: Bool {
        steps != nil || restingHeartRate != nil || sleepHours != nil
            || bodyMass != nil || oxygen != nil || hrv != nil || activeCalories != nil
    }

    var estado: EstadoDaSaude {
        guard isAvailable else { return .indisponivel }
        guard isAuthorized else { return .naoConectado }
        return temAlgumDado ? .conectadoComDados : .conectadoSemDados
    }

    /// Mapa PURO estado → texto. Puro de propósito: a asserção A27e percorre
    /// os quatro casos sem depender de haver HealthKit no aparelho onde o
    /// harness roda, que é como uma asserção fica verde sem provar nada.
    static func rotulo(para estado: EstadoDaSaude) -> String {
        switch estado {
        case .indisponivel:      return "Indisponível neste aparelho"
        case .naoConectado:      return "Desconectado"
        case .conectadoSemDados: return "Conectado, sem dados hoje"
        case .conectadoComDados: return "Conectado"
        }
    }

    /// O texto que as telas mostram.
    var rotuloDeConexao: String { Self.rotulo(para: estado) }

    /// Rótulo do card do Apple Watch. Mesma regra, aplicada ao relógio: não
    /// ter batimento nem sono hoje não prova que o relógio saiu do pulso.
    var rotuloDoRelogio: String {
        guard isAvailable else { return "Indisponível neste aparelho" }
        guard isAuthorized else { return "Desconectado" }
        return watchConnected ? "Conectado" : "Sem dados hoje"
    }

    // MARK: - Autorização

    func requestAuthorization() {
        #if DEBUG
        if DebugContextDump.suprimirPermissoes { return }
        #endif
        #if canImport(HealthKit)
        guard isAvailable else { return }

        var read: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { read.insert(steps) }
        if let hr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { read.insert(hr) }
        if let mass = HKObjectType.quantityType(forIdentifier: .bodyMass) { read.insert(mass) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { read.insert(sleep) }
        if let ox = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { read.insert(ox) }
        if let v = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { read.insert(v) }
        if let cal = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(cal) }

        store.requestAuthorization(toShare: [], read: read) { [weak self] success, _ in
            Task { @MainActor in
                guard let self else { return }
                // `success` diz que a FOLHA foi apresentada sem erro — não que
                // a pessoa concedeu. Por isso ele só liga a marca, nunca a
                // desliga: desligar em `success == false` apagaria a
                // autorização real de quem só teve um erro de apresentação.
                if success { self.marcarAutorizado() }
                // E buscamos sempre. Se não havia autorização, as consultas
                // voltam vazias e nada muda; se havia, os dados chegam mesmo
                // que `success` tenha vindo falso.
                self.refresh()
            }
        }
        #endif
    }

    // MARK: - Leitura

    func refresh() {
        // Contado ANTES de qualquer guarda: o que a A27c precisa provar é que
        // a partida PEDIU a busca. Se o aparelho não tem HealthKit, o pedido
        // continua tendo sido feito — e é o pedido que sumia.
        buscasDisparadas += 1
        #if canImport(HealthKit)
        guard isAvailable else { return }
        readStepsToday()
        readActiveCaloriesToday()
        readMostRecentQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] v in
            self?.restingHeartRate = v
        }
        readMostRecentQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] v in
            self?.bodyMass = v
        }
        readMostRecentQuantity(.oxygenSaturation, unit: HKUnit.percent()) { [weak self] v in
            self?.oxygen = v.map { $0 * 100 }
        }
        readMostRecentQuantity(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) { [weak self] v in
            self?.hrv = v
        }
        readSleepLastNight()
        #endif
    }

    #if canImport(HealthKit)
    private func readStepsToday() {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .count())
            Task { @MainActor in
                self?.steps = value
                // Perna 3: dado que chega É prova de autorização.
                if value != nil { self?.marcarAutorizado() }
            }
        }
        store.execute(query)
    }

    private func readMostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            Task { @MainActor in
                completion(value)
                if value != nil { self?.marcarAutorizado() }
            }
        }
        store.execute(query)
    }

    private func readActiveCaloriesToday() {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
            Task { @MainActor in
                self?.activeCalories = value
                if value != nil { self?.marcarAutorizado() }
            }
        }
        store.execute(query)
    }

    private func readSleepLastNight() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        // [2026-08-07 — DEFEITO relatado pelo Assis: "o sono indicou 11h30, mas
        // no meu relógio foram 6h50"]
        //
        // Aqui havia uma janela ROLANTE de 30 horas a partir de agora. Abrindo o
        // app às 10:00, ela começava às 04:00 de ONTEM — e engolia o rabo da
        // noite retrasada junto com a noite passada. Duas madrugadas somadas
        // como se fossem uma.
        //
        // A conta que o Assis viu: noite real 23:30→06:20 = 6h50, mais o trecho
        // 04:00→08:30 da noite anterior que caía dentro da janela = 4h30.
        // Total 11h20. Ele viu 11h30.
        //
        // A janela agora é ANCORADA, idêntica à de `fetchYesterdaySleepHours`
        // em HealthKitManager.swift — que sempre esteve certa. Os dois leitores
        // de HealthKit deste app precisam falar da MESMA madrugada; era esse
        // exatamente o risco descrito no cabeçalho de PontuacaoDeSono.swift.
        //
        // ATENÇÃO ao que isto NÃO conserta: amostras sobrepostas de fontes
        // diferentes (iPhone + relógio na mesma madrugada) continuam somadas
        // dentro de `NoiteDeSono.montar`. É defeito real, conhecido e
        // documentado lá; ficou para a versão seguinte por mudar um número já
        // visível na tela.
        let janela = janelaDaNoitePassada()
        let predicate = HKQuery.predicateForSamples(withStart: janela.inicio, end: janela.fim)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            let brutas = (samples as? [HKCategorySample]) ?? []
            // [2026-08-04] Antes esta consulta só somava horas e jogava fora o
            // ESTÁGIO de cada amostra — o dado mais rico que o relógio entrega.
            // Agora a amostra é traduzida e a noite inteira é montada por uma
            // função pura, compartilhada com o resto do app.
            let noite = NoiteDeSono.montar(brutas.compactMap(traduzirAmostraDeSono))
            Task { @MainActor in
                self?.noiteDeSono = noite
                // A duração exibida continua vindo da mesma soma de sempre.
                self?.sleepHours = (noite?.totalDormido).flatMap { $0 > 0 ? $0 : nil }
                // Amostra de sono, mesmo sem estágios, é prova de autorização.
                if !brutas.isEmpty { self?.marcarAutorizado() }
            }
        }
        store.execute(query)
    }

    #endif
}
