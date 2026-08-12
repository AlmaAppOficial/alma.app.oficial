// testes_refeicao.swift — a refeição com componentes, exercitada contra
// `Shared/Corpo/Refeicao.swift` (produção). Sem cópia, sem simulador.
//
// Rodar:  ./_scripts/mutacao_refeicao.sh
// Ou só:  xcrun swiftc -O Shared/Corpo/UnidadeDeMedida.swift \
//              Shared/Corpo/Refeicao.swift _scripts/testes_refeicao.swift \
//              -o /tmp/testes_refeicao && /tmp/testes_refeicao
//
// Duas famílias de asserção, e as duas nasceram de erros reais deste projeto:
//
//   R0..R2 · O DADO VELHO SOBREVIVE. `Meal` ganhou um campo e vive em
//            `UserDefaults`. É a mesma armadilha do `userFoods`, num dado que
//            dói mais: o diário do dia.
//
//   R3..R5 · O TOTAL É A SOMA. Deixar a refeição editável reabre a porta que o
//            bloco H fechou em 05/08 (tela mostrando um número, diário gravando
//            outro), agora com N números.
//
// CANÁRIOS: R0 e R3b. O primeiro prova que a armadilha do decoder existe e que
// este arquivo a enxerga; o segundo prova que o comparador de totais sabe
// reprovar. Se qualquer um passar, o resultado inteiro é descartado.

import Foundation

@main
enum TestesRefeicao {

    nonisolated(unsafe) static var ok = 0
    nonisolated(unsafe) static var falhas: [String] = []

    static func checa(_ id: String, _ desc: String, _ passou: Bool, _ detalhe: String = "") {
        if passou { ok += 1; print("  ✓ \(id) \(desc)\(detalhe.isEmpty ? "" : " — \(detalhe)")") }
        else { falhas.append("\(id) \(desc) — \(detalhe)"); print("  ✗ \(id) \(desc) — \(detalhe)") }
    }

    /// O diário como está gravado HOJE no aparelho de quem já usa o app: sem
    /// `componentes`, e com o `rawValue` de `MealType` que sempre esteve lá.
    static let jsonAntigo = """
    [{"id":"A1000000-0000-4000-8000-000000000001","type":"Café da manhã",
      "name":"Pão integral · 60 g","kcal":148,"protein":8,"carbs":25,"fat":2,"done":true},
     {"id":"A1000000-0000-4000-8000-000000000002","type":"Almoço",
      "name":"Frango · 250 g","kcal":413,"protein":78,"carbs":0,"fat":10,"done":false}]
    """.data(using: .utf8)!

    static func main() {
        print("═════ REFEIÇÃO COM COMPONENTES — contra o código de produção ═════")

        // ═══════════════════════════════════════════════════════════════════
        // R0 · CANÁRIO — a armadilha do decoder existe, e este arquivo a vê.
        // ═══════════════════════════════════════════════════════════════════
        struct MealIngenua: Codable {
            var id = UUID()
            let type: MealType
            let name: String
            let kcal: Int
            let protein: Int
            let carbs: Int
            let fat: Int
            var done: Bool
            var componentes: [ComponenteDaRefeicao] = []   // ← não-opcional
        }
        var ingenuaQuebrou = false
        var erro = "decodificou sem erro"
        do { _ = try JSONDecoder().decode([MealIngenua].self, from: jsonAntigo) }
        catch let DecodingError.keyNotFound(k, _) { ingenuaQuebrou = true; erro = "keyNotFound(\(k.stringValue))" }
        catch { ingenuaQuebrou = true; erro = "\(error)" }
        checa("R0", "CANÁRIO: campo não-opcional REPROVA o diário antigo",
              ingenuaQuebrou,
              ingenuaQuebrou ? "✓ armadilha visível: \(erro)"
                             : "✗✗ HARNESS CEGO — R1 não prova nada")

        // ── R1 · o diário antigo continua legível ──────────────────────────
        var antigas: [Meal] = []
        var erroAntigo = ""
        do { antigas = try JSONDecoder().decode([Meal].self, from: jsonAntigo) }
        catch { erroAntigo = "\(error)" }
        checa("R1", "o diário gravado antes dos componentes continua sendo lido",
              antigas.count == 2,
              antigas.count == 2 ? "2 refeições preservadas"
                                 : "PERDA DE DADOS — \(antigas.count) de 2 · \(erroAntigo)")
        // `!antigas.isEmpty` NÃO é decoração — foi acrescentado depois de a
        // mutação M1 flagrar esta asserção como CEGA em 12/08.
        //
        // `allSatisfy` sobre coleção VAZIA devolve `true`. Com a mutação viva
        // (decoder exigindo a chave), `antigas` vinha vazia, R1 e R1d ficavam
        // vermelhas como deviam — e R1b ficava VERDE, afirmando algo sobre duas
        // refeições que não existiam. Verdade vácua é o "verde cego" da Regra 2
        // com outro nome, e só apareceu porque a mutação foi de fato rodada.
        checa("R1b", "sem componentes, o campo é nil (e não lista vazia)",
              !antigas.isEmpty && antigas.allSatisfy { $0.componentes == nil },
              antigas.isEmpty
                ? "nada decodificado — asserção não teria o que afirmar"
                : antigas.map { "\($0.name)=\($0.componentes == nil ? "nil" : "[]")" }.joined(separator: " · "))

        // R1c · O `rawValue` do café. Esta asserção existe porque eu QUASE
        // troquei "Café da manhã" por "Café" ao mover o enum de arquivo em
        // 12/08 — o que faria todo registro de café do disco lançar
        // `dataCorrupted` e sumir da tela sem aviso.
        checa("R1c", "o rawValue \"Café da manhã\" continua sendo o do disco",
              antigas.first?.type == .cafe && MealType.cafe.rawValue == "Café da manhã",
              "lido=\(antigas.first?.type.rawValue ?? "NADA")")

        checa("R1d", "e os totais antigos atravessam intactos",
              antigas.first?.kcal == 148 && antigas.last?.protein == 78
                && antigas.last?.done == false,
              antigas.first.map { "\($0.kcal)kcal" } ?? "NADA")

        // ── R2 · ida e volta com componentes ───────────────────────────────
        let arroz = ComponenteDaRefeicao(nome: "Arroz branco", quantidade: 150,
                                         kcalPor100: 130, proteinaPor100: 3,
                                         carboPor100: 28, gorduraPor100: 0)
        let frango = ComponenteDaRefeicao(nome: "Peito de frango", quantidade: 120,
                                          kcalPor100: 165, proteinaPor100: 31,
                                          carboPor100: 0, gorduraPor100: 4)
        let salada = ComponenteDaRefeicao(nome: "Salada", quantidade: 60,
                                          kcalPor100: 20, proteinaPor100: 1,
                                          carboPor100: 4, gorduraPor100: 0)
        let suco = ComponenteDaRefeicao(nome: "Suco de laranja", quantidade: 200,
                                        unidade: .mililitro, kcalPor100: 45,
                                        proteinaPor100: 1, carboPor100: 11, gorduraPor100: 0)

        let prato = Meal.comComponentes(type: .almoco, name: "Prato feito",
                                        componentes: [arroz, frango, salada, suco])
        var voltou: Meal?
        if let d = try? JSONEncoder().encode(prato) {
            voltou = try? JSONDecoder().decode(Meal.self, from: d)
        }
        checa("R2", "a refeição com componentes sobrevive ao disco",
              voltou?.componentes?.count == 4,
              "\(voltou?.componentes?.count ?? -1) componentes")
        checa("R2b", "a unidade de cada componente sobrevive junto",
              voltou?.componentes?[3].unidade == .mililitro
                && voltou?.componentes?[0].unidade == .grama,
              voltou?.componentes?.map { "\($0.nome)=\($0.unidade.rawValue)" }
                .joined(separator: " ") ?? "NADA")

        // R2c · componente gravado ANTES da unidade existir (o mesmo caso do
        // StoredFood, um nível abaixo).
        let compAntigo = """
        {"nome":"Arroz","quantidade":150,"kcalPor100":130,"proteinaPor100":3,
         "carboPor100":28,"gorduraPor100":0}
        """.data(using: .utf8)!
        let c1 = try? JSONDecoder().decode(ComponenteDaRefeicao.self, from: compAntigo)
        checa("R2c", "componente sem unidade no JSON vira grama, sem lançar",
              c1?.unidade == .grama && c1?.quantidade == 150,
              c1.map { "\($0.nome) \($0.quantidade)\($0.unidade.rawValue)" } ?? "LANÇOU")

        // ═══════════════════════════════════════════════════════════════════
        // R3 · O INVARIANTE: o total é a soma dos componentes.
        // ═══════════════════════════════════════════════════════════════════
        let somaKcal = arroz.kcal + frango.kcal + salada.kcal + suco.kcal
        checa("R3", "os totais da refeição são a soma dos componentes",
              prato.kcal == somaKcal && prato.totaisBatemComOsComponentes,
              "total=\(prato.kcal) soma=\(somaKcal) · "
                + "arroz=\(arroz.kcal) frango=\(frango.kcal) salada=\(salada.kcal) suco=\(suco.kcal)")

        checa("R3a", "e os números são os da PORÇÃO, não os por 100",
              arroz.kcal == 195 && frango.kcal == 198 && suco.kcal == 90,
              "arroz(150g de 130/100)=\(arroz.kcal) frango(120g de 165/100)=\(frango.kcal)")

        // R3b · CANÁRIO do comparador. Monta uma refeição com total MENTIROSO
        // pelo `init` cru e exige que `totaisBatemComOsComponentes` acuse. Se
        // passar, R3 estaria aprovando qualquer coisa.
        let mentirosa = Meal(type: .almoco, name: "canário", kcal: 9999,
                             protein: 0, carbs: 0, fat: 0, done: true,
                             componentes: [arroz, frango])
        checa("R3b", "CANÁRIO: o comparador acusa total que não bate com a soma",
              mentirosa.totaisBatemComOsComponentes == false,
              mentirosa.totaisBatemComOsComponentes
                ? "✗✗ COMPARADOR CEGO" : "✓ comparador vivo (acusou 9999)")

        // ── R4 · a edição refaz a soma e preserva identidade ───────────────
        let editado = prato.trocandoComponentes([
            arroz.com(quantidade: 220), frango, salada.com(quantidade: 0), suco
        ])
        let somaEditada = arroz.com(quantidade: 220).kcal + frango.kcal + suco.kcal
        checa("R4", "editar a quantidade refaz o total sozinho",
              editado.kcal == somaEditada && editado.totaisBatemComOsComponentes
                && editado.kcal != prato.kcal,
              "antes=\(prato.kcal) depois=\(editado.kcal) esperado=\(somaEditada)")

        checa("R4b", "a edição preserva id e `done` — não vira linha nova no diário",
              editado.id == prato.id && editado.done == prato.done
                && editado.name == prato.name,
              "id igual=\(editado.id == prato.id) done=\(editado.done)")

        checa("R4c", "componente zerado sai da conta sem sumir da lista",
              editado.componentes?.count == 4
                && editado.componentes?[2].quantidade == 0
                && editado.componentes?[2].kcal == 0,
              "\(editado.componentes?.count ?? -1) itens, salada=\(editado.componentes?[2].kcal ?? -1) kcal")

        // ── R5 · entrada torta não vira caloria negativa ────────────────────
        let negativo = ComponenteDaRefeicao(nome: "Erro", quantidade: -50,
                                            kcalPor100: 100, proteinaPor100: 0,
                                            carboPor100: 0, gorduraPor100: 0)
        checa("R5", "quantidade negativa é aparada em 0, não subtrai do dia",
              negativo.quantidade == 0 && negativo.kcal == 0,
              "quantidade=\(negativo.quantidade) kcal=\(negativo.kcal)")

        // ── R6 · o que a tela usa ──────────────────────────────────────────
        checa("R6", "o resumo cita cada componente com a sua unidade",
              prato.resumoDosComponentes?.contains("Arroz branco 150 g") == true
                && prato.resumoDosComponentes?.contains("Suco de laranja 200 ml") == true,
              prato.resumoDosComponentes ?? "nil")

        checa("R6b", "refeição antiga não se diz editável",
              antigas.first?.editavel == false && prato.editavel == true,
              "antiga=\(antigas.first?.editavel ?? true) nova=\(prato.editavel)")

        print("─────────────────────────────────────────────────────────────────")
        if falhas.isEmpty { print("TUDO VERDE — \(ok) asserções"); exit(0) }
        print("\(falhas.count) FALHA(S) de \(ok + falhas.count):")
        for f in falhas { print("  · \(f)") }
        exit(1)
    }
}
