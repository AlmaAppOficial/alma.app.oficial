// PesoVigente.swift
// Alma — a ÚNICA verdade sobre o peso da pessoa
//
// [2026-08-04] O Assis digitou 83,0 kg em "Editar avaliação" e a aba Saúde
// mostrou 82,7 kg. Não era arredondamento: eram duas fontes concorrentes, com
// a precedência invertida em relação ao que qualquer pessoa espera.
//
// `SaudeView.swift:19` fazia:
//     health.bodyMass ?? model.weightKg
// ou seja, o Apple Saúde ganhava SEMPRE, e o valor digitado só apareceria se o
// HealthKit não tivesse absolutamente nada. Como tinha, o que ele digitava
// nunca chegava à tela — nem ao IMC, que saía calculado com o outro peso.
//
// Pior: havia TRÊS números possíveis circulando pelo app —
//   • `AppModel.weightKg` (digitado, em UserDefaults) → contexto da IA;
//   • `HealthManager.bodyMass` (Apple Saúde) → aba Saúde;
//   • e o IMC de `Models.imcSeguro`, que usa o digitado, contra o IMC da
//     `SaudeView`, que usava o do HealthKit. Dois IMCs para a mesma pessoa.
//
// PRECEDÊNCIA (decisão do Assis, 04/08): **o que a pessoa digitou sempre vence.**
// O Apple Saúde só preenche quando ela nunca digitou nada.
//
// Limite conhecido e aceito: quem usa balança inteligente não vê o peso novo
// automaticamente depois de ter digitado uma vez. A alternativa — vencer o mais
// recente — exige carimbo de data na edição E a data da amostra do HealthKit,
// que o `HealthManager` não expõe hoje. Fica registrado no CLAUDE.md como
// evolução, não como esquecimento.
//
// Função pura de propósito: dá para exercitar a regra inteira sem HealthKit,
// sem UI e sem aparelho.

import Foundation

/// De onde veio o número que está na tela. Existe para a UI poder DIZER —
/// metade da confusão do Assis foi não saber qual dos dois pesos estava vendo.
enum OrigemDoPeso {
    case digitado
    case appleSaude
    case ausente

    var rotulo: String {
        switch self {
        case .digitado:   return "informado por você"
        case .appleSaude: return "do Apple Saúde"
        case .ausente:    return "sem peso informado"
        }
    }

    var veioDoAppleSaude: Bool { self == .appleSaude }
}

enum PesoVigente {

    /// O peso que vale para o app inteiro.
    ///
    /// - Parameters:
    ///   - digitado: `AppModel.weightKg`. Zero significa "nunca informado".
    ///   - appleSaude: `HealthManager.bodyMass`, ou `nil` se não houver.
    static func decidir(digitado: Double, appleSaude: Double?) -> (kg: Double, origem: OrigemDoPeso) {
        if digitado > 0 {
            return (digitado, .digitado)          // o que a pessoa disse vence
        }
        if let hk = appleSaude, hk > 0 {
            return (hk, .appleSaude)              // só quando ela nunca disse
        }
        return (0, .ausente)
    }

    /// IMC a partir do peso vigente. `nil` sem peso ou sem altura — nunca NaN.
    static func imc(pesoKg: Double, alturaCm: Double) -> Double? {
        guard pesoKg > 0, alturaCm > 0 else { return nil }
        return pesoKg / pow(alturaCm / 100, 2)
    }
}
