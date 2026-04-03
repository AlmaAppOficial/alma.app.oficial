import SwiftUI

struct FeedView: View {

    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedPostForDetail: FeedPost? = nil
    @State private var showFilterSheet = false

    var body: some View {
        ZStack {
            CalmTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.posts.isEmpty {
                loadingView
            } else {
                scrollContent
            }
        }
        .navigationTitle("Bem-estar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showFilterSheet = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(CalmTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(viewModel: viewModel)
        }
        .sheet(item: $selectedPostForDetail) { post in
            NavigationView {
                PostDetailView(post: post, interaction: viewModel.interaction(for: post))
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            if viewModel.posts.isEmpty {
                viewModel.loadPosts()
            }
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CalmTheme.primary)
                .scaleEffect(1.3)
            Text("Carregando bem-estar...")
                .font(.system(size: 13))
                .foregroundColor(CalmTheme.textSecondary)
        }
    }

    // MARK: - Scroll content

    @ViewBuilder
    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {

                // Category chips
                categoryChipsRow
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Error banner
                if let err = viewModel.errorMessage {
                    errorBanner(err)
                }

                // Featured banner (only if no category selected)
                if viewModel.selectedCategory == nil && !viewModel.featuredPosts.isEmpty {
                    featuredSection
                }

                // Posts
                VStack(spacing: 12) {
                    ForEach(viewModel.filteredPosts) { post in
                        FeedCardView(
                            post: post,
                            interaction: viewModel.interaction(for: post),
                            onLike: { viewModel.toggleLike(post: post) },
                            onSave: { viewModel.toggleSave(post: post) },
                            onShare: {
                                viewModel.recordShare(post: post)
                                sharePost(post)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPostForDetail = post }
                        .onAppear { viewModel.loadMoreIfNeeded(currentPost: post) }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(CalmTheme.primary)
                            .padding(.vertical, 20)
                    } else if !viewModel.hasMorePages && !viewModel.filteredPosts.isEmpty {
                        endCaption
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // space for tab bar
            }
        }
        .refreshable {
            viewModel.loadPosts(refresh: true)
        }
    }

    // MARK: - Category chips

    @ViewBuilder
    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    let isSelected = viewModel.selectedCategory == category.id
                        || (viewModel.selectedCategory == nil && category.id == "all")

                    Button(action: { viewModel.selectCategory(category.id) }) {
                        HStack(spacing: 5) {
                            Text(category.icon)
                                .font(.system(size: 13))
                            Text(category.name)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isSelected
                                ? CalmTheme.primary
                                : CalmTheme.surface
                        )
                        .foregroundColor(
                            isSelected
                                ? .white
                                : CalmTheme.textSecondary
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : CalmTheme.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Featured section

    @ViewBuilder
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(CalmTheme.accent)
                Text("Em destaque")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.featuredPosts) { post in
                        FeaturedCard(post: post)
                            .onTapGesture { selectedPostForDetail = post }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(CalmTheme.textPrimary)
            Spacer()
            Button(action: { viewModel.loadPosts(refresh: true) }) {
                Text("Tentar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CalmTheme.primary)
            }
        }
        .padding(12)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - End caption

    @ViewBuilder
    private var endCaption: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundColor(CalmTheme.primary.opacity(0.6))
            Text("Você viu tudo por enquanto")
                .font(.system(size: 12))
                .foregroundColor(CalmTheme.textSecondary)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Native share

    private func sharePost(_ post: FeedPost) {
        let text = "\(post.title)\n\n\(post.description)\n\nVia ALMA App"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Featured Card (horizontal scroll)

private struct FeaturedCard: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ContentTypeBadge(type: post.contentType)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(CalmTheme.accent)
            }

            Text(post.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(CalmTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.description)
                .font(.system(size: 12))
                .foregroundColor(CalmTheme.textSecondary)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 12) {
                Label("\(post.likes)", systemImage: "heart")
                    .font(.system(size: 11))
                    .foregroundColor(CalmTheme.textSecondary)
                Label("\(post.saves)", systemImage: "bookmark")
                    .font(.system(size: 11))
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(width: 210, height: 140)
        .background(
            LinearGradient(
                colors: [CalmTheme.surface, CalmTheme.primary.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                .strokeBorder(CalmTheme.primary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                CalmTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        Text("Filtrar por Categoria")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CalmTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(viewModel.categories.filter { $0.id != "all" }) { category in
                                let isSelected = viewModel.selectedCategory == category.id

                                Button(action: {
                                    viewModel.selectCategory(category.id)
                                    dismiss()
                                }) {
                                    HStack(spacing: 8) {
                                        Text(category.icon)
                                            .font(.system(size: 16))
                                        Text(category.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(isSelected ? .white : CalmTheme.textPrimary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(12)
                                    .background(isSelected ? CalmTheme.primary : CalmTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)

                        if viewModel.selectedCategory != nil {
                            Button(action: {
                                viewModel.selectCategory("all")
                                dismiss()
                            }) {
                                Text("Limpar filtro")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }
                        .foregroundColor(CalmTheme.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
