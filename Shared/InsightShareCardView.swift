import SwiftUI

struct InsightShareCardView: View {
    let quote: String
    let author: String?
    let containerWidth: CGFloat

    private var containerHeight: CGFloat { containerWidth * (1350.0 / 1080.0) }
    private var hPad: CGFloat           { containerWidth * 0.10 }
    private var vPad: CGFloat           { containerWidth * 0.08 }
    private var quoteSize: CGFloat      { containerWidth * 0.042 }
    private var authorSize: CGFloat     { containerWidth * 0.016 }
    private var logoDiameter: CGFloat   { containerWidth * 0.055 }
    private var decorQuoteSize: CGFloat { containerWidth * 0.14 }

    private let lilasMedium = Color(red: 0.624, green: 0.478, blue: 0.918)             // #9F7AEA
    private let lilasFaint  = Color(red: 0.624, green: 0.478, blue: 0.918).opacity(0.5)

    var body: some View {
        ZStack {
            CalmTheme.shareCardBackground

            VStack(spacing: 0) {
                Spacer(minLength: vPad * 1.5)

                // Opening quote mark — centered above text
                Text("\u{201C}")
                    .font(.system(size: decorQuoteSize, weight: .light))
                    .foregroundColor(lilasFaint)

                // Quote — New York serif via .design: .serif
                Text(quote)
                    .font(.system(size: quoteSize, weight: .light, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(quoteSize * 0.35)
                    .padding(.horizontal, hPad)

                // Closing quote mark — centered below text
                Text("\u{201D}")
                    .font(.system(size: decorQuoteSize, weight: .light))
                    .foregroundColor(lilasFaint)

                // Author line — visible when present
                if let author = author, !author.isEmpty {
                    Text("— \(author.lowercased())")
                        .font(.system(size: authorSize, weight: .regular))
                        .tracking(authorSize * 0.15)
                        .foregroundColor(lilasMedium)
                        .padding(.top, vPad * 0.5)
                }

                Spacer(minLength: vPad * 1.5)

                // Footer: circle logo + wordmark
                VStack(spacing: logoDiameter * 0.2) {
                    Image("AlmaLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoDiameter, height: logoDiameter)
                        .clipShape(Circle())

                    Text("alma")
                        .font(.system(size: logoDiameter * 0.28, weight: .ultraLight))
                        .tracking(logoDiameter * 0.22)
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.bottom, vPad * 1.0)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
    }
}
