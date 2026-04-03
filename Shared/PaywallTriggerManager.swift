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

// MARK: - Paywall Trigger Manager (Actor)

@MainActor
actor PaywallTriggerManager: ObservableObject {
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
        // In production, would query StreakManager.shared.currentStreak
        // For now, return 0 (fallback)
        return 0
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

// MARK: - Post-Meditation Celebration Sheet

struct PostMeditationCelebrationSheet: View {
    let celebration: PostMeditationCelebration
    let onContinue: () -> Void
    let onShare: () -> Void

    @State private var particlesAnimating = false

    var body: some View {
        ZStack {
            // Particle animation background
            if particlesAnimating {
                ParticleAnimationView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onContinue) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
                .padding(16)

                ScrollView {
                    VStack(spacing: 32) {
                        // Celebration header
                        VStack(spacing: 16) {
                            // Sparkle emoji with particle effect
                            Text("✨")
                                .font(.system(size: 64))
                                .scaleEffect(particlesAnimating ? 1.1 : 1.0)

                            VStack(spacing: 8) {
                                Text("Você completou sua primeira meditação!")
                                    .font(.title2.bold())
                                    .foregroundColor(CalmTheme.textPrimary)
                                    .multilineTextAlignment(.center)

                                Text("🎉")
                                    .font(.system(size: 44))
                            }
                        }

                        // Meditation details
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Meditação Concluída")
                                        .font(.subheadline.bold())
                                        .foregroundColor(CalmTheme.textPrimary)

                                    Text(celebration.meditationTitle)
                                        .font(.caption)
                                        .foregroundColor(CalmTheme.textSecondary)
                                }

                                Spacer()

                                Text("\(celebration.durationMinutes) min")
                                    .font(.caption.bold())
                                    .foregroundColor(CalmTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(CalmTheme.primary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .padding(16)
                            .background(CalmTheme.surface)
                            .cornerRadius(CalmTheme.rMedium)
                        }

                        // Mood transformation (before → after)
                        if let moodBefore = celebration.moodBefore,
                           let moodAfter = celebration.moodAfter {
                            MoodTransformationCard(
                                moodBefore: moodBefore,
                                moodAfter: moodAfter
                            )
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }

                // Action buttons
                VStack(spacing: 12) {
                    // Share button
                    Button(action: onShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.bold())

                            Text("Compartilhar seu Momento")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(CalmTheme.surface)
                        .foregroundColor(CalmTheme.primary)
                        .cornerRadius(CalmTheme.rSmall)
                    }

                    // Continue to paywall
                    Button(action: onContinue) {
                        Text("Continuar sua Jornada")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        CalmTheme.primary,
                                        CalmTheme.primaryLight
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(CalmTheme.rSmall)
                    }
                }
                .padding(16)
            }
        }
        .background(CalmTheme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                particlesAnimating = true
            }
        }
    }
}

// MARK: - Mood Transformation Card

struct MoodTransformationCard: View {
    let moodBefore: String
    let moodAfter: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Como você se sente agora vs antes?")
                .font(.subheadline.bold())
                .foregroundColor(CalmTheme.textPrimary)

            HStack(spacing: 20) {
                // Before
                VStack(spacing: 8) {
                    Text("Antes")
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textSecondary)

                    Text(moodBefore)
                        .font(.system(size: 48))
                }
                .frame(maxWidth: .infinity)

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.title3.bold())
                    .foregroundColor(CalmTheme.primary)

                // After
                VStack(spacing: 8) {
                    Text("Agora")
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textSecondary)

                    Text(moodAfter)
                        .font(.system(size: 48))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
        }
    }
}

// MARK: - Particle Animation View

struct ParticleAnimationView: View {
    @State private var particles: [ParticleModel] = []

    var body: some View {
        Canvas { context in
            for particle in particles {
                var path = Circle().path(in: CGRect(x: particle.x - particle.size / 2,
                                                      y: particle.y - particle.size / 2,
                                                      width: particle.size,
                                                      height: particle.size))

                context.fill(path,
                             with: .color(Color.white.opacity(particle.opacity)))
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        for _ in 0..<20 {
            let x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
            let y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
            let size = CGFloat.random(in: 2...6)

            particles.append(ParticleModel(
                x: x,
                y: y,
                size: size,
                opacity: Double.random(in: 0.1...0.6)
            ))
        }
    }
}

struct ParticleModel {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

// MARK: - Integration with PaywallView (modified PaywallView to accept post-meditation context)

struct PostMeditationPaywallSheet: View {
    let celebration: PostMeditationCelebration?
    let onDismiss: () -> Void

    @State private var offer: PricingOffer?

    var body: some View {
        VStack(spacing: 0) {
            // Header with celebration context
            if let celebration = celebration {
                VStack(spacing: 12) {
                    Text("Você completou sua primeira meditação! 🎉")
                        .font(.headline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Continue sua jornada com acesso ilimitado")
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(CalmTheme.surface)
            }

            // Standard paywall content
            if let offer = offer {
                PaywallView(
                    offer: offer,
                    onSubscribe: { onDismiss() },
                    onDismiss: onDismiss
                )
            } else {
                ProgressView()
                    .padding(40)
            }
        }
        .onAppear {
            // Load best conversion offer
            offer = generateBestConversionOffer()
        }
    }

    private func generateBestConversionOffer() -> PricingOffer {
        return PricingOffer(
            variant: .control,
            title: "Continue sua Jornada",
            subtitle: "7 dias grátis para explorar tudo",
            price: 24.99,
            period: "/mês",
            cta: "Iniciar 7 dias grátis",
            description: "Acesso completo por 7 dias, depois R$ 24,99/mês. Cancele quando quiser.",
            includedFeatures: [
                "500+ meditações guiadas",
                "Sons ambientes relaxantes",
                "Exercícios de respiração",
                "Insights de humor diário",
                "Acompanhamento de progresso"
            ],
            socialProof: "4.8 ★ · 2.400 avaliações",
            badge: "🧘"
        )
    }
}

// MARK: - Preview

#if DEBUG
struct PostMeditationFlow_Previews: PreviewProvider {
    static let sampleCelebration = PostMeditationCelebration(
        meditationTitle: "Seu Primeiro Passo",
        durationMinutes: 5,
        moodBefore: "😰",
        moodAfter: "😌",
        timestamp: Date()
    )

    static var previews: some View {
        Group {
            PostMeditationCelebrationSheet(
                celebration: sampleCelebration,
                onContinue: {},
                onShare: {}
            )
            .preferredColorScheme(.dark)

            PostMeditationPaywallSheet(
                celebration: sampleCelebration,
                onDismiss: {}
            )
            .preferredColorScheme(.dark)
        }
    }
}
#endif
