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

        #if DEBUG
        // [Áudio do dia 2026-08-31 — QA] `-almaEmulador 1` liga o app nos
        // emuladores do Firebase (Auth 9099, Firestore 8080) e entra ANÔNIMO —
        // nenhuma credencial em lugar nenhum, nenhum byte em produção. Existe
        // para provar o fluxo do Áudio do dia de ponta a ponta (página →
        // ponteiro → caixa da Início → botão do Perfil) contra o emulador,
        // como manda o CLAUDE.md ("execução, não leitura"). Mesma família do
        // `semLogin`/`-abrirCorpo`: flag de LANÇAMENTO, nunca persistida, e o
        // Release nem compila este bloco.
        if UserDefaults.standard.bool(forKey: "almaEmulador") {
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
            let ajustes = Firestore.firestore().settings
            ajustes.host = "127.0.0.1:8080"
            ajustes.isSSLEnabled = false
            // Cache em memória: cada rodada de QA nasce limpa, sem disco
            // envenenado por uma execução anterior contra outro backend.
            ajustes.cacheSettings = MemoryCacheSettings()
            Firestore.firestore().settings = ajustes
            if Auth.auth().currentUser == nil {
                Auth.auth().signInAnonymously()
            }
        }
        #endif

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
        // e os eventos registrados no pulso (água, humor, treino, respiração).
        // Tolerante: se não houver Watch, é no-op.
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        // A ponte publica o estado (streak, água, treino, premium, catálogo
        // das 30 meditações) e processa os eventos com deduplicação.
        WatchBridge.shared.iniciar()

        // Categoria dos lembretes: no relógio, notificações desta categoria
        // usam a interface do Alma (NotificationController do AlmaWatch).
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: "ALMA_LEMBRETE",
                                   actions: [],
                                   intentIdentifiers: [],
                                   options: [])
        ])

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

        // [2026-08-04 — D-5] Este `setData(merge: true)` RECRIA `users/{uid}`.
        // A idempotência da Cloud Function só trata a transição false→true de
        // `deletionRequested`: um documento recriado depois da deleção nunca
        // mais era apagado. Se há limpeza pendente, a conta está em processo de
        // exclusão — não gravar nada.
        guard !LocalDataCleanupService.temLimpezaPendente else { return }

        Firestore.firestore().collection("users").document(uid).setData([
            "fcmToken": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
            // [Áudio do dia 2026-08-31] O fuso IANA viaja JUNTO com o token
            // (mesma escrita, mesmo funil — espelho do FcmTokenRepository.kt
            // do Android): os dois respondem à mesma pergunta do servidor,
            // "para onde e QUANDO empurrar?". O agendador do Áudio do dia
            // dispara às 6h da manhã NO FUSO DA PESSOA; sem este campo o
            // iPhone cai no padrão America/Sao_Paulo do servidor. Toda
            // rotação de token reatualiza — captura mudança de fuso em
            // viagem. O servidor valida contra a base IANA e ignora inválido.
            "timezone": TimeZone.current.identifier
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

    /// [2026-08-05] Toque em QUALQUER notificação leva à tela correspondente.
    ///
    /// Antes daqui só passava o push do feed (`action == "openFeed"`): os onze
    /// lembretes locais abriam o app na tela padrão. Ver o cabeçalho de
    /// `RotaDaNotificacao.swift` para o porquê de "às vezes leva" ser pior que
    /// "nunca leva".
    ///
    /// ESTE MÉTODO É O CAMINHO DOS DOIS CASOS DO iOS — app vivo e app fechado.
    /// Na partida fria ele dispara antes de existir qualquer view, e é por isso
    /// que o destino vai para um ESTADO guardado (`RoteadorDeNotificacao`) em
    /// vez de um evento: evento emitido aqui, com o app fechado, não teria
    /// ninguém escutando e sumiria em silêncio.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let identificador = response.notification.request.identifier

        if let destino = RotaDaNotificacao.destino(identificador: identificador,
                                                   userInfo: userInfo) {
            // `@Published` só pode ser tocado na fila principal — o delegate do
            // UNUserNotificationCenter não garante isso.
            DispatchQueue.main.async {
                RoteadorDeNotificacao.shared.rotear(destino)
            }
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

    /// Variante com resposta: o relógio espera saber a verdade — tocou,
    /// precisa do plano, ou dia inexistente (feedback honesto na tela).
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        if (message["action"] as? String) == "playMeditation",
           let day = message["day"] as? Int {
            DispatchQueue.main.async {
                let status = WatchBridge.shared.tocarMeditacao(dia: day)
                replyHandler(["status": status])
            }
        } else {
            handleWatchMessage(message)
            replyHandler(["status": "ok"])
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleWatchMessage(userInfo)
    }

    /// [2026-08-04 — Watch] Antes, este método postava .playMeditationFromWatch
    /// e NINGUÉM escutava — tocar no relógio não tocava nada (achado do
    /// diagnóstico). Agora tudo passa pelo WatchBridge: meditação toca DIRETO
    /// no engine (funciona em background, o app tem o modo audio), e os
    /// eventos do pulso (água, humor, treino, respiração) são aplicados com
    /// deduplicação por ID.
    private func handleWatchMessage(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            WatchBridge.shared.processarPayload(payload)
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
    /// [2026-08-05] Fonte única de aparência. Antes era `@AppStorage("isDarkMode")`,
    /// que a lua do Corpo não escrevia — ver o cabeçalho de AparenciaDoApp.swift.
    @ObservedObject private var aparencia = AparenciaDoApp.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                // [2026-08-04 — D-1] Se a exclusão de conta foi interrompida
                // entre a escrita irreversível no servidor e o fim da limpeza
                // local, a marca continua no disco e a limpeza é concluída
                // aqui. Sem isto, o servidor apagava a conta e o aparelho
                // ficava com peso, alergias, condições de saúde e humor.
                .task { LocalDataCleanupService.retomarLimpezaPendenteSeNecessario() }
                .preferredColorScheme(aparencia.colorScheme)
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
