// MoodSignal.swift
// Alma — humor como SINAL, nunca como registro
//
// [2026-08-02] O humor é dado sensível: a corregedoria do projeto manda que ele
// não saia do aparelho. Mas a Alma precisa perceber a tendência para acolher
// bem — sem isso, ela pergunta "como você está?" a quem registrou tristeza
// cinco dias seguidos.
//
// A solução é a mesma do desenho aprovado: o dado bruto FICA, o significado
// viaja. A pessoa marcou "Triste" quatro vezes esta semana? A Alma recebe
// "semana emocionalmente pesada" — nunca os rótulos, nunca as datas, nunca o
// que ela escreveu.
//
// ─────────────────────────────────────────────────────────────────────────────
// [2026-08-03 — CORREÇÃO DE BUG GRAVE, apontado na revisão independente (B2)]
//
// A primeira versão classificava por EMOJI ("😔", "😢", …). Só que o check-in
// do app grava PALAVRAS — "Ótimo", "Bem", "Normal", "Cansado", "Ansioso",
// "Triste" (InsightsView.swift). A interseção dos dois conjuntos é vazia:
// todo registro caía fora de "difícil" e fora de "leve", e a função devolvia
// "semana estável" para TODO MUNDO — inclusive para quem marcou "Triste" sete
// dias seguidos.
//
// Ou seja: o app estava afirmando à IA que uma pessoa em sofrimento estava
// estável. Desinformação ativa sobre saúde mental, exatamente o oposto do que
// este arquivo existe para fazer.
//
// Duas mudanças estruturais para que não volte:
//   1. A classificação passa a viver no MESMO tipo que a UI usa (`Mood`), então
//      acrescentar um humor novo na tela obriga a declarar a valência dele.
//   2. Quando nenhum registro é reconhecido, a função devolve `nil` — silêncio.
//      Antes ela afirmava estabilidade, que é uma afirmação sobre a saúde
//      mental de alguém feita sem base nenhuma.

import Foundation

// `Mood` e `MoodSignal.classificar` vivem em CorpoContextFormat.swift, que é
// uma camada pura (sem SwiftUI, sem UserDefaults, sem singletons). Isso é o que
// permite testá-los como executável standalone — e é justamente a ausência
// desse teste de ponta a ponta que deixou o bug B2 passar despercebido.

enum MoodSignal {

    /// Mínimo de check-ins para haver padrão. Abaixo disso, silêncio — um
    /// registro só não é tendência.
    static let minimoRegistros = CorpoContextFormat.minimoRegistrosHumor

    /// Sinal traduzido dos últimos 7 dias. `nil` quando não há base.
    @MainActor
    static func sinalDaSemana(agora: Date = Date()) -> String? {
        let historico = UserMemoryManager.shared.moodHistory
        let cal = Calendar.current
        guard let inicio = cal.date(byAdding: .day, value: -7, to: agora) else { return nil }

        let recentes = historico.filter { $0.date >= inicio }
        return classificar(rotulos: recentes.map(\.emoji))
    }

    static func classificar(rotulos: [String]) -> String? {
        CorpoContextFormat.classificarHumor(rotulos: rotulos)
    }
}
