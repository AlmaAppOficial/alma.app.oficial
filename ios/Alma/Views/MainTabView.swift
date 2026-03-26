import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager

    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var healthKitManager = HealthKitManager()

    init() {
        configureTabBarAppearance()
    }

    var body: some View {
        TabView {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }

            // Chat Tab
            ChatView()
                .tabItem {
                    Label("Alma IA", systemImage: "bubble.left.fill")
                }

            // Insights Tab
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            // Profile Tab
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
        }
        .accentColor(AlmaTheme.accent)
        .environmentObject(subscriptionManager)
        .environmentObject(healthKitManager)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        // Background color
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AlmaTheme.card)

        // Text colors
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AlmaTheme.textSecondary)
        itemAppearance.normal.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(AlmaTheme.textSecondary)
        ]

        itemAppearance.selected.iconColor = UIColor(AlmaTheme.accent)
        itemAppearance.selected.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(AlmaTheme.accent)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        // Apply to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
