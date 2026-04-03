import SwiftUI

// MARK: - Feed Card View

struct FeedCardView: View {
    let post: FeedPost
    let interaction: UserInteraction?
    let onLike: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top: badge + title + description ──────────────────
            VStack(alignment: .leading, spacing: 8) {
                ContentTypeBadge(type: post.contentType)

                Text(post.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CalmTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)

                Text(post.description)
                    .font(.system(size: 13))
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, CalmTheme.s16)
            .padding(.top, CalmTheme.s16)
            .padding(.bottom, CalmTheme.s12)

            // ── Author row ─────────────────────────────────────────
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(CalmTheme.primary.opacity(0.15))
                        .frame(width: 28, height: 28)
                    if post.authorId == "alma_official" {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CalmTheme.primary)
                    } else {
                        Text(String(post.author.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(CalmTheme.primary)
                    }
                }
                Text(post.author)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(CalmTheme.textSecondary)
                Spacer()
                Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundColor(CalmTheme.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, CalmTheme.s16)
            .padding(.bottom, CalmTheme.s12)

            Divider()
                .background(CalmTheme.textSecondary.opacity(0.15))
                .padding(.horizontal, CalmTheme.s16)

            // ── Action bar ─────────────────────────────────────────
            HStack(spacing: 0) {
                cardActionButton(
                    icon: (interaction?.liked == true) ? "heart.fill" : "heart",
                    count: post.likes,
                    color: (interaction?.liked == true) ? .red : CalmTheme.textSecondary,
                    action: onLike
                )
                cardActionButton(
                    icon: (interaction?.saved == true) ? "bookmark.fill" : "bookmark",
                    count: post.saves,
                    color: (interaction?.saved == true) ? CalmTheme.primary : CalmTheme.textSecondary,
                    action: onSave
                )
                cardActionButton(
                    icon: "square.and.arrow.up",
                    count: post.shares,
                    color: CalmTheme.textSecondary,
                    action: onShare
                )
            }
            .padding(.vertical, CalmTheme.s8)
        }
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
        .shadow(color: CalmTheme.primary.opacity(0.10), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func cardActionButton(icon: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 12))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CalmTheme.s8)
        }
        .buttonStyle(.plain)
    }
}

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