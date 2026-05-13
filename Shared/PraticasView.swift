import SwiftUI
import AVKit

// MARK: - MeditationDay Model
struct MeditationDay: Identifiable {
    let id = UUID()
    let day: Int
    let title: String
    let subtitle: String
    let durationMinutes: Int
    let category: String  // "Respiração", "Consciência Corporal", "Emoções", "Integração"

    static var all30Days: [MeditationDay] = {
        var days: [MeditationDay] = []

        // Titles below match GuidedMeditationEngine.buildDayN() — canonical
        // source for what the bundled audio narrates. Subtitles temporarily
        // empty: meditations will be regenerated, subtitles will be redesigned
        // alongside the new set. See ACTION_LOG 2026-05-13.

        // Week 1: Respiração (Days 1-7)
        days.append(MeditationDay(day: 1, title: "Respira e Acalma", subtitle: "", durationMinutes: 5, category: "Respiração"))
        days.append(MeditationDay(day: 2, title: "O Corpo como Lar", subtitle: "", durationMinutes: 6, category: "Respiração"))
        days.append(MeditationDay(day: 3, title: "Observar sem Julgar", subtitle: "", durationMinutes: 7, category: "Respiração"))
        days.append(MeditationDay(day: 4, title: "Ondas de Presença", subtitle: "", durationMinutes: 8, category: "Respiração"))
        days.append(MeditationDay(day: 5, title: "Raízes", subtitle: "", durationMinutes: 8, category: "Respiração"))
        days.append(MeditationDay(day: 6, title: "A Leveza Interior", subtitle: "", durationMinutes: 9, category: "Respiração"))
        days.append(MeditationDay(day: 7, title: "Gratidão", subtitle: "", durationMinutes: 10, category: "Respiração"))

        // Week 2: Consciência Corporal (Days 8-14)
        days.append(MeditationDay(day: 8, title: "Espaço e Abertura", subtitle: "", durationMinutes: 8, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 9, title: "A Luz que Habitas", subtitle: "", durationMinutes: 8, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 10, title: "Soltar", subtitle: "", durationMinutes: 9, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 11, title: "O Rio da Consciência", subtitle: "", durationMinutes: 9, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 12, title: "Amor-Bondade", subtitle: "", durationMinutes: 10, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 13, title: "Escuta Profunda", subtitle: "", durationMinutes: 10, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 14, title: "O Campo do Possível", subtitle: "", durationMinutes: 11, category: "Consciência Corporal"))

        // Week 3: Emoções (Days 15-21)
        days.append(MeditationDay(day: 15, title: "Integração do Caminho", subtitle: "", durationMinutes: 9, category: "Emoções"))
        days.append(MeditationDay(day: 16, title: "Expansão da Consciência", subtitle: "", durationMinutes: 10, category: "Emoções"))
        days.append(MeditationDay(day: 17, title: "A Testemunha Silenciosa", subtitle: "", durationMinutes: 10, category: "Emoções"))
        days.append(MeditationDay(day: 18, title: "Compaixão Universal", subtitle: "", durationMinutes: 11, category: "Emoções"))
        days.append(MeditationDay(day: 19, title: "O Sonhador e o Sonho", subtitle: "", durationMinutes: 11, category: "Emoções"))
        days.append(MeditationDay(day: 20, title: "Equanimidade", subtitle: "", durationMinutes: 12, category: "Emoções"))
        days.append(MeditationDay(day: 21, title: "O Coração como Centro", subtitle: "", durationMinutes: 12, category: "Emoções"))

        // Week 4+: Integração (Days 22-30)
        days.append(MeditationDay(day: 22, title: "Vazio Luminoso", subtitle: "", durationMinutes: 12, category: "Integração"))
        days.append(MeditationDay(day: 23, title: "A Tapeçaria do Momento", subtitle: "", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 24, title: "Dissolução dos Limites", subtitle: "", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 25, title: "Presença Total", subtitle: "", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 26, title: "O Observador Puro", subtitle: "", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 27, title: "Metta — Amor sem Condições", subtitle: "", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 28, title: "Renovação Profunda", subtitle: "", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 29, title: "O Grande Silêncio", subtitle: "", durationMinutes: 15, category: "Integração"))
        days.append(MeditationDay(day: 30, title: "Celebração do Ser", subtitle: "", durationMinutes: 15, category: "Integração"))

        return days
    }()
}

// MARK: - SoundItem Model
struct SoundItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let category: SoundCategory
    let audioTitle: String  // for AudioManager
    let audioType: AudioManagerType

    enum SoundCategory {
        case meditation, day, sleep
    }

    enum AudioManagerType {
        case binaural(frequencyHz: Double)
        case ambient(AmbientType)
        case silent(durationMinutes: Int)
        case stream(url: String, loops: Bool, duration: Double)
        // Audio bundlado dentro do app (Resources). Filename inclui extensao .mp3.
        // Se loops=true, AudioManager reseta no fim e toca infinito (usado pra sleep sounds).
        case bundled(filename: String, loops: Bool, duration: Double)
    }

    static func == (lhs: SoundItem, rhs: SoundItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - RoutePickerView (AirPlay/Bluetooth/TV)
struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        // Roxo Alma para ser visível em fundo escuro
        routePicker.tintColor = UIColor(red: 0.624, green: 0.478, blue: 0.918, alpha: 1)
        routePicker.activeTintColor = UIColor(red: 0.965, green: 0.678, blue: 0.333, alpha: 1)
        routePicker.backgroundColor = UIColor.clear
        return routePicker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - MiniPlayerBar
struct MiniPlayerBar: View {
    @ObservedObject var audio = AudioManager.shared
    var body: some View {
        VStack(spacing: 0) {
            // Barra de progresso no topo
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [CalmTheme.primary, CalmTheme.primaryLight],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * (audio.duration > 0 ? min(audio.elapsed / audio.duration, 1) : 0), height: 3)
                        .animation(.linear(duration: 0.1), value: audio.elapsed)
                }
            }
            .frame(height: 3)

            HStack(spacing: 12) {
                // Track info — sempre branco sobre fundo escuro
                VStack(alignment: .leading, spacing: 2) {
                    Text(audio.currentTrackTitle ?? "")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(formatTime(audio.elapsed))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.65))
                        Text("/")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                        Text(formatTime(audio.duration))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.65))
                    }
                }

                Spacer()

                // AirPlay/Bluetooth/TV — picker nativo do iOS
                RoutePickerView()
                    .frame(width: 32, height: 32)

                // Play/Pause
                Button(action: {
                    if audio.isPlaying {
                        audio.pause()
                    } else {
                        audio.resume()
                    }
                }) {
                    Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(CalmTheme.primaryLight)
                }

                // Parar
                Button(action: { audio.stopAllIncludingMeditation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(
            ZStack {
                // Fundo escuro roxo — sempre visível em modo claro e escuro
                LinearGradient(
                    colors: [
                        Color(red: 0.059, green: 0.031, blue: 0.180),  // #0f0830 — púrpura profundo
                        Color(red: 0.102, green: 0.047, blue: 0.251),  // #1a0c40 — roxo escuro
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .ignoresSafeArea()
            }
            .shadow(color: CalmTheme.primary.opacity(0.4), radius: 16, x: 0, y: -4)
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - VisualEffectBlur (for glassmorphism)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - PraticasView
struct PraticasView: View {
    @ObservedObject var audio = AudioManager.shared
    @State private var selectedMeditationDay: MeditationDay? = nil

    // Day sounds: 4 gravacoes reais de musica classica bundladas no app.
    // Substituiu binaurais sintéticos por arquivos mp3 reais em /ClassicalMusic/.
    // Build 77: Bach (CC0), Beethoven (PD), Mozart (PD), Pachelbel (CC).
    var daySounds: [SoundItem] = [
        SoundItem(
            title: "Bach",
            subtitle: "Variações Goldberg",
            category: .day,
            audioTitle: "Bach — Variações Goldberg",
            audioType: .bundled(filename: "bach_goldberg.mp3", loops: false, duration: 1535)
        ),
        SoundItem(
            title: "Beethoven",
            subtitle: "Sinfonia Pastoral · Mov I e II",
            category: .day,
            audioTitle: "Beethoven — Sinfonia Pastoral",
            audioType: .bundled(filename: "beethoven_pastoral.mp3", loops: false, duration: 1212)
        ),
        SoundItem(
            title: "Mozart",
            subtitle: "Concerto para Piano nº 21 · K.467",
            category: .day,
            audioTitle: "Mozart — Concerto K.467",
            audioType: .bundled(filename: "mozart_k467.mp3", loops: false, duration: 1196)
        ),
        SoundItem(
            title: "Pachelbel",
            subtitle: "Canon em Ré Maior",
            category: .day,
            audioTitle: "Pachelbel — Canon em Ré Maior",
            audioType: .bundled(filename: "pachelbel_canon.mp3", loops: false, duration: 1799)
        ),
    ]

    // Sleep sounds: 4 gravacoes reais bundladas em /SleepSounds/, todas com loop infinito.
    // Substituiu sons sinteticos (rainForest/ocean/forestNight/campfire gerados via DSP)
    // por mp3s reais Pixabay + pink noise gerado via ffmpeg.
    var sleepSounds: [SoundItem] = [
        SoundItem(
            title: "Água Corrente",
            subtitle: "Riacho calmo",
            category: .sleep,
            audioTitle: "Água Corrente",
            audioType: .bundled(filename: "sleep_water.mp3", loops: true, duration: 300)
        ),
        SoundItem(
            title: "Floresta Noturna",
            subtitle: "Vento e grilos",
            category: .sleep,
            audioTitle: "Floresta Noturna",
            audioType: .bundled(filename: "sleep_forest.mp3", loops: true, duration: 300)
        ),
        SoundItem(
            title: "Lareira",
            subtitle: "Fogo crepitando",
            category: .sleep,
            audioTitle: "Lareira",
            audioType: .bundled(filename: "sleep_fireplace.mp3", loops: true, duration: 300)
        ),
        SoundItem(
            title: "Ruído Rosa",
            subtitle: "Frequências naturais para sono profundo",
            category: .sleep,
            audioTitle: "Ruído Rosa",
            audioType: .bundled(filename: "sleep_pink_noise.mp3", loops: true, duration: 300)
        ),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Page header
                pageHeader

                // Meditação Guiada (30 dias)
                sectionHeader(icon: "sparkles", color: CalmTheme.primary, title: "Meditação Guiada • 30 Dias")
                meditationSectionGrouped

                // Música Clássica (gravações reais bundladas)
                sectionHeader(icon: "music.note.list", color: .orange, title: "Música Clássica")
                Text("Bach, Beethoven, Mozart e Pachelbel — gravações completas em domínio público")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, -16)
                soundGrid(sounds: daySounds)

                // Sons para o Sono
                sectionHeader(icon: "moon.stars.fill", color: .indigo, title: "Sons pra Dormir")
                Text("Ruídos naturais e ambientes calmos para uma noite de sono reparador")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, -16)
                soundGrid(sounds: sleepSounds)

                Spacer(minLength: 120)
            }
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarHidden(true)
        .onDisappear {
            // Garantir que todo o áudio para ao sair da tela
            GuidedMeditationEngine.shared.stop()
            AudioManager.shared.stop()
        }
    }

    // MARK: - Page Header
    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Práticas")
                    .font(.largeTitle.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Meditações e sons para o seu bem-estar")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
            AlmaLogo(size: 44)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Section Header
    private func sectionHeader(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
            Text(title)
                .font(.title3.bold())
                .foregroundColor(CalmTheme.textPrimary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Meditation Section (Grouped by Week)
    private var meditationSectionGrouped: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(0..<4, id: \.self) { weekIndex in
                let weekStart = weekIndex * 7
                let weekEnd = min(weekStart + 7, 30)
                let weekDays = Array(MeditationDay.all30Days[weekStart..<weekEnd])

                if !weekDays.isEmpty {
                    // Week header
                    HStack(spacing: 6) {
                        Text("Semana \(weekIndex + 1)")
                            .font(.subheadline.bold())
                            .foregroundColor(CalmTheme.primary)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                        Text(weekDays.first?.category ?? "")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                    .padding(.horizontal, 20)

                    // Horizontal scroll of meditation cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(weekDays) { med in
                                MeditationDayCard(med: med)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedMeditationDay = med
                                            // Para qualquer música/som antes de iniciar meditação
                                            AudioManager.shared.stop()
                                            GuidedMeditationEngine.shared.play(day: med)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Sound Grid
    private func soundGrid(sounds: [SoundItem]) -> some View {
        VStack(spacing: 12) {
            ForEach(sounds) { item in
                SoundCard(item: item, isPlaying: audio.currentTrackTitle == item.audioTitle)
                    .onTapGesture {
                        handleSoundTap(item)
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sound Tap Handler
    private func handleSoundTap(_ item: SoundItem) {
        if audio.currentTrackTitle == item.audioTitle && audio.isPlaying {
            audio.stop()
        } else {
            // Garante que a meditação guiada para completamente antes de iniciar qualquer novo áudio
            GuidedMeditationEngine.shared.stop()
            switch item.audioType {
            case .binaural(let freqHz):
                AudioManager.shared.playBinaural(title: item.audioTitle, frequencyHz: freqHz, duration: 3600)
            case .ambient(let ambientType):
                let dur: Double = item.category == .sleep ? 28800 : 3600
                AudioManager.shared.playAmbient(title: item.audioTitle, type: ambientType, duration: dur)
            case .silent(let durationMinutes):
                AudioManager.shared.playSilentMeditation(title: item.audioTitle, durationMinutes: durationMinutes)
            case .stream(let url, let loops, let duration):
                AudioManager.shared.playStream(title: item.audioTitle, url: url, duration: duration, loops: loops)
            case .bundled(let filename, let loops, let duration):
                let nameWithoutExt = filename.replacingOccurrences(of: ".mp3", with: "")
                if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: "mp3") {
                    AudioManager.shared.playStream(title: item.audioTitle, url: url.absoluteString, duration: duration, loops: loops)
                } else {
                    print("AUDIO: arquivo \(filename) nao bundlado")
                }
            }
        }
    }
}

// MARK: - MeditationDayCard
struct MeditationDayCard: View {
    let med: MeditationDay
    @ObservedObject var audio = AudioManager.shared

    var isCurrentlyPlaying: Bool {
        audio.currentTrackTitle == med.title && audio.isPlaying
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dia \(med.day)")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .cornerRadius(8)
                Spacer()
                if isCurrentlyPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.white)
                                .frame(width: 2, height: CGFloat.random(in: 4...10))
                                .animation(.easeInOut(duration: 0.4).repeatForever(), value: audio.isPlaying)
                        }
                    }
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }

            Spacer()

            Text(med.title)
                .font(.headline.bold())
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(med.subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(med.durationMinutes) min")
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .frame(width: 170, height: 200)
        .background(
            LinearGradient(
                colors: meditationColors(med.day),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: meditationColors(med.day).first!.opacity(0.35), radius: 12, x: 0, y: 6)
        .calmCard()
    }

    private func meditationColors(_ day: Int) -> [Color] {
        let palettes: [[Color]] = [
            [CalmTheme.primary, CalmTheme.primaryLight],
            [Color(red: 0.20, green: 0.55, blue: 0.85), Color(red: 0.35, green: 0.72, blue: 0.95)],
            [Color(red: 0.85, green: 0.40, blue: 0.55), Color(red: 0.95, green: 0.65, blue: 0.45)],
            [Color(red: 0.20, green: 0.65, blue: 0.55), Color(red: 0.40, green: 0.85, blue: 0.70)],
            [Color(red: 0.70, green: 0.35, blue: 0.75), Color(red: 0.50, green: 0.60, blue: 0.90)],
            [Color(red: 0.35, green: 0.50, blue: 0.70), Color(red: 0.65, green: 0.30, blue: 0.60)],
            [Color(red: 0.80, green: 0.45, blue: 0.30), Color(red: 0.60, green: 0.70, blue: 0.50)],
        ]
        return palettes[(day - 1) % palettes.count]
    }
}

// MARK: - SoundCard
struct SoundCard: View {
    let item: SoundItem
    let isPlaying: Bool

    var cardColor: Color {
        switch item.audioType {
        case .binaural(let freq):
            if freq == 40 { return CalmTheme.primary }
            else if freq == 10 { return Color(red: 0.2, green: 0.7, blue: 0.5) }
            else if freq == 8 { return Color(red: 0.98, green: 0.72, blue: 0.45) }
            else { return Color(red: 0.44, green: 0.50, blue: 0.76) }
        case .ambient(.whiteNoise): return Color(red: 0.5, green: 0.6, blue: 0.9)
        case .ambient(.rain): return Color(red: 0.3, green: 0.6, blue: 0.8)
        case .ambient(.nightSounds): return Color(red: 0.3, green: 0.7, blue: 0.45)
        case .ambient(.pinkNoise): return Color(red: 0.65, green: 0.45, blue: 0.60)
        case .ambient(.nature): return Color(red: 0.4, green: 0.7, blue: 0.5)
        case .ambient(.rainForest): return Color(red: 0.28, green: 0.52, blue: 0.78)
        case .ambient(.ocean): return Color(red: 0.18, green: 0.60, blue: 0.75)
        case .ambient(.forestNight): return Color(red: 0.22, green: 0.52, blue: 0.40)
        case .ambient(.campfire): return Color(red: 0.78, green: 0.40, blue: 0.20)
        case .silent: return Color(red: 0.6, green: 0.5, blue: 0.8)
        case .stream(let url, _, _):
            // Classical music — match by URL keyword
            if url.contains("Bach") || url.contains("Bach") { return Color(red: 0.38, green: 0.28, blue: 0.70) }
            if url.contains("vivaldi") || url.contains("Vivaldi") { return Color(red: 0.92, green: 0.52, blue: 0.25) }
            if url.contains("beethoven") || url.contains("Beethoven") { return Color(red: 0.38, green: 0.42, blue: 0.78) }
            if url.contains("mozart") || url.contains("Mozart") { return Color(red: 0.85, green: 0.68, blue: 0.20) }
            // Sleep ambient streams
            if url.contains("rain") { return Color(red: 0.28, green: 0.55, blue: 0.78) }
            if url.contains("ocean") { return Color(red: 0.20, green: 0.62, blue: 0.75) }
            if url.contains("night") || url.contains("forest") { return Color(red: 0.22, green: 0.55, blue: 0.40) }
            if url.contains("campfire") { return Color(red: 0.78, green: 0.42, blue: 0.22) }
            return Color(red: 0.50, green: 0.50, blue: 0.80)
        case .bundled(let filename, _, _):
            // Match por palavra-chave no filename do bundle
            if filename.contains("bach") { return Color(red: 0.38, green: 0.28, blue: 0.70) }
            if filename.contains("beethoven") { return Color(red: 0.38, green: 0.42, blue: 0.78) }
            if filename.contains("mozart") { return Color(red: 0.85, green: 0.68, blue: 0.20) }
            if filename.contains("pachelbel") { return Color(red: 0.55, green: 0.38, blue: 0.78) }
            if filename.contains("water") || filename.contains("rain") { return Color(red: 0.28, green: 0.55, blue: 0.78) }
            if filename.contains("forest") { return Color(red: 0.22, green: 0.55, blue: 0.40) }
            if filename.contains("fireplace") { return Color(red: 0.78, green: 0.42, blue: 0.22) }
            if filename.contains("pink_noise") { return Color(red: 0.65, green: 0.45, blue: 0.60) }
            return Color(red: 0.50, green: 0.50, blue: 0.80)
        }
    }

    var cardIcon: String {
        switch item.audioType {
        case .binaural(let freq):
            if freq == 40 { return "brain.head.profile" }
            else if freq == 10 { return "bolt.fill" }
            else if freq == 8 { return "waveform.path" }
            else { return "sparkles" }
        case .ambient(.whiteNoise): return "cloud.fill"
        case .ambient(.rain): return "cloud.drizzle.fill"
        case .ambient(.nightSounds): return "leaf.fill"
        case .ambient(.pinkNoise): return "heart.fill"
        case .ambient(.nature): return "tree.fill"
        case .ambient(.rainForest): return "cloud.rain.fill"
        case .ambient(.ocean): return "water.waves"
        case .ambient(.forestNight): return "moon.stars.fill"
        case .ambient(.campfire): return "flame.fill"
        case .silent: return "moon.stars.fill"
        case .stream(let url, _, _):
            if url.contains("Bach") { return "music.note" }
            if url.contains("vivaldi") || url.contains("Vivaldi") { return "music.quarternote.list" }
            if url.contains("beethoven") || url.contains("Beethoven") { return "moon.stars.fill" }
            if url.contains("mozart") || url.contains("Mozart") { return "sparkles" }
            if url.contains("rain") { return "cloud.drizzle.fill" }
            if url.contains("ocean") { return "water.waves" }
            if url.contains("night") || url.contains("forest") { return "leaf.fill" }
            if url.contains("campfire") { return "flame.fill" }
            return "music.note"
        case .bundled(let filename, _, _):
            if filename.contains("bach") { return "music.note" }
            if filename.contains("beethoven") { return "moon.stars.fill" }
            if filename.contains("mozart") { return "sparkles" }
            if filename.contains("pachelbel") { return "music.quarternote.list" }
            if filename.contains("water") || filename.contains("rain") { return "drop.fill" }
            if filename.contains("forest") { return "leaf.fill" }
            if filename.contains("fireplace") { return "flame.fill" }
            if filename.contains("pink_noise") { return "waveform" }
            return "music.note"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardColor.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: cardIcon)
                        .font(.title3)
                        .foregroundColor(cardColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play indicator or button
                if isPlaying {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(cardColor)
                                .frame(width: 3, height: CGFloat.random(in: 6...14))
                                .animation(.easeInOut(duration: 0.4).repeatForever(), value: isPlaying)
                        }
                    }
                } else {
                    ZStack {
                        Circle()
                            .fill(cardColor.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "play.fill")
                            .font(.caption.bold())
                            .foregroundColor(cardColor)
                            .offset(x: 1)
                    }
                }
            }
            .padding(14)
        }
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .shadow(color: CalmTheme.primary.opacity(0.06), radius: 8, x: 0, y: 4)
        .calmCard()
    }
}

// MARK: - FrequencyWaveformView
struct FrequencyWaveformView: View {
    let frequency: Double
    let color: Color
    let isPlaying: Bool

    @State private var phase: Double = 0
    let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            let amplitude = size.height * 0.38
            let cycles = 4.0

            for layerIndex in 0..<3 {
                let layerAmp = amplitude * (1.0 - Double(layerIndex) * 0.25)
                let phaseOffset = Double(layerIndex) * .pi / 3
                let opacity = 1.0 - Double(layerIndex) * 0.3

                var path = Path()
                let steps = Int(size.width)
                path.move(to: CGPoint(x: 0, y: midY))
                for x in 0...steps {
                    let t = Double(x) / size.width
                    let y = midY - layerAmp * sin(2 * .pi * cycles * t + phase + phaseOffset)
                    if x == 0 {
                        path.move(to: CGPoint(x: Double(x), y: y))
                    } else {
                        path.addLine(to: CGPoint(x: Double(x), y: y))
                    }
                }
                ctx.stroke(path, with: .color(color.opacity(isPlaying ? opacity : opacity * 0.3)), lineWidth: 2 - Double(layerIndex) * 0.5)
            }

            let freqText = "\(Int(frequency)) Hz"
            ctx.draw(Text(freqText).font(.caption2.bold()).foregroundColor(color.opacity(0.7)),
                     at: CGPoint(x: size.width - 24, y: 10))
        }
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation(.linear(duration: 0.04)) {
                    phase += 0.12
                }
            }
        }
    }
}

// MARK: - AmbienceWaveformView
struct AmbienceWaveformView: View {
    let color: Color
    let isPlaying: Bool

    @State private var heights: [CGFloat] = (0..<40).map { _ in CGFloat.random(in: 0.2...1.0) }
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<heights.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(isPlaying ? 0.7 : 0.25))
                    .frame(width: 4, height: 56 * heights[i])
                    .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.01), value: heights[i])
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { _ in
            if isPlaying {
                withAnimation {
                    for i in heights.indices {
                        heights[i] = CGFloat.random(in: 0.15...1.0)
                    }
                }
            }
        }
    }
}
