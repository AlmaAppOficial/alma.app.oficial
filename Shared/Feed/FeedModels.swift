import Foundation
import SwiftUI

// MARK: - FeedPost (Build 77 — curated link feed)

struct FeedPost: Identifiable, Equatable {
    let id: String
    let url: String
    let source: FeedSource
    let title: String
    let description: String
    let thumbnail: String?
    let createdAt: Date
    let createdBy: String

    static func == (lhs: FeedPost, rhs: FeedPost) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FeedSource

enum FeedSource: String, Codable, Hashable {
    case instagram
    case youtube
    case spotify
    case facebook
    case twitter
    case generic

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "instagram": self = .instagram
        case "youtube":   self = .youtube
        case "spotify":   self = .spotify
        case "facebook":  self = .facebook
        case "twitter":   self = .twitter
        default:          self = .generic
        }
    }

    var emoji: String {
        switch self {
        case .instagram: return "📷"
        case .youtube:   return "▶️"
        case .spotify:   return "🎵"
        case .facebook:  return "📘"
        case .twitter:   return "🐦"
        case .generic:   return "🔗"
        }
    }

    var label: String {
        switch self {
        case .instagram: return "Instagram"
        case .youtube:   return "YouTube"
        case .spotify:   return "Spotify"
        case .facebook:  return "Facebook"
        case .twitter:   return "Twitter"
        case .generic:   return "Link"
        }
    }

    var color: Color {
        switch self {
        case .instagram: return .purple
        case .youtube:   return .red
        case .spotify:   return .green
        case .facebook:  return .blue
        case .twitter:   return .cyan
        case .generic:   return .gray
        }
    }
}
