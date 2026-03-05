import Foundation

class MeditationViewModel: ObservableObject {
    @Published var isPlaying    = false
    @Published var timeRemaining: Int = 0
    @Published var progress: Double   = 0.0
    @Published var hasCompleted = false

    private var timer: Timer?
    private var totalDuration = 0

    func start(duration: Int) {
        stop()
        totalDuration  = duration
        timeRemaining  = duration
        progress       = 0.0
        hasCompleted   = false
        isPlaying      = true
        scheduleTimer()
    }

    func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying { scheduleTimer() } else { timer?.invalidate() }
    }

    func stop() {
        timer?.invalidate()
        timer         = nil
        isPlaying     = false
        timeRemaining = 0
        progress      = 0
        hasCompleted  = false
    }

    func skip(seconds: Int) {
        let skipped = max(0, timeRemaining - seconds)
        timeRemaining = skipped
        progress = 1.0 - Double(skipped) / Double(totalDuration)
        if skipped == 0 {
            stop()
            hasCompleted = true
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.progress = 1.0 - Double(self.timeRemaining) / Double(self.totalDuration)
            } else {
                self.timer?.invalidate()
                self.isPlaying    = false
                self.hasCompleted = true
            }
        }
    }

    var formattedTime: String {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    deinit { timer?.invalidate() }
}
