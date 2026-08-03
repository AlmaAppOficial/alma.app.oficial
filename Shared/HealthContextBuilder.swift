// HealthContextBuilder.swift
// Alma App — monta, NO APARELHO, o resumo de saúde que a IA recebe
//
// [Build 85 / 2.0 — 2026-07-31]
//
// Princípio: enviar SIGNIFICADO, não dado. A Alma não recebe séries de amostras
// nem valores clínicos — recebe um resumo curto e legível, do tipo:
//
//     [Contexto de hoje — 31/07, 10:20]
//     Movimento: 3.240 passos · 12 min de exercício
//     Sono: 6h20 na noite passada
//     Meditação: ainda não hoje · sequência de 4 dias
//
// Garantias desta camada:
//   1. Só entra o que o usuário autorizou (HealthContextConsent, por categoria).
//   2. Só entram campos com dado REAL — sem "—", sem zero inventado.
//   3. Teto de tamanho (maxCharacters): o contexto nunca vira um dump.
//   4. Nada de gravidez, gênero, vícios, ciclo, humor bruto ou localização.
//   5. Nada disso encosta em analytics/Meta/Crashlytics — proibido pelos termos
//      do HealthKit e pela corregedoria do projeto.
//
// Custo: ~60–90 tokens por mensagem (~US$0,00001 no gpt-4o-mini). Irrelevante
// perto do system prompt; o que importa aqui é privacidade, não custo.
//
// FUSÃO com o Corpo & Alma: as fontes são plugáveis. Quando treino/dieta
// existirem no mesmo app (ou via App Group), basta acrescentar uma linha em
// `build()` sob a categoria `.fitnessAndDiet` — nada mais muda.

import Foundation

struct HealthContextBuilder {

    /// Teto rígido do resumo. O servidor rejeita acima disso (defesa em profundidade).
    static let maxCharacters = 600

    private let health: HealthKitManager

    init(health: HealthKitManager) {
        self.health = health
    }

    /// Monta o contexto do dia. Retorna `nil` quando não há consentimento algum
    /// ou quando não há nenhum dado real — nesses casos nada é enviado e a Alma
    /// se comporta exatamente como nas versões anteriores.
    func build(now: Date = Date()) async -> String? {
        guard HealthContextConsent.hasAnyConsent else { return nil }

        var lines: [String] = []

        // ── Movimento e sono (HealthKit) ─────────────────────────────────────
        if HealthContextConsent.isGranted(.movementAndSleep) {
            var movement: [String] = []
            if let steps = await health.stepsToday() {
                movement.append("\(steps.formatted(.number.grouping(.automatic))) passos")
            }
            if let exercise = await health.exerciseMinutesToday() {
                movement.append("\(exercise) min de exercício")
            }
            if !movement.isEmpty {
                lines.append("Movimento: " + movement.joined(separator: " · "))
            }

            if let sleep = await health.lastNightSleepHours() {
                lines.append("Sono: \(Self.formatHours(sleep)) na noite passada")
            }
        }

        // ── Meditação e sequência (dados do próprio Alma + HealthKit) ────────
        if HealthContextConsent.isGranted(.meditation) {
            let meditatedToday = await MainActor.run { StreakManager.shared.isMeditationCompletedToday }
            let streak = await MainActor.run { StreakManager.shared.currentStreak }
            let mindful = await health.mindfulMinutesToday()

            // [2026-08-03] Esta era a única linha que violava a invariante do
            // arquivo ("campo sem dado não vira linha"): quem nunca meditou,
            // nunca abriu uma prática e não tem sequência recebia mesmo assim
            // "Meditação: ainda não meditou hoje". Além de gastar contexto, é
            // uma cobrança gratuita para quem acabou de instalar o app.
            //
            // Agora "ainda não meditou hoje" só é dito a quem TEM histórico —
            // aí a informação é real e útil ("você vem mantendo, hoje ainda
            // não"). Sem histórico nenhum, a linha simplesmente não existe.
            let totalHistorico = await MainActor.run { StreakManager.shared.totalMeditationDays }
            let temHistorico = streak > 0 || totalHistorico > 0

            var parts: [String] = []
            if let mindful, mindful > 0 {
                parts.append("\(mindful) min hoje")
            } else if meditatedToday {
                parts.append("já meditou hoje")
            } else if temHistorico {
                parts.append("ainda não meditou hoje")
            }
            if streak > 0 {
                parts.append("sequência de \(streak) \(streak == 1 ? "dia" : "dias")")
            }
            if !parts.isEmpty {
                lines.append("Meditação: " + parts.joined(separator: " · "))
            }
        }

        // ── Corpo: alimentação, água, treino, peso e suplementos ─────────────
        // [2026-08-02] A promessa central: a Alma passa a enxergar o usuário
        // inteiro, não só movimento e prática. Tudo derivado dos registros do
        // módulo Corpo, em resumo curto — nunca a lista de alimentos.
        if HealthContextConsent.isGranted(.fitnessAndDiet) {
            let corpo = await MainActor.run { CorpoContextSnapshot.atual() }

            if let alimentacao = corpo.linhaAlimentacao { lines.append(alimentacao) }
            if let agua = corpo.linhaAgua { lines.append(agua) }
            if let treino = corpo.linhaTreino { lines.append(treino) }
            if let peso = corpo.linhaPeso { lines.append(peso) }
            if let suplementos = corpo.linhaSuplementos { lines.append(suplementos) }
            if let perfil = corpo.linhaPerfil { lines.append(perfil) }
        }

        // ── Humor — SINAL traduzido, nunca o registro ────────────────────────
        // A pessoa escreveu "briguei com meu irmão"? A Alma recebe apenas
        // "semana emocionalmente pesada". O texto nunca sai do aparelho.
        if HealthContextConsent.isGranted(.mood) {
            if let sinal = await MainActor.run(body: { MoodSignal.sinalDaSemana() }) {
                lines.append("Humor: \(sinal)")
            }
        }

        // ── Ciclo menstrual — FORA por decisão de privacidade do projeto ─────
        // O gancho existe (HealthContextConsent.cycle, hoje sempre false).
        // Quando entrar, será como SINAL traduzido ("período de mais energia"),
        // nunca datas nem registros, e com consentimento próprio.

        guard !lines.isEmpty else { return nil }

        let header = "[Contexto de hoje — \(Self.formatTimestamp(now))]"
        return Self.montarComTeto(header: header, linhas: lines)
    }

    /// Ordem de prioridade quando o contexto não cabe nos 600 caracteres.
    ///
    /// [2026-08-03 — A16] O corte era `String(prefix(600))`: decepava o texto no
    /// meio da palavra e sacrificava sempre as ÚLTIMAS linhas montadas — que são
    /// justamente Perfil (alergias, limitações físicas) e Humor.
    ///
    /// Enquanto o Perfil nunca emitia (bug B3), isso era teórico. Depois que
    /// liguei os produtores, virou real: um perfil com restrição longa podia
    /// empurrar a alergia para fora, ou pior, entregá-la pela metade —
    /// "restrições alimentares: alergia a amend". Uma IA que lê isso pode
    /// concluir qualquer coisa.
    ///
    /// Agora o corte é por LINHA INTEIRA e por importância: o que protege a
    /// pessoa de dano fica; o que é conveniência sai primeiro.
    static func prioridade(_ linha: String) -> Int {
        if linha.hasPrefix("Perfil:") { return 0 }        // alergias e limitações
        if linha.hasPrefix("Humor:") { return 1 }         // sinal de sofrimento
        if linha.hasPrefix("Sono:") { return 2 }
        if linha.hasPrefix("Movimento:") { return 3 }
        if linha.hasPrefix("Alimentação") { return 4 }
        if linha.hasPrefix("Meditação:") { return 5 }
        if linha.hasPrefix("Treino:") { return 6 }
        if linha.hasPrefix("Peso:") { return 7 }
        if linha.hasPrefix("Água:") { return 8 }
        return 9                                          // suplementos e o resto
    }

    /// Monta respeitando o teto: descarta linhas inteiras, da menos importante
    /// para a mais, e nunca corta no meio de uma palavra.
    static func montarComTeto(header: String, linhas: [String]) -> String {
        var candidatas = linhas
        while true {
            let texto = ([header] + candidatas).joined(separator: "\n")
            if texto.count <= maxCharacters || candidatas.isEmpty { return texto }
            // Remove a de menor prioridade (maior número), a última em empate.
            if let alvo = candidatas.indices.max(by: {
                (prioridade(candidatas[$0]), $0) < (prioridade(candidatas[$1]), $1)
            }) {
                candidatas.remove(at: alvo)
            } else {
                return texto
            }
        }
    }

    // MARK: - Formatação

    /// 6.33 → "6h20". Arredonda para 5 minutos: precisão maior não ajuda a
    /// conversa e só aumenta a granularidade do dado que sai do aparelho.
    static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let rounded = (totalMinutes / 5) * 5
        let h = rounded / 60
        let m = rounded % 60
        return m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
    }

    static func formatTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM, HH:mm"
        return f.string(from: date)
    }
}
