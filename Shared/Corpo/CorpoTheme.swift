//
//  Theme.swift
//  Corpo & Alma
//
//  Tokens de design — paleta, tipografia e espaçamento.
//  Paleta calma e premium, alinhada à identidade do Alma.
//

import SwiftUI
import UIKit

enum Theme {
    // MARK: - Cores base (adaptáveis a claro/escuro)
    static let background   = Color(light: "F4F6F4", dark: "12150F")  // fundo
    static let surface      = Color(light: "FFFFFF", dark: "1D211A")  // cards
    static let surfaceAlt   = Color(light: "EBEFEC", dark: "262B22")  // realces

    static let ink          = Color(light: "1C2A27", dark: "ECF0E8")  // texto principal
    static let inkSoft      = Color(light: "7C8B85", dark: "9DA89A")  // texto secundário

    // MARK: - Cores de marca / domínios
    static let primary      = Color.corpoHex("6F7D3F")   // Saúde — verde oliva (marca)
    static let primaryDeep  = Color.corpoHex("525C2B")   // oliva escuro (gradientes)
    static let coral        = Color.corpoHex("E08A5C")   // Dieta — nutrição (terroso)
    static let azure        = Color.corpoHex("5C93B8")   // Atividade / sono
    static let gold         = Color.corpoHex("D9A441")   // Insights
    static let violet       = Color.corpoHex("8B7BD8")   // Mente / equilíbrio (ponte Alma)

    // MARK: - Espaçamento
    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 14
    static let spacing: CGFloat = 16
}

// MARK: - Color por hex

// [Fusão 2026-08-02] O Alma declara `Color.init?(hex:)` (failable) em
// Shared/Theme.swift. Manter outra `init(hex:)` aqui dava "invalid
// redeclaration"; usar a do Alma exigiria desembrulhar opcional em ~60 lugares.
// O módulo Corpo passa a ter o próprio helper, com nome distinto.
extension Color {
    /// Cor adaptável a claro/escuro a partir de dois hex (uso interno do Corpo).
    init(light: String, dark: String) {
        self = Color(UIColor { trait in
            UIColor(Color.corpoHex(trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// Hex -> Color, não-failable (equivalente ao init original do Corpo & Alma).
    static func corpoHex(_ hex: String) -> Color {
        let s = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgb: UInt64 = 0
        s.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Estilos reutilizáveis

extension View {
    /// Aparência padrão de "card" do app.
    func cardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}
