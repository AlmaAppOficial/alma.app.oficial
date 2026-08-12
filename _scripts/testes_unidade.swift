// testes_unidade.swift — as decisões da unidade de medida, exercitadas contra o
// ARQUIVO DE PRODUÇÃO (`Shared/Corpo/UnidadeDeMedida.swift`), não contra cópia.
//
// ═══════════════════════════════════════════════════════════════════════════
// COMO RODAR
//   ./_scripts/mutacao_unidade.sh          (compila, roda e faz as mutações)
// ou, só as asserções:
//   xcrun swiftc -O Shared/Corpo/UnidadeDeMedida.swift _scripts/testes_unidade.swift \
//        -o /tmp/testes_unidade && /tmp/testes_unidade
//
// POR QUE ESTE HARNESS EXISTE E NÃO BASTA O `AuditoriaBloqueadores`
//
// O `AuditoriaBloqueadores` roda DENTRO do app, no simulador. É a ferramenta
// certa para invariantes que envolvem `AppModel`, `UserDefaults` e telas. Mas
// cada rodada custa um build inteiro do app, o que torna caro o único
// procedimento que realmente prova uma asserção: apagar a linha de produção e
// conferir que o teste fica VERMELHO.
//
// O que se prova aqui é Foundation puro — decodificação de JSON — e roda em
// menos de dois segundos com `swiftc`. Isso permite mutar de verdade, várias
// vezes, que é o que a Regra 1 do CLAUDE.md pede.
//
// CANÁRIO: `U0` planta a versão INGÊNUA do tipo (campo não-opcional com valor
// padrão + decoder sintetizado) e EXIGE que ela quebre no JSON antigo. Se U0
// passar, o método de teste está cego — o `keyNotFound` não estaria sendo
// observado — e todo o resto do arquivo vira papel pintado. Ele diz isso em voz
// alta e devolve código de saída diferente de zero.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

@main
enum TestesUnidade {

    nonisolated(unsafe) static var ok = 0
    nonisolated(unsafe) static var falhas: [String] = []

    static func checa(_ id: String, _ desc: String, _ passou: Bool, _ detalhe: String = "") {
        if passou {
            ok += 1
            print("  ✓ \(id) \(desc)\(detalhe.isEmpty ? "" : " — \(detalhe)")")
        } else {
            falhas.append("\(id) \(desc) — \(detalhe)")
            print("  ✗ \(id) \(desc) — \(detalhe)")
        }
    }

    // ── O dado como ele existe HOJE no aparelho de quem já usa o app ────────
    // Copiado do formato que o `JSONEncoder` sintetizado produz para o
    // `StoredFood` de antes de 12/08/2026: sem a chave `unidade`.
    static let jsonAntigo = """
    [{"id":"5F3A2B1C-0000-4000-8000-000000000001","name":"Marmita da mãe",
      "brand":"Casa","kcalPer100":171,"proteinPer100":9,
      "carbsPer100":17,"fatPer100":6,"barcode":"7891000100103"},
     {"id":"5F3A2B1C-0000-4000-8000-000000000002","name":"Pão caseiro",
      "kcalPer100":247,"proteinPer100":13,"carbsPer100":41,"fatPer100":3}]
    """.data(using: .utf8)!

    static func main() {
        print("═════ UNIDADE DE MEDIDA — asserções contra o código de produção ═════")

        // ═══════════════════════════════════════════════════════════════════
        // U0 · CANÁRIO — a armadilha é REAL e este arquivo CONSEGUE vê-la.
        //
        // `IngenuoStoredFood` é o que se escreveria sem pensar: campo novo,
        // não-opcional, com valor padrão, e `Codable` sintetizado. A crença
        // errada é que o valor padrão cobre a chave ausente. Não cobre: o
        // decoder sintetizado usa `decode`, não `decodeIfPresent`, e lança.
        //
        // Se este canário PASSAR (isto é: se o ingênuo decodificar sem erro),
        // então ou a linguagem mudou ou o JSON de teste não representa o dado
        // antigo — e, nos dois casos, U1/U5 estariam verdes sem provar nada.
        // ═══════════════════════════════════════════════════════════════════
        struct IngenuoStoredFood: Codable {
            var id = UUID()
            var name: String
            var brand: String?
            var kcalPer100: Int
            var proteinPer100: Int
            var carbsPer100: Int
            var fatPer100: Int
            var barcode: String?
            var unidade: Unidade = .grama      // ← a linha que apaga os dados
        }

        var ingenuoQuebrou = false
        var erroDoIngenuo = "decodificou sem erro"
        do {
            _ = try JSONDecoder().decode([IngenuoStoredFood].self, from: jsonAntigo)
        } catch let DecodingError.keyNotFound(chave, _) {
            ingenuoQuebrou = true
            erroDoIngenuo = "keyNotFound(\(chave.stringValue))"
        } catch {
            ingenuoQuebrou = true
            erroDoIngenuo = "\(error)"
        }
        checa("U0", "CANÁRIO: o decoder sintetizado REPROVA o dado antigo",
              ingenuoQuebrou,
              ingenuoQuebrou ? "✓ armadilha visível: \(erroDoIngenuo)"
                             : "✗✗ HARNESS CEGO — o ingênuo passou, U1/U5 não provam nada")

        // ═══════════════════════════════════════════════════════════════════
        // U1 · O dado antigo continua legível — e vira grama.
        //
        // Mutação alvo: apagar o `init(from:)` à mão de `StoredFood` (deixando
        // o Swift sintetizar). Esta asserção tem de ficar VERMELHA.
        // ═══════════════════════════════════════════════════════════════════
        var antigos: [StoredFood] = []
        var erroAntigo = ""
        do { antigos = try JSONDecoder().decode([StoredFood].self, from: jsonAntigo) }
        catch { erroAntigo = "\(error)" }

        checa("U1", "alimento gravado antes da unidade existir continua sendo lido",
              antigos.count == 2,
              antigos.count == 2 ? "2 alimentos preservados"
                                 : "PERDA DE DADOS — decodificou \(antigos.count) de 2 · \(erroAntigo)")

        checa("U1b", "e ele é grama, que é o que de fato foi cadastrado",
              antigos.allSatisfy { $0.unidade == .grama },
              antigos.map { "\($0.name)=\($0.unidade.rawValue)" }.joined(separator: " "))

        checa("U1c", "os outros campos atravessaram intactos",
              antigos.first?.name == "Marmita da mãe"
                && antigos.first?.kcalPer100 == 171
                && antigos.first?.brand == "Casa"
                && antigos.first?.barcode == "7891000100103"
                && antigos.last?.brand == nil,
              antigos.first.map { "\($0.name)/\($0.kcalPer100)kcal/\($0.brand ?? "—")" } ?? "NADA")

        // U2 · o formato novo, com a unidade gravada.
        let jsonNovo = """
        [{"id":"5F3A2B1C-0000-4000-8000-000000000003","name":"Leite da fazenda",
          "kcalPer100":61,"proteinPer100":3,"carbsPer100":5,"fatPer100":3,
          "unidade":"ml"}]
        """.data(using: .utf8)!
        let novos = (try? JSONDecoder().decode([StoredFood].self, from: jsonNovo)) ?? []
        checa("U2", "alimento gravado em mililitro volta em mililitro",
              novos.first?.unidade == .mililitro,
              novos.first.map { "\($0.name)=\($0.unidade.rawValue)" } ?? "NADA")

        // U3 · ida e volta: o que foi salvo é o que volta.
        let leite = StoredFood(name: "Leite integral", kcalPer100: 61, proteinPer100: 3,
                               carbsPer100: 5, fatPer100: 3, unidade: .mililitro)
        let arroz = StoredFood(name: "Arroz", kcalPer100: 130, proteinPer100: 3,
                               carbsPer100: 28, fatPer100: 0, unidade: .grama)
        var voltaram: [StoredFood] = []
        if let d = try? JSONEncoder().encode([leite, arroz]) {
            voltaram = (try? JSONDecoder().decode([StoredFood].self, from: d)) ?? []
        }
        checa("U3", "ida e volta pelo disco preserva a unidade de cada item",
              voltaram.count == 2 && voltaram[0].unidade == .mililitro
                && voltaram[1].unidade == .grama,
              voltaram.map { "\($0.name)=\($0.unidade.rawValue)" }.joined(separator: " "))

        // U3b · a chave chega mesmo a ser escrita (senão U3 passaria por
        // acidente, lendo grama de um JSON sem campo nenhum).
        let escrito = (try? JSONEncoder().encode(leite)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        checa("U3b", "o encoder grava a chave `unidade` no disco",
              escrito.contains("\"unidade\"") && escrito.contains("\"ml\""),
              escrito.contains("\"ml\"") ? "grava \"unidade\":\"ml\"" : escrito)

        // U4 · rótulo desconhecido não derruba a coleção (troca consciente,
        // documentada em `lerRetrocompativel`).
        let jsonEstranho = """
        [{"name":"Vindo do futuro","kcalPer100":10,"proteinPer100":0,
          "carbsPer100":0,"fatPer100":0,"unidade":"oz"}]
        """.data(using: .utf8)!
        let estranhos = (try? JSONDecoder().decode([StoredFood].self, from: jsonEstranho)) ?? []
        checa("U4", "unidade desconhecida vira grama em vez de apagar a lista",
              estranhos.count == 1 && estranhos.first?.unidade == .grama,
              "decodificou \(estranhos.count) item(ns)")

        // U5 · a forma REAL do dado: lista misturada, velho e novo juntos.
        // É o que o `AppModel.init` lê da chave `userFoods` no primeiro
        // lançamento depois da atualização.
        let jsonMisto = """
        [{"name":"Antigo sem unidade","kcalPer100":100,"proteinPer100":1,
          "carbsPer100":1,"fatPer100":1},
         {"name":"Novo em ml","kcalPer100":40,"proteinPer100":0,
          "carbsPer100":9,"fatPer100":0,"unidade":"ml"}]
        """.data(using: .utf8)!
        let mistos = (try? JSONDecoder().decode([StoredFood].self, from: jsonMisto)) ?? []
        checa("U5", "lista misturada (antigo + novo) sobrevive inteira",
              mistos.count == 2 && mistos[0].unidade == .grama
                && mistos[1].unidade == .mililitro,
              mistos.map { "\($0.name)=\($0.unidade.rawValue)" }.joined(separator: " · "))

        // ── U6 · o texto que a tela mostra sai da unidade do alimento ───────
        checa("U6", "a quantidade é escrita com a unidade do próprio alimento",
              textoDaQuantidade(200, .mililitro) == "200 ml"
                && textoDaQuantidade(250, .grama) == "250 g",
              "\(textoDaQuantidade(200, .mililitro)) / \(textoDaQuantidade(250, .grama))")

        checa("U6b", "a base nutricional também: \"100 ml\", não \"100 g\"",
              Unidade.mililitro.cem == "100 ml" && Unidade.grama.cem == "100 g"
                && Unidade.mililitro.base100 == "por 100 ml",
              "\(Unidade.mililitro.cem) · \(Unidade.mililitro.base100)")

        // U7 · a unidade atravessa do alimento salvo para o item de catálogo —
        // é o caminho pelo qual o leite cadastrado volta na busca.
        checa("U7", "a unidade sobrevive à conversão para FoodItem",
              leite.asFoodItem.unidade == .mililitro
                && arroz.asFoodItem.unidade == .grama,
              "leite=\(leite.asFoodItem.unidade.rawValue) arroz=\(arroz.asFoodItem.unidade.rawValue)")

        // ═══════════════════════════════════════════════════════════════════
        // U8 · a unidade lida da EMBALAGEM (Open Food Facts)
        // ═══════════════════════════════════════════════════════════════════
        let casos: [(String?, Unidade?, String)] = [
            ("1 L",            .mililitro, "litro"),
            ("200 ml",         .mililitro, "mililitro com espaço"),
            ("350ml",          .mililitro, "mililitro grudado no número"),
            ("1,5 L",          .mililitro, "vírgula decimal"),
            ("6 x 1 L",        .mililitro, "fardo — vale a última unidade"),
            ("50 cl",          .mililitro, "centilitro (rótulo europeu)"),
            ("395 g",          .grama,     "grama"),
            ("500g",           .grama,     "grama grudado"),
            ("1 kg",           .grama,     "quilo é massa"),
            ("Leite em pó 400 g", .grama,  "líquido no NOME, massa na embalagem"),
            ("família",        nil,        "sem marcador → não inventa"),
            ("",               nil,        "vazio"),
            (nil,              nil,        "ausente"),
        ]
        var errosEmbalagem: [String] = []
        for (entrada, esperado, desc) in casos {
            let obtido = Unidade.daEmbalagem(entrada)
            if obtido != esperado {
                errosEmbalagem.append("\(entrada ?? "nil")→\(obtido?.rawValue ?? "nil") (esperado \(esperado?.rawValue ?? "nil"), \(desc))")
            }
        }
        checa("U8", "a unidade vem do que o fabricante declarou na embalagem",
              errosEmbalagem.isEmpty,
              errosEmbalagem.isEmpty ? "\(casos.count) casos" : errosEmbalagem.joined(separator: " | "))

        // ═══════════════════════════════════════════════════════════════════
        // U9 · CANÁRIO DO U8 — prova que ele distingue embalagem de NOME.
        //
        // A versão rápida e errada deste recurso rotularia por nome. Este
        // canário monta exatamente esse rotulador e exige que ele ERRE no caso
        // que a leitura da embalagem acerta. Se os dois derem o mesmo
        // resultado, `daEmbalagem` virou adivinhação por nome sem ninguém
        // notar, e U8 estaria aprovando a coisa errada.
        // ═══════════════════════════════════════════════════════════════════
        let adivinhaPorNome: (String) -> Unidade = { nome in
            let n = nome.lowercased()
            return ["leite", "suco", "água", "refrigerante", "chá", "café"]
                .contains(where: { n.contains($0) }) ? .mililitro : .grama
        }
        let armadilha = "Leite em pó 400 g"
        checa("U9", "CANÁRIO: a leitura da embalagem discorda da adivinhação por nome",
              adivinhaPorNome(armadilha) == .mililitro
                && Unidade.daEmbalagem(armadilha) == .grama,
              adivinhaPorNome(armadilha) == Unidade.daEmbalagem(armadilha)
                ? "✗✗ IGUAIS — daEmbalagem virou palpite por nome"
                : "✓ nome diz ml (errado), embalagem diz g (certo)")

        // ── Resultado ──────────────────────────────────────────────────────
        print("─────────────────────────────────────────────────────────────────")
        if falhas.isEmpty {
            print("TUDO VERDE — \(ok) asserções")
            exit(0)
        } else {
            print("\(falhas.count) FALHA(S) de \(ok + falhas.count):")
            for f in falhas { print("  · \(f)") }
            exit(1)
        }
    }
}
