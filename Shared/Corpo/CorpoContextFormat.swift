// CorpoContextFormat.swift
// Alma — Corpo · como um número vira frase para a IA
//
// [2026-08-02] Separado do CorpoContextSnapshot de propósito: aqui não há
// AppModel, SwiftUI nem UserDefaults — só valores entrando e texto saindo.
//
// Duas razões:
//   • testabilidade real. O projeto não tem target de unit-test (só bundles de
//     UI-test desatualizados), então a suíte roda como executável standalone via
//     swiftc. Isso só é possível com código sem dependência de framework.
//   • a regra "não invente dado" fica num lugar só: toda função devolve `nil`
//     quando não há registro, em vez de devolver zero ou "—".

import Foundation

/// Os humores que o check-in oferece. A tela (`InsightsView`) e o classificador
/// leem a MESMA lista: é impossível acrescentar um humor na interface sem
/// declarar aqui se ele é pesado, leve ou neutro. Foi a falta dessa amarração
/// que permitiu a tela gravar "Triste" enquanto o classificador procurava "😢".
enum Mood: String, CaseIterable, Identifiable {
    case otimo   = "Ótimo"
    case bem     = "Bem"
    case normal  = "Normal"
    case cansado = "Cansado"
    case ansioso = "Ansioso"
    case triste  = "Triste"

    var id: String { rawValue }

    enum Valencia { case leve, neutra, dificil }

    var valencia: Valencia {
        switch self {
        case .otimo, .bem:                return .leve
        case .normal:                     return .neutra
        case .cansado, .ansioso, .triste: return .dificil
        }
    }

    var icone: String {
        switch self {
        case .otimo:   return "sun.max.fill"
        case .bem:     return "leaf.fill"
        case .normal:  return "cloud.fill"
        case .cansado: return "moon.zzz.fill"
        case .ansioso: return "bolt.heart.fill"
        case .triste:  return "drop.fill"
        }
    }
}

enum CorpoContextFormat {

    // MARK: - Números em português

    /// 79.5 → "79,5"  ·  1.0 → "1,0"
    static func decimal(_ valor: Double, casas: Int = 1) -> String {
        String(format: "%.\(casas)f", valor).replacingOccurrences(of: ".", with: ",")
    }

    static func plural(_ n: Int, _ singular: String, _ plural: String) -> String {
        n == 1 ? singular : plural
    }

    /// Inteiro com separador de milhar do PT-BR: 7432 → "7.432".
    ///
    /// [2026-08-04] Achado no primeiro dump completo dos 12 dados: a linha de
    /// passos usava `.formatted(.number.grouping(.automatic))`, que segue o
    /// locale do APARELHO. Num aparelho fora do pt-BR saía "7 432" (espaço
    /// estreito) ou "7,432" — e a regra do projeto é PT-BR sempre, inclusive
    /// no texto que a IA lê e repete de volta para a pessoa.
    static func inteiro(_ valor: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: valor)) ?? "\(valor)"
    }

    // MARK: - Linhas

    static func alimentacao(kcal: Int, refeicoesFeitas: Int, meta: Int?, proteina: Int) -> String? {
        guard refeicoesFeitas > 0 else { return nil }

        // [2026-08-04] Achado no primeiro dump completo dos 12 dados: marcar a
        // refeição como feita SEM registrar alimento produzia
        // "0 kcal em 1 refeição · 0% da meta · 0 g de proteína" — três zeros
        // apresentados como medição, exatamente o dado fingido que a
        // corregedoria proíbe. Uma IA que lê isso pode concluir que a pessoa
        // passou o dia em jejum.
        //
        // O gesto é real e continua contando; os números não existem e por isso
        // não são afirmados.
        guard kcal > 0 || proteina > 0 else {
            let n = "\(refeicoesFeitas) \(plural(refeicoesFeitas, "refeição", "refeições"))"
            let marcada = plural(refeicoesFeitas, "marcada", "marcadas")
            return "Alimentação hoje: \(n) \(marcada), sem alimentos registrados"
        }

        var partes = ["\(kcal) kcal em \(refeicoesFeitas) \(plural(refeicoesFeitas, "refeição", "refeições"))"]
        if let meta, meta > 0 {
            partes.append("\(Int((Double(kcal) / Double(meta) * 100).rounded()))% da meta")
        }
        partes.append("\(proteina) g de proteína")
        return "Alimentação hoje: " + partes.joined(separator: " · ")
    }

    static func agua(ml: Int, metaMl: Int) -> String? {
        guard ml > 0 else { return nil }
        let litros = decimal(Double(ml) / 1000)
        guard metaMl > 0 else { return "Água: \(litros) L hoje" }
        let pct = Int((Double(ml) / Double(metaMl) * 100).rounded())
        return "Água: \(litros) L hoje (\(pct)% da meta)"
    }

    static func treino(treinouHoje: Bool, vezesNaSemana: Int) -> String? {
        guard treinouHoje || vezesNaSemana > 0 else { return nil }
        let frequencia = "\(vezesNaSemana) \(plural(vezesNaSemana, "vez", "vezes")) nos últimos 7 dias"
        return treinouHoje
            ? "Treino: já treinou hoje · \(frequencia)"
            : "Treino: ainda não treinou hoje · \(frequencia)"
    }

    /// `variacao` é nil quando não há histórico suficiente para uma tendência.
    static func peso(atual: Double, variacao: Double?) -> String? {
        guard atual > 0 else { return nil }
        var linha = "Peso: \(decimal(atual)) kg"
        if let variacao, abs(variacao) >= 0.1 {
            let sinal = variacao > 0 ? "+" : ""
            linha += " (\(sinal)\(decimal(variacao)) kg desde o primeiro registro)"
        }
        return linha
    }

    static func suplementos(tomadosHoje: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        return tomadosHoje == 0
            ? "Suplementos: nenhum dos \(total) tomado hoje"
            : "Suplementos: \(tomadosHoje) de \(total) tomados hoje"
    }

    /// O objetivo sozinho não vale uma linha — todo mundo tem um. O que muda a
    /// conduta da Alma são as restrições e limitações.
    /// Teto por campo de texto livre. [A16] Sem isto, uma restrição de 500
    /// caracteres sozinha estoura o contexto inteiro e empurra as outras linhas
    /// para fora. Corta em espaço, nunca no meio da palavra.
    static let maxCaracteresPorCampo = 120

    static func limitar(_ texto: String, _ maximo: Int = maxCaracteresPorCampo) -> String {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limpo.count > maximo else { return limpo }
        let corte = limpo.prefix(maximo)
        // Volta até o último espaço para não entregar palavra pela metade.
        if let ultimoEspaco = corte.lastIndex(of: " ") {
            return String(corte[..<ultimoEspaco]) + "…"
        }
        return String(corte) + "…"
    }

    static func perfil(objetivo: String, restricoes: String, condicoes: String) -> String? {
        var partes = ["objetivo \(objetivo.lowercased())"]

        let r = limitar(restricoes)
        if !r.isEmpty { partes.append("restrições alimentares: \(r)") }

        let c = limitar(condicoes)
        if !c.isEmpty { partes.append("limitações: \(c)") }

        return partes.count > 1 ? "Perfil: " + partes.joined(separator: " · ") : nil
    }

    // MARK: - Humor

    static let minimoRegistrosHumor = 3

    /// Traduz os rótulos REAIS do check-in em um sinal.
    ///
    /// [2026-08-03 — B2] Mora aqui, e não junto da leitura do histórico, por um
    /// motivo específico: assim é testável de ponta a ponta sem SwiftUI nem
    /// singletons. A versão anterior classificava por emoji enquanto a tela
    /// gravava palavras — a interseção era vazia e TODO usuário recebia
    /// "semana estável", inclusive quem marcou "Triste" sete dias seguidos.
    /// Os testes não pegaram porque exercitavam contagens injetadas, nunca os
    /// rótulos que o app grava.
    static func classificarHumor(rotulos: [String]) -> String? {
        // Rótulo desconhecido (versão antiga, dado corrompido) fica de fora da
        // conta em vez de virar "neutro" silencioso.
        let reconhecidos = rotulos.compactMap { Mood(rawValue: $0) }
        guard reconhecidos.count >= minimoRegistrosHumor else { return nil }

        return sinalDeHumor(
            dificeis: reconhecidos.filter { $0.valencia == .dificil }.count,
            leves:    reconhecidos.filter { $0.valencia == .leve }.count,
            total:    reconhecidos.count
        )
    }

    /// Traduz proporções em uma frase. Nunca recebe nem devolve emoji, data ou
    /// contagem — só o significado.
    static func sinalDeHumor(dificeis: Int, leves: Int, total: Int) -> String? {
        guard total >= minimoRegistrosHumor else { return nil }
        if Double(dificeis) / Double(total) >= 0.6 { return "semana emocionalmente pesada" }
        if Double(leves) / Double(total) >= 0.6 { return "semana leve, bom momento" }
        if dificeis > 0 && leves > 0 { return "semana oscilante" }
        return "semana estável"
    }
}
