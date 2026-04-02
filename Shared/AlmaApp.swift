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

        // Sign out anonymous users from old app version so they see the new login screen
        if let user = Auth.auth().currentUser, user.isAnonymous {
            try? Auth.auth().signOut()
        }

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
