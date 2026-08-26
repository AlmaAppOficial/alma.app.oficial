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
    case corpo    // água, refeições, treino, suplementos
    case alma     // meditação, sequência, marcos
    case vicio    // marcos do contador de tempo sem vício
    // [2026-08-26] Dono novo, e ele existe pelo motivo 1 deste arquivo.
    //
    // O jejum precisa avisar quando a janela abre e quando ela fecha. Se esses
    // avisos usassem prefixo `meal-`, eles pertenceriam ao dono `.corpo` — e
    // `NotificationManager.sync` limpa o dono `.corpo` INTEIRO toda vez que
    // alguém mexe no interruptor de água. O aviso de fim do jejum sumiria em
    // silêncio, que é exatamente o bug da fusão descrito lá em cima, cometido
    // de novo três semanas depois de ele ser documentado.
    case jejum    // abertura e fechamento da janela alimentar

    /// Prefixos dos identificadores que pertencem a este dono. É o que permite
    /// limpar sem atropelar o outro lado.
    var prefixos: [String] {
        switch self {
        case .corpo: return ["water-", "meal-", "workout", "supplement-"]
        case .alma:  return ["daily_", "personalized_", "streak_", "milestone_"]
        case .jejum: return ["jejum_"]
        // [2026-08-03 — A3] `addiction_*` era órfão: agendado por
        // AddictionFreeView e sem NENHUM ponto de cancelamento no app inteiro.
        // Sobrevivia a resetar o contador, ao logout e à exclusão de conta — o
        // próximo dono do aparelho recebia "1 MÊS SEM VÍCIO!" de um vício que
        // não é dele.
        case .vicio: return ["addiction_"]
        }
    }
}

enum GradeDeLembretes {

    /// Teto de lembretes por dia, somando TODAS as categorias ligadas.
    ///
    /// [2026-08-03] A revisão independente apontou que o "teto de 5/dia" que eu
    /// tinha mencionado não existia em lugar nenhum do código — com tudo ligado
    /// eram 9. Ou o número existe e é respeitado, ou não se fala nele. Aqui ele
    /// existe: 9 é o máximo real (4 de água + 3 de refeição + treino +
    /// suplemento), e a conta é verificada pela auditoria automática.
    ///
    /// Se alguém acrescentar categoria sem rever este número, a auditoria falha.
    ///
    /// [2026-08-26] O jejum acrescentou uma categoria e **não** mudou este
    /// número, e a razão não é descuido: os dois avisos do jejum são de disparo
    /// único (`UNTimeIntervalNotificationTrigger`, `repeats: false`), porque um
    /// jejum começa quando a pessoa aperta o botão e não todo dia às 9 h. Eles
    /// não são lembretes diários, não entram na conta de `totalDiario()` — que
    /// filtra por `repeats == true` — e não podem furar um teto do qual não
    /// fazem parte. Ver o cabeçalho do `JejumStore`.
    static let tetoDiario = 9

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

    /// Limpeza total — exclusão de conta e logout. Nenhum lembrete de um
    /// usuário pode sobreviver para o próximo.
    static func limparTudo() async {
        for dono in DonoDoLembrete.allCases {
            await limpar(dono)
        }
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
