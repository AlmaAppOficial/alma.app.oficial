import SwiftUI

struct MeditationPlayerView: View {
    let meditation: Meditation
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = MeditationViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: meditation.gradientColors + [meditation.gradientColors[0].opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Close button
                HStack {
                    Button {
                        vm.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(10)
                            .background(.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)

                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text(meditation.title)
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text(meditation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 24)

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: vm.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.progress)

                    VStack(spacing: 6) {
                        Text(vm.formattedTime)
                            .font(.system(size: 52, weight: .thin, design: .monospaced))
                            .foregroundColor(.white)
                        Text(vm.isPlaying ? "Meditando..." : (vm.hasCompleted ? "Concluído!" : "Pausado"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .frame(width: 220, height: 220)

                Spacer()

                // Controls
                HStack(spacing: 52) {
                    Button {
                        vm.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Button {
                        if vm.hasCompleted {
                            vm.start(duration: meditation.duration)
                        } else {
                            vm.togglePlayPause()
                        }
                    } label: {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .frame(width: 74, height: 74)
                            .background(.white.opacity(0.22))
                            .clipShape(Circle())
                    }

                    // Skip +30s
                    Button {
                        vm.skip(seconds: 30)
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                // Description
                Text(meditation.description)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
            .padding(.vertical, 24)

            // Completion overlay
            if vm.hasCompleted {
                CompletionOverlay(meditationTitle: meditation.title) {
                    userViewModel.recordSession(durationSeconds: meditation.duration)
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .onAppear { vm.start(duration: meditation.duration) }
        .onDisappear { vm.stop() }
        .animation(.easeInOut(duration: 0.4), value: vm.hasCompleted)
    }
}

// MARK: - CompletionOverlay

struct CompletionOverlay: View {
    let meditationTitle: String
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🎉")
                    .font(.system(size: 72))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.65), value: appeared)

                Text("Sessão Concluída!")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("Você completou "\(meditationTitle)".\nParabéns por cuidar da sua alma! 💜")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button(action: onDone) {
                    Text("Concluir")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundColor(.almaPrimary)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)
            }
            .padding(32)
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    MeditationPlayerView(meditation: Meditation.all[0])
        .environmentObject(UserViewModel())
}
