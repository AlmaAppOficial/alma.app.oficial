import SwiftUI

struct AlmaTheme {
    // MARK: - Colors
    static let background = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let card = Color(red: 0.13, green: 0.13, blue: 0.18)
    static let accent = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)

    // MARK: - Gradient
    static let accentGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.5, green: 0.3, blue: 0.9),
            Color(red: 0.4, green: 0.2, blue: 0.85)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Layout
    static let radius: CGFloat = 16
    static let paddingPage: CGFloat = 16
}

// MARK: - View Extensions

extension View {
    func almaCard() -> some View {
        self
            .padding(AlmaTheme.paddingPage)
            .background(AlmaTheme.card)
            .cornerRadius(AlmaTheme.radius)
    }

    func almaPrimaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(AlmaTheme.accentGradient)
            .foregroundColor(.white)
            .cornerRadius(AlmaTheme.radius)
            .fontWeight(.semibold)
    }

    func almaSecondaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(AlmaTheme.card)
            .foregroundColor(AlmaTheme.accent)
            .cornerRadius(AlmaTheme.radius)
            .fontWeight(.semibold)
    }
}
