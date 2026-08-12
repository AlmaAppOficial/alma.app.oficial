//
//  probe_somatotipo.swift — ACHADO, não conserto.
//
//  A gordura ausente parou de ser IMPRESSA, mas ela continua sendo CALCULADA
//  com. O rótulo do somatotipo, no caminho sem foto, sai de:
//
//      if bodyFat >= 25 || bmi >= 27      → endomorfo
//      else if bodyFat <= 12 && bmi < 21  → ectomorfo
//      else                               → mesomorfo
//
//  Com a gordura ausente (0), a primeira condição de "ectomorfo" — `<= 12` —
//  é satisfeita pela AUSÊNCIA, como se a pessoa fosse magra o bastante para
//  isso ter sido medido.
//
//  Isto é a mesma família do defeito consertado, um nível abaixo: ausência
//  entrando numa conta como se fosse medida. Não mexi porque mudar isso muda o
//  RÓTULO que as pessoas veem — decisão de produto, do Assis.
//
//  Esta sonda não afirma nada: ela imprime o que o código de produção faz hoje.
//

import Foundation

func rodar() async {
    // Mesmo corpo nas duas linhas. Muda só se a gordura foi informada.
    let peso = 55.0, altura = 175.0   // IMC ≈ 17.96 (abaixo de 21)
    let imc = peso / ((altura / 100) * (altura / 100))

    func entrada(_ g: Double) -> ScanInput {
        ScanInput(weightKg: peso, heightCm: altura, ageYears: 30, bodyFat: g,
                  goal: Goal.manter.rawValue, frontPhoto: nil, sidePhoto: nil)
    }

    print("IMC do corpo usado nas duas linhas: \(String(format: "%.2f", imc))")
    print("")

    for (rotulo, g) in [("gordura NÃO informada (0)", 0.0),
                        ("gordura informada: 10%", 10.0),
                        ("gordura informada: 30%", 30.0)] {
        let r = try! await MockAIPlanService().analyze(entrada(g))
        let somatotipo = r.analysis.somatotype.map { $0.rawValue } ?? "nenhum"
        let gordura = r.analysis.estimatedBodyFat.map { String(format: "%.0f%%", $0) } ?? "(linha escondida)"
        print("  \(rotulo.padding(toLength: 28, withPad: " ", startingAt: 0)) → rótulo: \(somatotipo)   | linha de gordura: \(gordura)")
    }

    print("")
    print("Leitura: quem não informou a gordura recebe o MESMO rótulo de quem")
    print("informou 10% — porque o 0 da ausência passa no teste `<= 12`.")
    print("A linha de gordura já não mente. O rótulo ainda é calculado com o vazio.")
}

await rodar()
