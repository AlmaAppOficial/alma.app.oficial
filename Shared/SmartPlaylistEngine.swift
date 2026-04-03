import Foundation

// MARK: - BinauralTrack
struct BinauralTrack: Identifiable {
    let id = UUID()
    let name: String
    let frequencyHz: Double
    let category: Category
    let description: String

    enum Category: String {
        case delta = "Delta"
        case theta = "Theta"
        case alpha = "Alpha"
        case beta  = "Beta"
        case gamma = "Gamma"
    }
}

// MARK: - SmartPlaylistEngine
enum SmartPlaylistEngine {

    static let library: [BinauralTrack] = [
        BinauralTrack(name: "Sono Profundo",       frequencyHz: 2,  category: .delta, description: "Relaxamento profundo e sono reparador"),
        BinauralTrack(name: "Descanso Noturno",    frequencyHz: 3,  category: .delta, description: "Ideal para adormecer rapidamente"),
        BinauralTrack(name: "Meditacao Guiada",    frequencyHz: 5,  category: .theta, description: "Estado meditativo profundo"),
        BinauralTrack(name: "Criatividade",        frequencyHz: 6,  category: .theta, description: "Estimula a criatividade e intuicao"),
        BinauralTrack(name: "Relaxamento Leve",    frequencyHz: 10, category: .alpha, description: "Calma e presenca no momento"),
        BinauralTrack(name: "Equilibrio Interior", frequencyHz: 11, category: .alpha, description: "Harmonia mente-corpo"),
        BinauralTrack(name: "Foco Produtivo",      frequencyHz: 18, category: .beta,  description: "Concentracao e produtividade"),
        BinauralTrack(name: "Energia Matinal",     frequencyHz: 20, category: .beta,  description: "Despertar e disposicao"),
        BinauralTrack(name: "Clareza Mental",      frequencyHz: 40, category: .gamma, description: "Maximo processamento cognitivo"),
    ]

    /// Generates a playlist based on biometric data
    static func generate(stressLevel: StressLevel, sleepHours: Double, heartRate: Double) -> [BinauralTrack] {
        var picks: [BinauralTrack] = []

        switch stressLevel {
        case .high:
            picks += library.filter { $0.category == .delta || $0.category == .theta }
        case .moderate:
            picks += library.filter { $0.category == .alpha || $0.category == .theta }
        case .low:
            picks += library.filter { $0.category == .alpha || $0.category == .beta }
        }

        if sleepHours < 6 && sleepHours > 0 {
            picks += library.filter { $0.category == .delta }
        }

        if heartRate > 90 {
            picks += library.filter { $0.category == .theta }
        }

        // Remove duplicates and limit to 4
        var seen = Set<String>()
        var unique: [BinauralTrack] = []
        for track in picks {
            if seen.insert(track.name).inserted {
                unique.append(track)
            }
        }

        return Array(unique.prefix(4))
    }
}

// MARK: - AIProactiveManager
enum AIProactiveManager {

    static func evaluate(sleep: Double, hrv: Double, heartRate: Double) -> String {
        if sleep > 0 && sleep < 5 {
            return "Voce dormiu pouco esta noite. Tente uma sessao de relaxamento Delta para recuperar energia e reduzir o cansaco."
        }
        if hrv > 0 && hrv < 25 {
            return "Seu HRV esta baixo, indicando estresse elevado. Respire fundo e considere uma meditacao Theta para equilibrar o sistema nervoso."
        }
        if heartRate > 90 {
            return "Sua frequencia cardiaca esta acima do normal. Um exercicio de respiracao pode ajudar a acalmar o corpo e a mente."
        }
        if sleep >= 7 && hrv > 50 {
            return "Otimo trabalho! Seu sono e HRV estao excelentes. Continue assim e aproveite o dia com energia positiva."
        }
        return "Cuide-se hoje. A Alma esta aqui para ajudar voce a manter o equilibrio entre corpo e mente."
    }
}
