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

        // Week 1: Respiração (Days 1-7)
        days.append(MeditationDay(day: 1, title: "Respira e Acalma", subtitle: "Iniciação à consciência da respiração", durationMinutes: 5, category: "Respiração"))
        days.append(MeditationDay(day: 2, title: "Respiração Profunda", subtitle: "Técnica de respiração quadrada", durationMinutes: 6, category: "Respiração"))
        days.append(MeditationDay(day: 3, title: "Inspiração e Libertação", subtitle: "Plenitude com cada respiro", durationMinutes: 7, category: "Respiração"))
        days.append(MeditationDay(day: 4, title: "Ritmo Natural", subtitle: "Sincronizar respiração e batida cardíaca", durationMinutes: 8, category: "Respiração"))
        days.append(MeditationDay(day: 5, title: "Respiração Nadi Shodhana", subtitle: "Equilibrar energia esquerda e direita", durationMinutes: 8, category: "Respiração"))
        days.append(MeditationDay(day: 6, title: "Bafejo da Calma", subtitle: "Respiração lenta para o sistema nervoso", durationMinutes: 9, category: "Respiração"))
        days.append(MeditationDay(day: 7, title: "Integração Semana 1", subtitle: "Consolidar a prática de respiração", durationMinutes: 10, category: "Respiração"))

        // Week 2: Consciência Corporal (Days 8-14)
        days.append(MeditationDay(day: 8, title: "Escaneio Corporal Guiado", subtitle: "Percurso atenta pelo corpo", durationMinutes: 8, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 9, title: "Pés Enraizados", subtitle: "Conexão com a terra sob seus pés", durationMinutes: 8, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 10, title: "Coluna da Luz", subtitle: "Energia ao longo da coluna vertebral", durationMinutes: 9, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 11, title: "Coração Atento", subtitle: "Consciência do coração e tórax", durationMinutes: 9, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 12, title: "Mãos Reflexivas", subtitle: "Sensibilidade nas mãos", durationMinutes: 10, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 13, title: "Aura Pessoal", subtitle: "Expansão do espaço ao seu redor", durationMinutes: 10, category: "Consciência Corporal"))
        days.append(MeditationDay(day: 14, title: "Integração Semana 2", subtitle: "O corpo como mapa de serenidade", durationMinutes: 11, category: "Consciência Corporal"))

        // Week 3: Emoções (Days 15-21)
        days.append(MeditationDay(day: 15, title: "Gratidão Profunda", subtitle: "Cultivar emoções positivas", durationMinutes: 9, category: "Emoções"))
        days.append(MeditationDay(day: 16, title: "Compaixão por ti", subtitle: "Auto-compaixão e aceitação", durationMinutes: 10, category: "Emoções"))
        days.append(MeditationDay(day: 17, title: "Libertação Emocional", subtitle: "Soltar tensão emocional acumulada", durationMinutes: 10, category: "Emoções"))
        days.append(MeditationDay(day: 18, title: "Alegria Radiante", subtitle: "Invocar e irradiar felicidade", durationMinutes: 11, category: "Emoções"))
        days.append(MeditationDay(day: 19, title: "Paz Interior", subtitle: "Encontrar a calma em qualquer situação", durationMinutes: 11, category: "Emoções"))
        days.append(MeditationDay(day: 20, title: "Amor Incondicional", subtitle: "Expandir capacidade de amar", durationMinutes: 12, category: "Emoções"))
        days.append(MeditationDay(day: 21, title: "Integração Semana 3", subtitle: "Emoções como bússola espiritual", durationMinutes: 12, category: "Emoções"))

        // Week 4+: Integração (Days 22-30)
        days.append(MeditationDay(day: 22, title: "Síntese Holística", subtitle: "Unificar respiração, corpo e emoção", durationMinutes: 12, category: "Integração"))
        days.append(MeditationDay(day: 23, title: "Força Silenciosa", subtitle: "Meditação de observação sem julgamento", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 24, title: "Consciência Expandida", subtitle: "Transcender limitações pessoais", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 25, title: "Propósito e Intenção", subtitle: "Clarificar sua missão pessoal", durationMinutes: 13, category: "Integração"))
        days.append(MeditationDay(day: 26, title: "Alinhamento Cósmico", subtitle: "Conectar com a energia do universo", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 27, title: "Renovação Celular", subtitle: "Reparação energética profunda", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 28, title: "Radiância Pessoal", subtitle: "Cultivar brilho interior", durationMinutes: 14, category: "Integração"))
        days.append(MeditationDay(day: 29, title: "Gratidão Expansiva", subtitle: "Honrar a jornada de 29 dias", durationMinutes: 15, category: "Integração"))
        days.append(MeditationDay(day: 30, title: "Ciclo Completo", subtitle: "Celebrar transformação e recomeçar", durationMinutes: 15, category: "Integração"))

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
                Button(action: { audio.stop() }) {
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

    var daySounds: [SoundItem] = [
        SoundItem(
            title: "Foco Total",
            subtitle: "J.S. Bach · Ária na Corda Sol",
            category: .day,
            audioTitle: "Foco Total — Bach, Ária na Corda Sol",
            audioType: .stream(
                url: "https://www.quantumdigitalmedia.de/Classicals-Music/Classicals.de%20-%20Bach%20-%20Air%20on%20the%20G%20String%20-%20BWV%201068%20-%20Arranged%20for%20Woodwinds%20and%20Strings.mp3",
                loops: false,
                duration: 600
            )
        ),
        SoundItem(
            title: "Criatividade",
            subtitle: "A. Vivaldi · As Quatro Estações, Primavera",
            category: .day,
            audioTitle: "Criatividade — Vivaldi, As Quatro Estações",
            audioType: .stream(
                url: "https://www.classicals.de/s/Classicalsde-Vivaldi-The-Four-Seasons-Spring-Violin-Concerto-in-E-major-Op-8-No-1-RV-269.mp3",
                loops: false,
                duration: 980
            )
        ),
        SoundItem(
            title: "Serenidade",
            subtitle: "L.v. Beethoven · Sonata ao Luar, Op. 27",
            category: .day,
            audioTitle: "Serenidade — Beethoven, Sonata ao Luar",
            audioType: .stream(
                url: "https://library.classicalmusicarchive.org/music/MS%20Collection/RVK/Classicals.de%20-%20Beethoven%20-%20Moonlight%20Sonata%20-%201.%20Adagio%20sostenuto%20-%20Piano%20Sonata%20Nr.%2014%2C%20Op.%2027%2C%20Nr.%202.mp3",
                loops: false,
                duration: 345
            )
        ),
        SoundItem(
            title: "Leveza",
            subtitle: "W.A. Mozart · Eine Kleine Nachtmusik",
            category: .day,
            audioTitle: "Leveza — Mozart, Eine Kleine Nachtmusik",
            audioType: .stream(
                url: "https://www.quantumdigitalmedia.de/Classicals-Music/Music/PG%20Archive/Advent%20Chamber%20Orchestra/Classicals.de%20-%20Mozart%20-%20Eine%20Kleine%20Nachtmusik%20-%20Allegro%20%28Advent%20Chamber%20Orchestra%29.mp3",
                loops: false,
                duration: 390
            )
        ),
    ]

    var sleepSounds: [SoundItem] = [
        SoundItem(
            title: "Chuva na Floresta",
            subtitle: "Chuva com rajadas suaves · sono profundo",
            category: .sleep,
            audioTitle: "Chuva na Floresta",
            audioType: .ambient(.rainForest)
        ),
        SoundItem(
            title: "Ondas do Oceano",
            subtitle: "Ondas rítmicas · respiração natural do mar",
            category: .sleep,
            audioTitle: "Ondas do Oceano",
            audioType: .ambient(.ocean)
        ),
        SoundItem(
            title: "Floresta Noturna",
            subtitle: "Grilos, brisa e sussurro da mata",
            category: .sleep,
            audioTitle: "Floresta Noturna",
            audioType: .ambient(.forestNight)
        ),
        SoundItem(
            title: "Fogueira Crepitante",
            subtitle: "Estalar do fogo · calor e aconchego",
            category: .sleep,
            audioTitle: "Fogueira Crepitante",
            audioType: .ambient(.campfire)
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

                // Música Clássica
                sectionHeader(icon: "music.note.list", color: .orange, title: "Música Clássica")
                Text("Bach, Vivaldi, Beethoven e Mozart — para cada momento do seu dia")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, -16)
                soundGrid(sounds: daySounds)

                // Sons para o Sono
                sectionHeader(icon: "moon.stars.fill", color: .indigo, title: "Sons para o Sono")
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
