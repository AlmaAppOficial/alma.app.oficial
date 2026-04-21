import SwiftUI
import Charts

struct MoodInsightsView: View {
    @State private var selectedTimeRange: TimeRange = .week
    @State private var patterns: [MoodPattern] = []
    @State private var moodHistory: [MoodEntry] = []
    @State private var moodStats: MoodStatistics = .empty
    @State private var meditationImpact: [String: Double] = [:]
    @State private var isLoading = true

    let moodRouter: MoodRouter

    enum TimeRange: String, CaseIterable {
        case week = "1 Semana"
        case month = "1 Mês"
        case all = "Tudo"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return 365
            }
        }
    }

    var body: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Time Range Selector
                        timeRangeSelector

                        if isLoading {
                            loadingView
                        } else if moodHistory.isEmpty {
                            emptyStateView
                        } else {
                            // Mood Chart
                            moodChartSection

                            // Statistics
                            statisticsSection

                            // Insights
                            if !patterns.isEmpty {
                                insightsSection
                            }

                            // Meditation Impact
                            if !meditationImpact.isEmpty {
                                meditationImpactSection
                            }

                            // Share Card
                            shareableInsightCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadData()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Seus Padrões de Humor")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Descubra insights sobre seu bem-estar")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(CalmTheme.surface)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.2)
        }
    }

    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        HStack(spacing: 12) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                        Task { await loadData() }
                    }
                }) {
                    Text(range.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(
                            selectedTimeRange == range
                                ? .white
                                : CalmTheme.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selectedTimeRange == range
                                ? CalmTheme.primary
                                : CalmTheme.surface
                        )
                        .cornerRadius(CalmTheme.rSmall)
                        .overlay(
                            RoundedRectangle(cornerRadius: CalmTheme.rSmall)
                                .stroke(
                                    selectedTimeRange == range ? Color.clear : CalmTheme.primary.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                }
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CalmTheme.primary)
            Text("Analisando seus dados...")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar")
                .font(.system(size: 44))
                .foregroundColor(CalmTheme.primary.opacity(0.5))

            VStack(spacing: 4) {
                Text("Nenhum dado ainda")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)

                Text("Comece a registrar seus humores para ver insights")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Registrar Humor")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CalmTheme.primary)
                .cornerRadius(CalmTheme.rSmall)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Mood Chart Section
    private var moodChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evolução do Seu Humor")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            VStack(spacing: 16) {
                // Line chart showing mood intensity over time
                Chart(moodHistory) { entry in
                    LineMark(
                        x: .value("Data", entry.timestamp),
                        y: .value("Intensidade", entry.intensity)
                    )
                    .foregroundStyle(CalmTheme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Data", entry.timestamp),
                        y: .value("Intensidade", entry.intensity)
                    )
                    .foregroundStyle(CalmTheme.primary)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [1, 5, 10])
                }
                .chartXAxis {
                    AxisMarks(format: .dateTime.weekday())
                }
                .foregroundColor(CalmTheme.textSecondary)
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(CalmTheme.primary)
                            .frame(width: 8, height: 8)
                        Text("Intensidade")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            Text("Estatísticas")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                statCard(
                    title: "Dias com Dados",
                    value: "\(moodStats.daysWithData)",
                    icon: "calendar",
                    color: CalmTheme.primary
                )

                statCard(
                    title: "Humor Médio",
                    value: String(format: "%.1f", moodStats.averageIntensity),
                    icon: "gauge",
                    color: CalmTheme.accent
                )

                statCard(
                    title: "Mais Frequente",
                    value: moodStats.mostFrequentMood?.emoji ?? "—",
                    icon: "star.fill",
                    color: CalmTheme.primary.opacity(0.7)
                )
            }
        }
    }

    private func statCard(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            Text(value)
                .font(.title3.bold())
                .foregroundColor(CalmTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CalmTheme.background)
        .cornerRadius(CalmTheme.rSmall)
    }

    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seus Padrões")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(patterns.prefix(3)) { pattern in
                    insightRow(pattern)
                }
            }
        }
    }

    private func insightRow(_ pattern: MoodPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(CalmTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.pattern)
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textPrimary)

                    HStack(spacing: 8) {
                        ProgressView(value: pattern.confidenceScore)
                            .tint(CalmTheme.primary)

                        Text(String(format: "%.0f%%", pattern.confidenceScore * 100))
                            .font(.caption2)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .background(CalmTheme.background)
        .cornerRadius(CalmTheme.rSmall)
    }

    // MARK: - Meditation Impact Section
    private var meditationImpactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Impacto da Meditação")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            VStack(spacing: 12) {
                ForEach(Array(meditationImpact.sorted { $0.value > $1.value }.prefix(3)), id: \.key) { mood, impact in
                    impactRow(mood: mood, impact: impact)
                }
            }
        }
    }

    private func impactRow(mood: String, impact: Double) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ao meditando durante \(mood)")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textPrimary)

                Text("Melhora média de humor")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: impact > 0 ? "arrow.up" : "arrow.down")
                    .font(.caption.bold())
                    .foregroundColor(impact > 0 ? .green : .orange)

                Text(String(format: "%.0f%%", abs(impact) * 10))
                    .font(.subheadline.bold())
                    .foregroundColor(impact > 0 ? .green : .orange)
            }
        }
        .padding(12)
        .background(CalmTheme.background)
        .cornerRadius(CalmTheme.rSmall)
    }

    // MARK: - Shareable Insight Card
    private var shareableInsightCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("📊")
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meu Bem-Estar")
                            .font(.headline)
                            .foregroundColor(CalmTheme.textPrimary)

                        Text("Últimos 7 dias")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .opacity(0.2)

                VStack(alignment: .leading, spacing: 8) {
                    moodSummaryLine(
                        count: moodStats.calmDays,
                        mood: "dias de calma",
                        emoji: "☁️"
                    )
                    moodSummaryLine(
                        count: moodStats.focusedDays,
                        mood: "dias de foco",
                        emoji: "🎯"
                    )
                    moodSummaryLine(
                        count: moodStats.anxiousDays,
                        mood: "dias de ansiedade",
                        emoji: "😰"
                    )
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        CalmTheme.primary.opacity(0.1),
                        CalmTheme.accent.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(CalmTheme.rMedium)
            .overlay(
                RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                    .stroke(CalmTheme.primary.opacity(0.2), lineWidth: 1)
            )

            Button(action: shareInsight) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Compartilhar no Instagram")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(CalmTheme.heroGradient)
                .foregroundColor(.white)
                .cornerRadius(CalmTheme.rMedium)
                .shadow(color: CalmTheme.primary.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
    }

    private func moodSummaryLine(count: Int, mood: String, emoji: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 20))

            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.headline.bold())
                    .foregroundColor(CalmTheme.textPrimary)

                Text(mood)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true

        let history = await moodRouter.getMoodHistory(days: selectedTimeRange.days)
        let patterns = await moodRouter.detectPatterns()
        let impact = await moodRouter.getMeditationImpact()

        await MainActor.run {
            self.moodHistory = history
            self.patterns = patterns
            self.meditationImpact = impact
            self.moodStats = calculateStatistics(from: history)
            self.isLoading = false
        }
    }

    private func calculateStatistics(from history: [MoodEntry]) -> MoodStatistics {
        let daysWithData = Set(history.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let avgIntensity = history.isEmpty ? 0 : Double(history.map { $0.intensity }.reduce(0, +)) / Double(history.count)

        let moodCounts = Dictionary(groupingBy: history, { $0.mood })
            .mapValues { $0.count }

        let mostFrequent = moodCounts.max(by: { $0.value < $1.value })?.key

        let calmDays = history.filter { $0.mood == .grato || $0.mood == .focado }.count
        let focusedDays = history.filter { $0.mood == .focado }.count
        let anxiousDays = history.filter { $0.mood == .ansioso || $0.mood == .estressado }.count

        return MoodStatistics(
            daysWithData: daysWithData,
            averageIntensity: avgIntensity,
            mostFrequentMood: mostFrequent,
            calmDays: calmDays,
            focusedDays: focusedDays,
            anxiousDays: anxiousDays
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func shareInsight() {
        let summary = """
        Meu bem-estar na última semana com @almaapp:
        🧘 \(moodStats.calmDays) dias de calma
        🎯 \(moodStats.focusedDays) dias focado
        Meditação muda meu estado mental.
        """

        let activityVC = UIActivityViewController(activityItems: [summary], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.windows.first?.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Types
struct MoodStatistics {
    let daysWithData: Int
    let averageIntensity: Double
    let mostFrequentMood: Mood?
    let calmDays: Int
    let focusedDays: Int
    let anxiousDays: Int

    static let empty = MoodStatistics(
        daysWithData: 0,
        averageIntensity: 0,
        mostFrequentMood: nil,
        calmDays: 0,
        focusedDays: 0,
        anxiousDays: 0
    )
}

// MARK: - Preview
#if DEBUG
struct MoodInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        MoodInsightsView(moodRouter: MoodRouter())
    }
}
#endif
