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
        .background(source.color.opacity(0.18))
        .foregroundColor(source.color)
        .clipShape(Capsule())
    }
}

// MARK: - FeedCardView (Build 81 — redesign: 16:9 thumbnail, gradient overlay, clean typography)
//
// Mudanças em relação ao Build 80:
// - Proporção da thumbnail: 1:1 (square) → 16:9 (padrão YouTube/video)
// - Gradiente escuro sobre thumbnail para separar visualmente texto da imagem
// - Badge da fonte sobreposta no topo-esquerdo da thumbnail
// - Título movido para DENTRO da thumbnail (overlay), sobre o gradiente
// - Descrição limitada a 2 linhas, hidden se muito genérica (≤ 60 chars URL-like)
// - Card com background mais escuro (#1A1A1A-ish = CalmTheme.surface)

struct FeedCardView: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail 16:9 com overlay de gradiente + badge + título
            thumbnailArea

            // Info footer: descrição (se útil) + share
            footerArea
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Thumbnail 16:9

    @ViewBuilder
    private var thumbnailArea: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Imagem de fundo
                if let thumb = post.resolvedThumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        case .empty:
                            placeholderBg
                                .overlay(ProgressView().tint(.white))
                        default:
                            placeholderBg
                        }
                    }
                } else {
                    placeholderBg
                }

                // Gradiente escuro de baixo para cima
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: Color.black.opacity(0.25), location: 0.45),
                        .init(color: Color.black.opacity(0.82), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Conteúdo sobreposto: badge (topo) + título (base)
                VStack(alignment: .leading, spacing: 0) {
                    // Badge no topo-esquerdo
                    HStack {
                        SourceBadge(source: post.source)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                    Spacer()

                    // Título na base da thumbnail
                    Text(displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Placeholder background

    @ViewBuilder
    private var placeholderBg: some View {
        LinearGradient(
            colors: [
                post.source.color.opacity(0.7),
                post.source.color.opacity(0.35),
                Color.black.opacity(0.6),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(post.source.emoji)
                .font(.system(size: 64))
                .opacity(0.6)
        )
    }

    // MARK: - Footer: descrição + compartilhar

    @ViewBuilder
    private var footerArea: some View {
        let desc = usefulDescription
        HStack(alignment: .top, spacing: 10) {
            if let desc {
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            shareButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // Oculta descrições genéricas (channel taglines do YouTube, URLs longas, etc.)
    private var usefulDescription: String? {
        let d = post.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty, d.count > 20 else { return nil }
        // Descarta descrições que sejam basicamente a URL
        guard !d.lowercased().hasPrefix("http") else { return nil }
        // Descarta o boilerplate padrão do YouTube
        let youtubeBoilerplate = "Assista vídeos e músicas que você ama"
        guard !d.hasPrefix(youtubeBoilerplate) else { return nil }
        return d
    }

    // MARK: - Share button

    @ViewBuilder
    private var shareButton: some View {
        if let url = URL(string: post.url) {
            ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CalmTheme.primary)
                    .padding(8)
                    .background(CalmTheme.primary.opacity(0.12))
                    .clipShape(Circle())
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
