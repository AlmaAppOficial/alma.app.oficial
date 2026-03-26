import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct InsightsView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var moodEntries: [MoodEntry] = []
    @State private var isLoading = true
    @State private var totalCheckIns = 0
    @State private var currentStreak = 0
    @State private var weekCheckIns = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stat Cards
                    HStack(spacing: 12) {
                        StatCard(
                            value: String(totalCheckIns),
                            label: "Check-ins",
                            icon: "✅"
                        )

                        StatCard(
                            value: String(currentStreak),
                            label: "Dias seguidos",
                            icon: "🔥"
                        )

                        StatCard(
                            value: String(weekCheckIns),
                            label: "Esta semana",
                            icon: "📊"
                        )
                    }
                    .padding(.horizontal, AlmaTheme.paddingPage)

                    // Mood Chart - Last 7 Days
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Últimos 7 dias")
                            .font(.headline)
                            .foregroundColor(AlmaTheme.textPrimary)
                            .padding(.horizontal, AlmaTheme.paddingPage)

                        MoodChartView(entries: moodEntries)
                            .frame(height: 100)
                    }

                    // Recent Entries
                    if moodEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 48))
                                .foregroundColor(AlmaTheme.accent)

                            Text("Sem registros ainda")
                                .font(.headline)
                                .foregroundColor(AlmaTheme.textPrimary)

                            Text("Comece a registrar seu humor para ver insights!")
                                .font(.caption)
                                .foregroundColor(AlmaTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Registros recentes")
                                .font(.headline)
                                .foregroundColor(AlmaTheme.textPrimary)
                                .padding(.horizontal, AlmaTheme.paddingPage)

                            LazyVStack(spacing: 8) {
                                ForEach(moodEntries) { entry in
                                    MoodRow(entry: entry)
                                }
                            }
                            .padding(.horizontal, AlmaTheme.paddingPage)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical, AlmaTheme.paddingPage)
            }
            .background(AlmaTheme.background)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadMoodEntries()
            }
            .refreshable {
                await refreshData()
            }
        }
    }

    private func loadMoodEntries() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        isLoading = true
        let db = Firestore.firestore()

        db.collection("users").document(uid).collection("moods")
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let entries = documents.compactMap { doc -> MoodEntry? in
                        let data = doc.data()
                        guard let emoji = data["emoji"] as? String,
                              let timestamp = data["date"] as? Timestamp else { return nil }

                        let text = data["text"] as? String ?? ""
                        return MoodEntry(
                            id: doc.documentID,
                            text: text,
                            emoji: emoji,
                            date: timestamp.dateValue()
                        )
                    }

                    DispatchQueue.main.async {
                        self.moodEntries = entries
                        calculateStats()
                        isLoading = false
                    }
                }
            }
    }

    private func refreshData() async {
        loadMoodEntries()
    }

    private func calculateStats() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()

        // Total check-ins
        totalCheckIns = moodEntries.count

        // This week count
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weekCheckIns = moodEntries.filter { $0.date >= weekAgo }.count

        // Current streak
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() as? [String: Any],
               let streak = data["streakDays"] as? Int {
                DispatchQueue.main.async {
                    self.currentStreak = streak
                }
            }
        }
    }
}

// MARK: - StatCard Component
struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 24))

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AlmaTheme.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(AlmaTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AlmaTheme.paddingPage)
        .background(AlmaTheme.card)
        .cornerRadius(AlmaTheme.radius)
    }
}

// MARK: - MoodRow Component
struct MoodRow: View {
    let entry: MoodEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text.isEmpty ? "Sem notas" : entry.text)
                    .font(.subheadline)
                    .foregroundColor(AlmaTheme.textPrimary)
                    .lineLimit(2)

                Text(entry.friendlyDate)
                    .font(.caption)
                    .foregroundColor(AlmaTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AlmaTheme.textSecondary)
                .font(.caption)
        }
        .padding(AlmaTheme.paddingPage)
        .background(AlmaTheme.card)
        .cornerRadius(AlmaTheme.radius)
    }
}

// MARK: - Mood Chart View
struct MoodChartView: View {
    let entries: [MoodEntry]

    var last7DaysEntries: [MoodEntry] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.date >= sevenDaysAgo }
    }

    var chartData: [MoodChartData] {
        let calendar = Calendar.current
        var data: [MoodChartData] = []

        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

            let dayEntries = entries.filter { $0.date >= startOfDay && $0.date < endOfDay }
            let emoji = dayEntries.first?.emoji ?? "❓"
            let dayName = calendar.component(.weekday, from: date)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_PT")
            formatter.dateFormat = "EEE"

            data.append(MoodChartData(
                date: date,
                emoji: emoji,
                dayName: formatter.string(from: date).prefix(1).uppercased()
            ))
        }

        return data.reversed()
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(chartData, id: \.date) { data in
                VStack(spacing: 4) {
                    Text(data.emoji)
                        .font(.system(size: 20))

                    Text(data.dayName)
                        .font(.caption2)
                        .foregroundColor(AlmaTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AlmaTheme.card)
                .cornerRadius(AlmaTheme.radius)
            }
        }
        .padding(.horizontal, AlmaTheme.paddingPage)
    }
}

struct MoodChartData {
    let date: Date
    let emoji: String
    let dayName: String
}

#Preview {
    InsightsView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
