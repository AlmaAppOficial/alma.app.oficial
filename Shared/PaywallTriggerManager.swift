import Foundation
import Combine
import SwiftUI

// MARK: - Paywall Trigger Enum

enum PaywallTrigger {
    case afterFirstCompletedMeditation  // MAIN TRIGGER: user at peak positive emotion = best conversion
    case beforeSecondMeditation          // fallback: if they skip completion
    case afterDay3                       // fallback: engaged user = good time to convert
    case streakAt3Days                   // fallback: committed user
}

// MARK: - Post-Meditation Celebration State

struct PostMeditationCelebration {
    let meditationTitle: String
    let durationMinutes: Int
    let moodBefore: String?  // emoji or description
    let moodAfter: String?   // emoji or description
    let timestamp: Date
}

// MARK: - Paywall Trigger Manager
// [2026-07-14] Era `@MainActor actor` — inválido (actor não pode ter global
// actor; o arquivo nunca compilou pois não pertencia a nenhum target).
// Convertido para `@MainActor final class`: mesma semântica pretendida.

@MainActor
final class PaywallTriggerManager: ObservableObject {
    static let shared = PaywallTriggerManager()

    // MARK: - Published Properties

    @Published var shouldShowPaywall: Bool = false
    @Published var paywallTriggerReason: PaywallTrigger?
    @Published var postMeditationCelebration: PostMeditationCelebration?

    // MARK: - Private State

    private let userDefaults = UserDefaults.standard
    private let meditationCompletedCountKey = "alma_meditations_completed_count"
    private let streakManagerKey = "alma_paywall_streak_shown"
    private let lastPaywallShownKey = "alma_last_paywall_shown"
    private let day3PaywallShownKey = "alma_day3_paywall_shown"

    // MARK: - Initialization

    private init() {
        Task {
            await checkPaywallEligibility()
        }
    }

    // MARK: - Premium Guard [2026-07-28]
    // Bug do audit de 25/jul: nenhum trigger checava premium — assinante
    // pagante via paywall após a 1ª meditação. Fonte da verdade: os flags do
    // App Group publicados pelo AccessManager (Alma) e pelo C&A (Models.swift).
    // Cobre StoreKit, claims, trial E a assinatura única entre os dois apps
    // ("quem assina um ganha o outro"). Mesmo contrato/validade de 30 dias
    // definidos no AccessManager.corpoAlmaPremiumActive().
    private var hasPremiumAccess: Bool {
        guard let d = UserDefaults(suiteName: "group.com.almaapp.shared") else { return false }
        if d.bool(forKey: "alma_isPremium") { return true }
        if let updated = d.object(forKey: "corpoealma_isPremium_updatedAt") as? Date,
           Date().timeIntervalSince(updated) < 60 * 60 * 24 * 30,
           d.bool(forKey: "corpoealma_isPremium") {
            return true
        }
        return false
    }

    // MARK: - Primary API: Record Meditation Completion

    /// Call this immediately after user completes meditation
    /// Triggers the celebration flow and potentially the paywall
    nonisolated func recordMeditationCompletion(
        meditationTitle: String,
        durationMinutes: Int,
        moodBefore: String? = nil,
        moodAfter: String? = nil
    ) async {
        await self.processMeditationCompletion(
            title: meditationTitle,
            duration: durationMinutes,
            moodBefore: moodBefore,
            moodAfter: moodAfter
        )
    }

    // MARK: - Internal Processing

    private func processMeditationCompletion(
        title: String,
        duration: Int,
        moodBefore: String?,
        moodAfter: String?
    ) async {
        // Increment meditation counter
        let completionCount = incrementMeditationCount()

        // Store post-meditation state for celebration sheet
        let celebration = PostMeditationCelebration(
            meditationTitle: title,
            durationMinutes: duration,
            moodBefore: moodBefore,
            moodAfter: moodAfter,
            timestamp: Date()
        )

        await MainActor.run {
            self.postMeditationCelebration = celebration
        }

        // [2026-07-28] Assinante (Alma ou C&A) vê a celebração, nunca o paywall.
        if hasPremiumAccess { return }

        // Main trigger: AFTER FIRST COMPLETED MEDITATION
        // User is at peak positive emotion = best conversion moment
        if completionCount == 1 {
            await MainActor.run {
                self.paywallTriggerReason = .afterFirstCompletedMeditation
                self.shouldShowPaywall = true
            }
            recordPaywallTrigger(reason: .afterFirstCompletedMeditation)
            return
        }

        // Fallback: Before second meditation (if they somehow skip completion screen)
        if completionCount == 1 {
            await MainActor.run {
                self.paywallTriggerReason = .beforeSecondMeditation
                self.shouldShowPaywall = true
            }
            recordPaywallTrigger(reason: .beforeSecondMeditation)
            return
        }

        // Fallback: Day 3 (streak shows engagement)
        let streakDays = await getStreakDays()
        if streakDays == 3 {
            let day3Shown = userDefaults.bool(forKey: day3PaywallShownKey)
            if !day3Shown {
                await MainActor.run {
                    self.paywallTriggerReason = .afterDay3
                    self.shouldShowPaywall = true
                }
                userDefaults.set(true, forKey: day3PaywallShownKey)
                recordPaywallTrigger(reason: .afterDay3)
                return
            }
        }
    }

    // MARK: - Paywall Eligibility Check

    private func checkPaywallEligibility() async {
        // [2026-07-28] Assinante (Alma ou C&A) nunca recebe paywall no launch.
        if hasPremiumAccess { return }

        let completionCount = getMeditationCount()

        // Only show paywall after first completion (or at milestones)
        if completionCount >= 1 {
            let lastShown = userDefaults.object(forKey: lastPaywallShownKey) as? Date
            let shouldShow = lastShown == nil || (Date().timeIntervalSince(lastShown ?? Date()) > 86400)

            if shouldShow {
                await MainActor.run {
                    self.shouldShowPaywall = true
                }
            }
        }
    }

    // MARK: - Dismiss Paywall

    nonisolated func dismissPaywall() async {
        await MainActor.run {
            self.shouldShowPaywall = false
            self.paywallTriggerReason = nil
            self.postMeditationCelebration = nil
        }
    }

    // MARK: - Helpers

    private func incrementMeditationCount() -> Int {
        let current = userDefaults.integer(forKey: meditationCompletedCountKey)
        let new = current + 1
        userDefaults.set(new, forKey: meditationCompletedCountKey)
        return new
    }

    private func getMeditationCount() -> Int {
        return userDefaults.integer(forKey: meditationCompletedCountKey)
    }

    private func getStreakDays() async -> Int {
        return StreakManager.shared.currentStreak
    }

    private func recordPaywallTrigger(reason: PaywallTrigger) {
        let reasonStr: String
        switch reason {
        case .afterFirstCompletedMeditation:
            reasonStr = "first_meditation"
        case .beforeSecondMeditation:
            reasonStr = "before_second"
        case .afterDay3:
            reasonStr = "day3_streak"
        case .streakAt3Days:
            reasonStr = "streak_3_days"
        }

        let timestamp = Date().timeIntervalSince1970
        print("Paywall triggered: \(reasonStr) at \(timestamp)")

        // Track in analytics
        userDefaults.set(Date(), forKey: lastPaywallShownKey)
    }
}

// MARK: - Views removidas (2026-07-14)
// PostMeditationCelebrationSheet, MoodTransformationCard, ParticleAnimationView,
// PostMeditationPaywallSheet e previews foram REMOVIDAS deste arquivo:
// - Nunca compilaram (arquivo estava fora de target) e nunca foram referenciadas.
// - Dependiam de PaywallView/PricingOffer (PaywallView.swift também órfão) e
//   continham social proof fictício ("4.8 ★ · 2.400 avaliações", "500+ meditações").
// - Quando o observer do paywall pós-meditação for ligado (ver CHECKUP_GERAL_20260713.md),
//   usar o PremiumWallView real (SubscriptionView.swift). Código antigo: git history.
