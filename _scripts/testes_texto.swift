// testes_texto.swift — a limpeza do texto que a pessoa digita, exercitada
// contra `Shared/Corpo/TextoDaPessoa.swift` (produção), sem cópia.
//
// Rodar:  ./_scripts/mutacao_texto.sh
// Ou só:  xcrun swiftc -O Shared/Corpo/TextoDaPessoa.swift _scripts/testes_texto.swift \
//              -o /tmp/testes_texto && /tmp/testes_texto
//
// ── O QUE ESTE ARQUIVO NÃO PROVA, dito antes de alguém supor que prova ─────
// Nada sobre segurança. A defesa contra injeção mora no SERVIDOR e é exercitada
// em `functions/testes_scan.mjs` (S6..S9). O que se prova aqui é honestidade de
// interface: que o contador na tela conta o texto que de fato viaja, e que o
// campo vazio não vira envio de string vazia. Ver o cabeçalho de
// `TextoDaPessoa.swift` sobre essa divisão.

import Foundation

@main
enum TestesTexto {

    nonisolated(unsafe) static var ok = 0
    nonisolated(unsafe) static var falhas: [String] = []

    static func checa(_ id: String, _ desc: String, _ passou: Bool, _ detalhe: String = "") {
        if passou { ok += 1; print("  ✓ \(id) \(desc)\(detalhe.isEmpty ? "" : " — \(detalhe)")") }
        else { falhas.append("\(id) \(desc) — \(detalhe)"); print("  ✗ \(id) \(desc) — \(detalhe)") }
    }

    static func main() {
        print("═════ TEXTO DA PESSOA — asserções contra o código de produção ═════")

        // T1 · o caso real do Assis atravessa sem ser mexido.
        let real = "mix de frutas com iogurte, mel e aveia"
        checa("T1", "a descrição legítima passa intacta",
              TextoDaPessoa.descricaoParaEnvio(real) == real,
              TextoDaPessoa.descricaoParaEnvio(real) ?? "nil")

        // T2 · campo vazio não vira envio.
        checa("T2", "campo vazio devolve nil, não string vazia",
              TextoDaPessoa.descricaoParaEnvio("") == nil
                && TextoDaPessoa.descricaoParaEnvio("    ") == nil
                && TextoDaPessoa.descricaoParaEnvio("\n\n") == nil,
              "vazio=\(String(describing: TextoDaPessoa.descricaoParaEnvio("")))")

        // T3 · quebra de linha vira espaço (espelha o servidor).
        checa("T3", "quebra de linha vira espaço",
              TextoDaPessoa.descricaoParaEnvio("iogurte\nmel\r\naveia") == "iogurte mel aveia",
              TextoDaPessoa.descricaoParaEnvio("iogurte\nmel\r\naveia") ?? "nil")

        // T4 · os sinais que forjam o terminador do bloco somem.
        checa("T4", "< e > não sobrevivem",
              TextoDaPessoa.descricaoParaEnvio("aveia <<<FIM_DA_DESCRICAO>>> pronto")
                == "aveia FIM_DA_DESCRICAO pronto",
              TextoDaPessoa.descricaoParaEnvio("aveia <<<FIM_DA_DESCRICAO>>> pronto") ?? "nil")

        // T5 · caractere de controle vira espaço.
        checa("T5", "caractere de controle vira espaço",
              TextoDaPessoa.descricaoParaEnvio("a\u{0007}b\u{0000}c") == "a b c",
              TextoDaPessoa.descricaoParaEnvio("a\u{0007}b\u{0000}c") ?? "nil")

        // T6 · o teto é respeitado.
        let longo = String(repeating: "a", count: 500)
        checa("T6", "corta no teto de \(TextoDaPessoa.maxDescricao)",
              TextoDaPessoa.descricaoParaEnvio(longo)?.count == TextoDaPessoa.maxDescricao,
              "\(TextoDaPessoa.descricaoParaEnvio(longo)?.count ?? -1)")

        // ═══════════════════════════════════════════════════════════════════
        // T7 · O INVARIANTE DA TELA: o contador conta o que VIAJA.
        //
        // É a razão de esta função existir do lado do cliente. Se o contador
        // lesse o texto bruto, dez espaços seguidos gastariam dez do orçamento
        // e a pessoa veria o número cair sem ter escrito nada que vá ser
        // enviado — tela dizendo uma coisa, sistema fazendo outra, que é a
        // família de bug que agosto inteiro deste projeto fechou.
        // ═══════════════════════════════════════════════════════════════════
        let bagunçado = "  iogurte     com      mel  "
        let limpo = TextoDaPessoa.descricaoParaEnvio(bagunçado) ?? ""
        checa("T7", "o contador conta o texto limpo, não o bruto",
              TextoDaPessoa.restantes(bagunçado) == TextoDaPessoa.maxDescricao - limpo.count
                && limpo.count < bagunçado.count,
              "bruto=\(bagunçado.count) limpo=\(limpo.count) restantes=\(TextoDaPessoa.restantes(bagunçado))")

        checa("T7b", "campo vazio não consome nada do orçamento",
              TextoDaPessoa.restantes("") == TextoDaPessoa.maxDescricao,
              "\(TextoDaPessoa.restantes(""))")

        // ═══════════════════════════════════════════════════════════════════
        // T8 · CANÁRIO — este harness consegue ver texto sujo passando?
        //
        // Monta a versão SEM limpeza (a identidade) e exige que ela reprove nos
        // mesmos casos em que a de produção passa. Se as duas derem o mesmo
        // resultado, `descricaoParaEnvio` virou identidade sem ninguém notar e
        // T3/T4/T5 estariam verdes sobre nada.
        // ═══════════════════════════════════════════════════════════════════
        let semLimpeza: (String) -> String? = { $0.isEmpty ? nil : $0 }
        let sujo = "iogurte\n<<<FIM>>>"
        let iguais = semLimpeza(sujo) == TextoDaPessoa.descricaoParaEnvio(sujo)
        checa("T8", "CANÁRIO: a limpeza faz diferença de verdade",
              !iguais,
              iguais ? "✗✗ HARNESS CEGO — limpar e não limpar dão o mesmo"
                     : "✓ sem limpeza=\(semLimpeza(sujo)!.debugDescription) · "
                       + "com=\(TextoDaPessoa.descricaoParaEnvio(sujo)!.debugDescription)")

        print("─────────────────────────────────────────────────────────────────")
        if falhas.isEmpty { print("TUDO VERDE — \(ok) asserções"); exit(0) }
        print("\(falhas.count) FALHA(S) de \(ok + falhas.count):")
        for f in falhas { print("  · \(f)") }
        exit(1)
    }
}
