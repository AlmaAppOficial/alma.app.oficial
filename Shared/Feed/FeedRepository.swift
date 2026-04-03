import Foundation
import FirebaseAuth

// MARK: - Repository Protocol
// Abstracts data layer so Firestore can be plugged in without changing ViewModels.
// To add real Firestore: create `FirestoreFeedRepository` implementing this protocol.

protocol FeedRepositoryProtocol {
    func fetchPosts(category: String?) async throws -> [FeedPost]
    func fetchMorePosts(after lastId: String, category: String?) async throws -> [FeedPost]
    func toggleLike(postId: String, userId: String, currentlyLiked: Bool) async throws -> Bool
    func toggleSave(postId: String, userId: String, currentlySaved: Bool) async throws -> Bool
    func recordShare(postId: String, userId: String) async throws
    func fetchInteraction(postId: String, userId: String) async throws -> UserInteraction?
    func fetchAllInteractions(userId: String) async throws -> [UserInteraction]
}

// MARK: - Mock Repository (works without Firestore dependency)

final class MockFeedRepository: FeedRepositoryProtocol {

    private var posts: [FeedPost] = FeedPost.samplePosts
    private var interactions: [String: UserInteraction] = [:]  // key: "\(userId)_\(postId)"

    func fetchPosts(category: String?) async throws -> [FeedPost] {
        try await Task.sleep(nanoseconds: 600_000_000) // simulate network
        if let category = category, category != "all" {
            return posts.filter { $0.categories.contains(category) }
        }
        return posts
    }

    func fetchMorePosts(after lastId: String, category: String?) async throws -> [FeedPost] {
        try await Task.sleep(nanoseconds: 400_000_000)
        return []  // No more pages in mock
    }

    func toggleLike(postId: String, userId: String, currentlyLiked: Bool) async throws -> Bool {
        let key = "\(userId)_\(postId)"
        let newLiked = !currentlyLiked
        if var interaction = interactions[key] {
            interaction.liked = newLiked
            interactions[key] = interaction
        } else {
            interactions[key] = UserInteraction(
                userId: userId, postId: postId,
                liked: newLiked, saved: false, shared: false,
                lastInteractedAt: Date()
            )
        }
        // Update post like count in-memory
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].likes += newLiked ? 1 : -1
        }
        return newLiked
    }

    func toggleSave(postId: String, userId: String, currentlySaved: Bool) async throws -> Bool {
        let key = "\(userId)_\(postId)"
        let newSaved = !currentlySaved
        if var interaction = interactions[key] {
            interaction.saved = newSaved
            interactions[key] = interaction
        } else {
            interactions[key] = UserInteraction(
                userId: userId, postId: postId,
                liked: false, saved: newSaved, shared: false,
                lastInteractedAt: Date()
            )
        }
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].saves += newSaved ? 1 : -1
        }
        return newSaved
    }

    func recordShare(postId: String, userId: String) async throws {
        let key = "\(userId)_\(postId)"
        if var interaction = interactions[key] {
            interaction.shared = true
            interactions[key] = interaction
        } else {
            interactions[key] = UserInteraction(
                userId: userId, postId: postId,
                liked: false, saved: false, shared: true,
                lastInteractedAt: Date()
            )
        }
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            posts[idx].shares += 1
        }
    }

    func fetchInteraction(postId: String, userId: String) async throws -> UserInteraction? {
        interactions["\(userId)_\(postId)"]
    }

    func fetchAllInteractions(userId: String) async throws -> [UserInteraction] {
        interactions.values.filter { $0.userId == userId }
    }
}

// MARK: - Smart Repository (Firestore + local fallback + auto-seed)

/// Wraps FirestoreFeedRepository with automatic fallback to local sample posts.
/// On first launch with empty Firestore, seeds 22 posts automatically.
final class SmartFeedRepository: FeedRepositoryProtocol {

    private let firestore = FirestoreFeedRepository()
    private let mock = MockFeedRepository()
    private var seededKey = "alma_feed_seeded_v1"

    func fetchPosts(category: String?) async throws -> [FeedPost] {
        do {
            let posts = try await firestore.fetchPosts(category: category)
            if posts.isEmpty {
                // Firestore empty — seed it asynchronously and return local posts now
                Task {
                    await seedIfNeeded()
                }
                return try await mock.fetchPosts(category: category)
            }
            return posts
        } catch {
            // Network error — return local posts as fallback
            return try await mock.fetchPosts(category: category)
        }
    }

    func fetchMorePosts(after lastId: String, category: String?) async throws -> [FeedPost] {
        do {
            return try await firestore.fetchMorePosts(after: lastId, category: category)
        } catch {
            return []
        }
    }

    func toggleLike(postId: String, userId: String, currentlyLiked: Bool) async throws -> Bool {
        do {
            return try await firestore.toggleLike(postId: postId, userId: userId, currentlyLiked: currentlyLiked)
        } catch {
            return try await mock.toggleLike(postId: postId, userId: userId, currentlyLiked: currentlyLiked)
        }
    }

    func toggleSave(postId: String, userId: String, currentlySaved: Bool) async throws -> Bool {
        do {
            return try await firestore.toggleSave(postId: postId, userId: userId, currentlySaved: currentlySaved)
        } catch {
            return try await mock.toggleSave(postId: postId, userId: userId, currentlySaved: currentlySaved)
        }
    }

    func recordShare(postId: String, userId: String) async throws {
        do {
            try await firestore.recordShare(postId: postId, userId: userId)
        } catch {
            try await mock.recordShare(postId: postId, userId: userId)
        }
    }

    func fetchInteraction(postId: String, userId: String) async throws -> UserInteraction? {
        do {
            return try await firestore.fetchInteraction(postId: postId, userId: userId)
        } catch {
            return try await mock.fetchInteraction(postId: postId, userId: userId)
        }
    }

    func fetchAllInteractions(userId: String) async throws -> [UserInteraction] {
        do {
            return try await firestore.fetchAllInteractions(userId: userId)
        } catch {
            return try await mock.fetchAllInteractions(userId: userId)
        }
    }

    // MARK: Auto-seed

    private func seedIfNeeded() async {
        let alreadySeeded = UserDefaults.standard.bool(forKey: seededKey)
        guard !alreadySeeded else { return }
        do {
            try await firestore.seedSamplePosts()
            UserDefaults.standard.set(true, forKey: seededKey)
        } catch {
            // Seed failed — will retry next launch
        }
    }
}

// MARK: - Shared instance

enum FeedRepositoryProvider {
    /// SmartFeedRepository: tries Firestore, falls back to local posts if empty/offline,
    /// and auto-seeds Firestore with 22 posts on first empty result.
    static let shared: FeedRepositoryProtocol = SmartFeedRepository()
}
