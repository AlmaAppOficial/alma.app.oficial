import SwiftUI

// MARK: - Alma Design System

struct AlmaTheme {

    // ── Cores ──────────────────────────────────────────────────────
    static let background       = Color(hex: "0B0D14")
    static let card             = Color(hex: "13151F")
    static let cardSecondary    = Color(hex: "1B1E2C")
    static let accent           = Color(hex: "7B8FFF")
    static let accentPurple     = Color(hex: "B07BFF")
    static let textPrimary      = Color.white
    static let textSecondary    = Color(hex: "8B90A0")
    static let success          = Color(hex: "4ADE80")
    static let warning          = Color(hex: "FBBF24")
    static let error            = Color(hex: "F87171")
    static let divider          = Color(hex: "1F2232")

    // ── Gradients ──────────────────────────────────────────────────
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "7B8FFF"), Color(hex: "B07BFF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: "0B0D14"), Color(hex: "0F1120")],
        startPoint: .top, endPoint: .bottom
    )

    // ── Corner Radius ──────────────────────────────────────────────
    static let radius: CGFloat      = 16
    static let radiusSmall: CGFloat = 10
    static let radiusPill: CGFloat  = 100

    // ── Spacing ────────────────────────────────────────────────────
    static let paddingPage: CGFloat = 20
    static let paddingCard: CGFloat = 16
}

// MARK: - Color from Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - View Modifiers
extension View {
    func almaCard() -> some View {
        self
            .padding(AlmaTheme.paddingCard)
            .background(AlmaTheme.card)
            .cornerRadius(AlmaTheme.radius)
    }

    func almaPrimaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AlmaTheme.accentGradient)
            .foregroundColor(.white)
            .cornerRadius(AlmaTheme.radius)
            .font(.system(.body, design: .rounded).weight(.semibold))
    }

    func almaSecondaryButton() -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AlmaTheme.card)
            .foregroundColor(AlmaTheme.textPrimary)
            .cornerRadius(AlmaTheme.radius)
            .overlay(RoundedRectangle(cornerRadius: AlmaTheme.radius).stroke(AlmaTheme.divider, lineWidth: 1))
            .font(.system(.body, design: .rounded).weight(.semibold))
    }
}
