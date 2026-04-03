import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firestore Feed Repository
// Implements FeedRepositoryProtocol using Firebase Firestore.
// Collections used:
//   feed_posts/{postId}
//   user_interactions/{userId}/posts/{postId}

final class FirestoreFeedRepository: FeedRepositoryProtocol {

    private let db = Firestore.firestore()
    private let pageSize = 10

    // MARK: - Collection references

    private var postsRef: CollectionReference {
        db.collection("feed_posts")
    }

    private func interactionsRef(userId: String) -> CollectionReference {
        db.collection("user_interactions").document(userId).collection("posts")
    }

    // MARK: - Fetch posts

    func fetchPosts(category: String?) async throws -> [FeedPost] {
        var query: Query = postsRef
            .whereField("isPublished", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if let category = category, category != "all" {
            query = postsRef
                .whereField("isPublished", isEqualTo: true)
                .whereField("categories", arrayContains: category)
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreFeedPost.self).toFeedPost(id: doc.documentID)
        }
    }

    func fetchMorePosts(after lastId: String, category: String?) async throws -> [FeedPost] {
        // Fetch cursor document first
        let cursorDoc = try await postsRef.document(lastId).getDocument()
        guard cursorDoc.exists else { return [] }

        var query: Query = postsRef
            .whereField("isPublished", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .start(afterDocument: cursorDoc)
            .limit(to: pageSize)

        if let category = category, category != "all" {
            query = postsRef
                .whereField("isPublished", isEqualTo: true)
                .whereField("categories", arrayContains: category)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: cursorDoc)
                .limit(to: pageSize)
        }

        let snapshot = try await query.getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: FirestoreFeedPost.self).toFeedPost(id: doc.documentID)
        }
    }

    // MARK: - Interactions

    func toggleLike(postId: String, userId: String, currentlyLiked: Bool) async throws -> Bool {
        let newLiked = !currentlyLiked
        let interactionRef = interactionsRef(userId: userId).document(postId)
        let postRef = postsRef.document(postId)

        try await db.runTransaction { transaction, errorPointer in
            // Update interaction document
            transaction.setData([
                "liked": newLiked,
                "postId": postId,
                "userId": userId,
                "lastInteractedAt": FieldValue.serverTimestamp()
            ], forDocument: interactionRef, merge: true)

            // Increment/decrement post like counter
            transaction.updateData([
                "likes": FieldValue.increment(Int64(newLiked ? 1 : -1))
            ], forDocument: postRef)

            return nil
        }
        return newLiked
    }

    func toggleSave(postId: String, userId: String, currentlySaved: Bool) async throws -> Bool {
        let newSaved = !currentlySaved
        let interactionRef = interactionsRef(userId: userId).document(postId)
        let postRef = postsRef.document(postId)

        try await db.runTransaction { transaction, errorPointer in
            transaction.setData([
                "saved": newSaved,
                "postId": postId,
                "userId": userId,
                "lastInteractedAt": FieldValue.serverTimestamp()
            ], forDocument: interactionRef, merge: true)

            transaction.updateData([
                "saves": FieldValue.increment(Int64(newSaved ? 1 : -1))
            ], forDocument: postRef)

            return nil
        }
        return newSaved
    }

    func recordShare(postId: String, userId: String) async throws {
        let interactionRef = interactionsRef(userId: userId).document(postId)
        let postRef = postsRef.document(postId)

        try await db.runTransaction { transaction, errorPointer in
            transaction.setData([
                "shared": true,
                "postId": postId,
                "userId": userId,
                "lastInteractedAt": FieldValue.serverTimestamp()
            ], forDocument: interactionRef, merge: true)

            transaction.updateData([
                "shares": FieldValue.increment(Int64(1))
            ], forDocument: postRef)

            return nil
        }
    }

    func fetchInteraction(postId: String, userId: String) async throws -> UserInteraction? {
        let doc = try await interactionsRef(userId: userId).document(postId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return UserInteraction(
            userId: data["userId"] as? String ?? userId,
            postId: postId,
            liked: data["liked"] as? Bool ?? false,
            saved: data["saved"] as? Bool ?? false,
            shared: data["shared"] as? Bool ?? false,
            lastInteractedAt: (data["lastInteractedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func fetchAllInteractions(userId: String) async throws -> [UserInteraction] {
        let snapshot = try await interactionsRef(userId: userId).getDocuments()
        return snapshot.documents.compactMap { doc -> UserInteraction? in
            guard let data = doc.data() as? [String: Any] else { return nil }
            return UserInteraction(
                userId: data["userId"] as? String ?? userId,
                postId: doc.documentID,
                liked: data["liked"] as? Bool ?? false,
                saved: data["saved"] as? Bool ?? false,
                shared: data["shared"] as? Bool ?? false,
                lastInteractedAt: (data["lastInteractedAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }
}

// MARK: - Firestore DTO

/// Intermediate Codable struct that maps Firestore field names to Swift types.
private struct FirestoreFeedPost: Codable {
    let title: String
    let description: String
    let content: String
    let contentType: String
    let categories: [String]
    let author: String
    let authorId: String
    let authorImage: String?
    let coverImage: String?
    let scientificBasis: [String]
    let sources: [String]
    let meditationDuration: Int?
    let meditationAudio: String?
    let hashtags: [String]
    let likes: Int
    let saves: Int
    let shares: Int
    let createdAt: Timestamp
    let isPublished: Bool
    let isFeatured: Bool

    func toFeedPost(id: String) -> FeedPost? {
        guard let type = FeedPost.ContentType(rawValue: contentType) else { return nil }
        return FeedPost(
            id: id,
            title: title,
            description: description,
            content: content,
            contentType: type,
            categories: categories,
            author: author,
            authorId: authorId,
            authorImage: authorImage,
            coverImage: coverImage,
            scientificBasis: scientificBasis,
            sources: sources,
            meditationDuration: meditationDuration,
            meditationAudio: meditationAudio,
            hashtags: hashtags,
            likes: likes,
            saves: saves,
            shares: shares,
            createdAt: createdAt.dateValue(),
            isPublished: isPublished,
            isFeatured: isFeatured
        )
    }
}

// MARK: - Seed helper (run once to populate Firestore from sample data)

extension FirestoreFeedRepository {
    /// Call this once (e.g. from admin panel) to seed Firestore with sample posts.
    func seedSamplePosts() async throws {
        let batch = db.batch()
        for post in FeedPost.samplePosts {
            let ref = postsRef.document(post.id)
            let data: [String: Any] = [
                "title": post.title,
                "description": post.description,
                "content": post.content,
                "contentType": post.contentType.rawValue,
                "categories": post.categories,
                "author": post.author,
                "authorId": post.authorId,
                "authorImage": post.authorImage as Any,
                "coverImage": post.coverImage as Any,
                "scientificBasis": post.scientificBasis,
                "sources": post.sources,
                "meditationDuration": post.meditationDuration as Any,
                "meditationAudio": post.meditationAudio as Any,
                "hashtags": post.hashtags,
                "likes": post.likes,
                "saves": post.saves,
                "shares": post.shares,
                "createdAt": Timestamp(date: post.createdAt),
                "isPublished": post.isPublished,
                "isFeatured": post.isFeatured,
                "moderationStatus": "approved"
            ]
            batch.setData(data, forDocument: ref)
        }
        try await batch.commit()
    }
}
