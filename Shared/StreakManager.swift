import Foundation
import Combine
import CloudKit

/// StreakManager - Gerencia a "Corrente de Paz" (streak de meditação)
/// Responsabilidades:
/// - Rastrear conclusões diárias de meditação
/// - Calcular streak atual
/// - Detectar e celebrar milestones
/// - Sincronizar com iCloud (CloudKit)
/// - Publicar atualizações via Combine para UI reativa
actor StreakManager: ObservableObject {

    // MARK: - Published Properties (for UI observation)
    @MainActor @Published var currentStreak: Int = 0
    @MainActor @Published var longestStreak: Int = 0
    @MainActor @Published var lastMeditationDate: Date?
    @MainActor @Published var totalMeditationDays: Int = 0
    @MainActor @Published var streakRecoveriesUsed: Int = 0
    @MainActor @Published var isMeditationCompletedToday: Bool = false
    @MainActor @Published var nextMilestone: Int?

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let cloudKitContainer: CKContainer
    private let calendar = Calendar.current
    private var cancellables = Set<AnyCancellable>()

    // Keys for UserDefaults persistence
    private let currentStreakKey = "alma_current_streak"
    private let longestStreakKey = "alma_longest_streak"
    private let lastMeditationDateKey = "alma_last_meditation_date"
    private let totalMeditationDaysKey = "alma_total_meditation_days"
    private let streakRecoveriesUsedKey = "alma_streak_recoveries_used"
    private let lastRecoveryDateKey = "alma_last_recovery_date"
    private let meditationHistoryKey = "alma_meditation_history"

    // Milestones para celebração
    private let milestones = [3, 7, 14, 21, 30, 60, 100, 365]

    // Notification
    static let streakUpdatedNotification = NSNotification.Name("StreakManagerUpdated")
    static let milestoneReachedNotification = NSNotification.Name("MilestoneReached")
    static let streakAtRiskNotification = NSNotification.Name("StreakAtRisk")

    // MARK: - Initialization
    init(container: CKContainer = CKContainer.default()) {
        self.cloudKitContainer = container
        Task {
            await loadFromStorage()
        }
    }

    // MARK: - Public API

    /// Marca uma meditação como completada para hoje
    /// Retorna true se streak foi incrementado, false se já tinha sido completado
    func recordMeditationCompletion(duration: Int = 0, mood: String = "") async -> Bool {
        let today = calendar.startOfDay(for: Date())
        let lastDate = await getLastMeditationDate()

        // Se já meditou hoje, não incrementa novamente
        if let lastDate = lastDate,
           calendar.isDate(lastDate, inSameDayAs: today) {
            return false
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Verifica se mantém streak (meditou ontem ou antes)
        let shouldIncrementStreak: Bool
        if let lastDate = lastDate {
            shouldIncrementStreak = calendar.isDate(lastDate, inSameDayAs: yesterday)
        } else {
            // Primeira meditação
            shouldIncrementStreak = true
        }

        // Atualiza streak
        let newStreak = shouldIncrementStreak ? (currentStreak + 1) : 1

        await MainActor.run {
            self.currentStreak = newStreak
            self.lastMeditationDate = today
            self.isMeditationCompletedToday = true

            if newStreak > self.longestStreak {
                self.longestStreak = newStreak
            }
        }

        // Incrementa dias totais de meditação
        let totalDays = await getTotalMeditationDays()
        await updateTotalMeditationDays(totalDays + 1)

        // Salva para persistência
        await saveToStorage()

        // Sincroniza com iCloud
        Task {
            await syncToCloudKit()
        }

        // Verifica milestones
        await checkForMilestones()

        // Notifica observers
        await notifyStreakUpdate()

        return true
    }

    /// Usa a recuperação da corrente (premium feature)
    /// Permite manter streak se perdeu 1 dia
    /// Retorna true se recovery foi bem-sucedido, false se já foi usado neste mês
    func useStreakRecovery() async -> Bool {
        // Verifica se já foi usado este mês
        let lastRecoveryDate = userDefaults.object(forKey: lastRecoveryDateKey) as? Date
        let today = calendar.startOfDay(for: Date())

        if let lastRecovery = lastRecoveryDate {
            let daysSinceRecovery = calendar.dateComponents([.day], from: lastRecovery, to: today).day ?? 0
            if daysSinceRecovery < 30 {
                return false // Já foi usado este mês
            }
        }

        // Marca a data do último uso
        userDefaults.set(today, forKey: lastRecoveryDateKey)

        let usagesCount = await getStreakRecoveriesUsed()
        await MainActor.run {
            self.streakRecoveriesUsed = usagesCount + 1
        }

        await saveToStorage()
        await syncToCloudKit()

        return true
    }

    /// Retorna o número de dias até o próximo milestone
    func daysUntilNextMilestone() async -> Int? {
        let current = await getCurrentStreak()
        let nextMilestone = milestones.first { $0 > current }

        if let next = nextMilestone {
            return next - current
        }
        return nil
    }

    /// Retorna descrição formatada do milestone
    func milestoneDescription(_ days: Int) -> String {
        let descriptions: [Int: String] = [
            3: "🌱 Seedling desbloqueado (Seu Jardim nasceu!)",
            7: "🌿 Verde - 'Iniciante da Paz'",
            14: "🌸 Flor primeira (Seu Jardim está florescendo)",
            21: "🌼 Amarelo - 'Meditador Comprometido'",
            30: "🌻 Flores cheias (Seu Jardim está lindo!)",
            60: "🌺 Roxo - 'Mestre da Serenidade'",
            100: "👑 Coroa ouro + frame perfil especial",
            365: "∞ Badge infinito + acesso VIP"
        ]

        return descriptions[days] ?? "🎉 Parabéns!"
    }

    /// Retorna status da corrente para notificações de risco
    func streakAtRiskStatus() async -> (isAtRisk: Bool, hoursRemaining: Int) {
        let lastDate = await getLastMeditationDate()
        let today = calendar.startOfDay(for: Date())

        guard let lastDate = lastDate else {
            return (false, 24)
        }

        let daysSinceLastMeditation = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0

        let isAtRisk = daysSinceLastMeditation >= 1
        let hoursRemaining = 24 - (daysSinceLastMeditation * 24)

        return (isAtRisk, max(0, hoursRemaining))
    }

    /// Reseta o streak (apenas para testes ou user reset explícito)
    func resetStreak() async {
        await MainActor.run {
            self.currentStreak = 0
            self.lastMeditationDate = nil
            self.isMeditationCompletedToday = false
        }

        await saveToStorage()
        await syncToCloudKit()
        await notifyStreakUpdate()
    }

    // MARK: - Private Helper Methods

    @MainActor
    private func getCurrentStreak() -> Int {
        return currentStreak
    }

    @MainActor
    private func getLastMeditationDate() -> Date? {
        return lastMeditationDate
    }

    @MainActor
    private func getTotalMeditationDays() -> Int {
        return totalMeditationDays
    }

    @MainActor
    private func getStreakRecoveriesUsed() -> Int {
        return streakRecoveriesUsed
    }

    private func updateTotalMeditationDays(_ days: Int) async {
        await MainActor.run {
            self.totalMeditationDays = days
        }
    }

    // MARK: - Persistence

    private func saveToStorage() async {
        let today = calendar.startOfDay(for: Date())
        let lastDate = await MainActor.run { self.lastMeditationDate }
        let streak = await MainActor.run { self.currentStreak }
        let longest = await MainActor.run { self.longestStreak }
        let total = await MainActor.run { self.totalMeditationDays }
        let recoveries = await MainActor.run { self.streakRecoveriesUsed }

        userDefaults.set(streak, forKey: currentStreakKey)
        userDefaults.set(longest, forKey: longestStreakKey)
        userDefaults.set(lastDate, forKey: lastMeditationDateKey)
        userDefaults.set(total, forKey: totalMeditationDaysKey)
        userDefaults.set(recoveries, forKey: streakRecoveriesUsedKey)

        // Adiciona ao histórico
        addToMeditationHistory(date: lastDate ?? today)
    }

    private func loadFromStorage() async {
        let streak = userDefaults.integer(forKey: currentStreakKey)
        let longest = userDefaults.integer(forKey: longestStreakKey)
        let lastDate = userDefaults.object(forKey: lastMeditationDateKey) as? Date
        let total = userDefaults.integer(forKey: totalMeditationDaysKey)
        let recoveries = userDefaults.integer(forKey: streakRecoveriesUsedKey)

        await MainActor.run {
            self.currentStreak = streak
            self.longestStreak = longest
            self.lastMeditationDate = lastDate
            self.totalMeditationDays = total
            self.streakRecoveriesUsed = recoveries

            // Verifica se já meditou hoje
            if let lastDate = lastDate {
                let today = self.calendar.startOfDay(for: Date())
                self.isMeditationCompletedToday = self.calendar.isDate(lastDate, inSameDayAs: today)
            }
        }

        // Valida integridade do streak
        await validateStreakIntegrity()
    }

    // MARK: - CloudKit Sync

    private func syncToCloudKit() async {
        let streak = await MainActor.run { self.currentStreak }
        let longest = await MainActor.run { self.longestStreak }
        let lastDate = await MainActor.run { self.lastMeditationDate }
        let total = await MainActor.run { self.totalMeditationDays }

        let record = CKRecord(recordType: "StreakData")
        record["currentStreak"] = streak as NSNumber
        record["longestStreak"] = longest as NSNumber
        record["lastMeditationDate"] = lastDate as? NSDate
        record["totalMeditationDays"] = total as NSNumber

        Task {
            do {
                try await cloudKitContainer.publicCloudDatabase.save(record)
            } catch {
                print("CloudKit sync error: \(error)")
                // Fallback to local storage is already done
            }
        }
    }

    // MARK: - Streak Validation

    private func validateStreakIntegrity() async {
        let today = calendar.startOfDay(for: Date())
        let lastDate = await MainActor.run { self.lastMeditationDate }

        guard let lastDate = lastDate else {
            return
        }

        let daysSinceLastMeditation = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0

        // Se passaram mais de 1 dia, quebra o streak
        if daysSinceLastMeditation > 1 {
            let streak = await MainActor.run { self.currentStreak }
            if streak > 0 {
                await MainActor.run {
                    self.currentStreak = 0
                }
                await saveToStorage()
            }
        }
    }

    // MARK: - Milestone Detection

    private func checkForMilestones() async {
        let streak = await MainActor.run { self.currentStreak }

        for milestone in milestones {
            if streak == milestone {
                await MainActor.run {
                    self.nextMilestone = nil
                }
                NotificationCenter.default.post(
                    name: Self.milestoneReachedNotification,
                    object: nil,
                    userInfo: ["milestone": milestone, "description": self.milestoneDescription(milestone)]
                )
            }
        }

        // Atualiza próximo milestone
        if let next = milestones.first(where: { $0 > streak }) {
            await MainActor.run {
                self.nextMilestone = next
            }
        }
    }

    // MARK: - Notifications

    private func notifyStreakUpdate() async {
        NotificationCenter.default.post(
            name: Self.streakUpdatedNotification,
            object: nil
        )
    }

    // MARK: - Meditation History (para análise)

    private func addToMeditationHistory(date: Date) {
        let dateString = ISO8601DateFormatter().string(from: date)

        var history = userDefaults.stringArray(forKey: meditationHistoryKey) ?? []
        if !history.contains(dateString) {
            history.append(dateString)
            userDefaults.set(history, forKey: meditationHistoryKey)
        }
    }

    /// Retorna histórico de meditações dos últimos N dias
    func getMeditationHistoryLastNDays(_ days: Int) -> [Date] {
        guard let history = userDefaults.stringArray(forKey: meditationHistoryKey) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        return history
            .compactMap { formatter.date(from: $0) }
            .filter { $0 >= cutoffDate }
            .sorted()
    }
}

// MARK: - Testing/Preview Support
#if DEBUG
extension StreakManager {
    /// Cria uma instância para teste com dados pré-populados
    static func preview() -> StreakManager {
        let manager = StreakManager()

        Task {
            for i in 0..<7 {
                let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
                await manager.recordMeditationCompletion(duration: 300)
            }
        }

        return manager
    }
}
#endif
