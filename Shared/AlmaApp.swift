import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications
import WatchConnectivity

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

        #if DEBUG
        // Captura de telas de validação (-semPermissoes 1): sem o alerta do
        // sistema por cima do conteúdo que se quer conferir.
        if DebugContextDump.suprimirPermissoes { return true }
        #endif
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

        // Apple Watch — ativa a sessão para receber o handoff ("tocar meditação X")
        // disparado pelo app do relógio. Tolerante: se não houver Watch, é no-op.
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
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

// MARK: - Apple Watch handoff (WatchConnectivity)

extension AppDelegate: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    // iOS exige estes dois (watchOS não). Reativa para continuar ouvindo o relógio.
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchMessage(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleWatchMessage(userInfo)
    }

    /// Recebe o pedido do relógio e avisa o app para tocar a meditação do dia.
    /// O áudio mora no iPhone; o Watch só dispara. Quem ouve `.playMeditationFromWatch`
    /// abre/inicia a prática (a tela de Práticas pode observar isto).
    private func handleWatchMessage(_ payload: [String: Any]) {
        guard (payload["action"] as? String) == "playMeditation",
              let day = payload["day"] as? Int else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .playMeditationFromWatch,
                object: nil,
                userInfo: ["day": day]
            )
        }
    }
}

// MARK: - Cross-view notification names

extension Notification.Name {
    static let openFeedTab = Notification.Name("openFeedTab")
    static let playMeditationFromWatch = Notification.Name("playMeditationFromWatch")
}

@main
struct AlmaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                // [2026-08-04 — achado na conferência visual] A Dieta exibia
                // "de 2 368 kcal consumidas": `Text("\(inteiro)")` no SwiftUI
                // formata pelo locale do APARELHO, e o separador de milhar em
                // PT-BR é ponto, não espaço. O mesmo valia para qualquer outro
                // número interpolado em Text no app inteiro.
                //
                // O Alma é um app PT-BR — a regra do projeto é PT-BR SEMPRE.
                // Fixar o locale na raiz resolve todos os casos de uma vez, em
                // vez de caçar interpolação por interpolação. (O contexto da
                // IA não depende disto: lá o número passa por
                // `CorpoContextFormat.inteiro`, que já é explícito.)
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}
