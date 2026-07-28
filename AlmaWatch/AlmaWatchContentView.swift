// AlmaWatchContentView.swift
// Alma — UI do app para Apple Watch (watchOS 8+).
//
// Telas da v1:
//   • Saúde      — frequência cardíaca + passos lidos do HealthKit NATIVO do Watch
//                  (usuários de Apple Watch têm o dado limpo, sem depender do iPhone).
//   • Respirar   — sessão de respiração guiada com animação + háptico no pulso.
//   • Meditações — lista que pede ao iPhone para tocar a meditação (handoff via
//                  WatchConnectivity; áudio pesado fica no telefone).
//   • Frase      — citação do dia (tom estoico do Alma).
//
// Compatível com watchOS 8 (NavigationView, sem NavigationStack).

import SwiftUI
import HealthKit
import WatchKit
import WatchConnectivity

// MARK: - Root

struct AlmaWatchContentView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: HealthGlanceView()) {
                    Label("Saúde", systemImage: "heart.fill")
                }
                NavigationLink(destination: BreathingView()) {
                    Label("Respirar", systemImage: "wind")
                }
                NavigationLink(destination: MeditationsView()) {
                    Label("Meditações", systemImage: "sparkles")
                }
                NavigationLink(destination: QuoteView()) {
                    Label("Frase do dia", systemImage: "quote.bubble")
                }
            }
            .navigationTitle("Alma")
        }
    }
}

// MARK: - Saúde

@MainActor
final class WatchHealthManager: ObservableObject {
    @Published var heartRate: Int = 0
    @Published var steps: Int = 0
    @Published var loading: Bool = true

    private let store = HKHealthStore()

    func requestAndLoad() async {
        guard HKHealthStore.isHealthDataAvailable(),
              let hr = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let st = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            loading = false
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [hr, st])
        } catch {
            loading = false
            return
        }
        let bpm = await latest(hr, unit: HKUnit(from: "count/min"))
        let stepsToday = await todaySum(st, unit: .count())
        heartRate = Int(bpm)
        steps = Int(stepsToday)
        loading = false
    }

    /// Última frequência cardíaca registrada (até 24h atrás, cobre relógio em repouso).
    nonisolated private func latest(_ type: HKQuantityType, unit: HKUnit) async -> Double {
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKSampleQuery(sampleType: type, predicate: pred, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let v = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0
                cont.resume(returning: v)
            }
            self.store.execute(q)
        }
    }

    /// Soma de passos de hoje.
    nonisolated private func todaySum(_ type: HKQuantityType, unit: HKUnit) async -> Double {
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
                let v = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: v)
            }
            self.store.execute(q)
        }
    }
}

struct HealthGlanceView: View {
    @StateObject private var health = WatchHealthManager()

    var body: some View {
        List {
            metricRow(icon: "heart.fill", color: .red,
                      value: health.heartRate > 0 ? "\(health.heartRate)" : "--",
                      unit: "bpm", label: "Freq. cardíaca")
            metricRow(icon: "figure.walk", color: .green,
                      value: "\(health.steps)",
                      unit: "passos", label: "Passos hoje")
            if health.loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
        }
        .navigationTitle("Saúde")
        .task { await health.requestAndLoad() }
    }

    private func metricRow(icon: String, color: Color, value: String, unit: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.title3.bold())
                    Text(unit).font(.caption2).foregroundColor(.secondary)
                }
                Text(label).font(.caption2).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Respirar

struct BreathingView: View {
    @State private var scale: CGFloat = 0.5
    @State private var phase: String = "Prepare-se"
    @State private var timer: Timer?
    @State private var cycles: Int = 0

    private let breatheSeconds: Double = 4

    var body: some View {
        VStack(spacing: 10) {
            Text(phase)
                .font(.headline)
                .animation(.easeInOut, value: phase)
            ZStack {
                Circle().fill(Color.purple.opacity(0.20)).frame(width: 110, height: 110)
                Circle().fill(Color.purple.opacity(0.55))
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale)
            }
            Text("\(cycles) ciclos").font(.caption2).foregroundColor(.secondary)
        }
        .navigationTitle("Respirar")
        .onAppear { breatheIn() }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func breatheIn() {
        phase = "Inspire"
        WKInterfaceDevice.current().play(.start)
        withAnimation(.easeInOut(duration: breatheSeconds)) { scale = 1.0 }
        timer = Timer.scheduledTimer(withTimeInterval: breatheSeconds, repeats: false) { _ in
            breatheOut()
        }
    }

    private func breatheOut() {
        phase = "Expire"
        WKInterfaceDevice.current().play(.stop)
        withAnimation(.easeInOut(duration: breatheSeconds)) { scale = 0.5 }
        timer = Timer.scheduledTimer(withTimeInterval: breatheSeconds, repeats: false) { _ in
            cycles += 1
            breatheIn()
        }
    }
}

// MARK: - Meditações (handoff para o iPhone)

struct WatchMeditation: Identifiable {
    let id: Int          // dia (1...) — casa com MeditationDay do iPhone
    let title: String
}

/// Envia mensagens ao app do iPhone (ex.: "tocar meditação X"). O telefone tem o
/// áudio; o relógio só dispara. Tolerante a falha: se o iPhone não estiver acessível,
/// não trava nada.
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func play(meditationDay day: Int) {
        let msg: [String: Any] = ["action": "playMeditation", "day": day]
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(msg, replyHandler: nil, errorHandler: nil)
        } else {
            // App do iPhone em background: enfileira via transferUserInfo.
            session.transferUserInfo(msg)
        }
    }

    // WCSessionDelegate (watchOS só exige este método).
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
}

struct MeditationsView: View {
    // Amostra das primeiras meditações (o título real vem do iPhone ao tocar).
    private let meditations: [WatchMeditation] = [
        WatchMeditation(id: 1, title: "Respira e Acalma"),
        WatchMeditation(id: 2, title: "O Corpo como Lar"),
        WatchMeditation(id: 3, title: "Soltar o Peso"),
        WatchMeditation(id: 4, title: "Presença"),
        WatchMeditation(id: 5, title: "Gratidão"),
    ]

    @State private var sentDay: Int?

    var body: some View {
        List {
            Section {
                ForEach(meditations) { med in
                    Button {
                        WatchConnectivityManager.shared.play(meditationDay: med.id)
                        sentDay = med.id
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack {
                            Text(med.title)
                            Spacer()
                            Image(systemName: sentDay == med.id ? "iphone.gen3" : "play.circle")
                                .foregroundColor(.purple)
                        }
                    }
                }
            } footer: {
                Text("Toca no iPhone. Mantenha o app aberto no telefone.")
                    .font(.caption2)
            }
        }
        .navigationTitle("Meditações")
    }
}

// MARK: - Frase do dia

struct QuoteView: View {
    private let quotes: [String] = [
        "Cuida da tua alma. — Marco Aurélio",
        "Você tem poder sobre sua mente, não sobre os eventos externos. — Marco Aurélio",
        "A felicidade da sua vida depende da qualidade dos seus pensamentos. — Marco Aurélio",
        "Não é o que acontece, mas como você reage que importa. — Epiteto",
        "A jornada de mil milhas começa com um passo. — Lao Tzu",
    ]

    private var todayQuote: String {
        let idx = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[idx % quotes.count]
    }

    var body: some View {
        ScrollView {
            Text(todayQuote)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
        }
        .navigationTitle("Frase")
    }
}
