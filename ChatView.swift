import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct ChatView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AlmaTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }

                                if isLoading {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(AlmaTheme.accent)

                                        Text("Alma está a pensar...")
                                            .font(.caption)
                                            .foregroundColor(AlmaTheme.textSecondary)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(AlmaTheme.card)
                                    .cornerRadius(AlmaTheme.radius)
                                    .padding(.horizontal, AlmaTheme.paddingPage)
                                }
                            }
                            .padding(AlmaTheme.paddingPage)
                        }
                        .onChange(of: messages.count) { _ in
                            if let lastMessage = messages.last {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }

                    Divider()
                        .background(AlmaTheme.card)

                    // Input Area
                    HStack(spacing: 8) {
                        TextField("Escreva uma mensagem...", text: $messageText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(AlmaTheme.textPrimary)

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(AlmaTheme.accentGradient)
                        .cornerRadius(AlmaTheme.radius)
                        .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                        .opacity(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading ? 0.5 : 1.0)
                    }
                    .padding(AlmaTheme.paddingPage)
                }
            }
            .navigationTitle("Falar com Alma")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadMessages()
            }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let uid = authManager.authManager?.currentUser?.uid else { return }

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            isUserMessage: true,
            timestamp: Date()
        )

        messages.append(userMessage)
        messageText = ""

        let db = Firestore.firestore()
        let messageData: [String: Any] = [
            "text": text,
            "isUserMessage": true,
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("users").document(uid).collection("messages").addDocument(data: messageData)

        // Simulate AI response
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let aiMessage = ChatMessage(
                id: UUID().uuidString,
                text: "Entendo. Como posso ajudar você a se sentir melhor?",
                isUserMessage: false,
                timestamp: Date()
            )
            messages.append(aiMessage)
            isLoading = false
        }
    }

    private func loadMessages() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(uid).collection("messages")
            .order(by: "timestamp", descending: false)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    let loadedMessages = documents.compactMap { doc -> ChatMessage? in
                        let data = doc.data()
                        return ChatMessage(
                            id: doc.documentID,
                            text: data["text"] as? String ?? "",
                            isUserMessage: data["isUserMessage"] as? Bool ?? false,
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                    DispatchQueue.main.async {
                        self.messages = loadedMessages
                    }
                }
            }
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let isUserMessage: Bool
    let timestamp: Date
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUserMessage {
                Spacer()
            }

            VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundColor(message.isUserMessage ? .white : AlmaTheme.textPrimary)
                    .padding(12)
                    .background(message.isUserMessage ? AlmaTheme.accent : AlmaTheme.card)
                    .cornerRadius(AlmaTheme.radius)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(AlmaTheme.textSecondary)
                    .padding(.horizontal, 12)
            }

            if !message.isUserMessage {
                Spacer()
            }
        }
        .padding(.horizontal, AlmaTheme.paddingPage)
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
