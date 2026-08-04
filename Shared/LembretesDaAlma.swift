// LembretesDaAlma.swift
// Alma — os lembretes de meditação que o app não tinha
//
// [2026-08-03 — A1 da revisão independente]
//
// Descoberta desconfortável: o Alma é um app de meditação e **não lembrava de
// meditar**. Existe um `HabitNotificationManager.swift` no disco com toda a
// lógica — manhã, noite, horário personalizado, sequência em risco, marcos —
// mas o arquivo NÃO está no project.pbxproj. Nunca foi compilado, nunca foi
// instanciado, nunca agendou nada. A tela de Perfil pedia permissão de
// notificação e não agendava coisa alguma depois.
//
// Por que não registrei aquele arquivo: são ~500 linhas que nunca passaram pelo
// compilador, na véspera de uma reauditoria. Registrar tudo seria trocar um
// problema conhecido por um risco desconhecido. Aqui fica o mínimo que cumpre a
// promessa — dois lembretes diários, ligáveis e desligáveis — dentro dos
// prefixos que a `GradeDeLembretes` já sabe limpar sem atropelar o Corpo.

import Foundation
import UserNotifications

enum LembretesDaAlma {

    /// Chave de preferência: a pessoa ligou os lembretes de meditação?
    static let chavePreferencia = "alma_lembretes_meditacao"

    static var ligados: Bool {
        get { UserDefaults.standard.bool(forKey: chavePreferencia) }
        set { UserDefaults.standard.set(newValue, forKey: chavePreferencia) }
    }

    private static let manha = 8
    private static let noite = 20

    /// Frases diferentes por horário. Nada de "não quebre sua sequência!": a
    /// notificação de um app de bem-estar não pode ser mais uma fonte de
    /// cobrança na vida de quem já está sobrecarregado.
    private static let textoManha = [
        "Um minuto de silêncio antes do dia começar.",
        "Que tal começar o dia respirando?",
        "Sua mente agradece cinco minutos agora."
    ]

    private static let textoNoite = [
        "Hora de desacelerar. Vamos respirar juntos?",
        "O dia foi longo. Cinco minutos para você.",
        "Feche o dia com um momento de calma."
    ]

    /// Liga os dois lembretes. Idempotente: reagendar substitui os anteriores.
    static func ligar() async {
        await GradeDeLembretes.limpar(.alma)

        agendar(id: "daily_morning", hora: manha, corpo: textoManha.randomElement() ?? textoManha[0])
        agendar(id: "daily_evening", hora: noite, corpo: textoNoite.randomElement() ?? textoNoite[0])

        ligados = true
    }

    static func desligar() async {
        await GradeDeLembretes.limpar(.alma)
        ligados = false
    }

    private static func agendar(id: String, hora: Int, corpo: String) {
        let content = UNMutableNotificationContent()
        content.title = "Alma"
        content.body = corpo
        content.sound = .default
        // [2026-08-04 — Watch] Espelhado no relógio, este lembrete ganha a
        // interface do Alma (NotificationController do target AlmaWatch).
        content.categoryIdentifier = "ALMA_LEMBRETE"

        var quando = DateComponents()
        quando.hour = hora
        quando.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: quando, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }
}
