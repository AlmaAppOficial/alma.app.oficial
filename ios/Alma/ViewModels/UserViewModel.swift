import Foundation
import SwiftUI

class UserViewModel: ObservableObject {
    @AppStorage("userName")       var userName: String = ""
    @AppStorage("currentStreak") var currentStreak: Int = 0
    @AppStorage("longestStreak") var longestStreak: Int = 0
    @AppStorage("totalSessions") var totalSessions: Int = 0
    @AppStorage("totalMinutes")  var totalMinutes: Int  = 0
    @AppStorage("lastSessionDate") private var lastSessionDate: String = ""

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default:      return "Boa noite"
        }
    }

    var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "🌅"
        case 12..<18: return "☀️"
        default:      return "🌙"
        }
    }

    func recordSession(durationSeconds: Int) {
        totalSessions += 1
        totalMinutes  += durationSeconds / 60
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let yesterday = DateFormatter.localizedString(
            from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            dateStyle: .short, timeStyle: .none
        )
        if lastSessionDate == today {
            // Same day — no streak change needed
        } else if lastSessionDate == yesterday {
            // Consecutive day — extend streak
            currentStreak  += 1
            lastSessionDate = today
            if currentStreak > longestStreak { longestStreak = currentStreak }
        } else {
            // Gap of more than one day — reset streak
            currentStreak   = 1
            lastSessionDate = today
        }
    }
}
