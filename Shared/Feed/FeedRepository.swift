import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - FeedRepository (Build 77 — curated link feed)
//
// Thin wrapper around:
//   - feed_posts/{id} Firestore reads (live listener)
//   - createFeedPost / deleteFeedPost Cloud Functions (callable protocol via
//     plain HTTPS, since the project does not link the FirebaseFunctions SDK)
//
// All writes go through Cloud Functions (admin check is server-side). Clients
// have read-only access to feed_posts via firestore.rules.

@MainActor
final class FeedRepository {

    static let shared = FeedRepository()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Cloud Function URLs

    private static let region = "southamerica-east1"
    private static let projectId = "alma-app-7dae6"
    private static func callableURL(_ name: String) -> URL {
        URL(string: "https://\(region)-\(projectId).cloudfunctions.net/\(name)")!
    }

    // MARK: - Reads

    func recentPostsQuery(limit: Int = 50) -> Query {
        db.collection("feed_posts")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
    }

    static func decode(_ snapshot: QueryDocumentSnapshot) -> FeedPost? {
        let data = snapshot.data()
        guard
            let url = data["url"] as? String,
            let title = data["title"] as? String,
            let sourceRaw = data["source"] as? String,
            let createdBy = data["createdBy"] as? String
        else { return nil }

        let createdAt: Date = {
            if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
            return Date()
        }()

        return FeedPost(
            id: snapshot.documentID,
            url: url,
            source: FeedSource(rawValue: sourceRaw),
            title: title,
            description: (data["description"] as? String) ?? "",
            thumbnail: data["thumbnail"] as? String,
            createdAt: createdAt,
            createdBy: createdBy
        )
    }

    // MARK: - Admin status

    func isAdmin(uid: String) async -> Bool {
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            return (snap.data()?["isAdmin"] as? Bool) == true
        } catch {
            return false
        }
    }

    // MARK: - Callable invocation (manual)

    /// Invokes a Firebase Callable function via plain HTTPS using the Callable
    /// wire protocol: { data: ... } request, { result: ... } / { error: ... }
    /// response, Bearer ID token in Authorization header.
    private func callFunction(_ name: String, payload: [String: Any]) async throws -> [String: Any] {
        guard let user = Auth.auth().currentUser else { throw FeedError.notAuthenticated }
        let idToken = try await user.getIDToken()

        var request = URLRequest(url: Self.callableURL(name))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["data": payload])

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FeedError.invalidResponse
        }

        if let errorDict = json["error"] as? [String: Any] {
            let message = (errorDict["message"] as? String) ?? "Erro desconhecido."
            let status = (errorDict["status"] as? String) ?? ""
            if status == "PERMISSION_DENIED" || http?.statusCode == 403 {
                throw FeedError.notAdmin
            }
            if status == "INVALID_ARGUMENT" || http?.statusCode == 400 {
                throw FeedError.serverMessage(message)
            }
            throw FeedError.serverMessage(message)
        }

        guard let result = json["result"] as? [String: Any] else {
            throw FeedError.invalidResponse
        }
        return result
    }

    // MARK: - Create

    enum CreatePostResult {
        case preview(FeedPost)
        case needsManual(FeedSource, reason: String)
    }

    func createPost(
        url: String,
        manualTitle: String? = nil,
        manualDescription: String? = nil
    ) async throws -> CreatePostResult {
        var payload: [String: Any] = ["url": url]
        if let manualTitle, !manualTitle.isEmpty { payload["manualTitle"] = manualTitle }
        if let manualDescription, !manualDescription.isEmpty { payload["manualDescription"] = manualDescription }

        let result = try await callFunction("createFeedPost", payload: payload)
        guard let mode = result["mode"] as? String else { throw FeedError.invalidResponse }

        switch mode {
        case "manual":
            let sourceRaw = (result["source"] as? String) ?? "generic"
            let reason = (result["reason"] as? String) ?? ""
            return .needsManual(FeedSource(rawValue: sourceRaw), reason: reason)

        case "preview":
            guard
                let postDict = result["post"] as? [String: Any],
                let postId = (result["postId"] as? String) ?? (postDict["id"] as? String),
                let postUrl = postDict["url"] as? String,
                let title = postDict["title"] as? String,
                let sourceRaw = postDict["source"] as? String,
                let createdBy = postDict["createdBy"] as? String
            else { throw FeedError.invalidResponse }

            let createdAt: Date = {
                if let ms = postDict["createdAt"] as? TimeInterval {
                    return Date(timeIntervalSince1970: ms / 1000.0)
                }
                return Date()
            }()

            let post = FeedPost(
                id: postId,
                url: postUrl,
                source: FeedSource(rawValue: sourceRaw),
                title: title,
                description: (postDict["description"] as? String) ?? "",
                thumbnail: postDict["thumbnail"] as? String,
                createdAt: createdAt,
                createdBy: createdBy
            )
            return .preview(post)

        default:
            throw FeedError.invalidResponse
        }
    }

    // MARK: - Delete

    func deletePost(postId: String) async throws {
        _ = try await callFunction("deleteFeedPost", payload: ["postId": postId])
    }

    // MARK: - User preferences

    func setFeedNotificationsEnabled(_ enabled: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData(
            ["feedNotificationsEnabled": enabled],
            merge: true
        )
    }

    func setFCMToken(_ token: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData(
            ["fcmToken": token],
            merge: true
        )
    }
}

// MARK: - Errors

enum FeedError: LocalizedError {
    case invalidResponse
    case urlInvalid
    case notAdmin
    case notAuthenticated
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:       return "Resposta do servidor inválida."
        case .urlInvalid:            return "URL inválida."
        case .notAdmin:              return "Apenas administradores podem publicar."
        case .notAuthenticated:      return "Faça login para continuar."
        case .serverMessage(let m):  return m
        }
    }
}

// MARK: - User.getIDToken async helper

private extension User {
    func getIDToken() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            self.getIDToken { token, error in
                if let token { cont.resume(returning: token) }
                else { cont.resume(throwing: error ?? FeedError.notAuthenticated) }
            }
        }
    }
}
