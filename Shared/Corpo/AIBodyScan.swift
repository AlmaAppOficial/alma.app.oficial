//
//  AIBodyScan.swift
//  Corpo & Alma
//
//  Scan corporal com IA: modelos + serviço.
//
//  IMPORTANTE (segurança): a chamada ao modelo de IA (Claude com visão) deve
//  acontecer num BACKEND (ex.: Firebase Function), nunca no app — para não expor
//  chaves. O app só envia medidas + fotos e recebe o resultado já pronto.
//  Enquanto o backend não existe, `MockAIPlanService` gera um plano real offline.
//

import Foundation

// MARK: - Modelos de resultado

enum Somatotype: String, Codable {
    case ectomorfo = "Ectomorfo"
    case mesomorfo = "Mesomorfo"
    case endomorfo = "Endomorfo"

    var descricao: String {
        switch self {
        case .ectomorfo: return "Estrutura mais magra, ganha massa com mais dificuldade."
        case .mesomorfo: return "Estrutura atlética, responde bem a treino e dieta."
        case .endomorfo: return "Tende a acumular gordura, foco em déficit e constância."
        }
    }
}

struct BodyAnalysis: Codable {
    let somatotype: Somatotype
    let estimatedBodyFat: Double
    let summary: String
    let observations: [String]
    let focusAreas: [String]
}

struct PlannedMeal: Codable, Identifiable {
    var id: String { type + title }
    let type: String
    let title: String
    let kcal: Int
    let items: [String]
}

struct PlannedDay: Codable, Identifiable {
    var id: String { day }
    let day: String
    let focus: String
    let exercises: [String]
}

struct GeneratedPlan: Codable {
    let dailyKcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let meals: [PlannedMeal]
    let week: [PlannedDay]
    let notes: String
}

struct ScanResult: Codable {
    let analysis: BodyAnalysis
    let plan: GeneratedPlan
    /// [F1] true = veio de IA real (Gemini/backend); false = estimativa local por medidas.
    /// Optional para decodificar resultados salvos antes deste campo existir.
    var isAIGenerated: Bool? = nil
}

struct ScanInput {
    let weightKg: Double
    let heightCm: Double
    let ageYears: Int
    let bodyFat: Double
    let goal: String
    let frontPhoto: Data?
    let sidePhoto: Data?
}

// MARK: - Serviço

protocol AIPlanService {
    func analyze(_ input: ScanInput) async throws -> ScanResult
}

/// Fábrica: Gemini (se API key configurada) → backend remoto → estimativa local.
enum AIService {
    /// URL do backend remoto (Firebase Function). Opcional — Gemini tem prioridade.
    static let endpoint: URL? = nil

    /// [F1] true quando há IA de verdade disponível. Sem IA, a UI precisa
    /// rotular o resultado como "Estimativa por medidas" — nunca fingir análise.
    static var isRealAI: Bool { GeminiConfig.isAvailable || endpoint != nil }

    static func make() -> AIPlanService {
        if GeminiConfig.isAvailable { return GeminiAIPlanService() }
        if let endpoint { return RemoteAIPlanService(endpoint: endpoint) }
        return MockAIPlanService()
    }
}

// MARK: - Gemini AI Plan Service

/// Chama o Gemini Vision diretamente para análise corporal real por foto.
struct GeminiAIPlanService: AIPlanService {
    func analyze(_ input: ScanInput) async throws -> ScanResult {
        try await GeminiService.analyzeBody(input: input)
    }
}

// MARK: - Backend real (produção)

struct RemoteAIPlanService: AIPlanService {
    let endpoint: URL

    func analyze(_ input: ScanInput) async throws -> ScanResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "weightKg": input.weightKg,
            "heightCm": input.heightCm,
            "ageYears": input.ageYears,
            "bodyFat": input.bodyFat,
            "goal": input.goal,
            "frontPhotoBase64": input.frontPhoto?.base64EncodedString() ?? "",
            "sidePhotoBase64": input.sidePhoto?.base64EncodedString() ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ScanResult.self, from: data)
    }
}

// MARK: - Gerador offline (mock inteligente — funciona sem backend)

struct MockAIPlanService: AIPlanService {
    func analyze(_ input: ScanInput) async throws -> ScanResult {
        // Simula o tempo de processamento da IA.
        try? await Task.sleep(nanoseconds: 1_300_000_000)

        let h = input.heightCm / 100
        let bmi = input.weightKg / (h * h)

        // Somatotipo (heurística por IMC + % gordura)
        let soma: Somatotype
        if input.bodyFat >= 25 || bmi >= 27 { soma = .endomorfo }
        else if input.bodyFat <= 12 && bmi < 21 { soma = .ectomorfo }
        else { soma = .mesomorfo }

        // Gasto energético (Mifflin-St Jeor, fator de atividade moderado)
        let bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * Double(input.ageYears) + 5
        let tdee = bmr * 1.45
        let adjust: Double
        switch input.goal {
        case Goal.perder.rawValue: adjust = -450
        case Goal.ganhar.rawValue: adjust = 300
        default: adjust = 0
        }
        let kcal = max(Int((tdee + adjust).rounded()), 1300)
        let protein = Int((1.8 * input.weightKg).rounded())
        let fat = Int(((Double(kcal) * 0.25) / 9).rounded())
        let carbs = max(Int((Double(kcal - protein * 4 - fat * 9) / 4).rounded()), 0)

        // [F1] Honestidade: este gerador NÃO usa fotos nem IA — o texto não pode
        // sugerir o contrário. O resultado sai rotulado como estimativa por medidas.
        let analysis = BodyAnalysis(
            somatotype: soma,
            estimatedBodyFat: input.bodyFat,
            summary: "Estimativa calculada apenas com suas medidas (peso, altura, idade e % de gordura informados) — sem análise de fotos. Seu perfil estimado é predominantemente \(soma.rawValue.lowercased()). \(soma.descricao) O plano abaixo foi calibrado para seu objetivo de \(input.goal.lowercased()).",
            observations: observations(for: input, bmi: bmi),
            focusAreas: focusAreas(for: input.goal)
        )

        let plan = GeneratedPlan(
            dailyKcal: kcal,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            meals: meals(kcal: kcal, goal: input.goal),
            week: week(for: input.goal),
            notes: "Estimativa por medidas — gerada sem IA. Ajuste porções conforme fome e energia, e priorize comida de verdade. Reavalie a cada 2–4 semanas."
        )

        return ScanResult(analysis: analysis, plan: plan, isAIGenerated: false)
    }

    private func observations(for input: ScanInput, bmi: Double) -> [String] {
        var out: [String] = []
        out.append(String(format: "IMC atual: %.1f (%@)", bmi, imcClass(bmi)))
        if input.frontPhoto == nil || input.sidePhoto == nil {
            out.append("Para uma análise mais precisa, adicione foto de frente e de lado.")
        }
        switch input.goal {
        case Goal.perder.rawValue:
            out.append("Déficit calórico moderado para perda de gordura preservando massa magra.")
            out.append("Inclua caminhadas diárias além dos treinos.")
        case Goal.ganhar.rawValue:
            out.append("Leve superávit calórico com proteína alta para ganho de massa.")
            out.append("Foque em progressão de carga nos treinos.")
        default:
            out.append("Manutenção com foco em composição corporal e constância.")
        }
        return out
    }

    private func focusAreas(for goal: String) -> [String] {
        switch goal {
        case Goal.perder.rawValue: return ["Gordura abdominal", "Condicionamento", "Core"]
        case Goal.ganhar.rawValue: return ["Peito e costas", "Pernas", "Ombros"]
        default: return ["Postura", "Mobilidade", "Resistência"]
        }
    }

    private func imcClass(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "abaixo do peso"
        case 18.5..<25: return "saudável"
        case 25..<30: return "sobrepeso"
        default: return "obesidade"
        }
    }

    private func meals(kcal: Int, goal: String) -> [PlannedMeal] {
        let cafe = Int(Double(kcal) * 0.25)
        let almoco = Int(Double(kcal) * 0.35)
        let lanche = Int(Double(kcal) * 0.15)
        let jantar = Int(Double(kcal) * 0.25)

        let ganho = goal == Goal.ganhar.rawValue
        return [
            PlannedMeal(type: "Café da manhã", title: "Energia da manhã", kcal: cafe,
                        items: ganho ? ["Ovos mexidos (3)", "Aveia com banana", "Pão integral", "Café"]
                                     : ["Ovos mexidos (2)", "Aveia com fruta", "Café sem açúcar"]),
            PlannedMeal(type: "Almoço", title: "Prato principal", kcal: almoco,
                        items: ["Frango/peixe grelhado", "Arroz integral", "Feijão", "Salada à vontade"]),
            PlannedMeal(type: "Lanche", title: "Pré ou pós-treino", kcal: lanche,
                        items: ganho ? ["Whey + banana", "Pasta de amendoim", "Castanhas"]
                                     : ["Iogurte natural", "Fruta", "Punhado de castanhas"]),
            PlannedMeal(type: "Jantar", title: "Refeição leve", kcal: jantar,
                        items: ["Proteína magra", "Batata-doce ou legumes", "Vegetais"])
        ]
    }

    private func week(for goal: String) -> [PlannedDay] {
        if goal == Goal.perder.rawValue {
            return [
                PlannedDay(day: "Segunda", focus: "Full Body + HIIT", exercises: ["Agachamento", "Supino halteres", "Remada", "Burpees 4x30s"]),
                PlannedDay(day: "Terça", focus: "Cardio + Core", exercises: ["Caminhada 40min", "Prancha", "Abdominais"]),
                PlannedDay(day: "Quarta", focus: "Full Body", exercises: ["Levantamento terra", "Desenvolvimento", "Afundo", "Mountain climbers"]),
                PlannedDay(day: "Quinta", focus: "Descanso ativo", exercises: ["Mobilidade", "Alongamento", "Caminhada leve"]),
                PlannedDay(day: "Sexta", focus: "HIIT", exercises: ["Polichinelos", "Agachamento com salto", "Burpees", "Corrida intervalada"]),
                PlannedDay(day: "Sábado", focus: "Full Body", exercises: ["Agachamento", "Remada", "Flexão", "Prancha"]),
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Caminhada leve", "Respiração"])
            ]
        } else if goal == Goal.ganhar.rawValue {
            return [
                PlannedDay(day: "Segunda", focus: "Peito e tríceps", exercises: ["Supino reto", "Supino inclinado", "Crucifixo", "Tríceps corda"]),
                PlannedDay(day: "Terça", focus: "Costas e bíceps", exercises: ["Barra fixa", "Remada curvada", "Puxada", "Rosca direta"]),
                PlannedDay(day: "Quarta", focus: "Pernas", exercises: ["Agachamento", "Leg press", "Cadeira extensora", "Panturrilha"]),
                PlannedDay(day: "Quinta", focus: "Ombros e core", exercises: ["Desenvolvimento", "Elevação lateral", "Encolhimento", "Prancha"]),
                PlannedDay(day: "Sexta", focus: "Full Body força", exercises: ["Levantamento terra", "Supino", "Agachamento", "Remada"]),
                PlannedDay(day: "Sábado", focus: "Descanso ativo", exercises: ["Mobilidade", "Caminhada"]),
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Recuperação total"])
            ]
        } else {
            return [
                PlannedDay(day: "Segunda", focus: "Superior", exercises: ["Supino halteres", "Remada", "Desenvolvimento", "Rosca"]),
                PlannedDay(day: "Terça", focus: "Cardio", exercises: ["Corrida leve 30min", "Core"]),
                PlannedDay(day: "Quarta", focus: "Inferior", exercises: ["Agachamento", "Afundo", "Stiff", "Panturrilha"]),
                PlannedDay(day: "Quinta", focus: "Mobilidade", exercises: ["Alongamento", "Yoga", "Respiração"]),
                PlannedDay(day: "Sexta", focus: "Full Body", exercises: ["Agachamento", "Flexão", "Remada", "Prancha"]),
                PlannedDay(day: "Sábado", focus: "Atividade livre", exercises: ["Caminhada", "Esporte", "Pedalada"]),
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Recuperação"])
            ]
        }
    }
}
