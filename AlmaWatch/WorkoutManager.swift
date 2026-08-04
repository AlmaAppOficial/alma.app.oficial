// WorkoutManager.swift
// Alma Watch — sessão de treino de verdade, com HKWorkoutSession +
// HKLiveWorkoutBuilder.
//
// É a primeira vez que o projeto usa essa API (zero ocorrências no repo até
// 04/08/2026). O que ela dá que o app nunca teve, em nenhuma plataforma:
//   • frequência cardíaca ao vivo durante o treino
//   • calorias medidas pelo relógio
//   • crédito nos anéis de atividade
//   • o treino gravado no Apple Saúde
//
// Ao encerrar, o relógio manda o evento "treinou hoje" para o iPhone —
// exatamente o registro que o AppModel já espera (workoutDays).

import Foundation
import HealthKit

@MainActor
final class WorkoutManager: NSObject, ObservableObject {

    enum Fase: Equatable {
        case parado
        case contagem
        case ativo
        case pausado
        case resumo
    }

    struct TipoDeTreino: Identifiable, Hashable {
        let id: String
        let nome: String
        let icone: String
        let atividade: HKWorkoutActivityType
    }

    static let tipos: [TipoDeTreino] = [
        .init(id: "forca", nome: "Força", icone: "dumbbell.fill", atividade: .functionalStrengthTraining),
        .init(id: "caminhada", nome: "Caminhada", icone: "figure.walk", atividade: .walking),
        .init(id: "corrida", nome: "Corrida", icone: "figure.run", atividade: .running),
        .init(id: "bike", nome: "Bike", icone: "figure.outdoor.cycle", atividade: .cycling),
        .init(id: "hiit", nome: "HIIT", icone: "flame.fill", atividade: .highIntensityIntervalTraining),
        .init(id: "yoga", nome: "Yoga", icone: "figure.mind.and.body", atividade: .yoga),
        .init(id: "alongamento", nome: "Alongamento", icone: "figure.flexibility", atividade: .flexibility),
    ]

    @Published var fase: Fase = .parado
    @Published var tipoAtual: TipoDeTreino?
    @Published var segundosDecorridos: Int = 0
    @Published var freqCardiaca: Int = 0
    @Published var kcalAtivas: Int = 0
    @Published var erro: String?

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var inicioReal: Date?
    private var timer: Timer?

    private var store: HKHealthStore { WatchHealth.shared.store }

    // MARK: - Ciclo de vida

    func iniciar(_ tipo: TipoDeTreino) async {
        erro = nil
        await WatchHealth.shared.pedirAutorizacao()

        let config = HKWorkoutConfiguration()
        config.activityType = tipo.atividade
        config.locationType = .unknown

        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: config)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            s.delegate = self
            b.delegate = self
            session = s
            builder = b
            tipoAtual = tipo
            fase = .contagem

            let inicio = Date()
            inicioReal = inicio
            s.startActivity(with: inicio)
            try await b.beginCollection(at: inicio)
            fase = .ativo
            ligarTimer()
        } catch {
            self.erro = "Não deu para iniciar o treino."
            fase = .parado
            session = nil
            builder = nil
        }
    }

    func pausar() {
        session?.pause()
        fase = .pausado
    }

    func retomar() {
        session?.resume()
        fase = .ativo
    }

    func encerrar() async {
        timer?.invalidate()
        timer = nil
        session?.end()
        do {
            try await builder?.endCollection(at: Date())
            _ = try await builder?.finishWorkout()
        } catch {
            // O treino pode ter menos de um minuto ou a escrita ter sido negada:
            // não escondemos, mas também não travamos o resumo.
            self.erro = "O Apple Saúde não gravou este treino."
        }
        fase = .resumo

        // Evento para o iPhone: marca o dia como treinado (workoutDays).
        let minutos = max(1, segundosDecorridos / 60)
        WatchSync.shared.registrarTreino(duracaoMin: minutos, tipo: tipoAtual?.nome ?? "Treino")
    }

    func limpar() {
        session = nil
        builder = nil
        tipoAtual = nil
        segundosDecorridos = 0
        freqCardiaca = 0
        kcalAtivas = 0
        inicioReal = nil
        fase = .parado
    }

    private func ligarTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let b = self.builder, self.fase == .ativo else { return }
                self.segundosDecorridos = Int(b.elapsedTime)
            }
        }
    }

    var tempoFormatado: String {
        let m = segundosDecorridos / 60
        let s = segundosDecorridos % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Delegates (chegam fora do MainActor)

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        Task { @MainActor in
            self.erro = "A sessão de treino falhou."
            self.fase = .parado
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for tipo in collectedTypes {
            guard let qt = tipo as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: qt) else { continue }
            switch qt.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let v = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
                Task { @MainActor in self.freqCardiaca = Int(v) }
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                let v = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in self.kcalAtivas = Int(v) }
            default:
                break
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
