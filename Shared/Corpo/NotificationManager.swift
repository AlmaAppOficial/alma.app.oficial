//
//  NotificationManager.swift
//  Corpo & Alma
//
//  Lembretes locais (água, refeições, treino). Notificações locais não exigem
//  capability Push — só a permissão do usuário.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Reagenda todos os lembretes conforme as preferências.
    func sync(water: Bool, meals: Bool, workout: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        if water {
            for hour in stride(from: 9, through: 21, by: 2) {
                schedule(id: "water-\(hour)",
                         title: "Hora de se hidratar 💧",
                         body: "Beba um copo de água e siga firme na meta do dia.",
                         hour: hour, minute: 0)
            }
        }
        if meals {
            schedule(id: "meal-breakfast", title: "Café da manhã 🍳", body: "Registre sua primeira refeição.", hour: 8, minute: 0)
            schedule(id: "meal-lunch", title: "Almoço 🥗", body: "Não esqueça de registrar o almoço.", hour: 12, minute: 30)
            schedule(id: "meal-dinner", title: "Jantar 🍽️", body: "Registre o jantar e feche o dia.", hour: 20, minute: 0)
        }
        if workout {
            schedule(id: "workout", title: "Bora treinar 💪", body: "Constância é tudo. Que tal o treino de hoje?", hour: 18, minute: 0)
        }
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
