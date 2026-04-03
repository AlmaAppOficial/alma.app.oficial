import SwiftUI

/// Quick Onboarding Flow for Alma App - A/B Test Variant B
/// Optimized for rapid completion and immediate success moment
/// 3 screens only: Welcome + Challenge Selection → First Meditation Preview → Permissions + Speedy Intro
/// All copy in Portuguese (Brazilian)
///
/// Hypothesis: Users complete faster, reach meditation sooner → higher D1 retention
/// Goal: 3-4 minutes total, 50%+ higher completion rate vs Variant A (10 screens)

@MainActor
class QuickOnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var selectedChallenge: String? = nil
    @Published var isAnalyticsEnabled = false
    @Published var onboardingStartTime = Date()
    @Published var selectedChallengeLabel = ""

    let totalSteps = 3 // Screen 1: Welcome + Challenge | Screen 2: Meditation Preview | Screen 3: Permissions

    // Challenge data for personalization
    let challenges: [(id: String, emoji: String, label: String, fullName: String)] = [
        ("anxiety", "😰", "Ansiedade", "Ansiedade"),
        ("sleep", "😴", "Sono", "Dormir Melhor"),
        ("stress", "😓", "Estresse", "Reduzir Estresse"),
        ("focus", "🎯", "Foco", "Melhorar Foco")
    ]

    func getRecommendedMeditationTitle() -> String {
        switch selectedChallenge {
        case "anxiety":
            return "Acalme sua Mente"
        case "sleep":
            return "Prepare-se para Dormir"
        case "stress":
            return "Respire Fundo"
        case "focus":
            return "Melhore seu Foco"
        default:
            return "Bem-vindo a Alma"
        }
    }

    func getRecommendedMeditationDescription() -> String {
        switch selectedChallenge {
        case "anxiety":
            return "Uma meditação tranquilizante para acalmar a mente e reduzir ansiedade em apenas 1 minuto."
        case "sleep":
            return "Prepare seu corpo para dormir profundamente com esta meditação guiada de 1 minuto."
        case "stress":
            return "Técnicas de respiração científica para aliviar estresse em 1 minuto apenas."
        case "focus":
            return "Desperte sua atenção com esta meditação energizante de 1 minuto."
        default:
            return "Sua primeira meditação com Alma."
        }
    }

    func trackOnboardingEvent(event: String, properties: [String: Any] = [:]) {
        // Firebase Analytics tracking
        var params = properties
        params["variant"] = "B" // Quick variant
        params["challenge"] = selectedChallenge ?? "none"
        params["timestamp"] = Date().timeIntervalSince1970

        // TODO: Integrate with Firebase Analytics
        // Analytics.logEvent(event, parameters: params)

        #if DEBUG
        print("📊 Onboarding Event: \(event) | \(params)")
        #endif
    }

    func trackOnboardingCompleted() {
        let timeSpent = Date().timeIntervalSince(onboardingStartTime)
        trackOnboardingEvent(
            event: "onboarding_completed",
            properties: [
                "time_spent_seconds": Int(timeSpent),
                "challenge_selected": selectedChallenge ?? "none"
            ]
        )
    }
}

// MARK: - Main View

struct QuickOnboardingView: View {
    @StateObject private var viewModel = QuickOnboardingViewModel()
    @AppStorage("quickOnboardingComplete") private var onboardingComplete = false
    @State private var showSpeedyMeditationPlayer = false

    var body: some View {
        ZStack {
            // Calm gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal progress indicator - only 3 dots for 3 screens
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= viewModel.currentStep ?
                                  Color(red: 0.6, green: 0.4, blue: 0.8) :
                                  Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 28)

                // Content
                Group {
                    switch viewModel.currentStep {
                    case 0:
                        welcomeAndChallengeStep
                    case 1:
                        meditationPreviewStep
                    case 2:
                        permissionsStep
                    default:
                        EmptyView()
                    }
                }
                .id(viewModel.currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation
                VStack(spacing: 12) {
                    Button(action: advance) {
                        HStack {
                            Text(buttonText)
                                .font(.headline)
                            if viewModel.currentStep < viewModel.totalSteps - 1 {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canAdvance ?
                                   LinearGradient(
                                       gradient: Gradient(colors: [
                                           Color(red: 0.7, green: 0.5, blue: 0.9),
                                           Color(red: 0.6, green: 0.4, blue: 0.8)
                                       ]),
                                       startPoint: .leading,
                                       endPoint: .trailing
                                   ) :
                                   LinearGradient(
                                       gradient: Gradient(colors: [
                                           Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.4),
                                           Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.4)
                                       ]),
                                       startPoint: .leading,
                                       endPoint: .trailing
                                   ))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canAdvance)

                    if viewModel.currentStep > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.currentStep -= 1
                            }
                        }) {
                            Text("Voltar")
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        .onAppear {
            viewModel.trackOnboardingEvent(event: "onboarding_started", properties: ["variant": "B"])
        }
        .fullScreenCover(isPresented: $showSpeedyMeditationPlayer) {
            // Show 1-minute "Speedy" meditation player
            SpeedyMeditationPlayerView(
                challengeType: viewModel.selectedChallenge ?? "general",
                challengeLabel: viewModel.selectedChallengeLabel,
                isPresented: $showSpeedyMeditationPlayer,
                onComplete: completeOnboarding
            )
        }
    }

    // MARK: - Step Views

    private var welcomeAndChallengeStep: some View {
        VStack(spacing: 24) {
            // Logo section
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.7, green: 0.5, blue: 0.9),
                                Color(red: 0.6, green: 0.4, blue: 0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)

                    Text("A")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 8)

            // Welcome text
            VStack(spacing: 12) {
                Text("Bem-vindo a Alma")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Text("Qual é seu maior desafio?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
            }
            .padding(.horizontal, 24)

            // Challenge buttons - minimal selection
            VStack(spacing: 10) {
                ForEach(viewModel.challenges, id: \.id) { challenge in
                    challengeButton(challenge)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func challengeButton(_ challenge: (id: String, emoji: String, label: String, fullName: String)) -> some View {
        Button(action: {
            viewModel.selectedChallenge = challenge.id
            viewModel.selectedChallengeLabel = challenge.fullName
            viewModel.trackOnboardingEvent(
                event: "challenge_selected",
                properties: ["challenge": challenge.id]
            )
        }) {
            HStack {
                Text(challenge.emoji)
                    .font(.system(size: 20))

                Text(challenge.label)
                    .font(.body.weight(.medium))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                if viewModel.selectedChallenge == challenge.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                        .font(.system(size: 20))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(viewModel.selectedChallenge == challenge.id ?
                       Color(red: 0.95, green: 0.92, blue: 0.98) :
                       Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.selectedChallenge == challenge.id ?
                           Color(red: 0.6, green: 0.4, blue: 0.8) :
                           Color.clear, lineWidth: 2)
            )
        }
    }

    private var meditationPreviewStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("🎧")
                    .font(.system(size: 64))

                VStack(spacing: 8) {
                    Text("Sua primeira meditação te espera")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    Text(viewModel.getRecommendedMeditationTitle())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                }
            }
            .padding(.horizontal, 24)

            // Meditation preview card
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)

                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.getRecommendedMeditationTitle())
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                                Text(viewModel.getRecommendedMeditationDescription())
                                    .font(.caption)
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                                    .lineLimit(3)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("1 min")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))

                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                            }
                        }
                        .padding(12)
                    }
                }
                .frame(height: 100)
            }
            .padding(.horizontal, 24)

            Text("Depois, você dirá se gostou e recomendaremos mais meditações personalizadas.")
                .font(.caption)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("🔔")
                    .font(.system(size: 64))

                VStack(spacing: 8) {
                    Text("Quase lá!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    Text("1 min apenas para conhecer o Alma")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                permissionItem("🔔", "Notificações diárias", "Lembretes para criar hábito")
                permissionItem("📊", "Analytics", "Entender seu progresso")
                permissionItem("❤️", "Apple Health", "Dados personalizados (opcional)")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func permissionItem(_ emoji: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(red: 0.98, green: 0.96, blue: 0.99))
        .cornerRadius(10)
    }

    // MARK: - Navigation Logic

    private var canAdvance: Bool {
        switch viewModel.currentStep {
        case 0:
            return viewModel.selectedChallenge != nil
        default:
            return true
        }
    }

    private var buttonText: String {
        switch viewModel.currentStep {
        case 2:
            return "Começar Meditação"
        default:
            return "Continuar"
        }
    }

    private func advance() {
        if viewModel.currentStep < viewModel.totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.currentStep += 1
            }
        } else {
            // Final step - trigger speedy meditation
            viewModel.trackOnboardingEvent(event: "ready_for_meditation")
            showSpeedyMeditationPlayer = true
        }
    }

    private func completeOnboarding() {
        viewModel.trackOnboardingCompleted()
        onboardingComplete = true
    }
}

// MARK: - Speedy Meditation Player (Placeholder)

struct SpeedyMeditationPlayerView: View {
    let challengeType: String
    let challengeLabel: String
    @Binding var isPresented: Bool
    let onComplete: () -> Void

    @State private var isPlaying = false
    @State private var playbackProgress: Double = 0
    @State private var autoCompleteTimer: Timer?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.98),
                    Color(red: 0.92, green: 0.95, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Close button
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Greeting with personalization
                VStack(spacing: 12) {
                    Text("Olá! 👋")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                    Text("Vi que você quer trabalhar \(challengeLabel.lowercased()). Vou te ajudar com isso.")
                        .font(.body)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Meditation player
                VStack(spacing: 20) {
                    // Play button
                    Button(action: {
                        isPlaying = true
                        startAutoComplete()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                    }

                    // Progress
                    VStack(spacing: 8) {
                        ProgressView(value: playbackProgress)
                            .tint(Color(red: 0.6, green: 0.4, blue: 0.8))

                        HStack {
                            Text(timeString(playbackProgress * 60))
                                .font(.caption.monospaced())
                            Spacer()
                            Text("1:00")
                                .font(.caption.monospaced())
                        }
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Skip to end button (for testing)
                #if DEBUG
                Button(action: {
                    playbackProgress = 1.0
                    isPlaying = false
                    autoCompleteTimer?.invalidate()
                    completeAndExit()
                }) {
                    Text("Skip (Debug)")
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                        .font(.caption)
                }
                #endif

                Spacer()
            }
        }
        .onDisappear {
            autoCompleteTimer?.invalidate()
        }
    }

    private func startAutoComplete() {
        autoCompleteTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            if playbackProgress < 1.0 {
                playbackProgress += 0.016 / 60 // 1-minute meditation
            } else {
                autoCompleteTimer?.invalidate()
                isPlaying = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    completeAndExit()
                }
            }
        }
    }

    private func completeAndExit() {
        onComplete()
        isPresented = false
    }

    private func timeString(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview {
    QuickOnboardingView()
}

#Preview("Speedy Meditation Player") {
    @State var isPresented = true
    return SpeedyMeditationPlayerView(
        challengeType: "anxiety",
        challengeLabel: "Ansiedade",
        isPresented: $isPresented,
        onComplete: {}
    )
}
