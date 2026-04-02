import SwiftUI
import FirebaseAuth

struct RootView: View {

    @StateObject private var access = AccessManager()
    @StateObject private var store  = StoreKitManager()
    @State private var logged = false
    @State private var isLoading = true
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if isLoading || access.isChecking {
                splashScreen
            } else if !logged {
                // Não autenticado → Login
                NavigationView {
                    LoginView(logged: $logged)
                }
            } else if !access.isPremium {
                // Autenticado mas sem subscrição activa → Paywall (Apple IAP)
                PremiumWallView()
                    .environmentObject(access)
                    .environmentObject(store)
            } else if !onboardingComplete {
                // Premium mas ainda não fez onboarding
                OnboardingBiometricsView()
            } else {
                // Premium + onboarding completo → App completa
                MainTabView()
                    .environmentObject(access)
                    .environmentObject(store)
            }
        }
        .onAppear {
            Auth.auth().addStateDidChangeListener { _, user in
                logged = user != nil
                if user == nil {
                    isLoading = false
                }
            }
        }
        .onChange(of: access.isChecking) { checking in
            if !checking { isLoading = false }
        }
    }

    // MARK: - Splash

    private var splashScreen: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 20) {
                AlmaLogoView(size: 100, animated: true)
                Text("Alma")
                    .font(.largeTitle.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Cuide da sua mente")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
    }
}
