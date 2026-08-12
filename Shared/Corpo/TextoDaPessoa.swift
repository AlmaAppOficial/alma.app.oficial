// TextoDaPessoa.swift
// Alma — Corpo · o que a pessoa digita, a caminho de um modelo de linguagem.
//
// ═══════════════════════════════════════════════════════════════════════════
// [2026-08-12] Nasce com o campo de descrição do scan de comida, pedido do
// Assis: "às vezes coloco um mix de frutas com iogurte, mel e aveia e a IA
// identifica só iogurte".
//
// O campo é uma boa ideia de produto e é a PRIMEIRA vez que texto escolhido
// livremente por alguém entra no caminho da `analisarFoto`. Por isso ele tem
// arquivo próprio, e por isso o arquivo só importa `Foundation`: assim
// `_scripts/testes_texto.swift` compila esta função com `swiftc` e prova o que
// ela faz, sem simulador (Regra 4 do CLAUDE.md).
//
// ── DIVISÃO DE RESPONSABILIDADE COM O SERVIDOR, dita para não haver dúvida ──
//
// Esta função NÃO é a defesa. A defesa mora no servidor
// (`functions/src/analiseDeFoto.ts`: `sanitizarTextoDeUsuario`,
// `montarPedidoComida`, a instrução `system` e o `json_schema` estrito), porque
// o cliente é justamente a parte que um atacante controla — quem monta o `POST`
// à mão nunca passa por aqui.
//
// O que ESTA função é: honestidade de interface. Ela garante que o texto
// mostrado no campo, o contador de caracteres embaixo dele e o que de fato
// viaja na requisição são a MESMA coisa. Sem ela, a pessoa digitaria 600
// caracteres, veria os 600 na tela e o servidor cortaria em 280 sem avisar —
// a família de bug que este projeto passou agosto inteiro fechando: a tela
// dizendo uma coisa e o sistema fazendo outra.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

public enum TextoDaPessoa {

    /// Teto de caracteres da descrição. Igual ao `MAX_CONTEXTO` do servidor —
    /// e é o servidor que manda: se os dois divergirem, quem corta é ele, e o
    /// contador da tela vira mentira. Mexer aqui é mexer lá, na mesma sessão.
    public static let maxDescricao = 280

    /// Deixa o texto pronto para viajar — ou devolve `nil` se não sobrou nada.
    ///
    /// `nil` e não `""` de propósito: sem descrição, a chave `contexto` nem
    /// entra no JSON, e o servidor monta o pedido antigo, sem bloco nenhum.
    /// Mandar string vazia faria o pedido carregar um bloco de descrição vazio,
    /// que é ruído para o modelo e uma diferença sem motivo entre "não escreveu"
    /// e "escreveu e apagou".
    ///
    /// As mesmas três limpezas do servidor, pelos mesmos motivos:
    /// · controle e quebra de linha viram espaço (é com linha nova que se finge
    ///   ter começado outra seção da mensagem);
    /// · `<` e `>` somem (são os tijolos do terminador do bloco lá);
    /// · espaço repetido colapsa, e o corte vem por último, para o teto contar
    ///   texto de verdade e não espaço.
    public static func descricaoParaEnvio(_ bruto: String) -> String? {
        var t = bruto
        t = String(t.map { c in
            (c.isNewline || c.unicodeScalars.first.map { $0.properties.generalCategory == .control } == true)
                ? " " : c
        })
        t.removeAll { $0 == "<" || $0 == ">" }
        t = t.split(whereSeparator: { $0 == " " || $0.isWhitespace })
             .joined(separator: " ")
             .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > maxDescricao {
            t = String(t.prefix(maxDescricao)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t.isEmpty ? nil : t
    }

    /// Quantos caracteres ainda cabem — o número que a tela mostra.
    ///
    /// Conta sobre o texto JÁ LIMPO, não sobre o que está no campo. Se contasse
    /// o bruto, dez espaços seguidos gastariam dez do orçamento e a pessoa veria
    /// o contador cair sem ter escrito nada que vá ser enviado.
    public static func restantes(_ bruto: String) -> Int {
        maxDescricao - (descricaoParaEnvio(bruto)?.count ?? 0)
    }
}
