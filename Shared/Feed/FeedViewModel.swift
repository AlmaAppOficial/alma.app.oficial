import Foundation
import SwiftUI
import FirebaseAuth

// MARK: - FeedViewModel

@MainActor
final class FeedViewModel: ObservableObject {

    // MARK: Published state
    @Published var posts: [FeedPost] = []
    @Published var categories: [FeedCategory] = FeedCategory.defaults
    @Published var selectedCategory: String? = nil
    @Published var interactions: [String: UserInteraction] = [:]  // keyed by postId
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var hasMorePages: Bool = true

    // MARK: Computed
    var filteredPosts: [FeedPost] {
        guard let cat = selectedCategory, cat != "all" else { return posts }
        return posts.filter { $0.categories.map { $0.lowercased() }.contains(cat.lowercased()) }
    }

    var featuredPosts: [FeedPost] {
        posts.filter { $0.isFeatured }.prefix(3).map { $0 }
    }

    // MARK: Private
    private let repository: FeedRepositoryProtocol
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "anonymous" }

    init(repository: FeedRepositoryProtocol = FeedRepositoryProvider.shared) {
        self.repository = repository
    }

    // MARK: - Load

    func loadPosts(refresh: Bool = false) {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        if refresh { hasMorePages = true }

        Task {
            do {
                let fetched = try await repository.fetchPosts(category: selectedCategory)
                let interactionList = try await repository.fetchAllInteractions(userId: currentUserId)
                let interactionMap = Dictionary(uniqueKeysWithValues: interactionList.map { ($0.postId, $0) })

                self.posts = fetched
                self.interactions = interactionMap
                self.isLoading = false
            } catch {
                self.errorMessage = "Não foi possível carregar o feed. Tente novamente."
                self.isLoading = false
            }
        }
    }

    func loadMoreIfNeeded(currentPost: FeedPost) {
        guard !isLoadingMore, hasMorePages else { return }
        guard let lastPost = filteredPosts.last, lastPost.id == currentPost.id else { return }

        isLoadingMore = true
        Task {
            do {
                let more = try await repository.fetchMorePosts(after: currentPost.id, category: selectedCategory)
                if more.isEmpty {
                    self.hasMorePages = false
                } else {
                    self.posts.append(contentsOf: more)
                }
                self.isLoadingMore = false
            } catch {
                self.isLoadingMore = false
            }
        }
    }

    func selectCategory(_ categoryId: String?) {
        let newId = (categoryId == selectedCategory || categoryId == "all") ? nil : categoryId
        selectedCategory = newId
        loadPosts(refresh: true)
    }

    // MARK: - Interactions

    func toggleLike(post: FeedPost) {
        let currentlyLiked = interactions[post.id]?.liked ?? false

        // Optimistic update
        var newInteraction = interactions[post.id] ?? UserInteraction(
            userId: currentUserId, postId: post.id,
            liked: false, saved: false, shared: false,
            lastInteractedAt: Date()
        )
        newInteraction = UserInteraction(
            userId: newInteraction.userId,
            postId: newInteraction.postId,
            liked: !currentlyLiked,
            saved: newInteraction.saved,
            shared: newInteraction.shared,
            lastInteractedAt: Date()
        )
        interactions[post.id] = newInteraction

        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].likes += currentlyLiked ? -1 : 1
        }

        Task {
            do {
                _ = try await repository.toggleLike(
                    postId: post.id,
                    userId: currentUserId,
                    currentlyLiked: currentlyLiked
                )
            } catch {
                // Revert optimistic update on failure
                self.interactions[post.id]?.liked = currentlyLiked
                if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[idx].likes += currentlyLiked ? 1 : -1
                }
            }
        }
    }

    func toggleSave(post: FeedPost) {
        let currentlySaved = interactions[post.id]?.saved ?? false

        var newInteraction = interactions[post.id] ?? UserInteraction(
            userId: currentUserId, postId: post.id,
            liked: false, saved: false, shared: false,
            lastInteractedAt: Date()
        )
        newInteraction = UserInteraction(
            userId: newInteraction.userId,
            postId: newInteraction.postId,
            liked: newInteraction.liked,
            saved: !currentlySaved,
            shared: newInteraction.shared,
            lastInteractedAt: Date()
        )
        interactions[post.id] = newInteraction

        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].saves += currentlySaved ? -1 : 1
        }

        Task {
            do {
                _ = try await repository.toggleSave(
                    postId: post.id,
                    userId: currentUserId,
                    currentlySaved: currentlySaved
                )
            } catch {
                self.interactions[post.id]?.saved = currentlySaved
                if let idx = self.posts.firstIndex(where: { $0.id == post.id }) {
                    self.posts[idx].saves += currentlySaved ? 1 : -1
                }
            }
        }
    }

    func recordShare(post: FeedPost) {
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].shares += 1
        }
        if var interaction = interactions[post.id] {
            interaction = UserInteraction(
                userId: interaction.userId,
                postId: interaction.postId,
                liked: interaction.liked,
                saved: interaction.saved,
                shared: true,
                lastInteractedAt: Date()
            )
            interactions[post.id] = interaction
        }
        Task {
            try? await repository.recordShare(postId: post.id, userId: currentUserId)
        }
    }

    func interaction(for post: FeedPost) -> UserInteraction? {
        interactions[post.id]
    }
}

// MARK: - PostDetailViewModel

@MainActor
final class PostDetailViewModel: ObservableObject {

    @Published var isLiked: Bool = false
    @Published var isSaved: Bool = false
    @Published var likeCount: Int
    @Published var saveCount: Int

    let post: FeedPost
    private let repository: FeedRepositoryProtocol
    private var currentUserId: String { Auth.auth().currentUser?.uid ?? "anonymous" }

    init(post: FeedPost,
         interaction: UserInteraction? = nil,
         repository: FeedRepositoryProtocol = FeedRepositoryProvider.shared) {
        self.post = post
        self.likeCount = post.likes
        self.saveCount = post.saves
        self.repository = repository
        if let i = interaction {
            self.isLiked = i.liked
            self.isSaved = i.saved
        }
    }

    func toggleLike() {
        let prev = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        Task {
            do {
                _ = try await repository.toggleLike(postId: post.id, userId: currentUserId, currentlyLiked: prev)
            } catch {
                self.isLiked = prev
                self.likeCount += prev ? 1 : -1
            }
        }
    }

    func toggleSave() {
        let prev = isSaved
        isSaved.toggle()
        saveCount += isSaved ? 1 : -1

        Task {
            do {
                _ = try await repository.toggleSave(postId: post.id, userId: currentUserId, currentlySaved: prev)
            } catch {
                self.isSaved = prev
                self.saveCount += prev ? 1 : -1
            }
        }
    }

    func recordShare() {
        Task { try? await repository.recordShare(postId: post.id, userId: currentUserId) }
    }
}
