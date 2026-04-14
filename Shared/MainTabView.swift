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

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                NavigationView {
                    HomeView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Início", systemImage: "house.fill") }

                NavigationView {
                    FeedView()
                }
                .tabItem { Label("Feed", systemImage: "newspaper.fill") }

                NavigationView {
                    PraticasView()
                }
                .tabItem { Label("Práticas", systemImage: "sparkles") }

                NavigationView {
                    InsightsView()
                        .environmentObject(hk)
                }
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

                NavigationView {
                    ProfileView()
                }
                .tabItem { Label("Perfil", systemImage: "person.fill") }
            }
            .tint(CalmTheme.primary)

            // Persistent mini player — visible on ALL tabs when audio is playing
            if audio.isPlaying || audio.currentTrackTitle != nil {
                MiniPlayerBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 49) // height of tab bar
            }
        }
        .animation(.easeInOut(duration: 0.25), value: audio.isPlaying)
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}
