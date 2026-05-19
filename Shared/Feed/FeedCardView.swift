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

// MARK: - FeedCardView (curated link card, Instagram-style layout)

struct FeedCardView: View {
    let post: FeedPost

    @State private var showShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Top: source badge
            HStack {
                SourceBadge(source: post.source)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Square thumbnail OR rich placeholder, full card width
            thumbnailArea

            // Title + description + share row
            VStack(alignment: .leading, spacing: 8) {
                Text(displayTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !post.description.isEmpty {
                    Text(post.description)
                        .font(.system(size: 14))
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Spacer()
                    shareButton
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                .strokeBorder(CalmTheme.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Thumbnail / Placeholder

    @ViewBuilder
    private var thumbnailArea: some View {
        Group {
            if let thumb = post.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
    }

    @ViewBuilder
    private var placeholder: some View {
        LinearGradient(
            colors: [
                post.source.color.opacity(0.85),
                post.source.color.opacity(0.55),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(post.source.emoji)
                .font(.system(size: 88))
                .opacity(0.9)
        )
    }

    // MARK: - Share button

    @ViewBuilder
    private var shareButton: some View {
        if let url = URL(string: post.url) {
            ShareLink(item: url) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                    Text("Compartilhar")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CalmTheme.primary.opacity(0.1))
                .foregroundColor(CalmTheme.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Display title fallback

    private var displayTitle: String {
        let trimmed = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let host = URL(string: post.url)?.host { return host }
        return post.url
    }
}
