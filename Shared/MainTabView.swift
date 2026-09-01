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

// [2026-08-14] `HealthMetric` removido junto com a `healthSection` da
// Início (pedido do Assis: os números já aparecem no Insights e no Corpo).
// Os quatro usos que existiam viviam todos lá dentro.
//
// Não confundir com `CorpoHealthMetric` (Shared/Corpo/Models.swift:13), que
// é outro tipo, do módulo Corpo, e continua vivo.


// MARK: - MainTabView
struct MainTabView: View {
    @StateObject private var hk = HealthKitManager()
    // [2026-08-31] Decisão do Assis: *"toda vez que abrir o app acho melhor
    // reler tudo, assim como calorias, etc"* — os dados de saúde são relidos
    // sempre que o app VOLTA ao primeiro plano, não só na primeira abertura.
    // A flag distingue "voltou do segundo plano" de "acabou de nascer":
    // na partida fria quem carrega é a `.task` da HomeView, e recarregar aqui
    // também seria a mesma leitura duas vezes na mesma abertura.
    @Environment(\.scenePhase) private var scenePhase
    @State private var passouPeloSegundoPlano = false
    @ObservedObject private var audio = AudioManager.shared
    @ObservedObject private var tabVisibility = TabVisibilityState.shared
    @ObservedObject private var paywallManager = PaywallTriggerManager.shared
    @ObservedObject private var aparencia = AparenciaDoApp.shared
    @ObservedObject private var roteador = RoteadorDeNotificacao.shared

    // Tab tag values — Feed = 1, used as the deep-link target for FCM push
    // notifications carrying action=openFeed (see AppDelegate, Build 77).
    //
    // [2026-08-05] Estes números são espelhados por `AbaDaAlma` em
    // RotaDaNotificacao.swift. A asserção R6 compara os dois: se alguém
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
        // [2026-08-31] RELEITURA DA SAÚDE AO VOLTAR AO PRIMEIRO PLANO.
        //
        // O defeito (prints do Assis, 10:36 do mesmo minuto): Insights com
        // "Sono (ontem) —" e "Sem dados de variabilidade", enquanto o Corpo
        // mostrava 7,0h e HRV 26 ms. Não era permissão — era o `hk` carregado
        // UMA vez na `.task` da HomeView; sono e HRV chegaram do relógio
        // depois, e ninguém relia. Este é o gatilho que faltava; os observers
        // do `iniciarObservadores()` cobrem o dado que muda com o app aberto.
        //
        // Fica AQUI, e não na HomeView/InsightsView, porque a instância é
        // desta view: um gatilho só atualiza TODAS as telas que a leem.
        //
        // • Sem piscar: `loadAll()` não limpa nada antes de buscar — cada
        //   @Published só é reatribuído quando a leitura nova responde.
        // • Sem travar: `Task` assíncrona; a UI não espera.
        // • Sem dupla leitura: o guard exige passagem REAL pelo segundo plano
        //   (`.background`). Partida fria e voltas de folha de permissão /
        //   central de controle (inactive → active) não recarregam.
        //   Forma de UM parâmetro no onChange: alvo de implantação < iOS 17,
        //   mesmo motivo de CorpoModuleView.swift:108.
        .onChange(of: scenePhase) { nova in
            if nova == .background { passouPeloSegundoPlano = true }
            guard nova == .active, passouPeloSegundoPlano else { return }
            passouPeloSegundoPlano = false
            Task { await hk.loadAll() }
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
