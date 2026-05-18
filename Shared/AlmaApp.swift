import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

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

        // [Build 77 — 15/05/2026] FCM push notifications setup.
        // Backend trigger (notifyNewFeedPost) lives in Cloud Functions.
        // Client: request authorization, register APNs, bridge token to FCM,
        // and persist fcmToken into users/{uid} on every refresh.
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error = error {
                print("⚠️ [FCM] Authorization error: \(error.localizedDescription)")
            }
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }

        return true
    }

    // Google Sign-In: handles the OAuth redirect URL after authentication
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // APNs → FCM bridge

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ [FCM] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - FCM token persistence

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken,
              let uid = Auth.auth().currentUser?.uid else { return }

        Firestore.firestore().collection("users").document(uid).setData([
            "fcmToken": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

// MARK: - Foreground presentation + tap handling

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let action = userInfo["action"] as? String, action == "openFeed" {
            NotificationCenter.default.post(name: .openFeedTab, object: nil)
        }

        completionHandler()
    }
}

// MARK: - Cross-view notification names

extension Notification.Name {
    static let openFeedTab = Notification.Name("openFeedTab")
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
