import SwiftUI

// MARK: - ChatMessage
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(_ text: String, isUser: Bool) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
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
