import SwiftUI

struct PostDetailView: View {
    let post: FeedPost
    let interaction: UserInteraction?
    @StateObject private var viewModel: PostDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    init(post: FeedPost, interaction: UserInteraction?) {
        self.post = post
        self.interaction = interaction
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(post: post, interaction: interaction))
    }

    var body: some View {
        ZStack(alignment: .top) {
            CalmTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header band ───────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        ContentTypeBadge(type: post.contentType)

                        Text(post.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(CalmTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Author row
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(CalmTheme.primary.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                if post.authorId == "alma_official" {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(CalmTheme.primary)
                                } else {
                                    Text(String(post.author.prefix(1)).uppercased())
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(CalmTheme.primary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.author)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(CalmTheme.textPrimary)
                                Text(post.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 11))
                                    .foregroundColor(CalmTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, CalmTheme.s16)
                    .padding(.top, CalmTheme.s16)
                    .padding(.bottom, CalmTheme.s20)

                    // ── Meditation player (if applicable) ─────────────
                    if post.contentType == .meditation {
                        MeditationPlayerView(post: post)
                            .padding(.horizontal, CalmTheme.s16)
                            .padding(.bottom, CalmTheme.s20)
                    }

                    // ── Main content ──────────────────────────────────
                    MarkdownTextView(text: post.content)
                        .padding(.horizontal, CalmTheme.s16)
                        .padding(.bottom, CalmTheme.s20)

                    // ── Scientific basis ──────────────────────────────
                    if !post.scientificBasis.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Bases Científicas", systemImage: "graduationcap")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CalmTheme.textPrimary)

                            FlowLayout(tags: post.scientificBasis, color: Color(hex: "#2563eb") ?? .blue)
                        }
                        .padding(CalmTheme.s16)
                        .background(CalmTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
                        .padding(.horizontal, CalmTheme.s16)
                        .padding(.bottom, CalmTheme.s20)
                    }

                    // ── Sources ───────────────────────────────────────
                    if !post.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Fontes", systemImage: "link")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CalmTheme.textPrimary)

                            ForEach(post.sources, id: \.self) { source in
                                Text("• \(source)")
                                    .font(.system(size: 11))
                                    .foregroundColor(CalmTheme.textSecondary)
                            }
                        }
                        .padding(CalmTheme.s16)
                        .background(CalmTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
                        .padding(.horizontal, CalmTheme.s16)
                        .padding(.bottom, CalmTheme.s20)
                    }

                    // ── Hashtags ──────────────────────────────────────
                    if !post.hashtags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(post.hashtags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(CalmTheme.primaryLight)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(CalmTheme.primary.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, CalmTheme.s16)
                        }
                        .padding(.bottom, CalmTheme.s24)
                    }

                    Divider()
                        .background(CalmTheme.textSecondary.opacity(0.2))
                        .padding(.horizontal, CalmTheme.s16)

                    // ── Action bar ─────────────────────────────────────
                    HStack(spacing: 0) {
                        detailActionButton(
                            icon: viewModel.isLiked ? "heart.fill" : "heart",
                            label: "Curtir",
                            count: viewModel.likeCount,
                            color: viewModel.isLiked ? .red : CalmTheme.textSecondary,
                            action: { viewModel.toggleLike() }
                        )
                        detailActionButton(
                            icon: viewModel.isSaved ? "bookmark.fill" : "bookmark",
                            label: "Salvar",
                            count: viewModel.saveCount,
                            color: viewModel.isSaved ? CalmTheme.primary : CalmTheme.textSecondary,
                            action: { viewModel.toggleSave() }
                        )
                        detailActionButton(
                            icon: "square.and.arrow.up",
                            label: "Compartilhar",
                            count: post.shares,
                            color: CalmTheme.textSecondary,
                            action: {
                                viewModel.recordShare()
                                showShareSheet = true
                            }
                        )
                    }
                    .padding(.vertical, CalmTheme.s8)
                    .padding(.bottom, CalmTheme.s24)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Voltar")
                            .font(.system(size: 15))
                    }
                    .foregroundColor(CalmTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["\(post.title)\n\n\(post.description)\n\nVia ALMA App"])
        }
    }

    @ViewBuilder
    private func detailActionButton(icon: String, label: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, CalmTheme.s12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Markdown-lite text renderer

private struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(paragraphs, id: \.self) { paragraph in
                if paragraph.hasPrefix("**") && paragraph.hasSuffix("**") {
                    Text(paragraph.dropFirst(2).dropLast(2))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)
                } else if paragraph.hasPrefix("• ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14))
                            .foregroundColor(CalmTheme.primary)
                            .padding(.top, 1)
                        Text(String(paragraph.dropFirst(2)))
                            .font(.system(size: 14))
                            .foregroundColor(CalmTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let num = bulletNumber(paragraph) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(num).")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CalmTheme.primary)
                            .frame(minWidth: 18, alignment: .leading)
                        Text(afterNumber(paragraph))
                            .font(.system(size: 14))
                            .foregroundColor(CalmTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if !paragraph.isEmpty {
                    Text(inlineMarkdown(paragraph))
                        .font(.system(size: 14))
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var paragraphs: [String] {
        text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func bulletNumber(_ s: String) -> Int? {
        guard let dot = s.firstIndex(of: "."),
              let n = Int(s[s.startIndex..<dot]) else { return nil }
        return n
    }

    private func afterNumber(_ s: String) -> String {
        guard let dot = s.firstIndex(of: ".") else { return s }
        return String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
    }

    private func inlineMarkdown(_ s: String) -> String {
        // Strip ** and * for plain Text (AttributedString needed for real bold/italic)
        s.replacingOccurrences(of: "**", with: "")
         .replacingOccurrences(of: "*", with: "")
    }
}

// MARK: - Flow layout for tags

private struct FlowLayout: View {
    let tags: [String]
    let color: Color

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var rows: [[String]] = [[]]

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(tags, id: \.self) { tag in
                    tagView(tag)
                        .alignmentGuide(.leading) { d in
                            if width + d.width > geo.size.width {
                                width = 0; height -= d.height + 6
                            }
                            let result = width
                            if tag == tags.last { width = 0 } else { width += d.width + 6 }
                            return -result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if tag == tags.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: CGFloat(((tags.count - 1) / 4 + 1)) * 30)
    }

    @ViewBuilder
    private func tagView(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

