import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - FeedViewModel (Build 77 — curated link feed)

@MainActor
final class FeedViewModel: ObservableObject {

    @Published var posts: [FeedPost] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isAdmin: Bool = false

    private var listener: ListenerRegistration?
    private let repository = FeedRepository.shared

    init() {
        startListening()
        Task { await refreshAdminStatus() }
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        listener?.remove()
        isLoading = true
        errorMessage = nil

        listener = repository.recentPostsQuery().addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = "Não foi possível carregar o feed. \(error.localizedDescription)"
                    return
                }
                guard let snapshot else { return }
                self.posts = snapshot.documents.compactMap { FeedRepository.decode($0) }
                self.errorMessage = nil
            }
        }
    }

    func refreshAdminStatus() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isAdmin = false
            return
        }
        isAdmin = await repository.isAdmin(uid: uid)
    }

    // MARK: - Admin actions

    func deletePost(_ post: FeedPost) async {
        do {
            try await repository.deletePost(postId: post.id)
            // Listener will remove the post from `posts` automatically.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
