import SwiftUI

struct HomeView: View {

    @EnvironmentObject var hk: HealthKitManager
    @State private var authorized = false
    @State private var showMoodChat = false
    @State private var showInsightShare = false
    @State private var navigateToPraticas = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ─────────────────────────────
                headerSection

                // ── HERO: Quick Start "Meditar Agora" Button (1 tap) ─────
                quickStartButton

                // ── Streak Display (Corrente de Paz) ──────────────────
                streakSection

                // ── Mood Check-in Button (small, optional) ──────────────
                moodCheckInButton

                // ── Fale com sua Alma (moved down) ────────────────────
                heroButton

                // ── Health Dashboard ───────────────────
                healthSection

                // ── Sound Suggestions ──────────────────
                soundSection

                // ── Saúde Feminina (apenas mulheres) ──────
                if UserMemoryManager.shared.isFemale {
                    feminineHealthCard
                }

                // ── Livre de Vícios ────────────────────────
                addictionFreeCard

                // ── Insight Card ───────────────────────────
                insightCard

                Spacer(minLength: 32)
            }
            .adaptiveContentWidth()
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            authorized = await hk.requestAuthorization()
            if authorized { await hk.loadAll() }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
            AlmaLogo(size: 44)
        }
    }

    // MARK: - Streak Display (Corrente de Paz)
    private var streakSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Corrente de Paz")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundColor(.orange)

                    Text("\(Int(0)) dias")
                        .font(.headline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Total meditado")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)

                Text("0 min")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.primary)
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Quick Start Button
    private var quickStartButton: some View {
        ZStack {
            NavigationLink(destination: PraticasView(), isActive: $navigateToPraticas) {
                EmptyView()
            }
            .hidden()

            Button(action: { navigateToPraticas = true }) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meditar Agora")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Comece uma sessão guiada de meditação")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [CalmTheme.accent, CalmTheme.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(CalmTheme.rLarge)
                .shadow(color: CalmTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Mood Check-in Button (small, optional)
    private var moodCheckInButton: some View {
        NavigationLink(destination: ChatView()) {
            HStack(spacing: 12) {
                Image(systemName: "smiley")
                    .font(.headline)
                    .foregroundColor(CalmTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Como você está?")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Conte-nos seu estado de espírito")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(12)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rSmall)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Button
    private var heroButton: some View {
        NavigationLink(destination: ChatView()) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fale com sua Alma")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Sua mentora de bem-estar esta pronta para te ouvir")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(CalmTheme.heroGradient)
            .cornerRadius(CalmTheme.rLarge)
            .shadow(color: CalmTheme.primary.opacity(0.35), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Health Section
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saúde hoje")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if authorized {
                    HStack(spacing: 4) {
                        Image(systemName: hk.stressLevel.icon)
                            .font(.caption)
                        Text(hk.stressLevel.label)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(hk.stressLevel.color.opacity(0.12))
                    .foregroundColor(hk.stressLevel.color)
                    .cornerRadius(12)
                }
            }

            if authorized {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 10) {
                    HealthMetric(icon: "heart.fill", color: .red,
                                 value: "\(Int(hk.heartRate))", unit: "bpm", label: "Frequencia")
                    HealthMetric(icon: "waveform.path", color: .purple,
                                 value: "\(Int(hk.hrv))", unit: "ms", label: "HRV")
                    HealthMetric(icon: "moon.fill", color: .indigo,
                                 value: String(format: "%.1f", hk.sleepHours), unit: "h", label: "Sono")
                    HealthMetric(icon: "figure.walk", color: .green,
                                 value: "\(hk.steps)", unit: "passos", label: "Passos")
                }

                // Wellness bars (InsightsView style)
                VStack(alignment: .leading, spacing: 12) {
                    WellnessRow(label: "Sono", value: hk.sleepHours, max: 10, icon: "moon.fill", color: .indigo)
                    WellnessRow(label: "Atividade", value: Double(hk.steps) / 10000.0, max: 1.0, icon: "figure.walk", color: .green)
                    WellnessRow(label: "Variabilidade", value: hk.hrv / 100.0, max: 1.0, icon: "waveform.path", color: .purple)
                    WellnessRow(label: "Cardio", value: hk.heartRate / 100.0, max: 1.0, icon: "heart.fill", color: .red)
                }
                .padding(.top, 8)
                .onAppear {
                    UserMemoryManager.shared.setHealthConnected(true)
                }
            } else {
                Button(action: {
                    Task {
                        authorized = await hk.requestAuthorization()
                        if authorized { await hk.loadAll() }
                    }
                }) {
                    Label("Conectar dados de saúde", systemImage: "heart.circle")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(CalmTheme.primary.opacity(0.1))
                        .foregroundColor(CalmTheme.primary)
                        .cornerRadius(CalmTheme.rSmall)
                }
            }
        }
        .calmCard()
    }

    // MARK: - Sound Suggestions
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sons recomendados")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                Text("para você agora")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            let tracks = recommendedTracks

            if tracks.isEmpty {
                Text("Abra o app de Saúde para ver recomendações personalizadas")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tracks) { track in
                            SoundTile(track: track)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 4)
                }
                .frame(height: 140)
            }
        }
    }

    private var recommendedTracks: [BinauralTrack] {
        let tracks = SmartPlaylistEngine.generate(
            stressLevel: hk.stressLevel,
            sleepHours: hk.sleepHours,
            heartRate: hk.heartRate
        )
        // Fallback: garante pelo menos 4 tracks padrão quando não há dados de saúde
        if tracks.isEmpty {
            return Array(SmartPlaylistEngine.library.prefix(4))
        }
        return tracks
    }

    // MARK: - Feminine Health Card (apenas mulheres)
    private var feminineHealthCard: some View {
        NavigationLink(destination: FeminineHealthView()) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.stand.dress")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                        Text("Saúde Feminina")
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                    }
                    Text("Ciclo menstrual\ne bem-estar")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Acompanha o teu ciclo\ne saúde reprodutiva")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.45, blue: 0.65).opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: Color(red: 0.90, green: 0.45, blue: 0.65).opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Addiction Free Card
    private var addictionFreeCard: some View {
        NavigationLink(destination: AddictionFreeView()) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                        Text("Livre de Vícios")
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                    }
                    Text("Cigarro, álcool\ne outros vícios")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Conta os teus dias livre\ne celebra cada conquista")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.70, blue: 0.50).opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lungs.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: Color(red: 0.20, green: 0.70, blue: 0.50).opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - AI Insight
    private var insightCard: some View {
        let birthDate = UserMemoryManager.shared.birthDate
        let hasValidBirthDate = birthDate != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(CalmTheme.accent)
                Text("Insights da Alma")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if hasValidBirthDate {
                    Button(action: { showInsightShare = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(CalmTheme.primary)
                    }
                }
            }

            if hasValidBirthDate, let date = birthDate {
                let insight = GuidanceEngine.dailyInsight(birthDate: date)

                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(CalmTheme.primary)
                        .frame(height: 3)
                        .cornerRadius(2)

                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\"\(insight.quote)\"")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary.opacity(0.85))
                        .italic()
                        .padding(.top, 2)
                }
            } else {
                NavigationLink(destination: ProfileView()) {
                    HStack(spacing: 6) {
                        Text("Defina sua data de nascimento no Perfil para receber Insights da Alma personalizados.")
                            .font(.subheadline)
                            .foregroundColor(CalmTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(CalmTheme.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .calmCard()
        .sheet(isPresented: $showInsightShare) {
            if let date = UserMemoryManager.shared.birthDate {
                InsightShareSheet(
                    insight: GuidanceEngine.dailyInsight(birthDate: date),
                    isPresented: $showInsightShare
                )
            }
        }
    }

    // MARK: - Helpers
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Bom dia" }
        if hour < 18 { return "Boa tarde" }
        return "Boa noite"
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: Date()).capitalized
    }
}

// MARK: - Wellness Row
struct WellnessRow: View {
    let label: String
    let value: Double
    let max: Double
    let icon: String
    let color: Color

    var progress: Double {
        min(value / max, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CalmTheme.primary.opacity(0.1))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.7), color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: g.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - SoundTile
struct SoundTile: View {
    let track: BinauralTrack
    @State private var isPlaying = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var tileWidth:  CGFloat { sizeClass == .regular ? 160 : 120 }
    private var tileHeight: CGFloat { sizeClass == .regular ? 90  : 70  }

    var body: some View {
        Button(action: {
            if isPlaying {
                AudioManager.shared.stop()
                isPlaying = false
            } else {
                AudioManager.shared.playBinaural(
                    title: track.name,
                    frequencyHz: track.frequencyHz,
                    duration: 30 * 60
                )
                isPlaying = true
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isPlaying
                                ? [CalmTheme.accent, CalmTheme.accent.opacity(0.7)]
                                : [CalmTheme.primary, CalmTheme.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: tileWidth, height: tileHeight)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                Text(track.name)
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineLimit(2)
                    .frame(width: tileWidth, alignment: .leading)

                Text("\(Int(track.frequencyHz)) Hz")
                    .font(.system(size: 10))
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .frame(width: tileWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
