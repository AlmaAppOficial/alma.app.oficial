import SwiftUI

struct MessageBubble: View {
    let message: String
    let isUser: Bool
    let timestamp: Date

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            // Message bubble
            HStack {
                if isUser {
                    Spacer()
                }

                Text(message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AlmaTheme.radius)
                            .fill(isUser ? AlmaTheme.accentGradient : AlmaTheme.card)
                    )

                if !isUser {
                    Spacer()
                }
            }

            // Timestamp
            Text(formatTime(timestamp))
                .font(.caption2)
                .foregroundColor(AlmaTheme.textSecondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(
            message: "Olá! Como você está se sentindo hoje?",
            isUser: false,
            timestamp: Date()
        )

        MessageBubble(
            message: "Estou me sentindo um pouco ansioso com os próximos projetos.",
            isUser: true,
            timestamp: Date()
        )

        MessageBubble(
            message: "Entendo. A ansiedade é uma resposta natural. Gostaria de conversar sobre isso?",
            isUser: false,
            timestamp: Date()
        )
    }
    .padding()
    .background(AlmaTheme.background)
}
