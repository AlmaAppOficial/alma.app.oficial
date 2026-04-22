import SwiftUI
import FirebaseAuth

struct RootView: View {

    @StateObject private var access = AccessManager()
    @StateObject private var store  = StoreKitManager()
    @State private var logged = false
    @State private var isLoading = true
    @State private var currentUser: User? = nil
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if isLoading || access.isChecking {
                splashScreen
            } else if !logged {
                // Não autenticado → Login
                NavigationStack {
                    LoginView(logged: $logged)
                }
            } else if !onboardingComplete {
                // Logado mas ainda não fez onboarding
                OnboardingBiometricsView()
            } else {
                // Logged in + onboarding complete → Full app
                ZStack(alignment: .top) {
                    MainTabView()
                        .environmentObject(access)
                        .environmentObject(store)

                    // Trial banner — shown only during free trial, dismissible per session
                    if let user = currentUser, access.isTrialActive(for: user) {
                        VStack(spacing: 0) {
                            trialBanner(daysRemaining: access.trialDaysRemaining(user: user))
                                .animation(.easeInOut(duration: 0.3), value: trialBannerDismissed)
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            Auth.auth().addStateDidChangeListener { _, user in
                logged = user != nil
                currentUser = user
                if user == nil {
                    isLoading = false
                }
            }
        }
        .onChange(of: access.isChecking) { checking in
            if !checking { isLoading = false }
        }
    }

    // MARK: - Trial Banner

    @State private var trialBannerDismissed = false

    @ViewBuilder
    private func trialBanner(daysRemaining: Int) -> some View {
        if !trialBannerDismissed {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text(daysRemaining == 1
                     ? "Último dia do seu período gratuito"
                     : "\(daysRemaining) dias gratuitos restantes")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation { trialBannerDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.85))
            .transition(.move(edge: .top).combined(with: .opacity))
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
