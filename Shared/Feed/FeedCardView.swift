import SwiftUI

// MARK: - SourceBadge (Build 77 — emoji + label, no trademark logos)

struct SourceBadge: View {
    let source: FeedSource

    var body: some View {
        HStack(spacing: 4) {
            Text(source.emoji)
                .font(.system(size: 11))
            Text(source.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(source.color.opacity(0.15))
        .foregroundColor(source.color)
        .clipShape(Capsule())
    }
}

// MARK: - FeedCardView (curated link card)

struct FeedCardView: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Source badge
            SourceBadge(source: post.source)

            // Thumbnail (if available)
            if let thumb = post.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(CalmTheme.surface)
                            .overlay(ProgressView().tint(CalmTheme.primary))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
            }

            // Title (with hostname/URL fallback so a missing OG title never
            // leaves the card showing only a badge).
            Text(displayTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(CalmTheme.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Description (if any)
            if !post.description.isEmpty {
                Text(post.description)
                    .font(.system(size: 13))
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                .strokeBorder(CalmTheme.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }

    private var displayTitle: String {
        let trimmed = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URL(string: post.url)?.host { return host }
        return post.url
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(post.source.color.opacity(0.08))
            .overlay(
                Text(post.source.emoji)
                    .font(.system(size: 36))
            )
    }
}
