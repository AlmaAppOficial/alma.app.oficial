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
    @Published var isAuthorized = false
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
                self?.isAuthorized = success
                if success { self?.refresh() }
            }
        }
        #endif
    }

    // MARK: - Leitura

    func refresh() {
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
            Task { @MainActor in self?.steps = value }
        }
        store.execute(query)
    }

    private func readMostRecentQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double?) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            Task { @MainActor in completion(value) }
        }
        store.execute(query)
    }

    private func readActiveCaloriesToday() {
        guard let type = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
            Task { @MainActor in self?.activeCalories = value }
        }
        store.execute(query)
    }

    private func readSleepLastNight() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        // Janela de 30 horas para capturar sono da noite anterior mesmo quando o app abre cedo
        let start = Calendar.current.date(byAdding: .hour, value: -30, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
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
            }
        }
        store.execute(query)
    }

    #endif
}
