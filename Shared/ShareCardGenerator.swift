import SwiftUI
import FirebaseAnalytics

// MARK: - Share Card Types
enum ShareCardType {
    case streak(days: Int)
    case moodInsight(summary: MoodWeeklySummary)
    case meditationCompleted(sessionName: String, duration: Int)
    case dailyQuote(quote: String)
}

struct MoodWeeklySummary {
    let calmDays: Int
    let focusDays: Int
    let restDays: Int
    let moodEmojis: [String]

    var totalDays: Int { calmDays + focusDays + restDays }
}

// MARK: - Meditation Quote Library
let meditationQuotes: [String] = [
    "A mente é tudo. O que você pensa, você se torna. 🌬️",
    "O presente é um presente. Viva nele. ✨",
    "Você não precisa encontrar a paz. Ela já está em você. 🧘",
    "Cada respiração é uma chance de começar de novo. 🌿",
    "Serenidade não é a ausência de tempestade, é paz durante ela. ☀️",
    "Meditação é como exercício para a mente. Pratique a calma. 💜",
    "Aquietar a mente é o primeiro passo para conhecer o coração. 💎",
    "Você é o escultor de sua própria mente. Molde com cuidado. 🎨",
    "Ser presente é ser inteiro. Viva aqui, agora. ⏰",
    "A paz vem de dentro. Não procure fora, procure dentro. 🌊"
]

// MARK: - Share Card Generator
actor ShareCardGenerator {
    static let shared = ShareCardGenerator()

    private let userDefaults = UserDefaults.standard

    /// Generate a SwiftUI view for the share card
    func generateShareCard(type: ShareCardType) -> some View {
        Group {
            switch type {
            case .streak(let days):
                StreakShareCard(days: days)
            case .moodInsight(let summary):
                MoodInsightShareCard(summary: summary)
            case .meditationCompleted(let name, let duration):
                MeditationCompletedShareCard(sessionName: name, duration: duration)
            case .dailyQuote(let quote):
                DailyQuoteShareCard(quote: quote)
            }
        }
    }

    /// Render card as UIImage for sharing
    func renderCardAsImage(type: ShareCardType) async -> UIImage? {
        let view = generateShareCard(type: type)
            .frame(width: 1080, height: 1920) // Instagram story dimension
            .background(CalmTheme.background)

        let controller = UIHostingController(rootViewController: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1080, height: 1920))
        window.rootViewController = controller
        window.makeKeyAndVisible()

        // Render using ImageRenderer (iOS 16+)
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = UIScreen.main.scale
            return renderer.uiImage
        } else {
            // Fallback for earlier iOS versions
            let snapshot = view.snapshot()
            return snapshot
        }
    }

    /// Share card via UIActivityViewController
    func shareCard(type: ShareCardType, from viewController: UIViewController) async {
        guard let image = await renderCardAsImage(type: type) else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [image, "Confira minha jornada com Alma 🧘 https://alma.app"],
            applicationActivities: nil
        )

        // Exclude activities
        activityViewController.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInMaps,
            .print
        ]

        viewController.present(activityViewController, animated: true)

        // Track share
        await recordCardShare(type: type)
    }

    // MARK: - Analytics
    func recordCardShown(type: ShareCardType) async {
        let typeString = cardTypeString(type)
        let params: [String: Any] = [
            "share_card_type": typeString,
            "timestamp": Date().timeIntervalSince1970
        ]
        Analytics.logEvent("share_card_shown", parameters: params)
    }

    func recordCardShared(type: ShareCardType) async {
        let typeString = cardTypeString(type)
        let params: [String: Any] = [
            "share_card_type": typeString,
            "timestamp": Date().timeIntervalSince1970
        ]
        Analytics.logEvent("share_card_shared", parameters: params)
    }

    func recordCardDismissed(type: ShareCardType) async {
        let typeString = cardTypeString(type)
        let params: [String: Any] = [
            "share_card_type": typeString,
            "timestamp": Date().timeIntervalSince1970
        ]
        Analytics.logEvent("share_card_dismissed", parameters: params)
    }

    private func recordCardShare(type: ShareCardType) async {
        await recordCardShared(type: type)
    }

    private func cardTypeString(_ type: ShareCardType) -> String {
        switch type {
        case .streak:
            return "streak"
        case .moodInsight:
            return "mood_insight"
        case .meditationCompleted:
            return "meditation_completed"
        case .dailyQuote:
            return "daily_quote"
        }
    }
}

// MARK: - Streak Share Card
struct StreakShareCard: View {
    let days: Int

    var body: some View {
        VStack(spacing: 0) {
            // Top gradient section
            VStack(spacing: 32) {
                // Flame animation
                VStack(spacing: 16) {
                    Text("🔥")
                        .font(.system(size: 80))
                        .scaleEffect(1.1)

                    Text("\(days) dias")
                        .font(.system(size: 64, weight: .bold, design: .default))
                        .foregroundColor(.white)
                }

                Text("Já meditei \(days) dias seguidos com o")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding(48)
            .background(
                LinearGradient(
                    colors: [
                        CalmTheme.primary,
                        CalmTheme.primaryLight
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Spacer()

            // Alma branding
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(CalmTheme.primary)
                        .frame(width: 12, height: 12)

                    Text("@alma.meditacao")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(CalmTheme.textPrimary)
                }

                Text("alma.app")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(24)
        }
        .background(CalmTheme.background)
    }
}

// MARK: - Mood Insight Share Card
struct MoodInsightShareCard: View {
    let summary: MoodWeeklySummary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 20) {
                Text("Minha semana com Alma")
                    .font(.system(size: 36, weight: .bold, design: .default))
                    .foregroundColor(.white)

                Text("✨")
                    .font(.system(size: 56))
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(
                LinearGradient(
                    colors: [
                        CalmTheme.primary.opacity(0.9),
                        CalmTheme.primaryLight.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Spacer()

            // Mood breakdown
            VStack(spacing: 24) {
                // Mood dots
                HStack(spacing: 12) {
                    ForEach(summary.moodEmojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 44))
                            .frame(height: 56)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // Stats
                VStack(spacing: 16) {
                    StatRow(icon: "😌", label: "Calma", count: summary.calmDays)
                    StatRow(icon: "🎯", label: "Foco", count: summary.focusDays)
                    StatRow(icon: "😴", label: "Descanso", count: summary.restDays)
                }
            }
            .padding(32)

            Spacer()

            // Branding
            VStack(spacing: 8) {
                Text("@alma.meditacao")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("alma.app")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(24)
        }
        .background(CalmTheme.background)
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 24))

            Text("\(count) \(label)")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(CalmTheme.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Meditation Completed Share Card
struct MeditationCompletedShareCard: View {
    let sessionName: String
    let duration: Int

    var body: some View {
        VStack(spacing: 0) {
            // Top section
            VStack(spacing: 24) {
                Text("Acabei de meditar")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)

                Text("🧘🏻")
                    .font(.system(size: 72))

                VStack(spacing: 8) {
                    Text(sessionName)
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundColor(.white)

                    Text("\(duration) minutos")
                        .font(.system(size: 20, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .background(
                LinearGradient(
                    colors: [
                        CalmTheme.primary,
                        CalmTheme.primaryLight
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Spacer()

            // Benefits
            VStack(spacing: 16) {
                BenefitItem(icon: "heart", text: "Saúde mental")
                BenefitItem(icon: "brain", text: "Foco e clareza")
                BenefitItem(icon: "moon.stars", text: "Melhor sono")
            }
            .padding(32)

            Spacer()

            // Branding
            VStack(spacing: 8) {
                Text("@alma.meditacao")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("alma.app")
                    .font(.system(size: 14))
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(24)
        }
        .background(CalmTheme.background)
    }
}

struct BenefitItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(CalmTheme.primary)

            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(CalmTheme.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Daily Quote Share Card
struct DailyQuoteShareCard: View {
    let quote: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                Text("✨")
                    .font(.system(size: 64))

                Text(quote)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(5)
                    .multilineTextAlignment(.center)
            }
            .padding(48)
            .frame(maxWidth: .infinity)

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Text("Sabedoria do dia")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("@alma.meditacao · alma.app")
                    .font(.system(size: 14))
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    CalmTheme.primary,
                    CalmTheme.primaryLight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - View Extension for Snapshot
extension View {
    func snapshot() -> UIImage? {
        let controller = UIHostingController(rootViewController: self)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()

        let renderer = UIGraphicsImageRenderer(size: UIScreen.main.bounds.size)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ShareCards_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StreakShareCard(days: 14)
                .frame(width: 1080, height: 1920)
                .previewDisplayName("Streak Card")

            MoodInsightShareCard(
                summary: MoodWeeklySummary(
                    calmDays: 4,
                    focusDays: 2,
                    restDays: 1,
                    moodEmojis: ["😌", "😌", "🎯", "😌", "🎯", "😴", "😌"]
                )
            )
            .frame(width: 1080, height: 1920)
            .previewDisplayName("Mood Insight Card")

            MeditationCompletedShareCard(
                sessionName: "Meditação para dormir",
                duration: 10
            )
            .frame(width: 1080, height: 1920)
            .previewDisplayName("Meditation Completed Card")

            DailyQuoteShareCard(
                quote: "A mente é tudo. O que você pensa, você se torna."
            )
            .frame(width: 1080, height: 1920)
            .previewDisplayName("Daily Quote Card")
        }
    }
}
#endif
