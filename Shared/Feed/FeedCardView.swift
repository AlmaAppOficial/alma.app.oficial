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

            // ── Cover visual ───────────────────────────────────────
            FeedCoverImage(post: post)

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

// MARK: - Feed Cover Image

struct FeedCoverImage: View {
    let post: FeedPost

    // Gradients por tipo de conteúdo — identidade visual ALMA
    private var gradientColors: [Color] {
        switch post.contentType {
        case .meditation:
            return [Color(red: 0.33, green: 0.22, blue: 0.71), Color(red: 0.20, green: 0.13, blue: 0.47)]
        case .article:
            return [Color(red: 0.13, green: 0.40, blue: 0.55), Color(red: 0.07, green: 0.22, blue: 0.33)]
        case .study:
            return [Color(red: 0.22, green: 0.55, blue: 0.45), Color(red: 0.11, green: 0.33, blue: 0.27)]
        case .reflectionCard:
            return [Color(red: 0.45, green: 0.35, blue: 0.60), Color(red: 0.25, green: 0.18, blue: 0.40)]
        case .userPost:
            return [Color(red: 0.25, green: 0.33, blue: 0.55), Color(red: 0.13, green: 0.18, blue: 0.33)]
        }
    }

    // Ícone decorativo por tipo
    private var decorativeSymbol: String {
        switch post.contentType {
        case .meditation: return "sparkles"
        case .article: return "text.book.closed.fill"
        case .study: return "chart.bar.xaxis"
        case .reflectionCard: return "quote.bubble.fill"
        case .userPost: return "person.fill"
        }
    }

    // Palavra-chave do título para o símbolo visual
    private var keywordIcon: String {
        let t = post.title.lowercased()
        if t.contains("ansiedade") || t.contains("anxiety") { return "waveform.path.ecg" }
        if t.contains("sono") || t.contains("sleep") { return "moon.stars.fill" }
        if t.contains("respiração") || t.contains("breath") { return "lungs.fill" }
        if t.contains("gratidão") || t.contains("gratitude") { return "heart.fill" }
        if t.contains("foco") || t.contains("focus") { return "target" }
        if t.contains("stress") || t.contains("burnout") { return "flame.fill" }
        if t.contains("propósito") || t.contains("alma") { return "sparkles" }
        if t.contains("solidão") || t.contains("solitude") { return "person.fill" }
        return decorativeSymbol
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Remote image (se disponível)
            if let urlString = post.coverImage, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .clipped()
                            .opacity(0.85)
                    default:
                        decorativeOverlay
                    }
                }
            } else {
                decorativeOverlay
            }
        }
        .frame(height: 140)
        .clipped()
    }

    // Overlay decorativo quando não há imagem real
    private var decorativeOverlay: some View {
        ZStack {
            // Círculo de fundo suave
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 160, height: 160)
                .offset(x: 80, y: -30)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 100, height: 100)
                .offset(x: -70, y: 40)

            HStack {
                Spacer()
                VStack {
                    Spacer()
                    Image(systemName: keywordIcon)
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                }
                .padding(.trailing, 24)
            }
        }
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