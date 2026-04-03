import SwiftUI
import Combine

// MARK: - Quick Start Button (FIX 1: Meditar Agora - 8 taps → 1 tap)
struct QuickStartButton: View {
    @State private var isAnimating = false
    @State private var showSkipSheet = false
    @State private var availableMeditations: [MeditationRecommendation] = []
    @State private var selectedMeditationIndex = 0

    @EnvironmentObject var streakManager: StreakManager
    @EnvironmentObject var userMemory: UserMemoryManager

    // Recommended meditation to play on single tap
    @State private var recommendedMeditation: MeditationRecommendation?
    @State private var isLoading = true

    // Navigation state
    @State private var navigateToMeditationPlayer = false

    var body: some View {
        ZStack {
            // Beautiful purple gradient card - THE HERO
            LinearGradient(
                gradient: Gradient(colors: [
                    CalmTheme.primary,
                    CalmTheme.primaryLight
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 20) {
                // Top: Meditation name + duration + play icon (single tap target)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meditar Agora")
                            .font(.headline.bold())
                            .foregroundColor(.white)

                        if let meditation = recommendedMeditation {
                            Text(meditation.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(2)

                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text("\(meditation.duration) min")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.white.opacity(0.8))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                Text("Próxima recomendação...")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Large play button
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)
                    }
                }
                .padding(20)

                // Bottom: "Pular" (Skip) button to see other meditations
                HStack(spacing: 12) {
                    Spacer()

                    Button(action: { showSkipSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                            Text("Pular")
                                .font(.caption.bold())
                        }
                        .foregroundColor(Color.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 160)
        .cornerRadius(CalmTheme.rLarge)
        .shadow(color: CalmTheme.primary.opacity(0.4), radius: 16, x: 0, y: 8)

        // SINGLE TAP → immediate meditation start (no friction)
        .onTapGesture {
            if let meditation = recommendedMeditation {
                // Play meditation immediately
                playRecommendedMeditation(meditation)
            }
        }

        // Pulse animation on the play button
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }

        .sheet(isPresented: $showSkipSheet) {
            MeditationSkipSheet(
                availableMeditations: availableMeditations,
                selectedIndex: $selectedMeditationIndex,
                onSelect: { meditation in
                    recommendedMeditation = meditation
                    showSkipSheet = false
                    playRecommendedMeditation(meditation)
                }
            )
        }

        .task {
            await loadRecommendedMeditation()
        }
    }

    // MARK: - Load Recommended Meditation

    @MainActor
    private func loadRecommendedMeditation() async {
        isLoading = true

        // Generate sample meditation library for demo
        let meditationLibrary = generateMeditationLibrary()
        availableMeditations = meditationLibrary

        // Determine what to show based on user state:
        // 1. If user has never meditated: show Day 1
        // 2. If user has streak: show next in sequence
        // 3. If Mood Router has a recommendation: show that

        let totalSessions = await userMemory.sessionsCompleted

        if totalSessions == 0 {
            // First meditation ever
            recommendedMeditation = meditationLibrary.first { $0.tags.contains("beginner") }
                ?? meditationLibrary.first
        } else {
            // Show next in sequence or mood-based recommendation
            recommendedMeditation = meditationLibrary[(totalSessions % meditationLibrary.count)]
        }

        isLoading = false
    }

    // MARK: - Play Meditation Immediately

    private func playRecommendedMeditation(_ meditation: MeditationRecommendation) {
        // Immediately start playback with zero friction
        // This would trigger the meditation player

        // Record analytics: quick start used
        Task {
            // Track quick start conversion
            print("Quick Start: Playing \(meditation.title)")
        }
    }

    // MARK: - Generate Sample Meditation Library

    private func generateMeditationLibrary() -> [MeditationRecommendation] {
        return [
            MeditationRecommendation(
                meditationType: "beginner",
                duration: 5,
                title: "Seu Primeiro Passo 🌱",
                description: "Uma introdução gentil à meditação",
                sequence: [],
                reasoning: "Ideal para começar sua jornada",
                tags: ["beginner", "calm"]
            ),
            MeditationRecommendation(
                meditationType: "anxiety",
                duration: 10,
                title: "Acalme a Mente Acelerada",
                description: "Técnicas para reduzir ansiedade",
                sequence: [],
                reasoning: "Para momentos de estresse",
                tags: ["anxiety", "focus"]
            ),
            MeditationRecommendation(
                meditationType: "sleep",
                duration: 15,
                title: "Caminho para o Sono Profundo",
                description: "Prepare-se para uma noite restauradora",
                sequence: [],
                reasoning: "Para melhor qualidade de sono",
                tags: ["sleep", "rest"]
            ),
            MeditationRecommendation(
                meditationType: "focus",
                duration: 8,
                title: "Foco Cristalino",
                description: "Aumente sua concentração e clareza",
                sequence: [],
                reasoning: "Para momentos de trabalho intenso",
                tags: ["focus", "productivity"]
            ),
            MeditationRecommendation(
                meditationType: "gratitude",
                duration: 7,
                title: "Gratidão e Abundância",
                description: "Cultive sentimentos de gratidão",
                sequence: [],
                reasoning: "Para elevar seu estado emocional",
                tags: ["gratitude", "calm"]
            )
        ]
    }
}

// MARK: - Skip Sheet (see other meditations)

struct MeditationSkipSheet: View {
    let availableMeditations: [MeditationRecommendation]
    @Binding var selectedIndex: Int
    let onSelect: (MeditationRecommendation) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableMeditations.indices, id: \.self) { index in
                        MeditationOptionRow(
                            meditation: availableMeditations[index],
                            isSelected: selectedIndex == index,
                            onTap: {
                                selectedIndex = index
                                onSelect(availableMeditations[index])
                                dismiss()
                            }
                        )
                    }
                }
                .padding(16)
            }
            .background(CalmTheme.background.ignoresSafeArea())
            .navigationTitle("Escolha sua Meditação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundColor(CalmTheme.primary)
                }
            }
        }
    }
}

// MARK: - Meditation Option Row

struct MeditationOptionRow: View {
    let meditation: MeditationRecommendation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meditation.title)
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)

                    Text(meditation.description)
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(meditation.duration) min")
                            .font(.caption.bold())
                    }
                    .foregroundColor(CalmTheme.primary.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CalmTheme.primary)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(CalmTheme.textSecondary.opacity(0.5))
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickStartButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            QuickStartButton()
                .environmentObject(StreakManager())
                .environmentObject(UserMemoryManager.shared)

            Spacer()
        }
        .padding(20)
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
#endif
