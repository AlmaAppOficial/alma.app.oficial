import SwiftUI

struct InsightsView: View {

    @EnvironmentObject var hk: HealthKitManager
    // [Build 82 — 2026-07-16] Gate premium: Insights é funcionalidade Premium.
    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store:  StoreKitManager

    // Local mood tracking (no Firestore)
    @State private var todayMood: String = ""
    @State private var moodHistory: [(name: String, date: Date)] = []
    @State private var showMoodPicker = false
    @State private var showInsightShare = false
    /// [2026-08-04 — B-4] Paywall vira sheet: a aba deixa de SER o paywall.
    @State private var showPaywallSheet = false

    // [2026-08-03] Os rótulos passam a vir do enum `Mood`, que é a MESMA fonte
    // que o classificador de humor usa. Enquanto eram uma lista solta aqui, a
    // tela gravava "Triste" e o classificador procurava "😢" — a Alma recebia
    // "semana estável" de quem estava em sofrimento (revisão independente, B2).
    private let moods: [(String, String, Color)] = Mood.allCases.map {
        ($0.rawValue, $0.icone, Self.cor(de: $0))
    }

    private static func cor(de mood: Mood) -> Color {
        switch mood {
        case .otimo:   return .yellow
        case .bem:     return .green
        case .normal:  return .gray
        case .cansado: return .indigo
        case .ansioso: return .orange
        case .triste:  return .blue
        }
    }

    var body: some View {
        // [Build 82] Gate premium — paywall para quem não assina
        //
        // [2026-08-04 — B-4 da reauditoria] O gate engolia o check-in de humor
        // junto: `moodCheckInCard` mora dentro do `else`, e
        // `UserMemoryManager.recordMood()` é chamado em UM único lugar do app
        // (:93 desta tela). Ou seja, o usuário grátis não conseguia registrar
        // um único humor — enquanto o ChatView escreve, para ele, que "o
        // check-in de humor continua livre para você".
        //
        // Efeito colateral que ninguém tinha visto: as asserções B2a/B2b/B2c
        // provam que o classificador de humor está certo, e não havia como o
        // grátis produzir um humor para ele classificar.
        //
        // Agora o não-assinante recebe o check-in + o convite; o resto dos
        // insights (análises, tendências, histórico) segue pago, como a régua
        // manda.
        if !access.isPremium {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Insights")
                            .font(.largeTitle.bold())
                            .foregroundColor(CalmTheme.textPrimary)
                        Spacer()
                        AlmaLogo(size: 44)
                    }

                    moodCheckInCard

                    Button(action: { showPaywallSheet = true }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Suas análises e tendências")
                                .font(.headline)
                                .foregroundColor(CalmTheme.textPrimary)
                            Text("O check-in de humor é livre. As análises da semana, o histórico e as tendências fazem parte do Premium.")
                                .font(.caption)
                                .foregroundColor(CalmTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CalmTheme.surface)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(CalmTheme.backgroundGradient.ignoresSafeArea())
            .sheet(isPresented: $showPaywallSheet) {
                PremiumWallView()
                    .environmentObject(access)
                    .environmentObject(store)
            }
        } else {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // Header with Alma logo
                HStack {
                    Text("Insights")
                        .font(.largeTitle.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Spacer()
                    AlmaLogo(size: 44)
                }

                // Mood check-in
                moodCheckInCard

                // Weekly wellness summary
                wellnessSummaryCard

                // Stress trend
                stressTrendCard

                // Insights da Alma
                insightsDaAlmaCard

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarHidden(true)
        } // end else (premium gate)
    }

    // MARK: - Mood Check-in
    private var moodCheckInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "face.smiling")
                    .foregroundColor(CalmTheme.accent)
                Text("Como você está?")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
            }

            if todayMood.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                    ForEach(moods, id: \.0) { mood in
                        Button(action: {
                            todayMood = mood.0
                            moodHistory.append((name: mood.0, date: Date()))
                            UserMemoryManager.shared.recordMood(mood.0)
                            #if os(iOS)
                            // [2026-08-04 — Watch] Espelha o rótulo do dia para
                            // o contexto do relógio (tela Humor mostra "feito").
                            WatchBridge.registrarHumorParaOWatch(mood.0)
                            WatchBridge.shared.publicarContexto()
                            #endif
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: mood.1)
                                    .font(.system(size: 28))
                                    .foregroundColor(mood.2)
                                Text(mood.0)
                                    .font(.caption)
                                    .foregroundColor(CalmTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(mood.2.opacity(0.1))
                            .cornerRadius(CalmTheme.rSmall)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: moodIcon(for: todayMood))
                        .font(.system(size: 40))
                        .foregroundColor(moodColor(for: todayMood))
                    VStack(alignment: .leading) {
                        Text("Check-in registrado!")
                            .font(.subheadline.bold())
                            .foregroundColor(CalmTheme.textPrimary)
                        Text("Volte amanhã para outro check-in")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .calmCard()
    }

    private func moodIcon(for mood: String) -> String {
        switch mood {
        case "Ótimo": return "sun.max.fill"
        case "Bem": return "leaf.fill"
        case "Normal": return "cloud.fill"
        case "Cansado": return "moon.zzz.fill"
        case "Ansioso": return "bolt.heart.fill"
        case "Triste": return "drop.fill"
        default: return "face.smiling"
        }
    }

    private func moodColor(for mood: String) -> Color {
        switch mood {
        case "Ótimo": return .yellow
        case "Bem": return .green
        case "Normal": return .gray
        case "Cansado": return .indigo
        case "Ansioso": return .orange
        case "Triste": return .blue
        default: return CalmTheme.primary
        }
    }

    // MARK: - Wellness Summary
    private var wellnessSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(CalmTheme.primary)
                Text("Resumo de bem-estar")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if !UserMemoryManager.shared.healthConnected {
                    Text("Sincronizar dados de saúde")
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.primary)
                }
            }

            // Empty state: 4 progress rings when no data
            if !UserMemoryManager.shared.healthConnected {
                HStack(spacing: 16) {
                    EmptyRing(label: "Sono", unit: "h", target: "8h", color: .indigo)
                    EmptyRing(label: "Passos", unit: "k", target: "10k", color: .green)
                    EmptyRing(label: "VFC", unit: "ms", target: "50ms", color: .purple)
                    EmptyRing(label: "BPM", unit: "", target: "60-90", color: .red)
                }
                .frame(maxWidth: .infinity)
                Text("Ative o Apple Health para ver seus dados em tempo real")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                let sleepHrs = hk.yesterdaySleepHours > 0 ? hk.yesterdaySleepHours : hk.sleepHours
                let hrvVal = hk.averageHRV > 0 ? hk.averageHRV : hk.hrv
                let hrAvg = hk.averageHeartRate > 0 ? hk.averageHeartRate : hk.heartRate
                // [2026-08-03 — A11] O gate `healthConnected` vira true pela
                // AUTORIZAÇÃO, não por existir dado. Sem isto a tela paga
                // exibia "Sono 0.0h · VFC 0 ms · Freq. 0 bpm" como se fossem
                // medições. A Home, ao lado, já usava "—".
                VStack(spacing: 10) {
                    InsightWellnessRow(label: "Sono (ontem)", value: sleepHrs > 0 ? String(format: "%.1fh", sleepHrs) : "—",
                                progress: min(sleepHrs / 8.0, 1.0), color: .indigo)
                    InsightWellnessRow(label: "Atividade", value: "\(hk.stepsFormatted) passos",
                                progress: min(Double(hk.steps) / 10000.0, 1.0), color: .green)
                    InsightWellnessRow(label: "HRV (variabilidade)", value: hrvVal > 0 ? "\(Int(hrvVal)) ms" : "—",
                                progress: min(hrvVal / 80.0, 1.0), color: .purple)
                    InsightWellnessRow(label: "Freq. média", value: hrAvg > 0 ? "\(Int(hrAvg)) bpm" : "—",
                                progress: hrAvg > 0 ? min(80.0 / max(hrAvg, 50.0), 1.0) : 0, color: .red)
                }
            }
        }
        .calmCard()
    }

    // MARK: - Stress Trend

    /// [2026-08-03 — BUG B7 da revisão independente]
    /// `stressLevel` nasce `.low` e continua `.low` quando não há dado nenhum.
    /// Sem este gate, a tela — que é PAGA — afirmava "Relaxado · seu corpo está
    /// respondendo bem" para quem nunca conectou o Apple Saúde. A Home já fazia
    /// a verificação certa; a Insights não. Mesmo critério nos dois lugares.
    private var hasStressData: Bool {
        hk.averageHRV > 0 || hk.hrv > 0 || hk.averageHeartRate > 0 || hk.heartRate > 0
    }

    @ViewBuilder
    private var stressTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: hasStressData ? hk.stressLevel.icon : "waveform.path.ecg")
                    .foregroundColor(hasStressData ? hk.stressLevel.color : CalmTheme.textSecondary)
                Text("Nível de stress")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if hasStressData {
                    Text(hk.stressLevel.label)
                        .font(.subheadline.bold())
                        .foregroundColor(hk.stressLevel.color)
                }
            }

            Text(hasStressData
                 ? stressDescription
                 : "Sem dados de variabilidade cardíaca ainda. Conecte um relógio ou o app Saúde para a Alma acompanhar isso com você.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .calmCard()
    }

    private var stressDescription: String {
        switch hk.stressLevel {
        case .low:
            return "Seu corpo está respondendo bem. Continue com seus hábitos saudáveis e aproveite esse momento de equilíbrio."
        case .moderate:
            return "Estresse moderado detectado. Considere fazer uma pausa para respirar ou uma curta meditação."
        case .high:
            return "Nível de estresse elevado. Recomendamos uma sessão de relaxamento profundo. A Alma pode te guiar."
        }
    }

    // MARK: - Insights da Alma
    private var insightsDaAlmaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(CalmTheme.accent)
                Text("Insights da Alma")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
            }

            if let birthDate = UserMemoryManager.shared.birthDate {
                let insight = GuidanceEngine.dailyInsight(birthDate: birthDate)

                VStack(alignment: .leading, spacing: 10) {
                    Rectangle()
                        .fill(CalmTheme.primary)
                        .frame(height: 3)
                        .cornerRadius(2)

                    // Main message
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Quote
                    Text("\"\(insight.quote)\"")
                        .font(.caption)
                        .italic()
                        .foregroundColor(CalmTheme.textSecondary.opacity(0.85))
                        .padding(.top, 4)

                    Button(action: { showInsightShare = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Compartilhar")
                        }
                        .font(.caption)
                        .foregroundColor(CalmTheme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(CalmTheme.primary.opacity(0.1))
                        .cornerRadius(CalmTheme.rSmall)
                    }
                    .padding(.top, 6)
                }
            } else {
                VStack(alignment: .center, spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(CalmTheme.primary)
                    Text("Defina sua data de nascimento no perfil para receber Insights personalizados da Alma")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .calmCard()
        .sheet(isPresented: $showInsightShare) {
            if let birthDate = UserMemoryManager.shared.birthDate {
                InsightShareSheet(
                    insight: GuidanceEngine.dailyInsight(birthDate: birthDate),
                    isPresented: $showInsightShare
                )
            }
        }
    }
}

// MARK: - EmptyRing
struct EmptyRing: View {
    let label: String
    let unit: String
    let target: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 7)
                    .frame(width: 58, height: 58)
                // Dashed empty arc (shows where data would fill)
                Circle()
                    .trim(from: 0, to: 0.08)
                    .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90))
                // Center text
                VStack(spacing: 0) {
                    Text("—")
                        .font(.caption.bold())
                        .foregroundColor(color.opacity(0.5))
                }
            }
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(CalmTheme.textSecondary)
            Text(target)
                .font(.caption2)
                .foregroundColor(CalmTheme.textSecondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - InsightWellnessRow
struct InsightWellnessRow: View {
    let label: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * max(0, min(progress, 1)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
