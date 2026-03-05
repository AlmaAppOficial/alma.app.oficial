import SwiftUI

struct MoodTrackerView: View {
    @EnvironmentObject var moodViewModel: MoodViewModel
    @State private var selectedMood: MoodEntry.MoodLevel = .good
    @State private var note = ""
    @FocusState private var noteIsFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    if let today = moodViewModel.todayEntry {
                        // ── Already logged today ─────────────────────
                        TodayMoodCard(entry: today)
                    } else {
                        // ── Log mood form ────────────────────────────
                        VStack(spacing: 18) {
                            Text("Como você está se sentindo?")
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)

                            // Emoji picker
                            HStack(spacing: 0) {
                                ForEach(MoodEntry.MoodLevel.allCases, id: \.self) { level in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedMood = level
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            Text(level.emoji)
                                                .font(.system(size: selectedMood == level ? 44 : 30))
                                                .scaleEffect(selectedMood == level ? 1.1 : 1)
                                                .animation(.spring(response: 0.3), value: selectedMood)
                                            Text(level.label)
                                                .font(.caption2)
                                                .foregroundColor(selectedMood == level ? .almaPrimary : .secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedMood == level ? Color.almaCard : Color.clear)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 8)

                            // Note field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Nota (opcional)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.secondary)

                                TextEditor(text: $note)
                                    .focused($noteIsFocused)
                                    .frame(height: 90)
                                    .padding(10)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                noteIsFocused ? Color.almaPrimary : Color(.systemGray5),
                                                lineWidth: noteIsFocused ? 1.5 : 1
                                            )
                                    )
                            }

                            // Save button
                            Button {
                                moodViewModel.add(mood: selectedMood, note: note)
                                note          = ""
                                noteIsFocused = false
                            } label: {
                                Text("Salvar Humor")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.almaPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                        }
                        .padding(20)
                        .background(Color.almaBackground)
                        .cornerRadius(20)
                    }

                    // ── History ──────────────────────────────────────
                    if !moodViewModel.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Histórico")
                                .font(.headline)
                            ForEach(moodViewModel.entries.prefix(14)) { entry in
                                MoodHistoryRow(entry: entry)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Humor")
            .background(Color.almaBackground.ignoresSafeArea())
            .onTapGesture { noteIsFocused = false }
        }
    }
}

// MARK: - TodayMoodCard

struct TodayMoodCard: View {
    let entry: MoodEntry

    var body: some View {
        VStack(spacing: 14) {
            Label("Humor de Hoje", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundColor(.almaPrimary)

            Text(entry.mood.emoji).font(.system(size: 64))

            Text(entry.mood.label)
                .font(.title2.bold())
                .foregroundColor(.almaPrimary)

            if !entry.note.isEmpty {
                Text(""\(entry.note)"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("Você já registrou seu humor hoje. Volte amanhã! 🌱")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.almaCard)
        .cornerRadius(20)
    }
}

// MARK: - MoodHistoryRow

struct MoodHistoryRow: View {
    let entry: MoodEntry

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale    = Locale(identifier: "pt_BR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(entry.mood.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.mood.label).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(formattedDate).font(.caption).foregroundColor(.secondary)
                }
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

#Preview {
    MoodTrackerView()
        .environmentObject(MoodViewModel())
}
