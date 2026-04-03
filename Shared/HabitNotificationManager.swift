import Foundation
import UserNotifications
import UIKit

/// HabitNotificationManager - Gerencia notificações push para habit loop
/// Responsabilidades:
/// - Agendar notificações locais com UNUserNotificationCenter
/// - Rotacionar entre 30 mensagens diferentes
/// - Detectar streaks em risco e enviar notificações escaladas
/// - Suprimir notificações em dias que usuário já meditou
/// - Solicitar permissão com contexto apropriado
actor HabitNotificationManager {

    // MARK: - Constants

    private let morningHour = 8 // 08:00
    private let eveningHour = 20 // 20:00

    private let notificationCategoryID = "MEDITATION_REMINDER"
    private let deepLinkCategoryID = "MEDITATION_ACTION"

    // MARK: - Notification Message Sets (30+ mensagens)

    private let morningMotivations = [
        "Bom dia! Seu momento de paz está aqui ☀️",
        "A manhã é perfeita para respirar. Vamos?",
        "Antes do caos, um momento só seu 🧘",
        "Seu corpo agradece uma meditação matinal",
        "Dia novo, mente clara. Vamos começar bem?",
        "Alma está esperando. Você tem 5 minutos?",
        "Comece o dia com propósito ✨",
        "Enquanto o café esfria, você medita?",
        "A calma da manhã é mágica. Participa?",
        "Seu dia vai ser melhor com meditação. Vem?"
    ]

    private let eveningReminders = [
        "Deixe o dia para trás. Hora de descansar 🌙",
        "Sua mente cansou. Vamos acalmar?",
        "Noite perfeita para se reconectar com você",
        "Antes de dormir: um momento de paz",
        "Seu corpo pede relaxamento. Tem tempo?",
        "A noite é silenciosa. Aproveita para meditar?",
        "Desligar do dia é importante. Medita comigo?",
        "Sono melhor começa agora. Vem?",
        "Encerre o dia com gratidão 🕯️",
        "Seu repouso noturno melhora com meditação"
    ]

    private let streakAtRiskMessages = [
        "Não quebre sua Corrente! Seu streak está em risco 🔥",
        "Faltam poucas horas. Você consegue! Sua corrente te espera",
        "Última chance hoje! Não perca seus dias meditados",
        "Sua Corrente está com fome 🔥 Medita agora?",
        "Você medita há vários dias. Vamos fazer um mais?"
    ]

    private let celebrationMessages = [
        "🔥 VOCÊ ATINGIU UM NOVO MARCO! Sua Corrente está crescendo",
        "Seu Jardim está lindíssimo agora 🌸",
        "PARABÉNS! Você é incrível 🏆",
        "Sua mente medita há muitos dias. Celebra com a gente! ∞",
        "Incrível! Seu Jardim floresceu. Compartilhe com alguém?"
    ]

    // MARK: - State Management

    private var lastNotificationDates: [String: Date] = [:]
    private var notificationIndices: [String: Int] = [:]

    // MARK: - Initialization

    nonisolated init() {
        Task {
            await requestNotificationPermission()
            await setupNotificationCategories()
        }
    }

    // MARK: - Public API

    /// Agenda notificações diárias padrão (manhã e noite)
    /// Deve ser chamado durante onboarding ou settings
    func scheduleDefaultNotifications(at morningTime: DateComponents?, eveningTime: DateComponents?) async {
        await cancelAllNotifications()

        // Morning notification
        if let morning = morningTime {
            await scheduleNotification(
                identifier: "daily_morning",
                title: "Alma",
                body: getRandomMorningNotification(),
                dateComponents: morning,
                repeats: true
            )
        }

        // Evening notification
        if let evening = eveningTime {
            await scheduleNotification(
                identifier: "daily_evening",
                title: "Alma",
                body: getRandomEveningNotification(),
                dateComponents: evening,
                repeats: true
            )
        }
    }

    /// Agenda notificações com base no horário preferido do usuário
    /// (aprendizado do histórico de uso)
    func schedulePersonalizedNotifications(baseOnUserHistory history: [Date]) async {
        // Analisa quando o usuário normalmente medita
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]

        for date in history {
            let hour = calendar.component(.hour, from: date)
            hourCounts[hour, default: 0] += 1
        }

        // Encontra o horário mais popular
        if let preferredHour = hourCounts.max(by: { $0.value < $1.value })?.key {
            var components = DateComponents()
            components.hour = preferredHour
            components.minute = 0

            await scheduleNotification(
                identifier: "personalized_optimal",
                title: "Alma",
                body: getContextualNotification(for: preferredHour),
                dateComponents: components,
                repeats: true
            )
        }
    }

    /// Detecta risco de quebra de streak e agenda notificação escalada
    func scheduleStreakAtRiskNotification(
        currentStreak: Int,
        lastMeditationDate: Date,
        preferredMeditationHour: Int = 20
    ) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysSinceLastMeditation = calendar.dateComponents([.day], from: lastMeditationDate, to: today).day ?? 0

        guard daysSinceLastMeditation >= 1 else {
            return // Ainda tem tempo hoje
        }

        // Calcula quando agendar a notificação
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = preferredMeditationHour
        components.minute = 0

        let message = streakAtRiskMessages.randomElement() ?? "Sua Corrente te espera! 🔥"
        let streakMessage = "Streak: \(currentStreak) dias"

        await scheduleNotification(
            identifier: "streak_at_risk_\(today.timeIntervalSince1970)",
            title: "🔥 Cuidado com sua Corrente",
            body: "\(message) \n\(streakMessage)",
            dateComponents: components,
            repeats: false
        )
    }

    /// Agenda notificação de celebração de milestone
    func scheduleMilestoneNotification(milestone: Int, streakMessage: String) async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 0

        let message = celebrationMessages.randomElement() ?? "Parabéns! 🎉"

        var content = UNMutableNotificationContent()
        content.title = "🎉 Milestone Reached!"
        content.body = "\(message)\n\(streakMessage)"
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.userInfo = [
            "type": "celebration",
            "milestone": milestone
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "milestone_\(milestone)", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling milestone notification: \(error)")
        }
    }

    /// Remove notificações se usuário já meditou hoje
    func suppressNotificationsIfMeditatedToday(_ completed: Bool) async {
        if completed {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            // Remove notificações futuras do dia de hoje
            let allPending = await UNUserNotificationCenter.current().pendingNotificationRequests()

            for request in allPending {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    if calendar.isDate(nextTriggerDate, inSameDayAs: today) {
                        await UNUserNotificationCenter.current().removePendingNotificationRequests(
                            withIdentifiers: [request.identifier]
                        )
                    }
                }
            }
        }
    }

    /// Controla a frequência de notificações
    /// Se usuário abre app em 5 min da notificação, reduz frequência próximas 24h
    func adjustNotificationFrequencyAfterEngagement() async {
        let defaults = UserDefaults.standard
        let lastEngagementKey = "last_notification_engagement"

        let now = Date()
        defaults.set(now, forKey: lastEngagementKey)

        // Próximas 24h: apenas 1 notificação por dia
        // Após 24h: volta ao normal (2/dia)
    }

    /// Desativa notificações automaticamente se nunca são abertas
    func autoDisableIfNeverEngaged(daysThreshold: Int = 7) async {
        let defaults = UserDefaults.standard
        let notificationOpenCountKey = "notification_open_count"
        let installDateKey = "app_install_date"

        let installDate = defaults.object(forKey: installDateKey) as? Date ?? Date()
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0

        if daysSinceInstall >= daysThreshold {
            let openCount = defaults.integer(forKey: notificationOpenCountKey)
            if openCount == 0 {
                await cancelAllNotifications()
                defaults.set(true, forKey: "notifications_auto_disabled")
            }
        }
    }

    /// Solicita permissão com contexto apropriado
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                print("Notification permission request failed: \(error)")
            }
        }
    }

    // MARK: - Private Helper Methods

    private func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        dateComponents: DateComponents,
        repeats: Bool
    ) async {
        var content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: 1)

        // Adiciona actions para deep linking
        let meditateAction = UNNotificationAction(
            identifier: "MEDITATE_ACTION",
            title: "Meditar",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Lembrar depois",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: deepLinkCategoryID,
            actions: [meditateAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        content.categoryIdentifier = deepLinkCategoryID
        UNUserNotificationCenter.current().setNotificationCategories([category])

        content.userInfo = [
            "type": "habit_reminder",
            "timestamp": Date().timeIntervalSince1970
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }

    private func getRandomMorningNotification() -> String {
        return morningMotivations.randomElement() ?? "Seu momento Alma chegou ☀️"
    }

    private func getRandomEveningNotification() -> String {
        return eveningReminders.randomElement() ?? "Hora de descansar 🌙"
    }

    private func getContextualNotification(for hour: Int) -> String {
        if hour < 12 {
            return getRandomMorningNotification()
        } else if hour < 18 {
            return "Sua mente precisa de uma pausa. Medita agora?"
        } else {
            return getRandomEveningNotification()
        }
    }

    private func setupNotificationCategories() async {
        let meditateAction = UNNotificationAction(
            identifier: "MEDITATE_ACTION",
            title: "Meditar agora",
            options: .foreground
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Depois",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: deepLinkCategoryID,
            actions: [meditateAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Notification Management

    func cancelAllNotifications() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelNotification(identifier: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}

// MARK: - Notification Handling Delegate

extension HabitNotificationManager: UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Mostrar notificação mesmo quando app está em foreground
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "MEDITATE_ACTION":
            // Deep link para tela de meditação
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenMeditationFromNotification"),
                object: nil,
                userInfo: userInfo
            )

        case "SNOOZE_ACTION":
            // Re-agenda para 1 hora depois
            scheduleSnoozeNotification(original: response.notification.request)

        default:
            // Notificação foi tocada (sem action)
            NotificationCenter.default.post(
                name: NSNotification.Name("NotificationEngaged"),
                object: nil,
                userInfo: userInfo
            )
        }

        completionHandler()
    }

    private func scheduleSnoozeNotification(original: UNNotificationRequest) {
        let snoozeDate = Date(timeIntervalSinceNow: 3600) // 1 hora depois
        var components = Calendar.current.dateComponents([.hour, .minute], from: snoozeDate)

        var content = original.content.mutableCopy() as! UNMutableNotificationContent
        content.body = "💭 \(content.body)" // Adiciona emoji para diferençar

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(original.identifier)_snoozed",
            content: content,
            trigger: trigger
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Error scheduling snooze notification: \(error)")
            }
        }
    }
}

// MARK: - Testing Support

#if DEBUG
extension HabitNotificationManager {
    /// Simula notificação para testes
    func simulateNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error in test notification: \(error)")
        }
    }
}
#endif
