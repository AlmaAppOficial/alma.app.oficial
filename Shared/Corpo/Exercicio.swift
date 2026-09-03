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
/// Apelidos de plano → id canônico de um dos 1.095.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// POR QUE UM MAPA À MÃO E NÃO UMA HEURÍSTICA (2026-09-03)
///
/// As duas fontes de plano escrevem nome livre, não id: o gerador local
/// (`AIBodyScan.week(for:)`) e a IA (`GeminiService`, que devolve
/// `"exercises": ["ex1", ...]` em texto). Alguém precisa traduzir "Tríceps
/// corda" para `triceps-pulley-com-corda`.
///
/// A tentação é casar por substring. Foi o que existia, e errava calado. Uma
/// medição de 03/09 sobre a pasta de fotos mostrou o tamanho do risco: um
/// casamento automático "plausível" ligava `supino-guilhotina` (*Neck Press*)
/// a `behind-the-neck-press`. São movimentos diferentes, com a barra em lados
/// opostos do pescoço. Num app que prescreve carga, isso não é erro cosmético.
///
/// São 44 nomes, não 1.095. Cada linha abaixo foi conferida contra o
/// `namePTBR`, o `nameEN`, o equipamento e o músculo primário da ficha de
/// destino. Quando um apelido não está aqui e não é um id, `resolveExercise`
/// devolve `nil` — e é para ser assim.
/// ═══════════════════════════════════════════════════════════════════════════
enum NomesDePlano {

    /// Chave = slug do apelido, para casar sem depender de caixa nem acento.
    private static let porSlug: [String: String] = {
        var d: [String: String] = [:]
        for (apelido, id) in tabela { d[slugDeExercicio(apelido)] = id }
        return d
    }()

    static func canonico(para nome: String) -> String? {
        porSlug[slugDeExercicio(nome)]
    }

    /// Apelido → id. Conferido linha a linha em 2026-09-03.
    static let tabela: [String: String] = [
        // ── Peito ───────────────────────────────────────────────────────────
        "Supino":            "supino-reto-com-barra",
        "Supino reto":       "supino-reto-com-barra",
        "Supino halteres":   "supino-com-halteres",   // o catálogo diz "com halteres"
        "Supino inclinado":  "supino-inclinado-com-halteres",
        // "Crucifixo" é o voador de peito para quem treina no Brasil — e é
        // isto que o plano quer dizer. Existe no catálogo uma ficha chamada só
        // "Crucifixo" que é OUTRA coisa: o `Crucifix` do free-exercise-db,
        // isometria de OMBRO (segurar peso parado para os lados), sem foto.
        //
        // A ficha errada NÃO foi renomeada, e isso é decisão medida, não
        // preguiça: renomear qualquer exercício órfã o histórico de séries de
        // quem já o treinou. Ver `SlugsRenomeados` e
        // `_scripts/prova_rename_crucifixo.swift`. Este apelido resolve o que
        // de fato incomodava — o plano da pessoa — sem tocar em dado gravado.
        "Crucifixo":         "crucifixo-com-halteres",
        "Flexão":            "flexao-de-braco",

        // ── Costas ──────────────────────────────────────────────────────────
        "Remada":            "remada-curvada-com-barra",
        "Remada curvada":    "remada-curvada-com-barra",
        "Puxada":            "puxada-alta-pegada-aberta",
        "Barra fixa":        "barra-fixa",
        "Levantamento terra": "levantamento-terra",

        // ── Ombros e trapézio ───────────────────────────────────────────────
        "Desenvolvimento":   "desenvolvimento-com-halteres",
        "Elevação lateral":  "elevacao-lateral-com-halteres",
        "Encolhimento":      "encolhimento-de-ombros-com-halteres",

        // ── Braços ──────────────────────────────────────────────────────────
        "Rosca":             "rosca-direta-com-barra",
        "Rosca direta":      "rosca-direta-com-barra",
        // Polia com corda. A ficha existe e TEM foto (`tricep-pushdown-*`).
        "Tríceps corda":     "triceps-pulley-com-corda",

        // ── Pernas ──────────────────────────────────────────────────────────
        "Agachamento":       "agachamento-livre",
        "Agachamento com salto": "agachamento-com-salto",
        "Afundo":            "afundo-com-halteres",
        "Leg press":         "leg-press-45",
        "Cadeira extensora": "cadeira-extensora",
        "Panturrilha":       "panturrilha-em-pe",
        "Stiff":             "stiff-com-halteres",

        // ── Core ────────────────────────────────────────────────────────────
        "Core":              "prancha",
        "Prancha":           "prancha",
        "Abdominais":        "abdominal-crunch",
        "Mountain climbers": "mountain-climbers",

        // ── Cardio e condicionamento ────────────────────────────────────────
        // "Caminhada 40min"/"Corrida leve 30min" trazem a duração no nome; a
        // ficha é a mesma, a duração vive no `focus` do dia.
        "Caminhada":         "caminhada-em-esteira",
        "Caminhada leve":    "caminhada-em-esteira",
        "Caminhada 40min":   "caminhada-em-esteira",
        "Corrida intervalada": "corrida-em-esteira",
        "Corrida leve 30min": "corrida-em-esteira",
        "Pedalada":          "bicicleta-ergometrica",
        "Polichinelos":      "polichinelos",
        "Burpees":           "burpee",
        "Burpees 4x30s":     "burpee",

        // ── Mobilidade e respiração ─────────────────────────────────────────
        "Alongamento":       "alongamento-de-isquiotibiais-em-pe",
        "Mobilidade":        "mobilidade-de-ombro-rotacao",
        "Respiração":        "respiracao-diafragmatica",
        "Yoga":              "saudacao-ao-sol-yoga"

        // NÃO ESTÃO AQUI, de propósito: "Esporte", "Recuperação",
        // "Recuperação total". Não são exercícios — são rótulos de dia de
        // descanso, e mapeá-los para "Caminhada em esteira" seria inventar de
        // novo, só que mais devagar. O gerador local deixou de emiti-los
        // (`AIBodyScan.week(for:)`); se a IA emitir, o dia fica sem aquela
        // linha, que é o certo para um dia de descanso.
    ]
}

/// Slugs que mudaram de nome exibido, do ANTIGO para o ATUAL.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// ⛔ ESTÁ VAZIO, E ISSO É O RESULTADO DE UMA MEDIÇÃO (2026-09-03)
///
/// **Nenhum exercício dos 1.095 pode ser renomeado hoje sem perder o histórico
/// de séries de quem já treinou aquele exercício.** Não é opinião: está medido
/// em `_scripts/prova_rename_crucifixo.swift`, que carrega bytes no formato
/// gravado e mede o que sai. Rode antes de discordar.
///
/// ── O ACHADO, QUE É CONTRAINTUITIVO ───────────────────────────────────────
///
/// A chave do histórico **não é o `id` do `exercises_v2.json`**. O `id` não é
/// persistido em lugar nenhum — `asLegacyExercise()` o descarta, e o `Exercise`
/// gravado em `customWorkouts` guarda só o NOME (asserção W2 da prova).
///
/// O que se grava é `slugDeExercicio(nome)`, calculado do NOME EXIBIDO na hora
/// da escrita (`RegrasDeSeries.montar`) e recalculado do nome exibido na hora
/// da leitura (`WorkoutSessionView`, `ultima(exercicioSlug:)`). São as duas
/// únicas pontas.
///
/// Logo: **renomear só o `namePTBR`, deixando o `id` em paz, quebra
/// exatamente igual.** Congelar o `id` dá a sensação de estar protegendo o
/// histórico e não protege nada — protegeria se o `id` participasse da
/// escrita, e ele não participa. Medido: a série gravada sob "Crucifixo"
/// (slug `crucifixo`) deixa de ser encontrada assim que a tela passa a
/// procurar pelo nome novo (asserção S3, com controle positivo em S4).
///
/// ── O QUE FARIA UM RENAME SER SEGURO ──────────────────────────────────────
///
/// Preencher este mapa NÃO basta, e a prova mostra por quê (asserção A2): ele
/// mapeia velho→novo, e o que está no disco é o VELHO. Resgatar o histórico
/// exige que a LEITURA procure também pelos slugs antigos — isto é,
/// `ultima(exercicioSlug:)` teria de consultar o conjunto {slug atual} ∪
/// {slugs antigos que apontam para ele}. É pouca linha, mas mexe no caminho de
/// leitura de dado persistido, e não se faz de passagem: se um dia for
/// necessário, faz-se com a prova reescrita para exigir S3 VERDE.
///
/// Enquanto isso não existir, este mapa fica vazio e `atual(_:)` é a
/// identidade. As chamadas ficam de propósito, para que o dia em que alguém
/// implementar a migração já encontre os pontos de aplicação no lugar.
/// ═══════════════════════════════════════════════════════════════════════════
enum SlugsRenomeados {
    static let de: [String: String] = [:]

    /// O slug atual de um slug possivelmente antigo. Identidade quando não mudou.
    static func atual(_ slug: String) -> String { de[slug] ?? slug }
}

func slugDeExercicio(_ nome: String) -> String {
    let folded = nome.folding(options: [.diacriticInsensitive, .caseInsensitive],
                              locale: Locale(identifier: "pt_BR"))
    let allowed = folded.lowercased().map { ch -> Character in
        (ch.isLetter || ch.isNumber) ? ch : "-"
    }
    return String(allowed).split(separator: "-").joined(separator: "-")
}
