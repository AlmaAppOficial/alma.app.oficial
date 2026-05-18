import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        Analytics.logEvent("app_open", parameters: nil)

        // 🎯 Meta Ads: regista abertura do app (ViewContent) para ajudar o algoritmo
        MetaEventsManager.shared.trackAppOpen()

        // [Build 77 — 12/05/2026] Removido force-signOut Anonymous na inicializacao.
        // Motivo: resetava UID Anonymous a cada abertura do app, perdendo historico/personalizacao
        // e fazendo o chat parecer "expirado" toda vez. Manter Anonymous users entre sessoes.
        // Migracao antiga (forcar login screen pra usuarios anonymous) ja nao e necessaria.
        // if let user = Auth.auth().currentUser, user.isAnonymous {
        //     try? Auth.auth().signOut()
        // }

        return true
    }

    // Google Sign-In: handles the OAuth redirect URL after authentication
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct AlmaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
