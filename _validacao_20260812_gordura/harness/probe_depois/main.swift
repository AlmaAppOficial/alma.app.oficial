//
//  probe_depois/main.swift — a MESMA sonda de `05_achado_somatotipo.txt`,
//  rodada contra a produção já corrigida. Serve para ler o antes e o depois
//  lado a lado, com o mesmo corpo e as mesmas três linhas.
//
//  Ela não afirma nada — quem afirma é o harness. Aqui só se imprime o que o
//  código de produção faz hoje, inclusive o RESUMO, porque o rótulo também era
//  pronunciado lá dentro e sumir do cabeçalho sem sumir do texto seria trocar
//  o defeito de lugar.
//

import Foundation

func rodar() async {
    // Mesmo corpo das três linhas do achado. IMC ≈ 17.96 (abaixo de 21).
    let peso = 55.0, altura = 175.0
    let imc = peso / ((altura / 100) * (altura / 100))

    func entrada(_ g: Double) -> ScanInput {
        ScanInput(weightKg: peso, heightCm: altura, ageYears: 30, bodyFat: g,
                  goal: Goal.manter.rawValue, frontPhoto: nil, sidePhoto: nil)
    }

    print("IMC do corpo usado nas três linhas: \(String(format: "%.2f", imc))")
    print("")

    for (rotulo, g) in [("gordura NÃO informada (0)", 0.0),
                        ("gordura informada: 10%", 10.0),
                        ("gordura informada: 30%", 30.0)] {
        let r = try! await MockAIPlanService().analyze(entrada(g))
        let somatotipo = r.analysis.somatotype.map { $0.rawValue } ?? "nenhum"
        let gordura = r.analysis.estimatedBodyFat.map { String(format: "%.0f%%", $0) } ?? "(linha escondida)"
        print("  \(rotulo.padding(toLength: 28, withPad: " ", startingAt: 0)) → rótulo: \(somatotipo.padding(toLength: 10, withPad: " ", startingAt: 0)) | linha de gordura: \(gordura)")
    }

    print("")
    print("─── e o RESUMO, que também pronunciava o rótulo ───")
    for (rotulo, g) in [("sem gordura informada", 0.0), ("com 10% informado", 10.0)] {
        let r = try! await MockAIPlanService().analyze(entrada(g))
        print("")
        print("  [\(rotulo)]")
        print("  \(r.analysis.summary)")
    }

    print("")
    print("Leitura: quem não informou a gordura não recebe rótulo nenhum — nem no")
    print("cabeçalho, nem no meio do resumo. Quem informou 10% continua recebendo")
    print("Ectomorfo, e quem informou 30%, Endomorfo: nada foi tirado de quem")
    print("informou. Compare com `05_achado_somatotipo.txt`, o mesmo corpo antes.")
}

await rodar()
