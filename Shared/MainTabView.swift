import SwiftUI
import HealthKit

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
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var keyboardVisible = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationStack {
                    HomeView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Início", systemImage: "house.fill") }

                NavigationStack {
                    FeedView()
                }
                .tabItem { Label("Feed", systemImage: "newspaper.fill") }

                NavigationStack {
                    PraticasView()
                }
                .tabItem { Label("Práticas", systemImage: "sparkles") }

                NavigationStack {
                    InsightsView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
            }
            .tint(CalmTheme.primary)

            // Persistent mini player — visible on ALL tabs when audio is playing
            // and the on-screen keyboard is not open (avoids overlap with input
            // bars like ChatView's TextField). Controls remain available via
            // Control Center / Lock Screen / Apple Watch while typing.
            if (audio.isPlaying || audio.currentTrackTitle != nil) && !keyboardVisible {
                MiniPlayerBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 49) // height of tab bar
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: audio.isPlaying)
        .animation(.easeInOut(duration: 0.2), value: keyboardVisible)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
