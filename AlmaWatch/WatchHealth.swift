// WatchHealth.swift
// Alma Watch — HealthKit nativo do relógio.
//
// LÊ: frequência cardíaca, passos, energia ativa e o resumo de atividade
//     (anéis Mover / Exercício / Em Pé).
// ESCREVE: sessões de atenção plena (mindfulSession) ao fim da respiração
//     guiada, e treinos via HKWorkoutSession (WorkoutManager).
//
// Os dados de saúde ficam no aparelho — nada disso sobe para servidor
// (regra de corregedoria do projeto).

import Foundation
import HealthKit

@MainActor
final class WatchHealth: ObservableObject {

    static let shared = WatchHealth()

    let store = HKHealthStore()

    @Published var freqCardiaca: Int = 0
    @Published var passosHoje: Int = 0
    @Published var moverKcal: Double = 0
    @Published var moverMetaKcal: Double = 0
    @Published var exercicioMin: Double = 0
    @Published var exercicioMetaMin: Double = 0
    @Published var emPeHoras: Double = 0
    @Published var emPeMetaHoras: Double = 0
    @Published var carregando = true

    private init() {}

    // MARK: - Autorização

    static var tiposLeitura: Set<HKObjectType> {
        var tipos: Set<HKObjectType> = [HKObjectType.activitySummaryType()]
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { tipos.insert(hr) }
        if let st = HKQuantityType.quantityType(forIdentifier: .stepCount) { tipos.insert(st) }
        if let en = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { tipos.insert(en) }
        return tipos
    }

    static var tiposEscrita: Set<HKSampleType> {
        var tipos: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let mind = HKObjectType.categoryType(forIdentifier: .mindfulSession) { tipos.insert(mind) }
        if let en = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { tipos.insert(en) }
        if let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) { tipos.insert(hr) }
        return tipos
    }

    func pedirAutorizacao() async {
        guard HKHealthStore.isHealthDataAvailable() else { carregando = false; return }
        do {
            try await store.requestAuthorization(toShare: Self.tiposEscrita, read: Self.tiposLeitura)
        } catch {
            carregando = false
            return
        }
    }

    // MARK: - Leituras do dia

    func atualizarTudo() async {
        await pedirAutorizacao()
        async let hr = ultimaFrequencia()
        async let passos = somaDeHoje(.stepCount, unidade: .count())
        let (fc, p) = await (hr, passos)
        freqCardiaca = Int(fc)
        passosHoje = Int(p)
        await carregarAneis()
        carregando = false
    }

    /// Última FC registrada nas últimas 24 h (cobre relógio em repouso).
    private func ultimaFrequencia() async -> Double {
        guard let tipo = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return 0 }
        let inicio = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: inicio, end: Date())
        let ordem = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: tipo, predicate: pred, limit: 1, sortDescriptors: [ordem]) { _, amostras, _ in
                let v = (amostras?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                cont.resume(returning: v)
            }
            store.execute(q)
        }
    }

    private func somaDeHoje(_ id: HKQuantityTypeIdentifier, unidade: HKUnit) async -> Double {
        guard let tipo = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }
        let inicio = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: inicio, end: Date())
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKStatisticsQuery(quantityType: tipo, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unidade) ?? 0)
            }
            store.execute(q)
        }
    }

    /// Anéis de atividade da Apple (Mover / Exercício / Em Pé) de hoje.
    private func carregarAneis() async {
        var comps = Calendar.current.dateComponents([.day, .month, .year, .era], from: Date())
        comps.calendar = Calendar.current
        let pred = HKQuery.predicateForActivitySummary(with: comps)
        let resumo: HKActivitySummary? = await withCheckedContinuation { cont in
            let q = HKActivitySummaryQuery(predicate: pred) { _, resumos, _ in
                cont.resume(returning: resumos?.first)
            }
            store.execute(q)
        }
        guard let r = resumo else { return }
        moverKcal = r.activeEnergyBurned.doubleValue(for: .kilocalorie())
        moverMetaKcal = r.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
        exercicioMin = r.appleExerciseTime.doubleValue(for: .minute())
        exercicioMetaMin = r.appleExerciseTimeGoal.doubleValue(for: .minute())
        emPeHoras = r.appleStandHours.doubleValue(for: .count())
        emPeMetaHoras = r.appleStandHoursGoal.doubleValue(for: .count())
    }

    // MARK: - Escrita: atenção plena

    /// Salva a sessão de respiração como mindfulSession no Apple Saúde.
    /// É isto que cumpre a promessa do NSHealthUpdateUsageDescription.
    func salvarAtencaoPlena(inicio: Date, fim: Date) async {
        guard HKHealthStore.isHealthDataAvailable(),
              let tipo = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let status = store.authorizationStatus(for: tipo)
        guard status != .sharingDenied else { return }
        let amostra = HKCategorySample(type: tipo,
                                       value: HKCategoryValue.notApplicable.rawValue,
                                       start: inicio, end: fim)
        try? await store.save(amostra)
    }
}
