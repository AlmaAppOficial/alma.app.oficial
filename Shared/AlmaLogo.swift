import SwiftUI

// MARK: - AlmaLogo
// Delegates to AlmaLogoView (real image asset) so every screen shows the correct logo.
struct AlmaLogo: View {
    let size: CGFloat

    var body: some View {
        AlmaLogoView(size: size)
    }
}

// MARK: - Logo with Brand Text
extension AlmaLogo {
    static func brand(size: CGFloat = 80) -> some View {
        VStack(spacing: 12) {
            AlmaLogoView(size: size)

            Text("Alma")
                .font(.system(size: size * 0.4, weight: .semibold, design: .default))
                .foregroundColor(CalmTheme.textPrimary)
                .tracking(1.5)
        }
    }
}

// MARK: - Preview
struct AlmaLogo_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            HStack(spacing: 20) {
                AlmaLogo(size: 44)
                AlmaLogo(size: 60)
                AlmaLogo(size: 80)
            }
            AlmaLogo.brand(size: 100)
            Spacer()
        }
        .padding()
        .background(CalmTheme.background)
    }
}
