// ContextoIATests.swift
// Alma — prova de que a IA enxerga o usuário inteiro
//
// [2026-08-02] A auditoria de promessa mostrou que a Alma via 4 de 12 fontes:
// sabia do sono e dos passos, mas não sabia "se você comeu, bebeu água, treinou
// ou quanto pesa". Cada teste aqui falha se uma dessas fontes parar de chegar.
//
// O projeto não tem target de unit-test (os bundles "Tests iOS/macOS" são de
// UI-test e estão desatualizados), então esta suíte roda como executável
// standalone, igual à do CycleCalculator:
//
//   swiftc -parse-as-library Shared/Corpo/CorpoContextFormat.swift \
//          ios/AlmaTests/ContextoIATests.swift -o /tmp/contexto_tests
//   /tmp/contexto_tests          # exit 0 = tudo passou

import Foundation

@main
struct ContextoIATests {

    static var falhas = 0
    static var total = 0

    static func check(_ condicao: Bool, _ nome: String, _ detalhe: String = "") {
        total += 1
        if condicao {
            print("  ok   \(nome)")
        } else {
            falhas += 1
            print("  FALHA \(nome)\(detalhe.isEmpty ? "" : " → \(detalhe)")")
        }
    }

    static func igual(_ a: String?, _ b: String?, _ nome: String) {
        check(a == b, nome, "esperado \(b ?? "nil"), veio \(a ?? "nil")")
    }

    static func main() {
        print("\n── Alimentação ──")
        testAlimentacao()
        print("\n── Água ──")
        testAgua()
        print("\n── Treino ──")
        testTreino()
        print("\n── Peso ──")
        testPeso()
        print("\n── Suplementos ──")
        testSuplementos()
        print("\n── Perfil (restrições e limitações) ──")
        testPerfil()
        print("\n── Humor (sinal traduzido) ──")
        testHumor()
        print("\n── Humor: pipeline real do check-in ──")
        testHumorPipelineReal()

        print("\n\(total - falhas)/\(total) passaram.")
        if falhas > 0 {
            print("\(falhas) FALHA(S).")
            exit(1)
        }
    }

    // MARK: - Alimentação

    static func testAlimentacao() {
        igual(CorpoContextFormat.alimentacao(kcal: 0, refeicoesFeitas: 0, meta: 2000, proteina: 0),
              nil,
              "sem refeição marcada, não existe linha")

        igual(CorpoContextFormat.alimentacao(kcal: 1100, refeicoesFeitas: 2, meta: 2000, proteina: 65),
              "Alimentação hoje: 1100 kcal em 2 refeições · 55% da meta · 65 g de proteína",
              "resumo completo")

        igual(CorpoContextFormat.alimentacao(kcal: 400, refeicoesFeitas: 1, meta: nil, proteina: 20),
              "Alimentação hoje: 400 kcal em 1 refeição · 20 g de proteína",
              "sem meta (perfil incompleto) a linha sai sem porcentagem")

        check(CorpoContextFormat.alimentacao(kcal: 400, refeicoesFeitas: 1, meta: 0, proteina: 20)?
                .contains("%") == false,
              "meta zero não vira divisão por zero")
    }

    // MARK: - Água

    static func testAgua() {
        igual(CorpoContextFormat.agua(ml: 0, metaMl: 2500), nil, "zero não é registro")
        igual(CorpoContextFormat.agua(ml: 1500, metaMl: 2500),
              "Água: 1,5 L hoje (60% da meta)",
              "decimal em português, com vírgula")
        check(CorpoContextFormat.agua(ml: 500, metaMl: 0) != nil,
              "meta ausente não apaga o registro de água")
    }

    // MARK: - Treino

    static func testTreino() {
        igual(CorpoContextFormat.treino(treinouHoje: false, vezesNaSemana: 0),
              nil,
              "quem nunca treinou não recebe linha de treino")

        igual(CorpoContextFormat.treino(treinouHoje: true, vezesNaSemana: 2),
              "Treino: já treinou hoje · 2 vezes nos últimos 7 dias",
              "treinou hoje")

        igual(CorpoContextFormat.treino(treinouHoje: false, vezesNaSemana: 1),
              "Treino: ainda não treinou hoje · 1 vez nos últimos 7 dias",
              "singular correto em 'vez'")
    }

    // MARK: - Peso

    static func testPeso() {
        igual(CorpoContextFormat.peso(atual: 0, variacao: nil), nil, "peso zero não é peso")

        igual(CorpoContextFormat.peso(atual: 79.5, variacao: nil),
              "Peso: 79,5 kg",
              "sem histórico, só o valor")

        igual(CorpoContextFormat.peso(atual: 79.5, variacao: -2.5),
              "Peso: 79,5 kg (-2,5 kg desde o primeiro registro)",
              "perda de peso mostra a direção")

        igual(CorpoContextFormat.peso(atual: 82.0, variacao: 1.3),
              "Peso: 82,0 kg (+1,3 kg desde o primeiro registro)",
              "ganho leva o sinal +")

        check(CorpoContextFormat.peso(atual: 80.0, variacao: 0.05)?.contains("(") == false,
              "variação irrelevante (50 g) não vira ruído")
    }

    // MARK: - Suplementos

    static func testSuplementos() {
        igual(CorpoContextFormat.suplementos(tomadosHoje: 0, total: 0),
              nil,
              "quem não cadastrou suplemento não ouve falar de suplemento")

        igual(CorpoContextFormat.suplementos(tomadosHoje: 0, total: 3),
              "Suplementos: nenhum dos 3 tomado hoje",
              "cadastrou mas não tomou")

        igual(CorpoContextFormat.suplementos(tomadosHoje: 2, total: 3),
              "Suplementos: 2 de 3 tomados hoje",
              "adesão parcial")
    }

    // MARK: - Perfil

    static func testPerfil() {
        igual(CorpoContextFormat.perfil(objetivo: "Manter", restricoes: "", condicoes: ""),
              nil,
              "só o objetivo não justifica ocupar o contexto")

        igual(CorpoContextFormat.perfil(objetivo: "Emagrecer", restricoes: "alergia a amendoim", condicoes: ""),
              "Perfil: objetivo emagrecer · restrições alimentares: alergia a amendoim",
              "restrição alimentar precisa chegar — sugerir amendoim a quem tem alergia é dano real")

        let completo = CorpoContextFormat.perfil(objetivo: "Ganhar massa",
                                                 restricoes: "sem lactose",
                                                 condicoes: "hérnia de disco")
        check(completo?.contains("sem lactose") == true && completo?.contains("hérnia de disco") == true,
              "restrições e limitações chegam juntas",
              completo ?? "nil")

        igual(CorpoContextFormat.perfil(objetivo: "Manter", restricoes: "   ", condicoes: "\n"),
              nil,
              "campo só com espaço não conta como preenchido")
    }

    // MARK: - Humor

    static func testHumor() {
        igual(CorpoContextFormat.sinalDeHumor(dificeis: 2, leves: 0, total: 2),
              nil,
              "menos de 3 registros não é tendência")

        igual(CorpoContextFormat.sinalDeHumor(dificeis: 4, leves: 1, total: 5),
              "semana emocionalmente pesada",
              "maioria difícil")

        igual(CorpoContextFormat.sinalDeHumor(dificeis: 0, leves: 4, total: 5),
              "semana leve, bom momento",
              "maioria leve")

        igual(CorpoContextFormat.sinalDeHumor(dificeis: 2, leves: 2, total: 5),
              "semana oscilante",
              "sem maioria, com os dois polos")

        igual(CorpoContextFormat.sinalDeHumor(dificeis: 0, leves: 0, total: 4),
              "semana estável",
              "registros neutros")

        // Privacidade: o que sai NUNCA pode conter número nem emoji.
        let saidas = [
            CorpoContextFormat.sinalDeHumor(dificeis: 4, leves: 1, total: 5),
            CorpoContextFormat.sinalDeHumor(dificeis: 0, leves: 4, total: 5),
            CorpoContextFormat.sinalDeHumor(dificeis: 2, leves: 2, total: 5),
            CorpoContextFormat.sinalDeHumor(dificeis: 0, leves: 0, total: 4)
        ].compactMap { $0 }

        let temNumero = saidas.contains { $0.rangeOfCharacter(from: .decimalDigits) != nil }
        check(!temNumero, "o sinal de humor não carrega contagem nenhuma")

        let temEmoji = saidas.contains { $0.unicodeScalars.contains { $0.properties.isEmoji } }
        check(!temEmoji, "o sinal de humor não carrega emoji nenhum")
    }

    // MARK: - Humor: o teste que faltava
    //
    // [2026-08-03] Os 29 testes anteriores passavam com o humor completamente
    // quebrado no app. Eles exercitavam `sinalDeHumor(dificeis:leves:total:)`
    // com contagens INJETADAS — nunca os rótulos que o check-in grava de fato.
    //
    // O bug B2 vivia exatamente nesse vão: a tela gravava "Triste" e o
    // classificador procurava "😢". Interseção vazia, resultado sempre
    // "semana estável". Cobertura verde, funcionalidade morta.
    //
    // Estes testes entram pelos RÓTULOS REAIS, os mesmos que a InsightsView usa.

    static func testHumorPipelineReal() {
        // Os rótulos que o app realmente grava, conforme o enum Mood.
        let rotulosReais = ["Ótimo", "Bem", "Normal", "Cansado", "Ansioso", "Triste"]
        check(rotulosReais.allSatisfy { Mood(rawValue: $0) != nil },
              "todo rótulo do check-in é reconhecido pelo classificador")

        // O caso que motivou tudo: sete dias de tristeza.
        igual(CorpoContextFormat.classificarHumor(rotulos: Array(repeating: "Triste", count: 7)),
              "semana emocionalmente pesada",
              "sete dias de 'Triste' NÃO podem virar 'semana estável'")

        igual(CorpoContextFormat.classificarHumor(rotulos: ["Ótimo", "Bem", "Ótimo", "Bem"]),
              "semana leve, bom momento",
              "semana boa é reconhecida")

        igual(CorpoContextFormat.classificarHumor(rotulos: ["Triste", "Ótimo", "Cansado", "Bem"]),
              "semana oscilante",
              "altos e baixos")

        igual(CorpoContextFormat.classificarHumor(rotulos: ["Normal", "Normal", "Normal"]),
              "semana estável",
              "'estável' só quando os registros são realmente neutros")

        // Silêncio em vez de afirmação sem base.
        igual(CorpoContextFormat.classificarHumor(rotulos: ["Triste", "Triste"]),
              nil,
              "dois registros não bastam para afirmar nada")

        igual(CorpoContextFormat.classificarHumor(rotulos: []),
              nil,
              "sem check-in, a Alma não recebe linha de humor")

        igual(CorpoContextFormat.classificarHumor(rotulos: ["😢", "😔", "😰"]),
              nil,
              "rótulo desconhecido (emoji legado) não vira 'estável' silencioso")

        // Trava de regressão: se alguém acrescentar um humor na tela sem
        // declarar a valência, este teste cai.
        // ── [2026-08-04] Dois achados do primeiro dump completo dos 12 ──────
        print("\n── Achados do dump completo de 04/08 ──")

        igual(CorpoContextFormat.inteiro(7432), "7.432",
              "milhar em PT-BR usa ponto, não o separador do locale do aparelho")
        igual(CorpoContextFormat.inteiro(950), "950",
              "abaixo de mil não ganha separador")
        igual(CorpoContextFormat.inteiro(1234567), "1.234.567",
              "milhão também")

        igual(CorpoContextFormat.alimentacao(kcal: 0, refeicoesFeitas: 1, meta: 2200, proteina: 0),
              "Alimentação hoje: 1 refeição marcada, sem alimentos registrados",
              "refeição marcada sem alimento NÃO vira '0 kcal · 0% da meta · 0 g'")

        igual(CorpoContextFormat.alimentacao(kcal: 0, refeicoesFeitas: 2, meta: 2200, proteina: 0),
              "Alimentação hoje: 2 refeições marcadas, sem alimentos registrados",
              "plural correto no caso sem alimentos")

        igual(CorpoContextFormat.alimentacao(kcal: 0, refeicoesFeitas: 1, meta: 2200, proteina: 24),
              "Alimentação hoje: 0 kcal em 1 refeição · 0% da meta · 24 g de proteína",
              "com proteína registrada, o zero de kcal é informação real e fica")

        check(Mood.allCases.count == 6, "o check-in tem 6 humores; mudou? declare a valência do novo")
        check(Mood.allCases.filter { $0.valencia == .dificil }.count == 3,
              "Cansado, Ansioso e Triste contam como semana difícil")
    }
}
