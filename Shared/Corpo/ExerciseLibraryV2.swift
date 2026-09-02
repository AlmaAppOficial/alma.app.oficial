//
//  ExerciseLibraryV2.swift
//  CorpoEAlma
//
//  Biblioteca de Exercícios 2.0 — modelo tipado, taxonomia de músculos
//  frente/costas e catálogo em JSON no bundle.
//
//  REGRAS DE COMPATIBILIDADE (não quebrar treinos salvos):
//  1. O struct legado `Exercise` e o formato persistido de `customWorkouts`
//     NÃO mudam nesta fase. A UI nova converte na borda (V2 -> legado ao
//     salvar; legado -> V2 ao exibir) via `asLegacyExercise()` / `init(legacy:)`.
//  2. `ExerciseV2.init(from:)` é tolerante: decodifica tanto o formato novo
//     quanto o legado, para permitir uma futura migração do storage sem risco.
//
//  Conteúdo importado: free-exercise-db (Unlicense / domínio público)
//  https://github.com/yuhonas/free-exercise-db — traduzido para PT-BR.
//

import SwiftUI

// MARK: - Taxonomia nível 1 (16 grupos tocáveis no mapa)

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    // Frente
    case peito, ombros, biceps, antebraco, abdomen, obliquos
    case quadriceps, adutores
    // Costas
    case trapezio, costas, lombar, triceps, gluteos, posteriorCoxa
    // Visível dos dois lados no mapa (desenhada atrás)
    case panturrilha
    // Pescoço (importação "neck"; região pequena no topo do mapa)
    case pescoco

    var id: String { rawValue }

    /// Zona do mapa em que o grupo é desenhado.
    var isFront: Bool {
        switch self {
        case .peito, .ombros, .biceps, .antebraco, .abdomen, .obliquos,
             .quadriceps, .adutores, .pescoco:
            return true
        case .trapezio, .costas, .lombar, .triceps, .gluteos,
             .posteriorCoxa, .panturrilha:
            return false
        }
    }

    var namePTBR: String {
        switch self {
        case .peito:         return "Peito"
        case .ombros:        return "Ombros"
        case .biceps:        return "Bíceps"
        case .antebraco:     return "Antebraço"
        case .abdomen:       return "Abdômen"
        case .obliquos:      return "Oblíquos"
        case .quadriceps:    return "Quadríceps"
        case .adutores:      return "Adutores"
        case .trapezio:      return "Trapézio"
        case .costas:        return "Costas"
        case .lombar:        return "Lombar"
        case .triceps:       return "Tríceps"
        case .gluteos:       return "Glúteos"
        case .posteriorCoxa: return "Posterior de coxa"
        case .panturrilha:   return "Panturrilha"
        case .pescoco:       return "Pescoço"
        }
    }

    /// SF Symbol de fallback quando o exercício não tem mídia.
    var fallbackSymbol: String {
        switch self {
        case .peito, .ombros, .triceps:      return "figure.strengthtraining.traditional"
        case .biceps, .antebraco:            return "dumbbell.fill"
        case .abdomen, .obliquos:            return "figure.core.training"
        case .quadriceps, .adutores,
             .gluteos, .posteriorCoxa:       return "figure.strengthtraining.functional"
        case .panturrilha:                   return "figure.walk"
        case .trapezio, .costas, .lombar:    return "figure.rower"
        case .pescoco:                       return "figure.flexibility"
        }
    }
}

// MARK: - Tipo, dificuldade e mídia

enum ExerciseType: String, Codable, CaseIterable, Identifiable, Hashable {
    case forca, cardio, alongamento, mobilidade, yogaPilates

    var id: String { rawValue }

    var namePTBR: String {
        switch self {
        case .forca:       return "Força"
        case .cardio:      return "Cardio"
        case .alongamento: return "Alongamento"
        case .mobilidade:  return "Mobilidade"
        case .yogaPilates: return "Yoga & Pilates"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable, Hashable {
    case iniciante, intermediario, avancado

    var id: String { rawValue }

    var namePTBR: String {
        switch self {
        case .iniciante:     return "Iniciante"
        case .intermediario: return "Intermediário"
        case .avancado:      return "Avançado"
        }
    }

    var tint: Color {
        switch self {
        case .iniciante:     return .green
        case .intermediario: return .orange
        case .avancado:      return .red
        }
    }

    /// Aceita os níveis da fonte (free-exercise-db: beginner/intermediate/expert).
    init(sourceLevel: String?) {
        switch sourceLevel?.lowercased() {
        case "beginner":               self = .iniciante
        case "intermediate":           self = .intermediario
        case "expert", "advanced":     self = .avancado
        default:                       self = .iniciante
        }
    }
}

/// Mídia do exercício, pensada para transição gradual:
/// legado (SF Symbol) → fotos remotas com cache (Fase 1) → GIF/vídeo (Fase 2).
enum ExerciseMedia: Codable, Hashable {
    case sfSymbol(String)
    case remoteImages([URL])   // CDN + cache local (URLCache)
    case animatedGif(URL)
    case video(URL)

    private enum CodingKeys: String, CodingKey { case kind, value, values }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "sfSymbol":
            self = .sfSymbol(try c.decode(String.self, forKey: .value))
        case "remoteImages":
            self = .remoteImages(try c.decode([URL].self, forKey: .values))
        case "animatedGif":
            self = .animatedGif(try c.decode(URL.self, forKey: .value))
        case "video":
            self = .video(try c.decode(URL.self, forKey: .value))
        default:
            self = .sfSymbol("figure.strengthtraining.traditional")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sfSymbol(let s):
            try c.encode("sfSymbol", forKey: .kind)
            try c.encode(s, forKey: .value)
        case .remoteImages(let urls):
            try c.encode("remoteImages", forKey: .kind)
            try c.encode(urls, forKey: .values)
        case .animatedGif(let u):
            try c.encode("animatedGif", forKey: .kind)
            try c.encode(u, forKey: .value)
        case .video(let u):
            try c.encode("video", forKey: .kind)
            try c.encode(u, forKey: .value)
        }
    }

    var firstImageURL: URL? {
        if case .remoteImages(let urls) = self { return urls.first }
        return nil
    }

    var sfSymbolName: String? {
        if case .sfSymbol(let s) = self { return s }
        return nil
    }
}

// MARK: - ExerciseV2

struct ExerciseV2: Identifiable, Codable, Hashable {
    let id: String                     // slug estável, ex.: "supino-com-halteres"
    let namePTBR: String
    let nameEN: String?
    let type: ExerciseType
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let difficulty: Difficulty
    let mechanics: String?             // "composto" | "isolado"
    let force: String?                 // "empurrar" | "puxar" | "estático"
    let media: ExerciseMedia
    let instructions: [String]
    let defaultSets: Int
    let defaultReps: String
    let sourceAttribution: String      // ex.: "free-exercise-db (Unlicense)"

    var displaySymbol: String {
        media.sfSymbolName
            ?? primaryMuscles.first?.fallbackSymbol
            ?? "figure.strengthtraining.traditional"
    }

    // Decode tolerante: aceita o formato novo E o formato do `Exercise` legado
    // (name/sets/reps/equipment/muscle/symbol/instructions) para viabilizar,
    // no futuro, migrar o storage sem quebrar dados antigos.
    private enum CodingKeys: String, CodingKey {
        case id, namePTBR, nameEN, type, primaryMuscles, secondaryMuscles
        case equipment, difficulty, mechanics, force, media, instructions
        case defaultSets, defaultReps, sourceAttribution
        // chaves do formato legado
        case name, sets, reps, muscle, symbol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let modernName = try c.decodeIfPresent(String.self, forKey: .namePTBR) {
            // Formato novo
            id               = try c.decode(String.self, forKey: .id)
            namePTBR         = modernName
            nameEN           = try c.decodeIfPresent(String.self, forKey: .nameEN)
            type             = try c.decodeIfPresent(ExerciseType.self, forKey: .type) ?? .forca
            primaryMuscles   = try c.decodeIfPresent([MuscleGroup].self, forKey: .primaryMuscles) ?? []
            secondaryMuscles = try c.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscles) ?? []
            equipment        = try c.decodeIfPresent(Equipment.self, forKey: .equipment) ?? .corporal
            difficulty       = try c.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .iniciante
            mechanics        = try c.decodeIfPresent(String.self, forKey: .mechanics)
            force            = try c.decodeIfPresent(String.self, forKey: .force)
            media            = try c.decodeIfPresent(ExerciseMedia.self, forKey: .media)
                               ?? .sfSymbol("figure.strengthtraining.traditional")
            instructions     = try c.decodeIfPresent([String].self, forKey: .instructions) ?? []
            defaultSets      = try c.decodeIfPresent(Int.self, forKey: .defaultSets) ?? 3
            defaultReps      = try c.decodeIfPresent(String.self, forKey: .defaultReps) ?? "12 reps"
            sourceAttribution = try c.decodeIfPresent(String.self, forKey: .sourceAttribution) ?? "catálogo C&A"
        } else {
            // Formato legado (Exercise antigo serializado)
            let legacyName   = try c.decode(String.self, forKey: .name)
            let muscleText   = try c.decodeIfPresent(String.self, forKey: .muscle) ?? ""
            let groups       = MuscleClassifier.classify(muscleText, name: legacyName)
            namePTBR         = legacyName
            id               = ExerciseV2.slug(for: legacyName)
            nameEN           = nil
            type             = .forca
            primaryMuscles   = groups.primary
            secondaryMuscles = groups.secondary
            equipment        = try c.decodeIfPresent(Equipment.self, forKey: .equipment) ?? .corporal
            difficulty       = .iniciante
            mechanics        = nil
            force            = nil
            media            = .sfSymbol(try c.decodeIfPresent(String.self, forKey: .symbol)
                                         ?? "figure.strengthtraining.traditional")
            instructions     = try c.decodeIfPresent([String].self, forKey: .instructions) ?? []
            defaultSets      = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
            defaultReps      = try c.decodeIfPresent(String.self, forKey: .reps) ?? "12 reps"
            sourceAttribution = "catálogo C&A (legado)"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(namePTBR, forKey: .namePTBR)
        try c.encodeIfPresent(nameEN, forKey: .nameEN)
        try c.encode(type, forKey: .type)
        try c.encode(primaryMuscles, forKey: .primaryMuscles)
        try c.encode(secondaryMuscles, forKey: .secondaryMuscles)
        try c.encode(equipment, forKey: .equipment)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encodeIfPresent(mechanics, forKey: .mechanics)
        try c.encodeIfPresent(force, forKey: .force)
        try c.encode(media, forKey: .media)
        try c.encode(instructions, forKey: .instructions)
        try c.encode(defaultSets, forKey: .defaultSets)
        try c.encode(defaultReps, forKey: .defaultReps)
        try c.encode(sourceAttribution, forKey: .sourceAttribution)
    }

    init(id: String, namePTBR: String, nameEN: String?, type: ExerciseType,
         primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup],
         equipment: Equipment, difficulty: Difficulty, mechanics: String?,
         force: String?, media: ExerciseMedia, instructions: [String],
         defaultSets: Int, defaultReps: String, sourceAttribution: String) {
        self.id = id; self.namePTBR = namePTBR; self.nameEN = nameEN
        self.type = type; self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles; self.equipment = equipment
        self.difficulty = difficulty; self.mechanics = mechanics; self.force = force
        self.media = media; self.instructions = instructions
        self.defaultSets = defaultSets; self.defaultReps = defaultReps
        self.sourceAttribution = sourceAttribution
    }

    /// [2026-09-02] A regra mudou de casa: `slugDeExercicio` (`Exercicio.swift`,
    /// só Foundation), porque o registro de séries grava o slug e precisa ser
    /// exercitado fora do simulador. Este nome fica, delegando — os chamadores
    /// (`init(legacy:)`, `resolve(legacy:)`) não mudaram.
    static func slug(for name: String) -> String {
        slugDeExercicio(name)
    }
}

// MARK: - Pontes com o modelo legado (formato persistido NÃO muda)

extension ExerciseV2 {
    /// Constrói um V2 a partir do `Exercise` legado (para exibir dados antigos na UI nova).
    init(legacy e: Exercise) {
        let groups = MuscleClassifier.classify(e.muscle, name: e.name)
        self.init(id: ExerciseV2.slug(for: e.name),
                  namePTBR: e.name,
                  nameEN: nil,
                  type: .forca,
                  primaryMuscles: groups.primary,
                  secondaryMuscles: groups.secondary,
                  equipment: e.equipment,
                  difficulty: .iniciante,
                  mechanics: nil,
                  force: nil,
                  media: .sfSymbol(e.symbol),
                  instructions: e.instructions,
                  defaultSets: e.sets,
                  defaultReps: e.reps,
                  sourceAttribution: "catálogo C&A (legado)")
    }

    /// Converte para o `Exercise` legado — usado ao SALVAR em `customWorkouts`,
    /// mantendo o formato persistido idêntico ao atual (compatibilidade total).
    func asLegacyExercise() -> Exercise {
        Exercise(name: namePTBR,
                 sets: defaultSets,
                 reps: defaultReps,
                 equipment: equipment,
                 muscle: (primaryMuscles.map(\.namePTBR) + secondaryMuscles.map(\.namePTBR))
                            .joined(separator: " e "),
                 symbol: displaySymbol,
                 instructions: instructions)
    }
}

// MARK: - Classificador de strings livres de músculo (legado -> enums)

enum MuscleClassifier {
    /// Converte o campo livre `muscle` (145 valores distintos no catálogo antigo)
    /// nos grupos tipados. Usa o texto do músculo e, como reforço, o nome do exercício.
    static func classify(_ muscleText: String, name: String = "")
        -> (primary: [MuscleGroup], secondary: [MuscleGroup]) {

        let text = normalize(muscleText + " " + name)
        var found: [MuscleGroup] = []

        let table: [(keywords: [String], group: MuscleGroup)] = [
            (["peito", "peitoral", "supino", "crucifixo", "flexao"], .peito),
            (["triceps", "frances", "testa", "coice", "mergulho"], .triceps),
            (["biceps", "rosca"], .biceps),
            (["antebraco", "punho", "pegada", "grip"], .antebraco),
            (["ombro", "deltoide", "desenvolvimento", "elevacao lateral", "elevacao frontal"], .ombros),
            (["trapezio", "encolhimento", "remada alta"], .trapezio),
            (["dorsal", "dorsais", "costas", "lat ", "lats", "puxada", "remada", "barra fixa", "pull"], .costas),
            (["lombar", "eretor", "hiperextensao", "bom dia", "terra"], .lombar),
            (["abdomen", "abdominal", "core", "prancha", "reto do abdomen"], .abdomen),
            (["obliquo", "russian twist", "rotacao de tronco", "lateral do tronco"], .obliquos),
            (["quadriceps", "agachamento", "leg press", "extensora", "afundo", "avanco", "passada"], .quadriceps),
            (["adutor", "interno da coxa"], .adutores),
            (["gluteo", "elevacao pelvica", "hip thrust", "abdutor", "quadril"], .gluteos),
            (["posterior", "isquio", "flexora", "stiff", "nordica"], .posteriorCoxa),
            (["panturrilha", "gemeos", "soleo", "tibial"], .panturrilha),
            (["pescoco", "cervical"], .pescoco)
        ]

        for entry in table where entry.keywords.contains(where: { text.contains($0) }) {
            if !found.contains(entry.group) { found.append(entry.group) }
        }

        // Termos genéricos que aparecem no catálogo antigo
        if found.isEmpty {
            if text.contains("perna") { found = [.quadriceps, .gluteos] }
            else if text.contains("corpo inteiro") || text.contains("corpo todo")
                    || text.contains("full body") { found = [.quadriceps, .peito, .abdomen] }
            else if text.contains("cardio") || text.contains("aerobico") { found = [.quadriceps] }
            else if text.contains("mobilidade") || text.contains("alongamento")
                    || text.contains("postura") { found = [.lombar] }
        }
        if text.contains("perna"), !found.contains(.quadriceps) { found.append(.quadriceps) }

        guard let first = found.first else { return ([.abdomen], []) } // último recurso
        return ([first], Array(found.dropFirst()))
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                  locale: Locale(identifier: "pt_BR")).lowercased()
    }
}

// MARK: - Catálogo V2 (JSON no bundle, com fallback ao catálogo legado)

enum ExerciseCatalog {
    /// Fonte única da biblioteca nova. Carrega `exercises_v2.json` do bundle;
    /// se ausente (build intermediário), converte o `exerciseLibrary` legado.
    static let all: [ExerciseV2] = load()

    static var byGroup: [MuscleGroup: [ExerciseV2]] = {
        var dict: [MuscleGroup: [ExerciseV2]] = [:]
        for ex in all {
            for g in Set(ex.primaryMuscles) { dict[g, default: []].append(ex) }
        }
        for (g, list) in dict {
            dict[g] = list.sorted {
                ($0.difficulty.sortOrder, $0.namePTBR) < ($1.difficulty.sortOrder, $1.namePTBR)
            }
        }
        return dict
    }()

    static func exercises(for group: MuscleGroup) -> [ExerciseV2] {
        byGroup[group] ?? []
    }

    /// Busca por nome PT/EN, sem acento e caixa.
    static func search(_ term: String) -> [ExerciseV2] {
        let t = term.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        guard t.count >= 2 else { return [] }
        return all.filter {
            $0.namePTBR.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .localizedCaseInsensitiveContains(t)
            || ($0.nameEN?.localizedCaseInsensitiveContains(t) ?? false)
        }
    }

    /// Resolve um exercício legado (de treino salvo) para o V2 rico, se existir.
    static func resolve(legacy e: Exercise) -> ExerciseV2 {
        if let match = all.first(where: { $0.id == ExerciseV2.slug(for: e.name) }) {
            return match
        }
        return ExerciseV2(legacy: e)
    }

    private static func load() -> [ExerciseV2] {
        if let url = Bundle.main.url(forResource: "exercises_v2", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([ExerciseV2].self, from: data),
           !list.isEmpty {
            return list
        }
        // Fallback: catálogo legado convertido (mantém o app 100% funcional)
        return exerciseLibrary.map(ExerciseV2.init(legacy:))
    }
}

extension Difficulty {
    var sortOrder: Int {
        switch self {
        case .iniciante: return 0
        case .intermediario: return 1
        case .avancado: return 2
        }
    }
}

// MARK: - Busca unificada (lista do mapa + builder usam a MESMA regra)

extension String {
    /// Normaliza para busca: sem acentos, sem caixa (pt-BR).
    var searchNormalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive],
                locale: Locale(identifier: "pt_BR"))
    }
}

extension ExerciseV2 {
    /// Busca parcial por nome PT-BR ou EN, insensível a acento e caixa.
    /// Termos com menos de 2 caracteres não filtram.
    func matches(search term: String) -> Bool {
        let t = term.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { return true }
        let needle = t.searchNormalized
        if namePTBR.searchNormalized.contains(needle) { return true }
        if let en = nameEN, en.searchNormalized.contains(needle) { return true }
        return false
    }
}
