import SwiftUI

struct HomeView: View {

    @EnvironmentObject var hk: HealthKitManager
    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store: StoreKitManager
    @State private var authorized = false
    @State private var showMoodChat = false
    @State private var showInsightShare = false
    @State private var navigateToPraticas = false
    @State private var showHomePaywall = false
    @State private var showChat = false

    @ObservedObject private var streakManager = StreakManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ─────────────────────────────
                headerSection

                // ── Premium banner — [Build 84] freemium: só p/ não-assinante ─
                if !access.isPremium {
                    premiumBanner
                }

                // ── HERO: Quick Start "Meditar Agora" Button (1 tap) ─────
                quickStartButton

                // ── Streak Display (Corrente de Paz) ──────────────────
                streakSection

                // [Build 77 — 12/05/2026] moodCheckInButton removido (era botao redundante
                // que tambem ia pra ChatView; mood check-in real esta em InsightsView).
                // Hero "Fale com sua Alma" segue como unico acesso ao chat na home.

                // ── Fale com sua Alma (Premium) ──────────────────
                heroButton

                // ── Sound Suggestions (acesso mínimo gratuito) ──
                soundSection

                // ── Health Dashboard (Premium) ─────────────────
                if access.isPremium {
                    healthSection
                }

                // ── Saúde Feminina (Premium + apenas mulheres) ──
                if access.isPremium && UserMemoryManager.shared.isFemale {
                    feminineHealthCard
                }

                // ── Livre de Vícios (Premium) ──────────────────
                if access.isPremium {
                    addictionFreeCard
                }

                // ── Insight Card (Premium) ─────────────────────
                if access.isPremium {
                    insightCard
                }

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
        .sheet(isPresented: $showHomePaywall) {
            PremiumWallView()
                .environmentObject(access)
                .environmentObject(store)
        }
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        Button(action: { showHomePaywall = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conheça Alma Premium")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(bannerSubtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [CalmTheme.primary, CalmTheme.primary.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(CalmTheme.rMedium)
        }
    }

    private var bannerSubtitle: String {
        // [Build 84 — 2026-07-29] Modelo freemium: nenhuma promessa de trial
        // em copy do app (decisão do Assis). A oferta introdutória do ASC, se
        // ativa, aparece na folha de pagamento da própria Apple.
        "Acesso completo · Toque para assinar"
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
            // Botão Corpo & Alma — acesso rápido ao app de saúde
            Button {
                let url = URL(string: "corpoealma://")!
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let storeURL = URL(string: "https://apps.apple.com/app/corpo-e-alma/id6744054437") {
                    UIApplication.shared.open(storeURL)
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(CalmTheme.accent)
                    Text("Corpo")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(CalmTheme.textSecondary)
                }
                .frame(width: 40, height: 44)
            }
            .accessibilityLabel("Abrir app Corpo & Alma — Saúde")
            .padding(.trailing, 8)
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

                    Text("\(streakManager.currentStreak) dias")
                        .font(.headline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Total meditado")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)

                Text("\(UserMemoryManager.shared.meditationMinutes) min")
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
        .navigationDestination(isPresented: $navigateToPraticas) {
            PraticasView()
        }
    }

    // MARK: - Hero Button
    // [Build 77 — 12/05/2026] moodCheckInButton removido (linhas 212-241):
    // botao redundante que tambem ia pra ChatView. Mood check-in real esta em InsightsView.
    // [Build 82 — 2026-07-15] Chat bloqueado para usuários gratuitos — exige Premium.
    // [Build 84 — 2026-07-29] FREEMIUM: chat abre para todos; não-assinante
    // tem N mensagens/dia (FreemiumLimits) e converte dentro do chat.
    private var heroButton: some View {
        Button(action: {
            showChat = true
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fale com sua Alma")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(access.isPremium
                         ? "Sua mentora de bem-estar esta pronta para te ouvir"
                         : (FreemiumLimits.chatHasFreeQuota
                            ? "\(FreemiumLimits.chatMessagesPerDay) mensagens grátis por dia · Toque para conversar"
                            : "Recurso Premium · Toque para conhecer"))
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
        .navigationDestination(isPresented: $showChat) { ChatView() }
    }

    // MARK: - Health Section
    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saúde hoje")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                // Badge de stress só aparece quando há dado real de HRV ou FC
                let hasStressData = hk.averageHRV > 0 || hk.hrv > 0
                                 || hk.averageHeartRate > 0 || hk.heartRate > 0
                if authorized && hasStressData {
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
                    // Mostra MEDIA do dia (mais robusto que ultimo valor instantaneo).
                    // Exibe "—" quando não há dado (0 é enganoso).
                    let hrVal    = hk.averageHeartRate > 0 ? hk.averageHeartRate : hk.heartRate
                    let hrvVal   = hk.averageHRV       > 0 ? hk.averageHRV       : hk.hrv
                    let sleepVal = hk.yesterdaySleepHours > 0 ? hk.yesterdaySleepHours : hk.sleepHours

                    HealthMetric(icon: "heart.fill", color: .red,
                                 value: hrVal  > 0 ? "\(Int(hrVal))"  : "—",
                                 unit: hrVal  > 0 ? "bpm" : "",
                                 label: "Freq. média")
                    HealthMetric(icon: "waveform.path", color: .purple,
                                 value: hrvVal > 0 ? "\(Int(hrvVal))" : "—",
                                 unit: hrvVal > 0 ? "ms"  : "",
                                 label: "HRV")
                    // Sono de ONTEM (janela 18h ontem -> 12h hoje, com fallback 48h)
                    HealthMetric(icon: "moon.fill", color: .indigo,
                                 value: sleepVal > 0 ? String(format: "%.1f", sleepVal) : "—",
                                 unit: sleepVal > 0 ? "h" : "",
                                 label: "Sono (ontem)")
                    HealthMetric(icon: "figure.walk", color: .green,
                                 value: hk.steps > 0 ? hk.stepsFormatted : "—",
                                 unit: hk.steps > 0 ? "passos" : "",
                                 label: "Passos")
                }

                // Dica quando o app Saúde não tem FC/HRV/sono (ex.: Garmin sem
                // escrita habilitada no Apple Health) — dado ausente na FONTE,
                // não é falha de leitura do Alma. [2026-07-14]
                if (hk.averageHeartRate <= 0 && hk.heartRate <= 0)
                    && (hk.averageHRV <= 0 && hk.hrv <= 0)
                    && (hk.yesterdaySleepHours <= 0 && hk.sleepHours <= 0) {
                    Text("O app Saúde ainda não tem dados de coração e sono. Usa Garmin ou outro relógio? Ative a escrita no Apple Health dentro do app do fabricante.")
                        .font(.caption2)
                        .foregroundColor(CalmTheme.textSecondary)
                        .padding(.top, 2)
                }

                // Wellness bars (InsightsView style)
                VStack(alignment: .leading, spacing: 12) {
                    WellnessRow(label: "Sono (ontem)", value: hk.yesterdaySleepHours > 0 ? hk.yesterdaySleepHours : hk.sleepHours, max: 10, icon: "moon.fill", color: .indigo)
                    WellnessRow(label: "Atividade", value: Double(hk.steps) / 10000.0, max: 1.0, icon: "figure.walk", color: .green)
                    WellnessRow(label: "Variabilidade", value: (hk.averageHRV > 0 ? hk.averageHRV : hk.hrv) / 100.0, max: 1.0, icon: "waveform.path", color: .purple)
                    WellnessRow(label: "Freq. cardíaca", value: (hk.averageHeartRate > 0 ? hk.averageHeartRate : hk.heartRate) / 100.0, max: 1.0, icon: "heart.fill", color: .red)
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

    // [Build 77 — 12/05/2026] Atualizado pra retornar [RecommendedSound] (MP3 bundle real,
    // nao mais BinauralTrack/sine wave). Converte StressLevel enum em Double 0-1 pro
    // SmartPlaylistEngine. Generate ja tem fallback interno (mix variado se sem dados).
    private var recommendedTracks: [RecommendedSound] {
        let stressDouble: Double? = {
            switch hk.stressLevel {
            case .low:      return 0.2
            case .moderate: return 0.5
            case .high:     return 0.8
            }
        }()
        return SmartPlaylistEngine.generate(
            stressLevel: stressDouble,
            sleepHours: hk.sleepHours > 0 ? hk.sleepHours : nil,
            heartRate: hk.heartRate > 0 ? hk.heartRate : nil
        )
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
                    Text("Acompanhe seu ciclo\ne saúde reprodutiva")
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
                    Text("Conte seus dias livres\ne celebre cada conquista")
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
// [Build 77 — 12/05/2026] Migrado de BinauralTrack (frequencias <20 Hz inaudiveis)
// pra RecommendedSound (MP3 real do bundle). Layout visual preservado:
// gradient + play/pause overlay + titulo + subtitulo (antes era "X Hz").
struct SoundTile: View {
    let track: RecommendedSound
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
                AudioManager.shared.playBundledSound(
                    filename: track.bundleFilename,
                    title: track.title,
                    duration: Double(track.durationSeconds),
                    loops: track.category == .sleep
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

                Text(track.title)
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineLimit(2)
                    .frame(width: tileWidth, alignment: .leading)

                Text(track.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(1)
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
