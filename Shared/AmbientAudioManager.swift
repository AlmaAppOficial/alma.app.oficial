import AVFoundation
import Combine
import os.log

/// Manages ambient sound mixing with meditation audio
/// Provides royalty-free ambient sounds (rain, forest, waves) mixed with voice tracks
/// Supports independent volume control and background audio playback
actor AmbientAudioManager: ObservableObject {
    // MARK: - Types

    /// Available ambient sound options
    enum AmbientSound: String, CaseIterable, Hashable, Codable {
        case silence = "Silêncio"
        case rain = "Chuva suave"
        case forest = "Floresta"
        case ocean = "Ondas do mar"
        case fire = "Lareira"
        case whitenoise = "Ruído branco"
        case bowls = "Tigelas tibetanas"

        /// Sound file name (without extension)
        var fileName: String {
            switch self {
            case .silence:
                return "silence"
            case .rain:
                return "ambient_rain"
            case .forest:
                return "ambient_forest"
            case .ocean:
                return "ambient_ocean"
            case .fire:
                return "ambient_fire"
            case .whitenoise:
                return "ambient_whitenoise"
            case .bowls:
                return "ambient_bowls"
            }
        }

        /// Human-readable display name
        var displayName: String {
            self.rawValue
        }
    }

    // MARK: - Properties

    @MainActor @Published private(set) var currentAmbientSound: AmbientSound = .silence
    @MainActor @Published private(set) var ambientVolume: Float = 0.3
    @MainActor @Published private(set) var isPlayingAmbient: Bool = false
    @MainActor @Published private(set) var error: Error?

    private let audioEngine: AVAudioEngine
    private let ambientPlayerNode: AVAudioPlayerNode
    private let meditationPlayerNode: AVAudioPlayerNode
    private let mixerNode: AVAudioMixerNode
    private let environmentalReverb: AVAudioUnitReverb
    private let eqUnit: AVAudioUnitEQ

    private var ambientAudioFile: AVAudioFile?
    private var fadeTimer: Timer?
    private let logger = Logger(subsystem: "com.alma.official", category: "AmbientAudio")

    // UserDefaults key for persisting user's ambient preference
    private static let ambientPreferenceKey = "AlmaAmbientSoundPreference"
    private static let ambientVolumeKey = "AlmaAmbientVolume"

    // MARK: - Initialization

    nonisolated init() {
        self.audioEngine = AVAudioEngine()
        self.ambientPlayerNode = AVAudioPlayerNode()
        self.meditationPlayerNode = AVAudioPlayerNode()
        self.mixerNode = audioEngine.mainMixerNode
        self.environmentalReverb = AVAudioUnitReverb()
        self.eqUnit = AVAudioUnitEQ(numberOfBands: 3)

        setupAudioEngine()
        loadUserPreferences()
    }

    // MARK: - Public Methods

    /// Sets the ambient sound and updates volume
    /// - Parameters:
    ///   - sound: The ambient sound to play
    ///   - volume: Volume level (0.0 to 1.0)
    nonisolated func setAmbientSound(_ sound: AmbientSound, volume: Float) {
        Task {
            await self._setAmbientSound(sound, volume: volume)
        }
    }

    /// Fades in ambient audio over specified duration
    /// - Parameter duration: Fade in duration in seconds
    nonisolated func fadeIn(duration: TimeInterval = 1.0) {
        Task {
            await self._fadeIn(duration: duration)
        }
    }

    /// Fades out ambient audio over specified duration
    /// - Parameter duration: Fade out duration in seconds
    nonisolated func fadeOut(duration: TimeInterval = 1.0) {
        Task {
            await self._fadeOut(duration: duration)
        }
    }

    /// Mixes ambient audio with meditation audio player
    /// - Parameter meditationPlayer: The meditation audio player to mix with
    nonisolated func mixWithMeditationAudio(meditationPlayer: AVAudioPlayer) {
        Task {
            await self._mixWithMeditationAudio(meditationPlayer: meditationPlayer)
        }
    }

    /// Gets current ambient sound preference
    nonisolated func getCurrentAmbientSound() async -> AmbientSound {
        await currentAmbientSound
    }

    /// Gets current ambient volume
    nonisolated func getCurrentVolume() async -> Float {
        await ambientVolume
    }

    /// Stops ambient audio playback
    nonisolated func stopAmbient() {
        Task {
            await self._stopAmbient()
        }
    }

    // MARK: - Private Methods

    private func _setAmbientSound(_ sound: AmbientSound, volume: Float) async {
        do {
            currentAmbientSound = sound
            ambientVolume = max(0.0, min(1.0, volume))

            // Save user preference
            await MainActor.run {
                UserDefaults.standard.set(sound.rawValue, forKey: Self.ambientPreferenceKey)
                UserDefaults.standard.set(ambientVolume, forKey: Self.ambientVolumeKey)
            }

            // Load and play audio file
            guard let audioFile = try loadAudioFile(for: sound) else {
                logger.warning("Could not load audio file for \(sound.displayName)")
                return
            }

            ambientAudioFile = audioFile
            try attachNodesToEngine()
            try configureAudioSession()

            ambientPlayerNode.volume = ambientVolume

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            if !ambientPlayerNode.isPlaying {
                try ambientPlayerNode.scheduleFile(audioFile, at: nil)
                ambientPlayerNode.play()

                await MainActor.run {
                    isPlayingAmbient = true
                }
            }

            logger.info("Ambient sound set to \(sound.displayName) at volume \(volume)")

        } catch {
            logger.error("Error setting ambient sound: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
        }
    }

    private func _fadeIn(duration: TimeInterval) async {
        let startVolume = ambientVolume
        let startDate = Date()

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startDate)
            let progress = min(elapsed / duration, 1.0)

            Task {
                await self._updateVolume(startVolume * Float(progress))

                if progress >= 1.0 {
                    self.fadeTimer?.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    private func _fadeOut(duration: TimeInterval) async {
        let startVolume = ambientVolume
        let startDate = Date()

        fadeTimer?.invalidate()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let elapsed = Date().timeIntervalSince(startDate)
            let progress = min(elapsed / duration, 1.0)

            Task {
                await self._updateVolume(startVolume * Float(1.0 - progress))

                if progress >= 1.0 {
                    await self._stopAmbient()
                    self.fadeTimer?.invalidate()
                    self.fadeTimer = nil
                }
            }
        }
    }

    private func _updateVolume(_ volume: Float) async {
        ambientVolume = max(0.0, min(1.0, volume))
        ambientPlayerNode.volume = ambientVolume
    }

    private func _stopAmbient() async {
        ambientPlayerNode.stop()
        fadeTimer?.invalidate()
        fadeTimer = nil

        await MainActor.run {
            isPlayingAmbient = false
        }
    }

    private func _mixWithMeditationAudio(meditationPlayer: AVAudioPlayer) async {
        do {
            try attachNodesToEngine()

            // Connect meditation player to mixer
            if let audioFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0) {
                let meditationAVAudioNode = AVAudioPlayerNode()
                audioEngine.attach(meditationAVAudioNode)
                audioEngine.connect(meditationAVAudioNode, to: mixerNode, format: audioFormat)
            }

            logger.info("Meditation audio mixed with ambient sound")
        } catch {
            logger.error("Error mixing audio: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
            }
        }
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        do {
            audioEngine.attach(ambientPlayerNode)
            audioEngine.attach(meditationPlayerNode)
            audioEngine.attach(environmentalReverb)
            audioEngine.attach(eqUnit)

            // Configure reverb for natural ambient sound
            environmentalReverb.loadFactoryPreset(.mediumHall)
            environmentalReverb.wetDryMix = 15

            // Configure EQ (optional warm eq curve)
            configureEQ()

            // Connect nodes
            if let format = audioEngine.mainMixerNode.outputFormat(forBus: 0) {
                audioEngine.connect(ambientPlayerNode, to: environmentalReverb, format: format)
                audioEngine.connect(environmentalReverb, to: eqUnit, format: format)
                audioEngine.connect(eqUnit, to: mixerNode, format: format)
            }

            logger.debug("Audio engine configured successfully")
        } catch {
            logger.error("Error configuring audio engine: \(error.localizedDescription)")
        }
    }

    private func attachNodesToEngine() throws {
        if !audioEngine.attachedNodes.contains(ambientPlayerNode) {
            audioEngine.attach(ambientPlayerNode)
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func configureEQ() {
        // Warm EQ: slight boost in low mids for ambient comfort
        if eqUnit.bands.count >= 3 {
            eqUnit.bands[0].frequency = 100
            eqUnit.bands[0].bandwidth = 1.0
            eqUnit.bands[0].gain = 2.0

            eqUnit.bands[1].frequency = 1000
            eqUnit.bands[1].bandwidth = 1.0
            eqUnit.bands[1].gain = 0.0

            eqUnit.bands[2].frequency = 8000
            eqUnit.bands[2].bandwidth = 1.0
            eqUnit.bands[2].gain = 1.0
        }
    }

    // MARK: - Audio File Loading

    private func loadAudioFile(for sound: AmbientSound) throws -> AVAudioFile? {
        guard let url = Bundle.main.url(
            forResource: sound.fileName,
            withExtension: "m4a"
        ) else {
            // Fallback for silence (no file needed)
            if sound == .silence {
                return nil
            }
            logger.warning("Audio file not found for \(sound.displayName)")
            return nil
        }

        let audioFile = try AVAudioFile(forReading: url)
        return audioFile
    }

    // MARK: - Persistence

    private func loadUserPreferences() {
        let defaults = UserDefaults.standard

        if let savedSoundName = defaults.string(forKey: Self.ambientPreferenceKey),
           let savedSound = AmbientSound(rawValue: savedSoundName) {
            Task {
                await MainActor.run {
                    self.currentAmbientSound = savedSound
                }
            }
        }

        let savedVolume = defaults.float(forKey: Self.ambientVolumeKey)
        if savedVolume > 0 {
            Task {
                await MainActor.run {
                    self.ambientVolume = savedVolume
                }
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        fadeTimer?.invalidate()
        try? audioEngine.stop()
    }
}

// MARK: - SwiftUI Preview Support

#if DEBUG
extension AmbientAudioManager {
    nonisolated static let preview: AmbientAudioManager = {
        AmbientAudioManager()
    }()
}
#endif
