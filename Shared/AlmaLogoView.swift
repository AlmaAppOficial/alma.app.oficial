// AlmaLogoView.swift
// Alma App — Componente reutilizável da logo real (imagem de ficheiro)
//
// COMO USAR:
//   AlmaLogoView(size: 120)             // onboarding / login
//   AlmaLogoView(size: 180)             // splash
//   AlmaLogoView(size: 80)              // paywall
//   AlmaLogoView(size: 40, padded: true) // navbar / header home
//
// NOTA: Requer AlmaLogo.imageset em Assets.xcassets com AlmaLogo.jpg

import SwiftUI

struct AlmaLogoView: View {
    var size: CGFloat = 80
    /// Se true, aplica canto arredondado (útil em contextos claros ou de destaque)
    var padded: Bool = false
    /// Animação de entrada (fade-in suave)
    var animated: Bool = false

    @State private var opacity: Double = 0

    var body: some View {
        Image("AlmaLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .opacity(animated ? opacity : 1)
            .onAppear {
                if animated {
                    withAnimation(.easeIn(duration: 0.6)) {
                        opacity = 1
                    }
                }
            }
            .accessibilityLabel("Alma — Saúde Mental & Clareza")
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
        VStack(spacing: 32) {
            Text("Splash (180pt)").foregroundColor(.white).font(.caption)
            AlmaLogoView(size: 180, animated: true)

            Text("Onboarding / Login (120pt)").foregroundColor(.white).font(.caption)
            AlmaLogoView(size: 120)

            Text("Paywall (80pt)").foregroundColor(.white).font(.caption)
            AlmaLogoView(size: 80)

            Text("Header Home (40pt)").foregroundColor(.white).font(.caption)
            AlmaLogoView(size: 40)
        }
        .padding()
    }
}
