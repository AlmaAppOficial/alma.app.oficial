import Foundation
import Combine

// MARK: - Mood Types
enum Mood: String, Codable, CaseIterable {
    case ansioso = "Ansioso"
    case estressado = "Estressado"
    case cansado = "Cansado"
    case triste = "Triste"
    case agitado = "Agitado"
    case focado = "Focado"
    case grato = "Grato"
    case neutro = "Neutro"

    var emoji: String {
        switch self {
        case .ansioso: return "😰"
        case .estressado: return "😫"
        case .cansado: return "😴"
        case .triste: return "😢"
        case .agitado: return "⚡"
        case .focado: return "🎯"
        case .grato: return "🙏"
        case .neutro: return "😐"
        }
    }

    var portuguese: String {
        self.rawValue
    }
}

// MARK: - Mood Context
struct MoodContext: Codable {
    let timeOfDay: TimeOfDay
    let dayOfWeek: String
    let location: String?
    let trigger: String?
    let timestamp: Date

    enum TimeOfDay: String, Codable {
        case morning, afternoon, evening, night
    }
}

// MARK: - Mood Entry
struct MoodEntry: Codable, Identifiable {
    let id: UUID
    let mood: Mood
    let intensity: Int // 1-10
    let context: MoodContext
    let notes: String?
    let timestamp: Date

    init(mood: Mood, intensity: Int, context: MoodContext, notes: String? = nil) {
        self.id = UUID()
        self.mood = mood
        self.intensity = intensity
        self.context = context
        self.notes = notes
        self.timestamp = context.timestamp
    }
}

// MARK: - Meditation Recommendation
struct MeditationRecommendation: Identifiable {
    let id: UUID = UUID()
    let meditationType: String
    let duration: Int // in minutes
    let title: String
    let description: String
    let sequence: [MeditationPhase]
    let reasoning: String // Portuguese explanation
    let tags: [String]

    struct MeditationPhase {
        let name: String
        let duration: Int
        let instructions: String
    }
}

// MARK: - Mood Pattern
struct MoodPattern: Identifiable {
    let id: UUID = UUID()
    let pattern: String // Portuguese description
    let frequency: Double // 0.0 to 1.0
    let timeRange: DateInterval?
    let confidenceScore: Double
}

// MARK: - MoodRouter Actor
actor MoodRouter {

    // MARK: - State
    private var moodHistory: [MoodEntry] = []
    private var meditationResponses: [UUID: TimeInterval] = [:]

    // Keep a reference to AnalyticsManager for event tracking
    let analyticsManager: AnalyticsManager?

    // MARK: - Init
    init(analyticsManager: AnalyticsManager? = nil) {
        self.analyticsManager = analyticsManager
        self.moodHistory = loadMoodHistory()
    }

    // MARK: - Core Functions

    /// Main function: routes user to appropriate meditation based on mood
    func recommendMeditation(
        mood: Mood,
        timeAvailable: Int,
        streak: Int
    ) async -> MeditationRecommendation {
        let context = MoodContext(
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getDayOfWeek(),
            location: nil,
            trigger: nil,
            timestamp: Date()
        )

        let recommendation = buildRecommendation(
            for: mood,
            intensity: 5, // default mid-range
            timeAvailable: timeAvailable,
            streak: streak,
            context: context
        )

        // Track in analytics
        await analyticsManager?.logEvent(.moodLogged(mood: mood.rawValue, intensity: 5))

        return recommendation
    }

    /// Full recommendation with intensity
    func recommendMeditation(
        mood: Mood,
        intensity: Int,
        timeAvailable: Int,
        streak: Int
    ) async -> MeditationRecommendation {
        let context = MoodContext(
            timeOfDay: getCurrentTimeOfDay(),
            dayOfWeek: getDayOfWeek(),
            location: nil,
            trigger: nil,
            timestamp: Date()
        )

        let recommendation = buildRecommendation(
            for: mood,
            intensity: intensity,
            timeAvailable: timeAvailable,
            streak: streak,
            context: context
        )

        await analyticsManager?.logEvent(.moodLogged(mood: mood.rawValue, intensity: intensity))

        return recommendation
    }

    /// Log mood entry
    func logMood(_ mood: Mood, intensity: Int, context: MoodContext, notes: String? = nil) async {
        let entry = MoodEntry(mood: mood, intensity: intensity, context: context, notes: notes)
        moodHistory.append(entry)
        saveMoodHistory()

        await analyticsManager?.logEvent(.moodLogged(mood: mood.rawValue, intensity: intensity))
    }

    /// Get mood history
    func getMoodHistory(days: Int) async -> [MoodEntry] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        return moodHistory.filter { $0.timestamp >= cutoffDate }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Detect patterns in mood data
    func detectPatterns() async -> [MoodPattern] {
        guard moodHistory.count >= 5 else { return [] }

        var patterns: [MoodPattern] = []

        // Pattern 1: Day of week analysis
        let dayPatterns = analyzeByDayOfWeek()
        patterns.append(contentsOf: dayPatterns)

        // Pattern 2: Time of day analysis
        let timePatterns = analyzeByTimeOfDay()
        patterns.append(contentsOf: timePatterns)

        // Pattern 3: Mood transitions
        let transitionPatterns = analyzeMoodTransitions()
        patterns.append(contentsOf: transitionPatterns)

        return patterns
    }

    /// Get meditation impact: how much mood improved after meditation
    func getMeditationImpact() async -> [String: Double] {
        var impacts: [String: Double] = [:]

        // Analyze mood improvement within same day after meditation
        let recentDays = await getMoodHistory(days: 30)

        if recentDays.count >= 2 {
            var improvementByMood: [String: [Int]] = [:]

            for i in 0..<(recentDays.count - 1) {
                let current = recentDays[i]
                let next = recentDays[i + 1]

                // Only count if within 2 hours (likely meditation impact)
                if next.timestamp.timeIntervalSince(current.timestamp) < 7200 {
                    let key = current.mood.rawValue
                    if improvementByMood[key] == nil {
                        improvementByMood[key] = []
                    }
                    let improvement = next.intensity - current.intensity
                    improvementByMood[key]?.append(improvement)
                }
            }

            // Calculate averages
            for (mood, improvements) in improvementByMood {
                let average = Double(improvements.reduce(0, +)) / Double(improvements.count)
                impacts[mood] = average
            }
        }

        return impacts
    }

    // MARK: - Private Helpers

    private func buildRecommendation(
        for mood: Mood,
        intensity: Int,
        timeAvailable: Int,
        streak: Int,
        context: MoodContext
    ) -> MeditationRecommendation {
        switch mood {
        case .ansioso, .estressado:
            return buildAnxietyRecommendation(intensity: intensity, timeAvailable: timeAvailable)
        case .cansado, .triste:
            return buildEnergyRecommendation(for: mood, intensity: intensity, timeAvailable: timeAvailable)
        case .agitado:
            return buildGroundingRecommendation(intensity: intensity, timeAvailable: timeAvailable)
        case .focado:
            return buildProductivityRecommendation(timeAvailable: timeAvailable)
        case .grato:
            return buildAppreciationRecommendation(timeAvailable: timeAvailable)
        case .neutro:
            return buildStreakBasedRecommendation(streak: streak, timeAvailable: timeAvailable)
        }
    }

    private func buildAnxietyRecommendation(
        intensity: Int,
        timeAvailable: Int
    ) -> MeditationRecommendation {
        let phases: [MeditationRecommendation.MeditationPhase] = [
            .init(
                name: "Respiração 4-7-8",
                duration: 5,
                instructions: "Respire por 4 tempos, segure por 7, solte por 8. Repita 4 vezes."
            ),
            .init(
                name: "Meditação de Aterramento",
                duration: timeAvailable > 10 ? 10 : 5,
                instructions: "Sinta seus 5 sentidos: identifique 5 coisas que vê, 4 que toca, 3 que ouve, 2 que cheira, 1 que saboreia."
            )
        ]

        let duration = min(timeAvailable, 15)

        return MeditationRecommendation(
            meditationType: "anxiety_relief",
            duration: duration,
            title: "Acalme sua Ansiedade",
            description: "Sessão de respiração e aterramento especialmente projetada para aliviar a ansiedade",
            sequence: phases,
            reasoning: "Você está ansioso. Preparei uma sessão de respiração 4-7-8 seguida de meditação de aterramento — isso ativa seu sistema nervoso parassimpático e traz você de volta ao presente.",
            tags: ["respiração", "aterramento", "ansiedade"]
        )
    }

    private func buildEnergyRecommendation(
        for mood: Mood,
        intensity: Int,
        timeAvailable: Int
    ) -> MeditationRecommendation {
        let isTriste = mood == .triste
        let name = isTriste ? "Meditação Compaixão & Gratidão" : "Energização Gentil"
        let phase1Name = isTriste ? "Meditação de Auto-Compaixão" : "Energização Suave"
        let phase2Name = isTriste ? "Meditação de Gratidão" : "Movimento Consciente"

        let phases: [MeditationRecommendation.MeditationPhase] = [
            .init(
                name: phase1Name,
                duration: timeAvailable > 10 ? 8 : 5,
                instructions: isTriste
                    ? "Coloque a mão no coração. Diga: 'Eu cuido de mim. Sou digno de amor e gentileza.'"
                    : "Comece com respirações profundas e alongamentos suaves."
            ),
            .init(
                name: phase2Name,
                duration: timeAvailable > 10 ? 8 : 5,
                instructions: isTriste
                    ? "Liste 3 coisas pelas quais é grato, mesmo que pequenas."
                    : "Caminhada consciente ou movimentos leves para despertar a vitalidade."
            )
        ]

        let duration = min(timeAvailable, 16)

        return MeditationRecommendation(
            meditationType: isTriste ? "compassion" : "energy",
            duration: duration,
            title: name,
            description: isTriste
                ? "Cultive compaixão por si mesmo e gratidão"
                : "Desperte sua energia de forma gentil e sustentável",
            sequence: phases,
            reasoning: isTriste
                ? "Você está triste. Vou guiá-lo através de auto-compaixão e gratidão — estudos mostram que isso muda sua neurobiologia."
                : "Você está cansado. Uma energização suave (não intensa) vai restaurar sua vitalidade sem esgotar você ainda mais.",
            tags: isTriste ? ["compassão", "gratidão", "tristeza"] : ["energia", "cansaço", "movimento"]
        )
    }

    private func buildGroundingRecommendation(
        intensity: Int,
        timeAvailable: Int
    ) -> MeditationRecommendation {
        let phases: [MeditationRecommendation.MeditationPhase] = [
            .init(
                name: "Varredura Corporal",
                duration: timeAvailable > 10 ? 8 : 5,
                instructions: "Escaneie seu corpo de cima para baixo, observando sensações sem julgamento."
            ),
            .init(
                name: "Âncora de Respiração",
                duration: timeAvailable > 10 ? 7 : 5,
                instructions: "Traga atenção para a respiração. Conte 10 respirações completas."
            )
        ]

        let duration = min(timeAvailable, 15)

        return MeditationRecommendation(
            meditationType: "grounding",
            duration: duration,
            title: "Traga-se ao Presente",
            description: "Técnicas de aterramento para acalmar a agitação e restaurar o foco",
            sequence: phases,
            reasoning: "Você está agitado — muita energia sem direção. Varredura corporal + âncora de respiração traz você de volta ao corpo e ao presente.",
            tags: ["aterramento", "foco", "agitação"]
        )
    }

    private func buildProductivityRecommendation(
        timeAvailable: Int
    ) -> MeditationRecommendation {
        let duration = min(timeAvailable, 15)

        let phases: [MeditationRecommendation.MeditationPhase] = [
            .init(
                name: "Clareza Mental",
                duration: 3,
                instructions: "Identifique sua tarefa principal. Visualize completando-a com sucesso."
            ),
            .init(
                name: "Meditação de Foco",
                duration: duration - 3,
                instructions: "Mantenha a atenção no presente. Quando divagar, retorne suavemente."
            )
        ]

        return MeditationRecommendation(
            meditationType: "productivity",
            duration: duration,
            title: "Foco Cristalino",
            description: "Alinhe sua mente com sua intenção e aproveite o estado de fluxo",
            sequence: phases,
            reasoning: "Você está em modo focado — vou ajudar você a cristalizar sua intenção e entrar em estado de fluxo para máxima produtividade.",
            tags: ["produtividade", "foco", "concentração"]
        )
    }

    private func buildAppreciationRecommendation(
        timeAvailable: Int
    ) -> MeditationRecommendation {
        let duration = min(timeAvailable, 12)

        let phases: [MeditationRecommendation.MeditationPhase] = [
            .init(
                name: "Meditação de Gratidão",
                duration: duration,
                instructions: "Pense em 3 momentos pequenos pelo quais está grato. Sinta a gratidão no corpo."
            )
        ]

        return MeditationRecommendation(
            meditationType: "appreciation",
            duration: duration,
            title: "Celebre sua Gratidão",
            description: "Aprofunde seu estado de gratidão com uma meditação de apreciação",
            sequence: phases,
            reasoning: "Você está em um estado positivo! Vou amplificar isso com uma meditação de gratidão que solidifica sua resiliência emocional.",
            tags: ["gratidão", "apreciação", "positividade"]
        )
    }

    private func buildStreakBasedRecommendation(
        streak: Int,
        timeAvailable: Int
    ) -> MeditationRecommendation {
        // Vary based on streak position
        let isEarlyStreak = streak % 10 < 3
        let isMilestone = streak % 10 == 0

        if isMilestone {
            let duration = min(timeAvailable, 20)
            let phases: [MeditationRecommendation.MeditationPhase] = [
                .init(
                    name: "Reflexão & Celebração",
                    duration: duration,
                    instructions: "Reflita sobre sua jornada nos últimos dias. Celebre sua dedicação."
                )
            ]

            return MeditationRecommendation(
                meditationType: "milestone",
                duration: duration,
                title: "Marco de \(streak) Dias!",
                description: "Uma meditação especial para celebrar seu comprometimento",
                sequence: phases,
                reasoning: "Parabéns! Você atingiu \(streak) dias. Esta meditação celebra sua resiliência e reforça seu compromisso com bem-estar.",
                tags: ["marco", "celebração", "streak"]
            )
        } else {
            let duration = min(timeAvailable, 10)
            let phases: [MeditationRecommendation.MeditationPhase] = [
                .init(
                    name: "Renovação",
                    duration: duration,
                    instructions: "Respire a intenção de manter sua sequência. Visualize seu sucesso."
                )
            ]

            return MeditationRecommendation(
                meditationType: "streak_maintenance",
                duration: duration,
                title: "Renovação Diária",
                description: "Reforçe seu compromisso com sua prática diária",
                sequence: phases,
                reasoning: "Dia \(streak) da sua sequência! Esta meditação rápida renova seu compromisso e mantém seu momentum.",
                tags: ["renovação", "rotina", "streak"]
            )
        }
    }

    // MARK: - Pattern Analysis

    private func analyzeByDayOfWeek() -> [MoodPattern] {
        var dayMoods: [String: [Mood]] = [:]
        var dayIntensities: [String: [Int]] = [:]

        for entry in moodHistory {
            let day = entry.context.dayOfWeek
            dayMoods[day, default: []].append(entry.mood)
            dayIntensities[day, default: []].append(entry.intensity)
        }

        var patterns: [MoodPattern] = []
        let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let portugueseDays = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]

        for (index, day) in daysOfWeek.enumerated() {
            guard let moods = dayMoods[day], !moods.isEmpty else { continue }

            let moodCounts = Dictionary(groupingBy: moods, { $0 })
                .mapValues { $0.count }

            if let (dominantMood, count) = moodCounts.max(by: { $0.value < $1.value }) {
                let frequency = Double(count) / Double(moods.count)

                if frequency > 0.4 {
                    let pattern = "Você geralmente fica mais \(dominantMood.portuguese.lowercased()) nas \(portugueseDays[index])s"
                    patterns.append(MoodPattern(
                        pattern: pattern,
                        frequency: frequency,
                        timeRange: nil,
                        confidenceScore: frequency
                    ))
                }
            }
        }

        return patterns
    }

    private func analyzeByTimeOfDay() -> [MoodPattern] {
        var timeOfDayMoods: [MoodContext.TimeOfDay: [Mood]] = [:]
        var timeOfDayIntensities: [MoodContext.TimeOfDay: [Int]] = [:]

        for entry in moodHistory {
            let timeOfDay = entry.context.timeOfDay
            timeOfDayMoods[timeOfDay, default: []].append(entry.mood)
            timeOfDayIntensities[timeOfDay, default: []].append(entry.intensity)
        }

        var patterns: [MoodPattern] = []

        let timeLabels: [MoodContext.TimeOfDay: String] = [
            .morning: "pela manhã",
            .afternoon: "à tarde",
            .evening: "à noite",
            .night: "durante a noite"
        ]

        for (timeOfDay, label) in timeLabels {
            guard let moods = timeOfDayMoods[timeOfDay], !moods.isEmpty else { continue }

            let avgIntensity = Double(timeOfDayIntensities[timeOfDay, default: []].reduce(0, +))
                / Double(moods.count)

            if avgIntensity > 6.5 {
                let pattern = "Sua ansiedade tende a aumentar \(label)"
                patterns.append(MoodPattern(
                    pattern: pattern,
                    frequency: avgIntensity / 10.0,
                    timeRange: nil,
                    confidenceScore: avgIntensity / 10.0
                ))
            }
        }

        return patterns
    }

    private func analyzeMoodTransitions() -> [MoodPattern] {
        guard moodHistory.count >= 5 else { return [] }

        var transitions: [String: Int] = [:]

        for i in 0..<(moodHistory.count - 1) {
            let from = moodHistory[i].mood.rawValue
            let to = moodHistory[i + 1].mood.rawValue
            let key = "\(from) → \(to)"
            transitions[key, default: 0] += 1
        }

        var patterns: [MoodPattern] = []

        for (transition, count) in transitions {
            if count >= 2 {
                let pattern = "Você frequentemente passa de \(transition)"
                patterns.append(MoodPattern(
                    pattern: pattern,
                    frequency: Double(count) / Double(moodHistory.count),
                    timeRange: nil,
                    confidenceScore: Double(count) / Double(moodHistory.count)
                ))
            }
        }

        return patterns.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    // MARK: - Utility Functions

    private func getCurrentTimeOfDay() -> MoodContext.TimeOfDay {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    private func getDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    // MARK: - Persistence

    private func saveMoodHistory() {
        guard let encoded = try? JSONEncoder().encode(moodHistory) else { return }
        UserDefaults.standard.set(encoded, forKey: "moodHistory")
    }

    private func loadMoodHistory() -> [MoodEntry] {
        guard let data = UserDefaults.standard.data(forKey: "moodHistory") else { return [] }
        return (try? JSONDecoder().decode([MoodEntry].self, from: data)) ?? []
    }
}
