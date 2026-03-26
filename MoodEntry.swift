import Foundation

struct MoodEntry: Identifiable {
    let id: String
    let text: String
    let emoji: String
    let date: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_PT")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    var friendlyDate: String {
        if isToday {
            return "Hoje"
        } else if isYesterday {
            return "Ontem"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_PT")
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}
