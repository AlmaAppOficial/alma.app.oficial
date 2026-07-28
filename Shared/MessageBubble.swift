import SwiftUI

// MARK: - ChatMessage
// [Build 84 — 2026-07-28] Codable para persistência local do histórico
// (ChatHistoryStore). `isTransient` marca avisos de erro/sistema exibidos
// no chat que NÃO devem ser gravados no histórico.
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var isTransient: Bool

    init(_ text: String, isUser: Bool, isTransient: Bool = false) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.isTransient = isTransient
    }

    /// Reconstrói uma mensagem vinda do histórico (local ou Firestore).
    init(id: UUID = UUID(), text: String, isUser: Bool, timestamp: Date) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.timestamp = timestamp
        self.isTransient = false
    }

    // Decodifica com tolerância a campos ausentes (histórico de versões antigas).
    private enum CodingKeys: String, CodingKey {
        case id, text, isUser, timestamp, isTransient
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.text = try c.decode(String.self, forKey: .text)
        self.isUser = try c.decode(Bool.self, forKey: .isUser)
        self.timestamp = (try? c.decode(Date.self, forKey: .timestamp)) ?? Date()
        self.isTransient = (try? c.decode(Bool.self, forKey: .isTransient)) ?? false
    }
}

// MARK: - MessageBubble
struct MessageBubble: View {

    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 48) }

            if !message.isUser {
                // Alma avatar
                Text("A")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(CalmTheme.heroGradient)
                    .clipShape(Circle())
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : CalmTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .cornerRadius(18)

                Text(formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(CalmTheme.textSecondary)
            }

            if !message.isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isUser {
            CalmTheme.heroGradient
        } else {
            CalmTheme.primary.opacity(0.08)
        }
    }

    private var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: message.timestamp)
    }
}
