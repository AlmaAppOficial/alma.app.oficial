import Foundation

struct UserProfile: Codable {
    var name: String
    var joinDate: Date
    var totalSessions: Int
    var totalMinutes: Int
    var currentStreak: Int
    var longestStreak: Int

    static let `default` = UserProfile(
        name: "",
        joinDate: Date(),
        totalSessions: 0,
        totalMinutes: 0,
        currentStreak: 0,
        longestStreak: 0
    )
}
