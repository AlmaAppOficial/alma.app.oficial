import SwiftUI

// MARK: - Legacy Theme (kept for backward compatibility)
struct AlmaTheme {
    static let background = Color(red: 0.059, green: 0.039, blue: 0.118)  // #0f0a1e
    static let card       = Color(red: 0.102, green: 0.063, blue: 0.251)  // #1a1040
    static let accent     = Color(red: 0.486, green: 0.227, blue: 0.929)  // #7c3aed
}

// MARK: - CalmTheme (Violeta Profundo — tonalidade das artes sociais 2026)
enum CalmTheme {
    // Core palette — adaptive colors respond to system dark/light mode
    // Dark mode: violeta profundo (#0f0a1e / #1a1040) — mesma paleta das artes
    static let background    = Color(UIColor { t in t.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.059, green: 0.039, blue: 0.118, alpha: 1)  // #0f0a1e
                                    : UIColor(red: 0.96,  green: 0.95,  blue: 0.99,  alpha: 1) })

    static let surface       = Color(UIColor { t in t.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.102, green: 0.063, blue: 0.251, alpha: 1)  // #1a1040
                                    : UIColor.white })

    static let primary       = Color(red: 0.486, green: 0.227, blue: 0.929)  // #7c3aed — violeta vivo
    static let primaryLight  = Color(red: 0.624, green: 0.478, blue: 0.918)  // #9F7AEA — violeta médio
    static let accent        = Color(red: 0.965, green: 0.678, blue: 0.333)  // #F6AD55 — laranja do anel

    static let textPrimary   = Color(UIColor { t in t.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.914, green: 0.835, blue: 1.000, alpha: 1)  // #e9d5ff
                                    : UIColor(red: 0.15,  green: 0.10,  blue: 0.25,  alpha: 1) })

    static let textSecondary = Color(UIColor { t in t.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)  // #a78bfa
                                    : UIColor(red: 0.48,  green: 0.42,  blue: 0.60,  alpha: 1) })

    static let shareCardBackground = Color(red: 0.102, green: 0.059, blue: 0.180)  // #1a0f2e

    // Gradients — espelham o visual das artes
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.102, green: 0.020, blue: 0.200),  // #1a0533 — roxo escuro
            primary,                                          // #7c3aed — violeta vivo
            primaryLight                                      // #9F7AEA — violeta médio
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let backgroundGradient = LinearGradient(
        colors: [background, Color(red: 0.102, green: 0.063, blue: 0.251)],  // #0f0a1e → #1a1040
        startPoint: .top, endPoint: .bottom
    )

    // Spacing
    static let s8:  CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24

    // Radius
    static let rSmall:  CGFloat = 12
    static let rMedium: CGFloat = 16
    static let rLarge:  CGFloat = 24
}

// MARK: - CalmCard Modifier
struct CalmCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(CalmTheme.s16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: CalmTheme.primary.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func calmCard() -> some View {
        modifier(CalmCardModifier())
    }
}

// MARK: - Color from Hex
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: return nil
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
