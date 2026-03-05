import SwiftUI

// MARK: - BreatheView

struct BreatheView: View {

    // 4-7-8 Technique: Inhale 4s → Hold 7s → Exhale 8s
    private let pattern: [(phase: BreathPhase, seconds: Int)] = [
        (.inhale, 4), (.hold, 7), (.exhale, 8)
    ]

    @State private var phase: BreathPhase = .idle
    @State private var circleScale: CGFloat = 0.65
    @State private var countdown = 0
    @State private var cycleCount = 0
    @State private var isRunning = false
    @State private var timer: Timer?

    private var cycleLabel: String {
        let plural = cycleCount > 1
        return "\(cycleCount) ciclo\(plural ? "s" : "") completo\(plural ? "s" : "")"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.almaBackground, Color(red: 0.88, green: 0.93, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 36) {

                    // ── Info ──────────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("Técnica 4-7-8")
                            .font(.title2.bold())
                            .foregroundColor(.almaPrimary)
                        Text("Cientificamente comprovada para reduzir ansiedade")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 8)

                    Spacer()

                    // ── Animated circle ────────────────────────────────
                    ZStack {
                        // Ripple rings
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.almaPrimary.opacity(0.06 - Double(i) * 0.018))
                                .frame(width: 230 + CGFloat(i * 38), height: 230 + CGFloat(i * 38))
                                .scaleEffect(circleScale)
                        }

                        // Main circle
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.almaLight, Color.almaPrimary],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 110
                                )
                            )
                            .frame(width: 210, height: 210)
                            .scaleEffect(circleScale)
                            .shadow(color: Color.almaPrimary.opacity(0.35), radius: 24)

                        // Text inside circle
                        VStack(spacing: 8) {
                            Text(phase.instruction)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            if isRunning {
                                Text("\(countdown)")
                                    .font(.system(size: 44, weight: .thin, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .onTapGesture {
                        isRunning ? stopBreathing() : startBreathing()
                    }

                    // Cycle counter
                    if cycleCount > 0 {
                        Label(cycleLabel, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.almaPrimary)
                    }

                    Spacer()

                    // ── Step cards ─────────────────────────────────────
                    HStack(spacing: 14) {
                        StepCard(duration: "4s",  label: "Inspire",  color: .blue)
                        StepCard(duration: "7s",  label: "Segure",   color: .almaPrimary)
                        StepCard(duration: "8s",  label: "Expire",   color: .teal)
                    }
                    .padding(.horizontal)

                    Text(isRunning ? "Toque no círculo para pausar" : "Toque no círculo para começar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("Respirar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Breathing Logic

    private func startBreathing() {
        isRunning  = true
        cycleCount = 0
        runStep(index: 0)
    }

    private func stopBreathing() {
        timer?.invalidate()
        timer     = nil
        isRunning = false
        withAnimation(.easeInOut(duration: 0.6)) {
            phase       = .idle
            circleScale = BreathPhase.idle.targetScale
        }
        countdown = 0
    }

    private func runStep(index: Int) {
        guard isRunning else { return }

        if index >= pattern.count {
            cycleCount += 1
            runStep(index: 0)
            return
        }

        let (nextPhase, secs) = pattern[index]
        phase     = nextPhase
        countdown = secs

        withAnimation(.easeInOut(duration: Double(secs))) {
            circleScale = nextPhase.targetScale
        }

        var remaining = secs
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            remaining -= 1
            countdown  = remaining
            if remaining <= 0 {
                t.invalidate()
                runStep(index: index + 1)
            }
        }
    }
}

// MARK: - Supporting Types

private enum BreathPhase {
    case idle, inhale, hold, exhale

    var instruction: String {
        switch self {
        case .idle:   return "Toque\npara\ncomeçar"
        case .inhale: return "Inspire"
        case .hold:   return "Segure"
        case .exhale: return "Expire"
        }
    }

    var targetScale: CGFloat {
        switch self {
        case .idle, .exhale: return 0.65
        case .inhale, .hold: return 1.2
        }
    }
}

// MARK: - StepCard

private struct StepCard: View {
    let duration: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(duration)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

#Preview {
    BreatheView()
}
