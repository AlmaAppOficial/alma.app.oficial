// WatchTheme.swift
// Alma Watch — identidade visual do Alma e do Corpo adaptada ao pulso.
//
// Regra central (HIG "Designing for watchOS"): o fundo do relógio é PRETO PURO
// (OLED + Always-On). A marca não vem do fundo, vem da COR DE ACENTO e da forma:
// violeta = Alma, oliva = Corpo.
//
// As escolhas de cor abaixo vêm da medição de contraste WCAG contra #000000
// feita no diagnóstico de 04/08/2026 (DIAGNOSTICO_APPLE_WATCH_20260804.md):
//   • #7c3aed (primary do Alma)  = 3,69:1 → SÓ anel/superfície, nunca texto pequeno
//   • #9F7AEA (primaryLight)     = 6,45:1 → o violeta de texto no pulso
//   • #6F7D3F (primary do Corpo) = 4,68:1 → anel/ícone; texto usa a variante clara
//   • #525C2B (primaryDeep)      = 2,92:1 → PROIBIDO no relógio

import SwiftUI

enum WatchTheme {

    // MARK: - Alma (violeta)

    /// Superfícies e anéis — não usar em texto pequeno (3,69:1).
    static let almaPrimary = Color(hexW: "7C3AED")
    /// O violeta de texto do pulso (6,45:1).
    static let almaText = Color(hexW: "9F7AEA")
    /// Texto principal claro (15,43:1).
    static let almaBright = Color(hexW: "E9D5FF")
    /// Texto secundário (7,72:1).
    static let almaSoft = Color(hexW: "A78BFA")
    /// Laranja de destaque — número do streak (11,03:1).
    static let accent = Color(hexW: "F6AD55")

    // MARK: - Corpo (oliva e métricas)

    /// Oliva da marca — anéis e ícones (4,68:1).
    static let corpoOliva = Color(hexW: "6F7D3F")
    /// Oliva clareado para texto no pulso.
    static let corpoOlivaClaro = Color(hexW: "A9BC6B")
    /// Dieta / nutrição (7,96:1).
    static let coral = Color(hexW: "E08A5C")
    /// Atividade / sono (6,32:1).
    static let azure = Color(hexW: "5C93B8")
    /// Insights (9,34:1).
    static let gold = Color(hexW: "D9A441")
    /// Ponte Corpo → Alma (5,92:1).
    static let violet = Color(hexW: "8B7BD8")

    // MARK: - Neutros

    static let textPrimary = Color(hexW: "ECF0E8")
    static let textSecondary = Color(hexW: "9DA89A")
    /// Superfície de cartão sobre preto: branco a 8%.
    static let card = Color.white.opacity(0.08)
    static let cardStrong = Color.white.opacity(0.14)

    // MARK: - Gradientes de marca

    static var heroAlma: LinearGradient {
        LinearGradient(colors: [Color(hexW: "1A0533"), almaPrimary.opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var heroCorpo: LinearGradient {
        LinearGradient(colors: [Color(hexW: "12150F"), corpoOliva.opacity(0.5)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Hex helper (nome próprio para nunca colidir com o Color(hex:) do iOS)

extension Color {
    init(hexW: String) {
        let h = hexW.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Cartão padrão do pulso

struct CartaoWatch: ViewModifier {
    var destaque = false
    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(destaque ? WatchTheme.cardStrong : WatchTheme.card,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func cartaoWatch(destaque: Bool = false) -> some View {
        modifier(CartaoWatch(destaque: destaque))
    }
}
