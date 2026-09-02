// Exercicio.swift
// Alma — Corpo · o exercício prescrito e o treino que a pessoa monta.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTES TIPOS MUDARAM DE ARQUIVO (2026-09-02)
//
// `Equipment`, `Exercise` e `CustomWorkout` viviam em `Models.swift`, ao lado
// do `AppModel` — que importa SwiftUI e arrasta meia dúzia de dependências. O
// conteúdo deles NÃO mudou uma vírgula; só o endereço.
//
// O motivo é o mesmo que levou `Meal` para `Refeicao.swift`: o formato
// persistido de `customWorkouts` é o que está gravado no aparelho de quem já
// montou um treino, e a única prova que vale é decodificar um JSON gravado
// ANTES da mudança com o código de DEPOIS. `_scripts/testes_series.swift`
// compila ESTE arquivo com `swiftc` e faz exatamente isso (asserção L1). Em
// `Models.swift` a prova era impossível fora do simulador.
//
// ── A ARMADILHA QUE ESTE ARQUIVO EXISTE PARA NÃO CAIR ─────────────────────
//
// `AppModel.init` lê `customWorkouts` com `try?` (`Models.swift`, procure por
// "customWorkouts"). Um campo novo NÃO OPCIONAL em `Exercise` faz o
// decodificador sintetizado lançar `keyNotFound` em todo treino já gravado, o
// `try?` engole o erro, e a pessoa abre o app com a lista "Meus treinos" vazia
// — sem mensagem, sem volta. Por isso o registro de séries (reps × carga) NÃO
// acrescentou campo aqui: mora numa coleção própria, `RegistroDeSeries.swift`.
// Prescrição e execução são coisas diferentes, e é também o desenho certo.
//
// Se um dia for inevitável acrescentar campo: OPCIONAL, e a asserção L1 tem de
// continuar verde com o JSON antigo (a mutação M-L1 prova que ela enxerga).
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case corporal = "Peso corporal"
    case halteres = "Halteres"
    case barra = "Barra"
    case maquina = "Máquina"
    case cabo = "Cabo/Polia"
    case smith = "Smith"
    case kettlebell = "Kettlebell"
    case elastico = "Elástico"
    case banco = "Banco"
    case anilha = "Anilha"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .corporal:   return "figure.stand"
        case .halteres:   return "dumbbell.fill"
        case .barra:      return "dumbbell.fill"
        case .maquina:    return "gearshape.2.fill"
        case .cabo:       return "figure.strengthtraining.functional"
        case .smith:      return "square.split.2x1.fill"
        case .kettlebell: return "dumbbell.fill"
        case .elastico:   return "figure.flexibility"
        case .banco:      return "chair.lounge.fill"
        case .anilha:     return "circle.circle.fill"
        }
    }
}

/// ⚠️ FORMATO PERSISTIDO. Está no disco de quem montou um treino
/// (`customWorkouts`). Ver o cabeçalho antes de acrescentar campo.
struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let equipment: Equipment
    let muscle: String
    let symbol: String            // SF Symbol que ilustra o movimento
    let instructions: [String]
}

/// Treino montado pelo usuário (persistido).
struct CustomWorkout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [Exercise]
}

// MARK: - Identidade estável de um exercício

/// O slug de um exercício, a partir do nome: "Supino com halteres" →
/// "supino-com-halteres". É o `id` dos 1.095 do `exercises_v2.json` (conferido
/// em 02/09: os 1.095 ids são exatamente `slug(namePTBR)`, zero divergências).
///
/// [2026-09-02] Era `ExerciseV2.slug(for:)`, num arquivo que importa SwiftUI.
/// Veio para cá porque o registro de séries grava o slug NA ESCRITA: o
/// `Exercise` legado guardado no treino não carrega id nenhum (`asLegacyExercise`
/// descarta), e o histórico de um exercício precisa de uma chave que não mude
/// quando alguém corrigir um acento no nome exibido. `ExerciseV2.slug(for:)`
/// continua existindo e delega para cá — uma regra, dois nomes, nunca duas
/// implementações.
func slugDeExercicio(_ nome: String) -> String {
    let folded = nome.folding(options: [.diacriticInsensitive, .caseInsensitive],
                              locale: Locale(identifier: "pt_BR"))
    let allowed = folded.lowercased().map { ch -> Character in
        (ch.isLetter || ch.isNumber) ? ch : "-"
    }
    return String(allowed).split(separator: "-").joined(separator: "-")
}
