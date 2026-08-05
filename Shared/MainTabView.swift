import SwiftUI
import HealthKit

// MARK: - TabVisibilityState
// Singleton para sinalizar visibilidade do mini player a partir de qualquer view.
// Usado para esconder o mini player enquanto ChatView está em tela (não há
// solução robusta via UIResponder.keyboardWillShow dentro de TabView+NavigationStack).
final class TabVisibilityState: ObservableObject {
    static let shared = TabVisibilityState()
    @Published var hideMiniPlayer = false
    private init() {}
}

// StressLevel + HealthKitManager foram movidos para Shared/HealthKitManager.swift

// MARK: - HealthMetric card
struct HealthMetric: View {
    let icon: String
    let color: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(.headline.bold())
                    Text(unit).font(.caption).foregroundColor(CalmTheme.textSecondary)
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rSmall)
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @StateObject private var hk = HealthKitManager()
    @ObservedObject private var audio = AudioManager.shared
    @ObservedObject private var tabVisibility = TabVisibilityState.shared
    @ObservedObject private var paywallManager = PaywallTriggerManager.shared
    @ObservedObject private var aparencia = AparenciaDoApp.shared
    @ObservedObject private var roteador = RoteadorDeNotificacao.shared

    // Tab tag values — Feed = 1, used as the deep-link target for FCM push
    // notifications carrying action=openFeed (see AppDelegate, Build 77).
    //
    // [2026-08-05] Estes números são espelhados por `AbaDaAlma` em
    // RotaDaNotificacao.swift. A asserção N6 compara os dois: se alguém
    // reordenar as abas aqui e esquecer de lá, a notificação passa a levar para
    // a aba errada — que é pior do que não levar a lugar nenhum.
    private enum Tab: Int {
        case home = 0, feed = 1, praticas = 2, insights = 3, profile = 4
    }

    @State private var selectedTab: Tab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Início", systemImage: "house.fill") }
                .tag(Tab.home)

                NavigationStack {
                    FeedView()
                }
                .tabItem { Label("Feed", systemImage: "newspaper.fill") }
                .tag(Tab.feed)

                NavigationStack {
                    PraticasView()
                }
                .tabItem { Label("Práticas", systemImage: "sparkles") }
                .tag(Tab.praticas)

                NavigationStack {
                    InsightsView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(Tab.insights)

                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
                .tag(Tab.profile)
            }
            .tint(CalmTheme.primary)

            // Persistent mini player — visível em TODAS as abas enquanto há áudio.
            // Excecao: views que escondem o mini player explicitamente via
            // TabVisibilityState (ex: ChatView, para evitar sobreposicao com
            // o TextField). Áudio segue tocando; controles permanecem via
            // Control Center / Lock Screen / Apple Watch.
            if (audio.isPlaying || audio.currentTrackTitle != nil) && !tabVisibility.hideMiniPlayer {
                MiniPlayerBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 49) // height of tab bar
            }
        }
        .animation(.easeInOut(duration: 0.25), value: audio.isPlaying)
        .animation(.easeInOut(duration: 0.25), value: tabVisibility.hideMiniPlayer)
        .preferredColorScheme(aparencia.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .openFeedTab)) { _ in
            selectedTab = .feed
        }
        // [2026-08-05] Encaminhamento por toque em notificação.
        //
        // AS DUAS CHAMADAS SÃO OBRIGATÓRIAS E COBREM CASOS DIFERENTES:
        //   • `onAppear`  → APP FECHADO. O delegate já roteou durante o launch,
        //     antes desta view existir. Ela nasce e encontra o destino esperando.
        //   • `onChange`  → APP VIVO (primeiro/segundo plano). Esta view já
        //     existe e o destino chega depois.
        // Apagar qualquer uma das duas quebra metade dos caminhos — e é sempre
        // a metade fria que passa despercebida.
        .onAppear { encaminharNotificacaoPendente() }
        .onChange(of: roteador.pendente) { _ in encaminharNotificacaoPendente() }
        // [2026-08-04 — Watch] Handoff do relógio: o áudio já foi disparado
        // pelo WatchBridge (toca até com o app em background); aqui só levamos
        // a pessoa para a aba de Práticas quando o app está aberto.
        .onReceive(NotificationCenter.default.publisher(for: .playMeditationFromWatch)) { _ in
            selectedTab = .praticas
        }
        .sheet(isPresented: $paywallManager.shouldShowPaywall, onDismiss: {
            Task { await PaywallTriggerManager.shared.dismissPaywall() }
        }) {
            PremiumWallView()
        }
    }

    /// Cumpre o que esta tela sabe cumprir e deixa o resto pendente.
    ///
    /// Aba do Alma → resolve aqui e limpa. Chat, Corpo e Livre de Vícios vivem
    /// empilhados na Início: esta view só troca para a aba Início e NÃO limpa o
    /// pendente — a `HomeView` termina o trabalho quando aparecer. É por isso
    /// que o `consumir` recebe um predicado em vez de esvaziar sempre.
    private func encaminharNotificacaoPendente() {
        guard let pendente = roteador.pendente else { return }

        switch pendente {
        case .almaAba(let aba):
            _ = roteador.consumir { if case .almaAba = $0 { return true } else { return false } }
            selectedTab = Tab(rawValue: aba.rawValue) ?? .home
        case .corpoAba, .conversarComAlma, .livreDeVicios:
            selectedTab = .home
        }
    }
}
