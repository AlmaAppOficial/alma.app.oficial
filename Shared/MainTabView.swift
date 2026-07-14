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
    @AppStorage("isDarkMode") private var isDarkMode = false

    // Tab tag values — Feed = 1, used as the deep-link target for FCM push
    // notifications carrying action=openFeed (see AppDelegate, Build 77).
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
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: .openFeedTab)) { _ in
            selectedTab = .feed
        }
        .sheet(isPresented: $paywallManager.shouldShowPaywall, onDismiss: {
            Task { await PaywallTriggerManager.shared.dismissPaywall() }
        }) {
            PremiumWallView()
        }
    }
}
