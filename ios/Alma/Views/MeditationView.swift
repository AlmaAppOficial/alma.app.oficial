import SwiftUI

struct MeditationView: View {
    @State private var selectedDuration = 5
    @State private var isMeditating = false
    @State private var timeRemaining = 0
    @State private var timer: Timer?

    let durations = [5, 10, 15, 20, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                AlmaTheme.background.ignoresSafeArea()

                VStack(spacing: 30) {
                    Text("Meditar")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AlmaTheme.textPrimary)

                    if !isMeditating {
                        VStack(spacing: 20) {
                            Text("Selecione a duração")
                                .font(.headline)
                                .foregroundColor(AlmaTheme.textPrimary)

                            HStack(spacing: 12) {
                                ForEach(durations, id: \.self) { duration in
                                    Button(action: { selectedDuration = duration }) {
                                        Text("\(duration)m")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(maxWidth: .infinity)
                                            .padding(12)
                                            .background(
                                                selectedDuration == duration ?
                                                AlmaTheme.accentGradient :
                                                AlmaTheme.card
                                            )
                                            .foregroundColor(selectedDuration == duration ? .white : AlmaTheme.textPrimary)
                                            .cornerRadius(AlmaTheme.radius)
                                    }
                                }
                            }
                        }
                        .padding(AlmaTheme.paddingPage)
                        .background(AlmaTheme.card)
                        .cornerRadius(AlmaTheme.radius)

                        Button(action: startMeditation) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Começar Meditação")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AlmaTheme.accentGradient)
                            .foregroundColor(.white)
                            .cornerRadius(AlmaTheme.radius)
                        }
                    } else {
                        VStack(spacing: 30) {
                            Text(formatTime(timeRemaining))
                                .font(.system(size: 80, weight: .thin, design: .default))
                                .foregroundColor(AlmaTheme.accent)
                                .tabularNums()

                            Text("Respire profundamente...")
                                .font(.subheadline)
                                .foregroundColor(AlmaTheme.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: stopMeditation) {
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
                        }
                        .padding(AlmaTheme.paddingPage)
                    }

                    Spacer()
                }
                .padding(AlmaTheme.paddingPage)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func startMeditation() {
        timeRemaining = selectedDuration * 60
        isMeditating = true
        startTimer()
    }

    private func stopMeditation() {
        isMeditating = false
        timer?.invalidate()
        timer = nil
        timeRemaining = 0
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                stopMeditation()
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    MeditationView()
        .preferredColorScheme(.dark)
}
