import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

let backendURL = "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat"
private let maxFreeMessages = 5

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var showPaywall: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private var messageCount: Int = 0

    init() {
        Task {
            await listenToMessages()
        }
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Public Methods

    /// Sends a message to the backend and stores it in Firestore
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }

        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""

        // Check message limit for free users
        messageCount += 1
        if messageCount > maxFreeMessages {
            showPaywall = true
            messageCount = maxFreeMessages // Reset to prevent further increment
            return
        }

        // Add user message locally
        let userChatMessage = ChatMessage(
            id: UUID().uuidString,
            text: userMessage,
            isUser: true,
            date: Date()
        )
        messages.append(userChatMessage)

        // Save to Firestore
        do {
            try await saveMessageToFirestore(userChatMessage)
        } catch {
            errorMessage = "Failed to save message"
            messages.removeLast()
            return
        }

        // Send to backend
        isTyping = true
        defer { isTyping = false }

        do {
            guard let firebaseToken = try await Auth.auth().currentUser?.getIDToken() else {
                errorMessage = "Authentication failed"
                return
            }

            let response = try await callBackendChat(message: userMessage, token: firebaseToken)

            // Add bot response locally
            let botMessage = ChatMessage(
                id: UUID().uuidString,
                text: response,
                isUser: false,
                date: Date()
            )
            messages.append(botMessage)

            // Save bot response to Firestore
            try await saveMessageToFirestore(botMessage)

        } catch {
            errorMessage = "Failed to get response: \(error.localizedDescription)"
        }
    }

    /// Subscribes to real-time updates of messages from Firestore
    func listenToMessages() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }

        listenerRegistration = db
            .collection("users")
            .document(uid)
            .collection("chat")
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                Task { @MainActor in
                    if let error = error {
                        self.errorMessage = "Failed to load messages: \(error.localizedDescription)"
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        self.messages = []
                        return
                    }

                    do {
                        self.messages = try documents.compactMap { doc in
                            try doc.data(as: ChatMessage.self)
                        }
                        self.messageCount = documents.count
                    } catch {
                        self.errorMessage = "Failed to decode messages"
                    }
                }
            }
    }

    /// Clears all chat messages
    func clearChat() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not authenticated"
            return
        }

        do {
            let batch = db.batch()
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("chat")
                .getDocuments()

            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }

            try await batch.commit()
            messages = []
            messageCount = 0
            errorMessage = nil
        } catch {
            errorMessage = "Failed to clear chat: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    private func saveMessageToFirestore(_ message: ChatMessage) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }

        let messageData: [String: Any] = [
            "id": message.id,
            "text": message.text,
            "isUser": message.isUser,
            "date": Timestamp(date: message.date)
        ]

        try await db
            .collection("users")
            .document(uid)
            .collection("chat")
            .document(message.id)
            .setData(messageData)
    }

    private func callBackendChat(message: String, token: String) async throws -> String {
        guard let url = URL(string: backendURL) else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ChatError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        return chatResponse.response
    }
}

// MARK: - Helper Types

private struct ChatResponse: Decodable {
    let response: String
}

enum ChatError: LocalizedError {
    case notAuthenticated
    case invalidURL
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidURL:
            return "Invalid backend URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
