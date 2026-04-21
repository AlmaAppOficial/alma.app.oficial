import SwiftUI

struct InsightShareCardView: View {
    let quote: String

    var body: some View {
        ZStack {
            CalmTheme.heroGradient

            VStack(spacing: 0) {
                AlmaLogoView(size: 48)
                    .opacity(0.55)
                    .padding(.top, 80)

                Spacer()

                VStack(spacing: 20) {
                    Text("\u{201C}")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundColor(.white.opacity(0.35))

                    Text(quote)
                        .font(.system(size: 36, weight: .light, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 72)

                    Text("\u{201D}")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                Text("alma")
                    .font(.system(size: 22, weight: .ultraLight, design: .default))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(6)
                    .padding(.bottom, 80)
            }
        }
    }
}
