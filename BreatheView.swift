import SwiftUI

struct BreatheView: View {
    @State private var isExercising = false
    @State private var currentPhase: BreathingPhase = .inhale
    @State private var timer: Timer?
    @State private var phaseTimeRemaining: Int = 4
    @State private var roundCount: Int = 0
    @State private var progress: Double = 0

    let totalRounds = 5

    var phaseText: String {
        switch currentPhase {
        case .inhale:
            return "Inspira"
        case .hold:
            return "Aguenta"
        case .exhale:
            return "Expira"
        }
    }

    var phaseDuration: Int {
        switch currentPhase {
        case .inhale:
            return 4
        case .hold:
            return 7
        case .exhale:
            return 8
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AlmaTheme.background.ignoresSafeArea()

                VStack(spacing: 40) {
                    // Round Counter
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ronda")
                                .font(.caption)
                                .foregroundColor(AlmaTheme.textSecondary)

                            Text("\(roundCount)/\(totalRounds)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AlmaTheme.textPrimary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Duração")
                                .font(.caption)
                                .foregroundColor(AlmaTheme.textSecondary)

                            Text(formatTime(roundCount > 0 ? roundCount * 38 : 0))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AlmaTheme.textPrimary)
                        }
                    }
                    .padding(AlmaTheme.paddingPage)
                    .background(AlmaTheme.card)
                    .cornerRadius(AlmaTheme.radius)

                    Spacer()

                    // Animated Breathing Circle
                    VStack(spacing: 20) {
                        ZStack {
                            // Progress Ring
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            AlmaTheme.accent.opacity(0.3),
                                            AlmaTheme.accent.opacity(0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 12
                                )
                                .frame(width: 240, height: 240)

                            // Progress Ring Filled
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    LinearGradient(
                                        gradient: AlmaTheme.accentGradient.gradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 240, height: 240)
                                .rotationEffect(.degrees(-90))

                            // Center Circle
                            VStack(spacing: 16) {
                                Text(phaseText)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AlmaTheme.textPrimary)

                                Text(String(phaseTimeRemaining))
                                    .font(.system(size: 60, weight: .bold, design: .rounded))
                                    .foregroundColor(AlmaTheme.accent)
                                    .tabularNums()
                            }
                            .scaleEffect(1.0 + (Double(phaseTimeRemaining) / Double(phaseDuration)) * 0.1)
                            .animation(.easeInOut(duration: 0.5), value: phaseTimeRemaining)
                        }
                        .frame(width: 260, height: 260)
                    }

                    Spacer()

                    // Control Buttons
                    HStack(spacing: 12) {
                        if isExercising {
                            Button(action: stopExercise) {
                                HStack(spacing: 8) {
                                    Image(systemName: "stop.fill")
                                    Text("Parar")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.red.opacity(0.2))
                                .foregroundColor(.red)
                                .cornerRadius(AlmaTheme.radius)
                            }
                        } else {
                            Button(action: startExercise) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("Começar")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AlmaTheme.accentGradient)
                                .foregroundColor(.white)
                                .cornerRadius(AlmaTheme.radius)
                            }
                        }
                    }
                    .padding(AlmaTheme.paddingPage)
                }
                .padding(AlmaTheme.paddingPage)
            }
            .navigationTitle("Respirar")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func startExercise() {
        isExercising = true
        roundCount = 1
        currentPhase = .inhale
        phaseTimeRemaining = phaseDuration
        progress = 0

        startPhaseTimer()
    }

    private func stopExercise() {
        isExercising = false
        timer?.invalidate()
        timer = nil
        roundCount = 0
        phaseTimeRemaining = phaseDuration
        progress = 0
    }

    private func startPhaseTimer() {
        timer?.invalidate()

        let phaseDuration = self.phaseDuration
        var secondsElapsed = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            secondsElapsed += 1
            phaseTimeRemaining = phaseDuration - secondsElapsed

            // Update progress
            progress = Double(secondsElapsed) / Double(phaseDuration)

            if secondsElapsed >= phaseDuration {
                advancePhase()
            }
        }
    }

    private func advancePhase() {
        timer?.invalidate()
        timer = nil

        switch currentPhase {
        case .inhale:
            currentPhase = .hold
        case .hold:
            currentPhase = .exhale
        case .exhale:
            if roundCount < totalRounds {
                roundCount += 1
                currentPhase = .inhale
            } else {
                stopExercise()
                return
            }
        }

        phaseTimeRemaining = phaseDuration
        progress = 0
        startPhaseTimer()
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

enum BreathingPhase {
    case inhale
    case hold
    case exhale
}

#Preview {
    BreatheView()
        .preferredColorScheme(.dark)
}
