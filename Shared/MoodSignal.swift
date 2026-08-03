// MoodSignal.swift
// Alma — humor como SINAL, nunca como registro
//
// [2026-08-02] O humor é dado sensível: a corregedoria do projeto manda que ele
// não saia do aparelho. Mas a Alma precisa perceber a tendência para acolher
// bem — sem isso, ela pergunta "como você está?" a quem registrou tristeza
// cinco dias seguidos.
//
// A solução é a mesma do desenho aprovado: o dado bruto FICA, o significado
// viaja. A pessoa registrou 😔 quatro vezes esta semana? A Alma recebe
// "semana emocionalmente pesada" — nunca os emojis, nunca as datas, nunca o
// que ela escreveu.

import Foundation

enum MoodSignal {

    /// Mínimo de check-ins para haver padrão. Abaixo disso, silêncio — um
    /// registro só não é tendência.
    static let minimoRegistros = CorpoContextFormat.minimoRegistrosHumor

    /// Emojis que o app usa no check-in, agrupados por valência.
    private static let dificeis: Set<String> = ["😔", "😢", "😰", "😡", "😴", "🥺", "😞"]
    private static let leves: Set<String> = ["😊", "😌", "🙂", "😄", "🥰", "✨"]

    /// Sinal traduzido dos últimos 7 dias. `nil` quando não há base.
    @MainActor
    static func sinalDaSemana(agora: Date = Date()) -> String? {
        let historico = UserMemoryManager.shared.moodHistory
        let cal = Calendar.current
        guard let inicio = cal.date(byAdding: .day, value: -7, to: agora) else { return nil }

        let recentes = historico.filter { $0.date >= inicio }

        // A tradução em si mora no CorpoContextFormat, onde é testável sem
        // depender de UserMemoryManager nem de SwiftUI.
        return CorpoContextFormat.sinalDeHumor(
            dificeis: recentes.filter { dificeis.contains($0.emoji) }.count,
            leves: recentes.filter { leves.contains($0.emoji) }.count,
            total: recentes.count
        )
    }
}
