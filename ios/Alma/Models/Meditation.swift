import SwiftUI

struct Meditation: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let duration: Int // seconds
    let category: Category
    let description: String
    let gradientColors: [Color]

    var formattedDuration: String { "\(duration / 60) min" }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Category

    enum Category: String, CaseIterable {
        case all       = "Todos"
        case morning   = "Manhã"
        case focus     = "Foco"
        case sleep     = "Sono"
        case anxiety   = "Ansiedade"
        case gratitude = "Gratidão"

        var icon: String {
            switch self {
            case .all:       return "square.grid.2x2"
            case .morning:   return "sunrise.fill"
            case .focus:     return "brain.head.profile"
            case .sleep:     return "moon.stars.fill"
            case .anxiety:   return "heart.fill"
            case .gratitude: return "sun.max.fill"
            }
        }

        var emoji: String {
            switch self {
            case .all:       return "🔮"
            case .morning:   return "🌅"
            case .focus:     return "🧠"
            case .sleep:     return "🌙"
            case .anxiety:   return "💙"
            case .gratitude: return "☀️"
            }
        }
    }

    // MARK: - Sample Data

    static let all: [Meditation] = [
        Meditation(
            title: "Respiração Consciente",
            subtitle: "Para começar o dia",
            duration: 600,
            category: .morning,
            description: "Desperte sua consciência com esta meditação suave. Foque na respiração e prepare a mente para um dia incrível.",
            gradientColors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 0.9, green: 0.38, blue: 0.1)]
        ),
        Meditation(
            title: "Foco Profundo",
            subtitle: "Clareza mental",
            duration: 900,
            category: .focus,
            description: "Desenvolva concentração e clareza mental para maximizar sua produtividade e criatividade.",
            gradientColors: [Color(red: 0.15, green: 0.4, blue: 0.9), Color(red: 0.3, green: 0.55, blue: 1.0)]
        ),
        Meditation(
            title: "Sono Tranquilo",
            subtitle: "Para uma boa noite",
            duration: 1200,
            category: .sleep,
            description: "Relaxe completamente e prepare-se para um sono profundo e verdadeiramente restaurador.",
            gradientColors: [Color(red: 0.3, green: 0.1, blue: 0.7), Color(red: 0.5, green: 0.2, blue: 0.9)]
        ),
        Meditation(
            title: "Alívio da Ansiedade",
            subtitle: "Calme a mente",
            duration: 600,
            category: .anxiety,
            description: "Técnicas comprovadas para reduzir a ansiedade e restaurar a paz interior em poucos minutos.",
            gradientColors: [Color(red: 0.8, green: 0.2, blue: 0.5), Color(red: 1.0, green: 0.4, blue: 0.6)]
        ),
        Meditation(
            title: "Gratidão Diária",
            subtitle: "Cultive a positividade",
            duration: 480,
            category: .gratitude,
            description: "Pratique a gratidão e transforme sua perspectiva de vida com este exercício poderoso.",
            gradientColors: [Color(red: 0.95, green: 0.7, blue: 0.1), Color(red: 1.0, green: 0.55, blue: 0.0)]
        ),
        Meditation(
            title: "Escaneamento Corporal",
            subtitle: "Liberte a tensão",
            duration: 900,
            category: .focus,
            description: "Uma jornada de atenção pelo seu corpo para liberar tensão acumulada e restaurar o equilíbrio.",
            gradientColors: [Color(red: 0.1, green: 0.6, blue: 0.7), Color(red: 0.15, green: 0.75, blue: 0.8)]
        ),
        Meditation(
            title: "Meditação Noturna",
            subtitle: "Relaxamento profundo",
            duration: 1800,
            category: .sleep,
            description: "Desligue o dia e entre em um estado de relaxamento profundo antes de dormir.",
            gradientColors: [Color(red: 0.1, green: 0.05, blue: 0.4), Color(red: 0.3, green: 0.1, blue: 0.6)]
        ),
        Meditation(
            title: "Respiração 4-7-8",
            subtitle: "Anti-ansiedade",
            duration: 480,
            category: .anxiety,
            description: "Técnica de respiração cientificamente comprovada para acalmar o sistema nervoso em segundos.",
            gradientColors: [Color.almaDark, Color.almaPrimary]
        ),
    ]
}
