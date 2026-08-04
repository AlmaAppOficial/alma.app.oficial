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

    /// Reagenda os lembretes do Corpo conforme as preferências.
    ///
    /// [2026-08-02 — bug da fusão] Aqui havia
    /// `center.removeAllPendingNotificationRequests()`. Isso apagava também os
    /// lembretes da Alma (meditação, sequência, marcos): mexer no interruptor
    /// de água calava a meditação, sem erro nenhum. Agora a limpeza é só do que
    /// pertence ao Corpo — ver `GradeDeLembretes`.
    func sync(water: Bool, meals: Bool, workout: Bool, supplements: Bool = false, supplementHour: Int = 9) {
        Task {
            await GradeDeLembretes.limpar(.corpo)

            if water {
                // Eram 7 avisos (de 2 em 2 horas). Passaram a 4: cobre o dia sem
                // virar despertador. A meta de 2,5 L continua a mesma.
                for hour in GradeDeLembretes.horariosAgua {
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
            // [2026-08-02] Categoria nova. O app já deixava cadastrar
            // suplementos e cobrava a adesão, mas nunca lembrava de tomar.
            if supplements {
                schedule(id: "supplement-daily",
                         title: "Seus suplementos 💊",
                         body: "Hora de tomar o que você programou para hoje.",
                         hour: supplementHour, minute: 0)
            }
        }
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // [2026-08-04 — Watch] Mesma categoria dos lembretes da Alma: no
        // relógio, a notificação aparece com a interface da marca.
        content.categoryIdentifier = "ALMA_LEMBRETE"

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
