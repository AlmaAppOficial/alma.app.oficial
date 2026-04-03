import Foundation
import FirebaseAnalytics

// MARK: - Data Models
struct UserPricingProfile {
    let sessionCount: Int
    let streakDays: Int
    let currentMood: String? // e.g., "ansioso", "estressado", "calmo"
    let onboardingUrgency: OnboardingUrgency
    let timeOfDay: Int // 0-23 hour
    let daysUsingApp: Int

    /// Calculate urgency score (0.0 to 1.0)
    var urgencyScore: Double {
        var score = 0.0

        // Onboarding urgency weighted highest
        switch onboardingUrgency {
        case .grave: score += 0.4
        case .moderate: score += 0.25
        case .mild: score += 0.1
        }

        // Time of day (late night = higher urgency for anxiety)
        if timeOfDay >= 22 || timeOfDay <= 4 {
            score += 0.2
        }

        // Current mood
        if let mood = currentMood {
            if mood == "ansioso" || mood == "estressado" {
                score += 0.2
            }
        }

        // Session count (earlier in journey = higher urgency)
        if sessionCount < 3 {
            score += 0.1
        }

        return min(score, 1.0)
    }

    /// Calculate investment score based on streak and consistency
    var investmentScore: Double {
        if streakDays >= 30 {
            return 0.9
        } else if streakDays >= 14 {
            return 0.7
        } else if streakDays >= 7 {
            return 0.5
        } else if daysUsingApp >= 7 {
            return 0.3
        }
        return 0.0
    }
}

enum OnboardingUrgency: String, Codable {
    case grave = "grave"
    case moderate = "moderate"
    case mild = "mild"
}

enum PricingVariant: String, Codable {
    case control = "control"
    case urgency = "urgency"
    case streak = "streak"
    case founder = "founder"
}

struct PricingOffer: Identifiable, Codable {
    let id: String
    let variant: PricingVariant
    let title: String
    let subtitle: String
    let price: Double
    let period: String
    let discountPercent: Int?
    let cta: String
    let description: String
    let includedFeatures: [String]
    let socialProof: String?
    let urgencyText: String?
    let countdown: Int? // days remaining for founder offer
    let backgroundColor: String // hex color
    let accentColor: String // hex color

    // Experimental: emoji or visual indicator
    let badge: String?

    init(
        variant: PricingVariant,
        title: String,
        subtitle: String,
        price: Double,
        period: String,
        discountPercent: Int? = nil,
        cta: String,
        description: String,
        includedFeatures: [String],
        socialProof: String? = nil,
        urgencyText: String? = nil,
        countdown: Int? = nil,
        backgroundColor: String = "#7c5cbf",
        accentColor: String = "#d4af37",
        badge: String? = nil
    ) {
        self.id = UUID().uuidString
        self.variant = variant
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.period = period
        self.discountPercent = discountPercent
        self.cta = cta
        self.description = description
        self.includedFeatures = includedFeatures
        self.socialProof = socialProof
        self.urgencyText = urgencyText
        self.countdown = countdown
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.badge = badge
    }
}

struct ConversionEvent: Codable {
    let offerId: String
    let variant: PricingVariant
    let timestamp: Date
    let converted: Bool
    let sessionCount: Int
    let streakDays: Int
    let urgencyScore: Double
}

// MARK: - Dynamic Pricing Manager Actor
actor DynamicPricingManager {
    static let shared = DynamicPricingManager()

    private var conversionHistory: [ConversionEvent] = []
    private var abTestAssignments: [String: PricingVariant] = [:]
    private let userDefaults = UserDefaults.standard

    private let conversionsKey = "alma_pricing_conversions"
    private let abTestKey = "alma_pricing_ab_test"

    init() {
        loadConversionHistory()
        loadABTestAssignments()
    }

    // MARK: - Main Logic
    func recommendOffer(userProfile: UserPricingProfile) async -> PricingOffer {
        // Get or assign A/B test variant
        let variant = await getABTestVariant()

        // Generate appropriate offer based on variant and user profile
        return generateOffer(variant: variant, userProfile: userProfile)
    }

    private func generateOffer(variant: PricingVariant, userProfile: UserPricingProfile) -> PricingOffer {
        switch variant {
        case .urgency:
            return generateUrgencyOffer(userProfile: userProfile)
        case .streak:
            return generateStreakOffer(userProfile: userProfile)
        case .founder:
            return generateFounderOffer()
        case .control:
            return generateStandardOffer()
        }
    }

    // MARK: - Offer Generators
    private func generateUrgencyOffer(userProfile: UserPricingProfile) -> PricingOffer {
        let urgencyScore = userProfile.urgencyScore

        // High urgency → more aggressive messaging
        if urgencyScore > 0.6 {
            return PricingOffer(
                variant: .urgency,
                title: "Sua paz começa hoje",
                subtitle: "Acesso completo ao Alma",
                price: 24.99,
                period: "/mês",
                cta: "Iniciar 7 dias grátis",
                description: "7 dias de acesso total, depois R$ 24,99/mês. Cancele quando quiser.",
                includedFeatures: [
                    "500+ meditações guiadas",
                    "Sons ambientes relaxantes",
                    "Exercícios de respiração",
                    "Insights de humor diário",
                    "Suporte prioritário"
                ],
                socialProof: "4.8 ★ · 2.400 avaliações",
                urgencyText: "⏰ Milhares já encontraram paz com o Alma",
                backgroundColor: "#7c5cbf",
                accentColor: "#ff6b6b",
                badge: "🎯"
            )
        } else {
            return generateStandardOffer()
        }
    }

    private func generateStreakOffer(userProfile: UserPricingProfile) -> PricingOffer {
        if userProfile.streakDays >= 7 && userProfile.streakDays < 30 {
            return PricingOffer(
                variant: .streak,
                title: "Você é dedicado!",
                subtitle: "40% de desconto para quem não desiste",
                price: 14.99,
                period: "/mês",
                discountPercent: 40,
                cta: "Desbloquear desconto",
                description: "Você já meditou \(userProfile.streakDays) dias seguidos! Merece um desconto especial.",
                includedFeatures: [
                    "500+ meditações guiadas",
                    "Sons ambientes relaxantes",
                    "Exercícios de respiração",
                    "Insights de humor diário",
                    "Suporte prioritário"
                ],
                socialProof: "4.8 ★ · 2.400 avaliações",
                urgencyText: "🔥 Apenas para usuários ativos",
                backgroundColor: "#7c5cbf",
                accentColor: "#f0ad4e",
                badge: "🔥"
            )
        } else if userProfile.streakDays >= 30 {
            return PricingOffer(
                variant: .streak,
                title: "Mestre em meditação",
                subtitle: "50% de desconto para dedicados",
                price: 12.49,
                period: "/mês",
                discountPercent: 50,
                cta: "Desbloquear desconto master",
                description: "Você é um exemplo de consistência. Aqui está um desconto que merece.",
                includedFeatures: [
                    "500+ meditações guiadas",
                    "Sons ambientes relaxantes",
                    "Exercícios de respiração",
                    "Insights de humor diário",
                    "Suporte prioritário",
                    "Acesso antecipado a conteúdo novo"
                ],
                socialProof: "4.8 ★ · 2.400 avaliações",
                urgencyText: "👑 Apenas para mestres de meditação",
                backgroundColor: "#7c5cbf",
                accentColor: "#d4af37",
                badge: "👑"
            )
        } else {
            return generateStandardOffer()
        }
    }

    private func generateFounderOffer() -> PricingOffer {
        // Calculate remaining days (assuming 50 total slots over 30 days)
        let maxDays = 30
        let daysElapsed = Calendar.current.dayOfYear(Date()) % maxDays
        let daysRemaining = max(0, maxDays - daysElapsed)

        return PricingOffer(
            variant: .founder,
            title: "50 Vagas — Acesso vitalício",
            subtitle: "Apenas R$ 399 para sempre",
            price: 399.00,
            period: "única",
            cta: "Ativar acesso vitalício",
            description: "Última chance: oferta limitada apenas para 50 primeiros usuários.",
            includedFeatures: [
                "500+ meditações (atualizadas para sempre)",
                "Sons ambientes ilimitados",
                "Novos conteúdos gratuitos (vitalício)",
                "Suporte prioritário",
                "Seu nome nos créditos do app"
            ],
            socialProof: "Apenas \(50 - min(50, daysRemaining)) vagas restantes",
            urgencyText: "⚡ \(daysRemaining) dias até encerrar",
            countdown: daysRemaining,
            backgroundColor: "#d4af37",
            accentColor: "#7c5cbf",
            badge: "💎"
        )
    }

    private func generateStandardOffer() -> PricingOffer {
        return PricingOffer(
            variant: .control,
            title: "Comece sua jornada",
            subtitle: "7 dias grátis para explorar",
            price: 24.99,
            period: "/mês",
            cta: "Iniciar 7 dias grátis",
            description: "Acesso completo por 7 dias, depois R$ 24,99/mês. Cancele quando quiser.",
            includedFeatures: [
                "500+ meditações guiadas",
                "Sons ambientes relaxantes",
                "Exercícios de respiração",
                "Insights de humor diário",
                "Suporte por email"
            ],
            socialProof: "4.8 ★ · 2.400 avaliações",
            backgroundColor: "#7c5cbf",
            accentColor: "#5c9cff",
            badge: "✨"
        )
    }

    // MARK: - A/B Testing
    func getABTestVariant() async -> PricingVariant {
        if let userId = getCurrentUserId() {
            if let assigned = abTestAssignments[userId] {
                return assigned
            }

            // Assign new variant (deterministic hash-based)
            let variant = determineVariant(for: userId)
            abTestAssignments[userId] = variant
            saveABTestAssignments()

            // Log A/B test assignment
            let params: [String: Any] = [
                "ab_test_variant": variant.rawValue,
                "timestamp": Date().timeIntervalSince1970
            ]
            Analytics.logEvent("paywall_variant_assigned", parameters: params)

            return variant
        }

        return .control
    }

    private func determineVariant(for userId: String) -> PricingVariant {
        // Hash-based deterministic assignment (consistent across sessions)
        let hash = userId.hashValue
        let distribution = abs(hash) % 100

        switch distribution {
        case 0..<25:
            return .urgency
        case 25..<50:
            return .streak
        case 50..<60:
            return .founder
        default:
            return .control
        }
    }

    // MARK: - Conversion Tracking
    func recordConversion(offer: PricingOffer, converted: Bool, userProfile: UserPricingProfile) async {
        let event = ConversionEvent(
            offerId: offer.id,
            variant: offer.variant,
            timestamp: Date(),
            converted: converted,
            sessionCount: userProfile.sessionCount,
            streakDays: userProfile.streakDays,
            urgencyScore: userProfile.urgencyScore
        )

        conversionHistory.append(event)
        saveConversionHistory()

        // Log to Firebase Analytics
        let params: [String: Any] = [
            "offer_id": offer.id,
            "variant": offer.variant.rawValue,
            "converted": converted,
            "session_count": userProfile.sessionCount,
            "streak_days": userProfile.streakDays,
            "urgency_score": userProfile.urgencyScore
        ]

        Analytics.logEvent(
            converted ? "subscription_started" : "paywall_dismissed",
            parameters: params
        )
    }

    func recordPaywallShown(offer: PricingOffer) async {
        let params: [String: Any] = [
            "offer_id": offer.id,
            "variant": offer.variant.rawValue
        ]
        Analytics.logEvent("paywall_shown", parameters: params)
    }

    // MARK: - Analytics
    func getConversionRate(variant: PricingVariant) async -> Double? {
        let eventsForVariant = conversionHistory.filter { $0.variant == variant }
        guard eventsForVariant.count > 0 else { return nil }

        let conversions = eventsForVariant.filter { $0.converted }.count
        return Double(conversions) / Double(eventsForVariant.count)
    }

    func getVariantPerformance() async -> [PricingVariant: Double] {
        var performance: [PricingVariant: Double] = [:]

        for variant in [PricingVariant.control, .urgency, .streak, .founder] {
            if let rate = await getConversionRate(variant: variant) {
                performance[variant] = rate
            }
        }

        return performance
    }

    // MARK: - Persistence
    private func loadConversionHistory() {
        if let data = userDefaults.data(forKey: conversionsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                conversionHistory = try decoder.decode([ConversionEvent].self, from: data)
            } catch {
                print("Failed to load conversion history: \(error)")
            }
        }
    }

    private func saveConversionHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversionHistory)
            userDefaults.set(data, forKey: conversionsKey)
        } catch {
            print("Failed to save conversion history: \(error)")
        }
    }

    private func loadABTestAssignments() {
        if let data = userDefaults.data(forKey: abTestKey) {
            do {
                let decoded = try JSONDecoder().decode([String: String].self, from: data)
                abTestAssignments = decoded.compactMapValues { PricingVariant(rawValue: $0) }
            } catch {
                print("Failed to load A/B test assignments: \(error)")
            }
        }
    }

    private func saveABTestAssignments() {
        do {
            let encoded = abTestAssignments.mapValues { $0.rawValue }
            let data = try JSONEncoder().encode(encoded)
            userDefaults.set(data, forKey: abTestKey)
        } catch {
            print("Failed to save A/B test assignments: \(error)")
        }
    }

    private func getCurrentUserId() -> String? {
        // In a real app, get from Firebase Auth
        return userDefaults.string(forKey: "alma_user_id") ?? UUID().uuidString
    }
}

// MARK: - Helper Extension
extension Calendar {
    func dayOfYear(_ date: Date) -> Int {
        let components = dateComponents([.day], from: startOfYear(date), to: date)
        return (components.day ?? 0) + 1
    }

    private func startOfYear(_ date: Date) -> Date {
        guard let startOfYear = dateComponents([.year], from: date).date else {
            return date
        }
        return startOfYear
    }
}
