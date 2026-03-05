import Foundation

class MoodViewModel: ObservableObject {
    @Published var entries: [MoodEntry] = []
    private let storageKey = "alma_moodEntries"

    init() { load() }

    func add(mood: MoodEntry.MoodLevel, note: String) {
        entries.insert(MoodEntry(date: Date(), mood: mood, note: note), at: 0)
        save()
    }

    var todayEntry: MoodEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data    = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
