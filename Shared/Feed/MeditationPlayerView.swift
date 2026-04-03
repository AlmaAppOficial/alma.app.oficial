import SwiftUI
import AVFoundation

struct MeditationPlayerView: View {
    let post: FeedPost

    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var displayLink: Timer?

    private var totalDuration: Double {
        Double(post.meditationDuration ?? 420)
    }

    var body: some View {
        VStack(spacing: 20) {

            // ── Waveform visualization ──────────────────────────────
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    WaveBar(index: i, isPlaying: isPlaying)
                }
            }
            .frame(height: 44)
            .padding(.top, 4)

            // ── Play / Pause ────────────────────────────────────────
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(CalmTheme.primary)
                        .frame(width: 64, height: 64)
                        .shadow(color: CalmTheme.primary.opacity(0.4), radius: 12, y: 4)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .offset(x: isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)

            // ── Timeline ────────────────────────────────────────────
            VStack(spacing: 6) {
                Slider(value: $currentTime, in: 0...totalDuration) { editing in
                    if !editing {
                        audioPlayer?.currentTime = currentTime
                    }
                }
                .tint(CalmTheme.primary)

                HStack {
                    Text(formatTime(currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CalmTheme.textSecondary)
                    Spacer()
                    Text(formatTime(totalDuration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }

            // ── Duration label ──────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                Text("\(Int(totalDuration / 60)) minutos · Meditação guiada")
                    .font(.system(size: 12))
            }
            .foregroundColor(CalmTheme.textSecondary)
        }
        .padding(CalmTheme.s16)
        .background(CalmTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
        .onDisappear { stopPlayback() }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        if let urlStr = post.meditationAudio, let url = URL(string: urlStr) {
            // Real audio
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.currentTime = currentTime
                audioPlayer?.play()
            } catch {
                // Audio unavailable — run demo timer
            }
        }
        // Demo timer (runs even without real audio for UI demo)
        isPlaying = true
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async {
                if let player = self.audioPlayer {
                    self.currentTime = player.currentTime
                    if !player.isPlaying {
                        self.isPlaying = false
                        self.displayLink?.invalidate()
                    }
                } else {
                    // Simulate progress for demo
                    if self.currentTime < self.totalDuration {
                        self.currentTime += 0.5
                    } else {
                        self.isPlaying = false
                        self.displayLink?.invalidate()
                    }
                }
            }
        }
    }

    private func pausePlayback() {
        isPlaying = false
        audioPlayer?.pause()
        displayLink?.invalidate()
        displayLink = nil
    }

    private func stopPlayback() {
        isPlaying = false
        audioPlayer?.stop()
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Format

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Animated Wave Bar

private struct WaveBar: View {
    let index: Int
    let isPlaying: Bool

    @State private var height: CGFloat = 10

    private let heights: [CGFloat] = [18, 30, 22, 40, 28, 20, 14]
    private let delays:  [Double]  = [0, 0.1, 0.2, 0.05, 0.15, 0.25, 0.08]

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(CalmTheme.primary.opacity(isPlaying ? 0.85 : 0.35))
            .frame(width: 4, height: height)
            .animation(
                isPlaying
                    ? .easeInOut(duration: 0.55)
                        .repeatForever(autoreverses: true)
                        .delay(delays[index % delays.count])
                    : .easeOut(duration: 0.3),
                value: height
            )
            .onAppear { updateHeight() }
            .onChange(of: isPlaying) { _ in updateHeight() }
    }

    private func updateHeight() {
        height = isPlaying ? heights[index % heights.count] : 10
    }
}
