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

// MARK: - Thumbnail resolution (Build 79 — YouTube real thumbnails)

extension FeedPost {
    /// Thumbnail a exibir: o salvo no post; ou, para YouTube sem thumbnail, derivado
    /// direto do ID do vídeo (`img.youtube.com`), sem precisar de chamada extra à
    /// API oEmbed. Posts antigos do YouTube que vieram com `thumbnail` nulo passam a
    /// mostrar a capa real em vez do gradiente placeholder.
    var resolvedThumbnail: String? {
        if let t = thumbnail, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        if source == .youtube, let id = FeedPost.youtubeID(from: url) {
            return "https://img.youtube.com/vi/\(id)/hqdefault.jpg"
        }
        return nil
    }

    /// Extrai o ID do vídeo de uma URL do YouTube — cobre `watch?v=`, `youtu.be/`,
    /// `/embed/`, `/shorts/` e `/v/`. Retorna `nil` se não for reconhecível.
    static func youtubeID(from urlString: String) -> String? {
        guard let comps = URLComponents(string: urlString) else { return nil }
        let host = (comps.host ?? "").lowercased()

        if host.contains("youtu.be") {
            if let first = comps.path.split(separator: "/").first {
                return validYouTubeID(String(first))
            }
            return nil
        }

        if host.contains("youtube.com") {
            if let v = comps.queryItems?.first(where: { $0.name == "v" })?.value,
               let id = validYouTubeID(v) {
                return id
            }
            let parts = comps.path.split(separator: "/").map(String.init)
            if let idx = parts.firstIndex(where: { $0 == "embed" || $0 == "shorts" || $0 == "v" }),
               idx + 1 < parts.count {
                return validYouTubeID(parts[idx + 1])
            }
        }
        return nil
    }

    /// IDs do YouTube têm 11 chars em [A-Za-z0-9_-]. Limpa sobras de query/fragment.
    private static func validYouTubeID(_ raw: String) -> String? {
        let id = raw.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return id.count >= 10 ? String(id.prefix(11)) : nil
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
