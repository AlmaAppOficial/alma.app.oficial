// GradeDeLembretes.swift
// Alma — registro único de todos os lembretes do app
//
// [2026-08-02] Por que este arquivo existe:
//
// 1. BUG DA FUSÃO. O `NotificationManager` do Corpo chamava
//    `removeAllPendingNotificationRequests()` para reagendar os próprios
//    lembretes. Quando os apps eram separados isso era inofensivo. Depois da
//    fusão, passou a apagar TAMBÉM os lembretes da Alma (meditação, sequência,
//    marcos) — silenciosamente, sem erro nenhum. Quem mexesse num interruptor
//    de água perdia o lembrete de meditar. Aqui cada dono limpa só o que é seu.
//
// 2. VOLUME. Somadas, as categorias chegavam a 15 notificações por dia (7 de
//    água + 3 de refeição + treino + 3 do Alma). Um app que promete calma não
//    pode tocar de hora em hora. O Assis pediu para MANTER todas as categorias
//    — então a redução vem do espaçamento, não do corte: água passa de 7 para 4.
//
// 3. SUPLEMENTOS. A categoria nunca existiu, embora o app deixe cadastrar
//    suplementos e cobre a adesão. Agora existe.

import Foundation
import UserNotifications

enum DonoDoLembrete: String, CaseIterable {
    case corpo   // água, refeições, treino, suplementos
    case alma    // meditação, sequência, marcos

    /// Prefixos dos identificadores que pertencem a este dono. É o que permite
    /// limpar sem atropelar o outro lado.
    var prefixos: [String] {
        switch self {
        case .corpo: return ["water-", "meal-", "workout", "supplement-"]
        case .alma:  return ["daily_", "personalized_", "streak_", "milestone_"]
        }
    }
}

enum GradeDeLembretes {

    /// Horários de água. Eram 7 (9,11,13,15,17,19,21h). Quatro pontos cobrem o
    /// dia inteiro e mantêm a meta viável sem transformar o app em despertador.
    static let horariosAgua = [9, 13, 17, 20]

    /// Remove apenas os lembretes de um dono, preservando os do outro.
    static func limpar(_ dono: DonoDoLembrete) async {
        let centro = UNUserNotificationCenter.current()
        let pendentes = await centro.pendingNotificationRequests()
        let alvos = pendentes
            .map(\.identifier)
            .filter { id in dono.prefixos.contains { id.hasPrefix($0) } }
        guard !alvos.isEmpty else { return }
        centro.removePendingNotificationRequests(withIdentifiers: alvos)
    }

    /// Conta quantos lembretes por dia cada dono tem agendados — usado na tela
    /// de notificações para mostrar o total real, e não uma estimativa.
    static func totalDiario() async -> Int {
        let pendentes = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pendentes.filter { req in
            (req.trigger as? UNCalendarNotificationTrigger)?.repeats == true
        }.count
    }
}
