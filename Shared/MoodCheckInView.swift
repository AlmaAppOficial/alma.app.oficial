import SwiftUI

struct MoodCheckInView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedMood: Mood?
    @State private var selectedIntensity: Int = 5
    @State private var selectedTime: Int = 10
    @State private var showRecommendation = false
    @State private var recommendation: MeditationRecommendation?
    @State private var isLoading = false

    let moodRouter: MoodRouter
    let streakCount: Int

    var body: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Step 1: Mood Selection
                        if !showRecommendation {
                            moodSelectionSection
                        }

                        // Step 2: Intensity Slider
                        if selectedMood != nil && !showRecommendation {
                            intensitySection
                        }

                        // Step 3: Time Available
                        if selectedMood != nil && !showRecommendation {
                            timeAvailableSection
                        }

                        // Recommendation Card
                        if let recommendation = recommendation, showRecommendation {
                            recommendationCard(recommendation)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                // Action Button
                if !showRecommendation && selectedMood != nil {
                    startButton
                        .padding(20)
                } else if showRecommendation {
                    actionButtons
                        .padding(20)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Como você está agora?")
                        .font(.title2.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Vamos personalizar sua meditação")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
        }
        .padding(20)
        .background(CalmTheme.surface)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.2)
        }
    }

    // MARK: - Mood Selection Section
    private var moodSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Qual é seu estado emocional?")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            VStack(spacing: 12) {
                // Row 1: Ansioso, Estressado, Cansado, Triste
                HStack(spacing: 12) {
                    moodButton(.ansioso)
                    moodButton(.estressado)
                    moodButton(.cansado)
                    moodButton(.triste)
                }

                // Row 2: Agitado, Focado, Grato, Neutro
                HStack(spacing: 12) {
                    moodButton(.agitado)
                    moodButton(.focado)
                    moodButton(.grato)
                    moodButton(.neutro)
                }
            }
        }
    }

    // MARK: - Mood Button
    private func moodButton(_ mood: Mood) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMood = mood
                selectedIntensity = 5
            }
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            VStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 32))

                Text(mood.portuguese)
                    .font(.caption2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                Group {
                    if selectedMood == mood {
                        CalmTheme.heroGradient
                    } else {
                        LinearGradient(
                            colors: [CalmTheme.surface, CalmTheme.surface.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(CalmTheme.rMedium)
            .overlay(
                RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                    .stroke(
                        selectedMood == mood ? CalmTheme.primary : Color.clear,
                        lineWidth: 2
                    )
            )
            .shadow(
                color: selectedMood == mood ? CalmTheme.primary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }

    // MARK: - Intensity Section
    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Intensidade")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(selectedIntensity)")
                        .font(.title3.bold())
                        .foregroundColor(CalmTheme.primary)
                    Text("de 10")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }

            VStack(spacing: 12) {
                Slider(value: .init(
                    get: { Double(selectedIntensity) },
                    set: { selectedIntensity = Int($0) }
                ), in: 1...10, step: 1)
                    .tint(CalmTheme.primary)

                HStack(spacing: 12) {
                    Text("Leve")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)

                    Spacer()

                    Text("Intensa")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Time Available Section
    private var timeAvailableSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quanto tempo você tem?")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            VStack(spacing: 12) {
                timeButton(duration: 5, label: "⚡ 5 min\nRápido")
                timeButton(duration: 10, label: "🧘 10 min\nPadrão")
                timeButton(duration: 20, label: "🌿 20+ min\nProfundo")
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func timeButton(duration: Int, label: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTime = duration
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(CalmTheme.textPrimary)
                }

                Spacer()

                if selectedTime == duration {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(CalmTheme.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                selectedTime == duration
                    ? CalmTheme.primary.opacity(0.1)
                    : CalmTheme.surface
            )
            .cornerRadius(CalmTheme.rMedium)
            .overlay(
                RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                    .stroke(
                        selectedTime == duration ? CalmTheme.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
    }

    // MARK: - Start Button
    private var startButton: some View {
        Button(action: generateRecommendation) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(isLoading ? "Gerando..." : "Gerar Meditação")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(CalmTheme.heroGradient)
            .foregroundColor(.white)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: CalmTheme.primary.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .disabled(isLoading)
    }

    // MARK: - Recommendation Card
    @ViewBuilder
    private func recommendationCard(_ rec: MeditationRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rec.title)
                            .font(.title2.bold())
                            .foregroundColor(CalmTheme.textPrimary)

                        HStack(spacing: 8) {
                            Image(systemName: "hourglass.circle.fill")
                                .font(.caption)
                                .foregroundColor(CalmTheme.primary)

                            Text("\(rec.duration) minutos")
                                .font(.caption)
                                .foregroundColor(CalmTheme.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(CalmTheme.accent)

                        Text("Personalizado")
                            .font(.caption2)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)

            // Reasoning
            VStack(alignment: .leading, spacing: 8) {
                Text("Por que isso?")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textSecondary)

                Text(rec.reasoning)
                    .font(.body)
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineSpacing(2)
            }

            // Phases
            VStack(alignment: .leading, spacing: 12) {
                Text("Estrutura da Sessão")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textSecondary)

                VStack(spacing: 12) {
                    ForEach(rec.sequence, id: \.name) { phase in
                        phaseRow(phase)
                    }
                }
            }

            // Tags
            HStack {
                ForEach(rec.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .foregroundColor(CalmTheme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(CalmTheme.primary.opacity(0.1))
                        .cornerRadius(8)
                }
                Spacer()
            }
        }
        .padding(20)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rLarge)
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.rLarge)
                .stroke(CalmTheme.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: CalmTheme.primary.opacity(0.1), radius: 12, x: 0, y: 4)
        .transition(.scale.combined(with: .opacity))
    }

    private func phaseRow(_ phase: MeditationRecommendation.MeditationPhase) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text("\(phase.duration)'")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.primary)

                Circle()
                    .fill(CalmTheme.primary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
            .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(phase.name)
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)

                Text(phase.instructions)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineSpacing(1.5)
            }

            Spacer()
        }
        .padding(12)
        .background(CalmTheme.background)
        .cornerRadius(CalmTheme.rSmall)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showRecommendation = false
                    selectedMood = nil
                    recommendation = nil
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Voltar")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(CalmTheme.surface)
                .foregroundColor(CalmTheme.textPrimary)
                .cornerRadius(CalmTheme.rMedium)
                .overlay(
                    RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                        .stroke(CalmTheme.primary.opacity(0.3), lineWidth: 1)
                )
            }

            Button(action: startMeditation) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 18))
                    Text("Começar")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(CalmTheme.heroGradient)
                .foregroundColor(.white)
                .cornerRadius(CalmTheme.rMedium)
                .shadow(color: CalmTheme.primary.opacity(0.3), radius: 12, x: 0, y: 4)
            }
        }
    }

    // MARK: - Actions
    private func generateRecommendation() {
        guard let mood = selectedMood else { return }

        isLoading = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            let rec = await moodRouter.recommendMeditation(
                mood: mood,
                intensity: selectedIntensity,
                timeAvailable: selectedTime,
                streak: streakCount
            )

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.recommendation = rec
                    self.showRecommendation = true
                }
                self.isLoading = false
                UIImpactFeedbackGenerator(style: .success).impactOccurred()
            }
        }
    }

    private func startMeditation() {
        guard let recommendation = recommendation else { return }

        // Log mood and meditation start
        Task {
            let context = MoodContext(
                timeOfDay: getCurrentTimeOfDay(),
                dayOfWeek: getDayOfWeek(),
                location: nil,
                trigger: nil,
                timestamp: Date()
            )

            await moodRouter.logMood(
                selectedMood ?? .neutro,
                intensity: selectedIntensity,
                context: context
            )
        }

        // Dismiss to start meditation
        dismiss()
    }

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
}

// MARK: - Preview
#if DEBUG
struct MoodCheckInView_Previews: PreviewProvider {
    static var previews: some View {
        MoodCheckInView(
            moodRouter: MoodRouter(),
            streakCount: 7
        )
    }
}
#endif
