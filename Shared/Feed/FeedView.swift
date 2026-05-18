import SwiftUI
import FirebaseAuth

// MARK: - FeedView (Build 77 — curated link feed)
//
// Read-only list of curated external links. Admins (users/{uid}.isAdmin == true)
// see a "+" button to create new posts and can swipe-to-delete existing ones.
// Tapping a card opens the URL externally — Universal Links route to native
// apps (Instagram, YouTube, Spotify…) when installed.

struct FeedView: View {

    @StateObject private var viewModel = FeedViewModel()
    @State private var showCreateSheet = false
    @State private var pendingDelete: FeedPost? = nil

    var body: some View {
        ZStack {
            CalmTheme.background.ignoresSafeArea()

            if viewModel.isLoading && viewModel.posts.isEmpty {
                loadingView
            } else {
                contentList
            }
        }
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(CalmTheme.primary)
                    }
                    .accessibilityLabel("Nova publicação")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateFeedPostView()
        }
        .confirmationDialog(
            "Apagar publicação?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { post in
            Button("Apagar", role: .destructive) {
                Task { await viewModel.deletePost(post) }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("Esta ação não pode ser desfeita.")
        }
        .onAppear {
            Task { await viewModel.refreshAdminStatus() }
        }
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(CalmTheme.primary)
                .scaleEffect(1.3)
            Text("Carregando feed...")
                .font(.system(size: 13))
                .foregroundColor(CalmTheme.textSecondary)
        }
    }

    // MARK: - Content list

    @ViewBuilder
    private var contentList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                tagline
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                if let err = viewModel.errorMessage {
                    errorBanner(err)
                        .padding(.horizontal, 16)
                }

                if viewModel.posts.isEmpty && !viewModel.isLoading {
                    emptyState
                        .padding(.horizontal, 16)
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.posts) { post in
                        cardRow(for: post)
                            .padding(.horizontal, 16)
                    }
                }

                Text("Links abrem aplicativos externos")
                    .font(.system(size: 11))
                    .foregroundColor(CalmTheme.textSecondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Tagline

    @ViewBuilder
    private var tagline: some View {
        Text("Inspirações selecionadas para a sua jornada")
            .font(.system(size: 13))
            .foregroundColor(CalmTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Card row (tap + swipe)

    @ViewBuilder
    private func cardRow(for post: FeedPost) -> some View {
        FeedCardView(post: post)
            .contentShape(Rectangle())
            .onTapGesture { open(post: post) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.isAdmin {
                    Button(role: .destructive) {
                        pendingDelete = post
                    } label: {
                        Label("Apagar", systemImage: "trash")
                    }
                }
            }
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(CalmTheme.primary.opacity(0.6))
            Text("Em breve, novas inspirações.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CalmTheme.textPrimary)
            Text("Volte mais tarde para descobrir conteúdos selecionados.")
                .font(.system(size: 12))
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
        }
        .padding(12)
        .background(CalmTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
    }

    // MARK: - Open URL

    private func open(post: FeedPost) {
        guard let url = URL(string: post.url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
