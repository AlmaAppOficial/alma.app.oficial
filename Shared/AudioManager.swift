import AVFoundation
import AVKit
import MediaPlayer
import UIKit

// MARK: - Ambient Sound Type
enum AmbientType {
    case whiteNoise
    case pinkNoise
    case rain
    case nature
    case nightSounds
    // High-quality real-time synthesis:
    case rainForest    // Chuva na Floresta — DSP pink noise + LFO
    case ocean         // Ondas do Oceano — wave LFO envelope
    case forestNight   // Floresta Noturna — quiet base + cricket chirps
    case campfire      // Fogueira Crepitante — brown noise + crackle pops
}

// MARK: - Audio Manager
class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    @Published var isPlaying = false
    @Published var currentTrackTitle: String? = nil
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0

    // Shown as "album" line in Control Center / Lock Screen
    var nowPlayingAlbum: String = "Alma"

    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var pausedElapsed: Double = 0
    private var currentDuration: Double = 0
    private var bellTimer: Timer?
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    // AVPlayer for streaming
    var player: AVPlayer?
    private var playerLoopObserver: NSObjectProtocol?

    private var sinePhase: Double = 0
    private var sineFrequency: Double = 0

    private var noiseBuffer: [Float] = []
    private var noiseIndex: Int = 0

    // MARK: - Real-Time Ambient DSP State (audio thread only — no heap allocs)
    private var ambCurrentType: AmbientType = .rainForest
    private var randSeed: UInt64 = 987654321
    private var pk0: Float = 0, pk1: Float = 0, pk2: Float = 0
    private var pk3: Float = 0, pk4: Float = 0, pk5: Float = 0, pk6: Float = 0
    private var ambLFO1: Double = 0, ambLFO2: Double = 0
    private var ambOscPhase: Double = 0
    private var ambCrackleTimer: Double = 0
    private var ambCrackleDecay: Float = 0
    private var ambCrackleActive: Bool = false
    private var ambBrownLast: Float = 0

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    // MARK: - Session & Remote Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: []
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            self?.stop()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            if self.isPlaying { self.pause() } else { self.resume() }
            return .success
        }
    }

    // MARK: - Now Playing Info (Lock Screen / Control Center / Apple Watch)

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                   currentTrackTitle ?? "Alma",
            MPMediaItemPropertyArtist:                  "Alma",
            MPMediaItemPropertyAlbumTitle:              nowPlayingAlbum,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPMediaItemPropertyPlaybackDuration:        currentDuration,
            MPNowPlayingInfoPropertyPlaybackRate:       isPlaying ? 1.0 : 0.0
        ]

        // Use the bundled Alma logo; fall back to a generated purple tile if missing
        let artwork = UIImage(named: "AlmaLogo") ?? makeAlmaArtworkFallback()
        let artSize = CGSize(width: 512, height: 512)
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artSize) { _ in artwork }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Generates a purple rounded-square "ALMA" image used as album art when
    /// the bundled AlmaLogo asset is unavailable (e.g. simulator without asset).
    private func makeAlmaArtworkFallback() -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            // Purple background matching Alma brand
            UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 96).fill()
            // "ALMA" centred in white
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 108, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let text = "ALMA" as NSString
            let tSize = text.size(withAttributes: attrs)
            let tRect = CGRect(x: (size.width - tSize.width) / 2,
                               y: (size.height - tSize.height) / 2,
                               width: tSize.width, height: tSize.height)
            text.draw(in: tRect, withAttributes: attrs)
        }
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Engine Lifecycle

    private func detachCurrentNode() {
        if let node = sourceNode {
            audioEngine.detach(node)
            sourceNode = nil
        }
    }

    private func startEngine() throws {
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }
    }

    // MARK: - Streaming (Classical Music & Ambient)

    func playStream(title: String, url: String, duration: Double, loops: Bool = false) {
        stopAndReset()
        nowPlayingAlbum = "Alma"

        guard let streamURL = URL(string: url) else {
            print("Invalid stream URL: \(url)")
            return
        }

        let playerItem = AVPlayerItem(url: streamURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.volume = 1.0
        player = avPlayer
        avPlayer.play()

        currentTrackTitle = title
        currentDuration = duration
        startTime = CACurrentMediaTime()
        pausedElapsed = 0

        DispatchQueue.main.async {
            self.isPlaying = true
            self.duration = duration
        }
        startTimerUpdates()
        updateNowPlayingInfo()

        if loops {
            playerLoopObserver = NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }

        // Observe playback errors
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("Stream error for \(title): \(error.localizedDescription)")
            }
            DispatchQueue.main.async { self?.isPlaying = false }
        }
    }

    // MARK: - Soft Background Music for Meditation
    // Generates a warm multi-harmonic tone (singing bowl style) at very low volume.
    // Designed to sit under the voice guide without competing with it.
    func playMeditationBackground() {
        guard let format = audioFormat else { return }

        // Three harmonically related frequencies: root + 5th + octave (soft, open chord)
        let frequencies: [Double] = [174.0, 261.0, 432.0]   // healing, heart, harmony
        var phases = [Double](repeating: 0, count: frequencies.count)
        // Very slow LFO: 0.04 Hz = 25s breath cycle
        var lfoPhase: Double = 0

        let bgNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard self != nil else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let floatData = buffers[0].mData!.assumingMemoryBound(to: Float.self)
            for i in 0..<Int(frameCount) {
                // Gentle LFO envelope (0.04 → 0.12 amplitude swing)
                lfoPhase += 2.0 * .pi * 0.04 / 44100.0
                let lfo = Float(0.08 + 0.04 * sin(lfoPhase))
                // Sum harmonics
                var sample: Float = 0
                for (j, freq) in frequencies.enumerated() {
                    let weight: Float = j == 0 ? 0.6 : (j == 1 ? 0.3 : 0.1)
                    sample += Float(sin(phases[j])) * weight
                    phases[j] += 2.0 * .pi * freq / 44100.0
                    if phases[j] > 2.0 * .pi { phases[j] -= 2.0 * .pi }
                }
                floatData[i] = sample * lfo
            }
            return noErr
        }

        sourceNode = bgNode
        audioEngine.attach(bgNode)
        audioEngine.connect(bgNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 0.18   // soft under the voice

        do { try startEngine() } catch { print("Meditation BG error: \(error)") }
    }

    func stopMeditationBackground() {
        if audioEngine.isRunning { audioEngine.stop() }
        detachCurrentNode()
        audioEngine.mainMixerNode.outputVolume = 1.0
    }

    /// Called by GuidedMeditationEngine after loading the bundled .m4a to
    /// correct the duration from the estimated script value to the real file length.
    func updateMeditationDuration(_ actualDuration: Double) {
        currentDuration = actualDuration
        duration = actualDuration
        updateNowPlayingInfo()
    }

    /// Called by GuidedMeditationEngine to register the meditation track in
    /// Now Playing Center, lock screen, Control Center, and Apple Watch.
    func registerMeditationNowPlaying(title: String, durationMinutes: Int) {
        let dur = Double(durationMinutes * 60)
        nowPlayingAlbum = "Meditação Guiada • Alma"
        currentTrackTitle = title
        currentDuration = dur
        startTime = CACurrentMediaTime()
        pausedElapsed = 0
        // Set isPlaying synchronously so updateNowPlayingInfo() sees rate = 1.0
        isPlaying = true
        duration  = dur
        elapsed   = 0
        print("🎵 [AudioManager] registerMeditationNowPlaying — title=\(title), isPlaying=\(isPlaying), thread=\(Thread.isMainThread ? "main" : "bg")")
        startTimerUpdates()
        updateNowPlayingInfo()
    }

    // MARK: - Binaural Beats

    func playBinaural(title: String, frequencyHz: Double, duration: Double) {
        stopAndReset()
        currentTrackTitle = title
        currentDuration = duration
        sineFrequency = frequencyHz
        sinePhase = 0

        guard let format = audioFormat else { return }

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let floatData = buffers[0].mData!.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                floatData[i] = Float(sin(self.sinePhase)) * 0.3
                self.sinePhase += 2.0 * .pi * self.sineFrequency / 44100.0
                if self.sinePhase > 2.0 * .pi { self.sinePhase -= 2.0 * .pi }
            }
            return noErr
        }

        sourceNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        do {
            try startEngine()
            DispatchQueue.main.async {
                self.isPlaying = true
                self.duration = duration
            }
            startTime = CACurrentMediaTime()
            pausedElapsed = 0
            startTimerUpdates()
            scheduleAutoStop(duration: duration)
            updateNowPlayingInfo()
        } catch {
            print("Binaural playback error: \(error)")
        }
    }

    // MARK: - Ambient Sounds

    func playAmbient(title: String, type: AmbientType, duration: Double) {
        stopAndReset()
        currentTrackTitle = title
        currentDuration = duration

        guard let format = audioFormat else { return }

        switch type {
        case .rainForest, .ocean, .forestNight, .campfire:
            // Real-time DSP synthesis — infinite, never loops, no pre-buffer
            ambCurrentType = type
            pk0=0; pk1=0; pk2=0; pk3=0; pk4=0; pk5=0; pk6=0
            ambLFO1=0; ambLFO2=0; ambOscPhase=0
            ambCrackleTimer=0; ambCrackleDecay=0; ambCrackleActive=false
            ambBrownLast=0; randSeed=987654321

            let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }
                let bufs = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let fd = bufs[0].mData!.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(frameCount) { fd[i] = self.ambientRTSample() }
                return noErr
            }
            sourceNode = node
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)

        default:
            // Legacy buffer-based approach for whiteNoise / pinkNoise / rain / nature / nightSounds
            generateNoiseBuffer(type: type)
            let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self = self else { return noErr }
                let bufs = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let fd = bufs[0].mData!.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(frameCount) {
                    fd[i] = self.noiseBuffer.isEmpty ? 0 : self.noiseBuffer[self.noiseIndex % self.noiseBuffer.count]
                    self.noiseIndex += 1
                }
                return noErr
            }
            sourceNode = node
            audioEngine.attach(node)
            audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        }

        audioEngine.mainMixerNode.outputVolume = 1.0

        do {
            try startEngine()
            DispatchQueue.main.async {
                self.isPlaying = true
                self.duration = duration
            }
            startTime = CACurrentMediaTime()
            pausedElapsed = 0
            startTimerUpdates()
            scheduleAutoStop(duration: duration)
            updateNowPlayingInfo()
        } catch {
            print("Ambient playback error: \(error)")
        }
    }

    // MARK: - Silent Meditation with Bell

    func playSilentMeditation(title: String, durationMinutes: Int) {
        stopAndReset()
        currentTrackTitle = title
        currentDuration = Double(durationMinutes * 60)

        playBell()

        DispatchQueue.main.async {
            self.isPlaying = true
            self.duration = Double(durationMinutes * 60)
        }
        startTime = CACurrentMediaTime()
        pausedElapsed = 0
        startTimerUpdates()
        updateNowPlayingInfo()

        DispatchQueue.main.asyncAfter(deadline: .now() + currentDuration) { [weak self] in
            guard let self = self else { return }
            self.playBell()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.stop()
            }
        }
    }

    // MARK: - Playback Controls

    func pause() {
        guard isPlaying else { return }
        // Pause AVPlayer (streams), AVAudioEngine (synthesized), and guided meditation voice
        player?.pause()
        if audioEngine.isRunning { audioEngine.pause() }
        Task { await MainActor.run { GuidedMeditationEngine.shared.pause() } }
        pausedElapsed = elapsed
        displayLink?.invalidate()
        displayLink = nil
        DispatchQueue.main.async { self.isPlaying = false }
        updateNowPlayingInfo()
    }

    func resume() {
        guard !isPlaying, currentTrackTitle != nil else { return }
        Task { await MainActor.run { GuidedMeditationEngine.shared.resume() } }
        if player != nil {
            // Resume AVPlayer stream
            player?.play()
            startTime = CACurrentMediaTime() - pausedElapsed
            DispatchQueue.main.async { self.isPlaying = true }
            startTimerUpdates()
        } else {
            // Resume AVAudioEngine synthesized sound (or meditation background)
            do {
                try startEngine()
                startTime = CACurrentMediaTime() - pausedElapsed
                DispatchQueue.main.async { self.isPlaying = true }
                startTimerUpdates()
            } catch {
                print("Resume error: \(error)")
            }
        }
        updateNowPlayingInfo()
    }

    func stop() {
        stopAndReset()
        clearNowPlayingInfo()
    }

    /// Explicit "kill switch" for user-initiated full stop — includes the guided
    /// meditation voice (ttsPlayer) that generic stop() intentionally does not touch.
    /// Call only from UI actions that mean "encerrar sessão" (MiniPlayer X button).
    /// Never from lifecycle hooks that also precede a new play() — would race.
    @MainActor
    func stopAllIncludingMeditation() {
        GuidedMeditationEngine.shared.stop()
        stop()
    }

    // MARK: - Internal Reset

    private func stopAndReset() {
        // Stop AVPlayer stream first
        player?.pause()
        player = nil
        if let obs = playerLoopObserver {
            NotificationCenter.default.removeObserver(obs)
            playerLoopObserver = nil
        }

        displayLink?.invalidate()
        displayLink = nil
        bellTimer?.invalidate()
        bellTimer = nil

        // Stop engine BEFORE detaching nodes — modifying the graph while running can crash
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        detachCurrentNode()

        // Use sync when already on main thread to avoid a race where a deferred
        // async block clears state that registerMeditationNowPlaying() already set.
        let resetState = {
            self.isPlaying = false
            self.elapsed = 0
            self.duration = 0
            self.currentTrackTitle = nil
        }
        print("🛑 [AudioManager] stopAndReset — thread=\(Thread.isMainThread ? "main(sync)" : "bg(async)")")
        if Thread.isMainThread { resetState() } else { DispatchQueue.main.async(execute: resetState) }
        sinePhase = 0
        noiseIndex = 0
        pausedElapsed = 0
        nowPlayingAlbum = "Alma"
    }

    // MARK: - Timer Updates

    private func startTimerUpdates() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateElapsedTime))
        displayLink?.preferredFramesPerSecond = 2
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateElapsedTime() {
        let currentElapsed = CACurrentMediaTime() - startTime
        DispatchQueue.main.async {
            self.elapsed = currentElapsed
            // Keep Now Playing elapsed in sync
            if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentElapsed
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }

        if currentElapsed >= currentDuration && currentDuration > 0 {
            stop()
        }
    }

    private func scheduleAutoStop(duration: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.isPlaying else { return }
            self.stop()
        }
    }

    // MARK: - Real-Time Ambient DSP (audio thread — allocation-free)

    /// LCG random: fast, deterministic, no heap allocation
    private func lcgRand() -> Float {
        randSeed = randSeed &* 6364136223846793005 &+ 1442695040888963407
        return Float(Int32(bitPattern: UInt32(randSeed >> 32))) / Float(Int32.max)
    }

    /// Paul Kellet's refined pink noise (1/f spectrum)
    private func pinkRT() -> Float {
        let w = lcgRand()
        pk0 = 0.99886 * pk0 + w * 0.0555179
        pk1 = 0.99332 * pk1 + w * 0.0750759
        pk2 = 0.96900 * pk2 + w * 0.1538520
        pk3 = 0.86650 * pk3 + w * 0.3104856
        pk4 = 0.55000 * pk4 + w * 0.5329522
        pk5 = -0.7616 * pk5 - w * 0.0168980
        let pink = pk0 + pk1 + pk2 + pk3 + pk4 + pk5 + pk6 + w * 0.5362
        pk6 = w * 0.115926
        return pink * 0.11
    }

    /// Brown noise (1/f², warm low-end rumble)
    private func brownRT() -> Float {
        let w = lcgRand()
        ambBrownLast = (ambBrownLast + 0.02 * w) / 1.02
        return ambBrownLast * 3.5
    }

    private func ambientRTSample() -> Float {
        switch ambCurrentType {
        case .rainForest:   return rainRTSample()
        case .ocean:        return oceanRTSample()
        case .forestNight:  return forestRTSample()
        case .campfire:     return campfireRTSample()
        default:            return 0
        }
    }

    /// Chuva na Floresta: ruído rosa com LFOs de intensidade variável + impacto de gotas
    private func rainRTSample() -> Float {
        ambLFO1 += 2.0 * .pi * 0.07 / 44100.0   // 0.07 Hz — ciclo de 14 s (chuva pesada→leve)
        ambLFO2 += 2.0 * .pi * 0.28 / 44100.0   // 0.28 Hz — rajada de 3.6 s
        if ambLFO1 > 2.0 * .pi { ambLFO1 -= 2.0 * .pi }
        if ambLFO2 > 2.0 * .pi { ambLFO2 -= 2.0 * .pi }
        let env = Float(0.65 + 0.22 * sin(ambLFO1) + 0.13 * sin(ambLFO2))
        let pink = pinkRT()
        // Gotas individuais: impacto de alta frequência + corpo de baixa frequência
        let drop = lcgRand() * 0.08
        let dropBody = lcgRand() < -0.98 ? brownRT() * 0.3 : 0  // gotas grossas ocasionais
        return (pink * env + drop + dropBody) * 0.72
    }

    /// Ocean: two wave LFOs with asymmetric build-crash envelope on pink noise layers
    private func oceanRTSample() -> Float {
        ambLFO1 += 2.0 * .pi * 0.125 / 44100.0  // 0.125 Hz — 8s wave
        ambLFO2 += 2.0 * .pi * 0.090 / 44100.0  // 0.090 Hz — 11s wave (offset)
        if ambLFO1 > 2.0 * .pi { ambLFO1 -= 2.0 * .pi }
        if ambLFO2 > 2.0 * .pi { ambLFO2 -= 2.0 * .pi }
        // Squared sine gives asymmetric "build up then crash" wave shape
        let w1 = max(0, Float(sin(ambLFO1))); let wave1 = w1 * w1
        let w2 = max(0, Float(sin(ambLFO2 + .pi * 0.7))); let wave2 = w2
        return (pinkRT() * 2.2 * wave1 * 0.65 + pinkRT() * 1.5 * wave2 * 0.35) * 0.58
    }

    /// Floresta Noturna: ruído base com grilos (3.8 kHz) e vento suave com LFO
    private func forestRTSample() -> Float {
        // Ruído rosa base audível como sussurro de floresta (aumentado de 0.07 → 0.18)
        let base = pinkRT() * 0.18

        // LFO lento simulando brisa (0.04 Hz — ciclo de 25 s)
        ambLFO1 += 2.0 * .pi * 0.04 / 44100.0
        if ambLFO1 > 2.0 * .pi { ambLFO1 -= 2.0 * .pi }
        let breeze = pinkRT() * Float(0.06 + 0.04 * sin(ambLFO1))

        // Grilos: 3800 Hz, disparados probabilisticamente (~18/s)
        var chirp: Float = 0
        if !ambCrackleActive {
            if (lcgRand() + 1.0) * 0.5 < 0.0004 {
                ambCrackleActive = true; ambCrackleDecay = 0.32
            }
        }
        if ambCrackleActive {
            ambOscPhase += 2.0 * .pi * 3800.0 / 44100.0
            if ambOscPhase > 2.0 * .pi { ambOscPhase -= 2.0 * .pi }
            chirp = Float(sin(ambOscPhase)) * ambCrackleDecay * 0.28
            ambCrackleDecay -= 1.2 / 44100.0
            if ambCrackleDecay <= 0 { ambCrackleActive = false; ambCrackleDecay = 0 }
        }
        return (base + breeze + chirp) * 0.78
    }

    /// Campfire: brown noise rumble + slow fire-breath LFO + random crackle pops
    private func campfireRTSample() -> Float {
        let brown = brownRT() * 0.35
        ambLFO1 += 2.0 * .pi * 0.06 / 44100.0   // 0.06 Hz — slow fire breath
        if ambLFO1 > 2.0 * .pi { ambLFO1 -= 2.0 * .pi }
        let fireBreath = Float(0.5 + 0.5 * sin(ambLFO1)) * pinkRT() * 0.25
        var crackle: Float = 0
        if !ambCrackleActive {
            if (lcgRand() + 1.0) * 0.5 < 0.0006 {   // ~26 crackle triggers/sec
                ambCrackleActive = true; ambCrackleDecay = 0.07
            }
        }
        if ambCrackleActive {
            crackle = lcgRand() * ambCrackleDecay * 1.8
            ambCrackleDecay -= 10.0 / 44100.0
            if ambCrackleDecay <= 0 { ambCrackleActive = false; ambCrackleDecay = 0 }
        }
        return (brown + fireBreath + crackle) * 0.52
    }

    // MARK: - Noise Generation (legacy buffer approach)

    private func generateNoiseBuffer(type: AmbientType) {
        let bufferSize = 44100 / 10

        switch type {
        case .whiteNoise:
            noiseBuffer = (0..<bufferSize).map { _ in Float.random(in: -0.3...0.3) }

        case .pinkNoise:
            var b0: Float = 0, b1: Float = 0
            noiseBuffer = (0..<bufferSize).map { _ in
                let white = Float.random(in: -1...1)
                let pink = (white + 2 * b0 + b1) / 4
                b1 = b0
                b0 = pink
                return pink * 0.3
            }

        case .rain:
            let rainRateHz: Float = 0.2
            var phase: Float = 0
            noiseBuffer = (0..<bufferSize).map { _ in
                let white = Float.random(in: -0.5...0.5)
                phase += rainRateHz / 44100.0
                let mod = 0.5 + 0.5 * sin(phase * 2 * .pi)
                return white * mod * 0.25
            }

        case .nature:
            var prev: Float = 0
            noiseBuffer = (0..<bufferSize).map { _ in
                let white = Float.random(in: -0.3...0.3)
                let filtered = (white + prev) / 2
                prev = filtered
                return filtered
            }

        case .nightSounds:
            noiseBuffer = (0..<bufferSize).map { _ in
                let white = Float.random(in: -0.2...0.2)
                let occ = Int.random(in: 0..<100) < 5 ? Float.random(in: -0.5...0.5) : 0
                return (white + occ) * 0.2
            }

        default:
            // New real-time types (.rainForest, .ocean, .forestNight, .campfire)
            // are handled in playAmbient and never reach this buffer path.
            noiseBuffer = []
        }

        noiseIndex = 0
    }

    // MARK: - Bell Sound

    private func playBell() {
        let bellFrequency = 528.0
        let bellDuration = 2.0
        let sampleRate = 44100.0

        guard let format = audioFormat else { return }

        // Detach any old bell node (we track with a separate var if needed — here just use a local ref)
        var bellPhase = 0.0

        let bellNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let floatData = buffers[0].mData!.assumingMemoryBound(to: Float.self)

            for i in 0..<Int(frameCount) {
                let t = bellPhase / sampleRate
                let decay = max(0.0, 1.0 - t / bellDuration)
                floatData[i] = Float(sin(bellPhase * 2 * .pi * bellFrequency / sampleRate)) * Float(decay) * 0.4
                bellPhase += 1.0
            }
            return noErr
        }

        audioEngine.attach(bellNode)
        audioEngine.connect(bellNode, to: audioEngine.mainMixerNode, format: format)

        do {
            try startEngine()
        } catch {
            print("Bell engine error: \(error)")
        }

        // Detach bell node after it finishes playing
        DispatchQueue.main.asyncAfter(deadline: .now() + bellDuration + 0.5) { [weak self] in
            self?.audioEngine.detach(bellNode)
        }
    }
}
