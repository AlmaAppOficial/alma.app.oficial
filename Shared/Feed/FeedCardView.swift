import SwiftUI

// MARK: - Content Type Badge

struct ContentTypeBadge: View {
    let type: FeedPost.ContentType

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: type.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(type.label)
                .font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(badgeColor.opacity(0.18))
        .foregroundColor(badgeColor)
        .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch type {
        case .article:        return CalmTheme.primary
        case .meditation:     return Color(hex: "#059669") ?? .green
        case .study:          return Color(hex: "#2563eb") ?? .blue
        case .reflectionCard: return Color(hex: "#d97706") ?? .orange
        case .userPost:       return Color(hex: "#db2777") ?? .pink
        }
    }
}