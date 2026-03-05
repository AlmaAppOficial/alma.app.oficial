import Foundation

struct MoodEntry: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var mood: MoodLevel
    var note: String

    enum MoodLevel: Int, Codable, CaseIterable {
        case terrible = 1, bad = 2, okay = 3, good = 4, great = 5

        var emoji: String {
            switch self {
            case .terrible: return "😔"
            case .bad:      return "😕"
            case .okay:     return "😐"
            case .good:     return "🙂"
            case .great:    return "😄"
            }
        }

        var label: String {
            switch self {
            case .terrible: return "Péssimo"
            case .bad:      return "Ruim"
            case .okay:     return "Ok"
            case .good:     return "Bem"
            case .great:    return "Ótimo"
            }
        }
    }
}
