import SwiftUI
import FirebaseAuth

struct RootView: View {

    @StateObject private var access = AccessManager()
    @StateObject private var store  = StoreKitManager()
    @State private var logged = false
    @State private var isLoading = true
    @State private var currentUser: User? = nil
    @State private var showMetaConsent = false
    @State private var authStateDidChangeHandle: AuthStateDidChangeListenerHandle? = nil
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

                    // [Build 84 — 2026-07-29] Banner de trial removido — modelo
                    // freemium não tem trial de 7 dias.
                }
                // Consentimento Meta (LGPD) — pedido uma única vez, espelha o Android.
                // Sem "Permitir", o MetaEventsManager nunca envia eventos.
                .onAppear {
                    if !MetaEventsManager.shared.hasAskedConsent {
                        showMetaConsent = true
                    }
                }
                .alert("Ajude o Alma a crescer", isPresented: $showMetaConsent) {
                    Button("Permitir") { MetaEventsManager.shared.setConsent(true) }
                    Button("Agora não", role: .cancel) { MetaEventsManager.shared.setConsent(false) }
                } message: {
                    Text("Com a sua permissão, o Alma mede de forma anônima quais anúncios trazem novas pessoas para cuidar da mente. Nunca compartilhamos seu humor, ciclo ou dados de saúde.")
                }
            }
        }
        .onAppear {
            if authStateDidChangeHandle == nil {
                authStateDidChangeHandle = Auth.auth().addStateDidChangeListener { _, user in
                    logged = user != nil
                    currentUser = user
                    if user == nil {
                        isLoading = false
                    }
                }
            }
        }
        .onChange(of: access.isChecking) { checking in
            if !checking { isLoading = false }
        }
        .onDisappear {
            if let handle = authStateDidChangeHandle {
                Auth.auth().removeStateDidChangeListener(handle)
                authStateDidChangeHandle = nil
            }
        }
    }

    // [Build 84 — 2026-07-29] trialBanner removido — modelo freemium sem trial.

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
