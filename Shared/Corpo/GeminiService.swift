//
//  GeminiService.swift
//  Corpo & Alma
//
//  Serviço de IA para scan de comida e análise corporal via Google Gemini Flash.
//  API key gratuita: ai.google.dev → Get API key → Create API key
//  Coloque a key em GoogleService-Info.plist com a chave "GEMINI_API_KEY"
//

import Foundation
import UIKit

// MARK: - Chave de API

enum GeminiConfig {
    static var apiKey: String {
        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let key  = dict["GEMINI_API_KEY"] as? String,
            !key.isEmpty
        else { return "" }
        return key
    }

    static var isAvailable: Bool { !apiKey.isEmpty }
}

// MARK: - Erros

enum GeminiError: LocalizedError {
    case missingKey
    case badResponse(Int)
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .missingKey:         return "API key do Gemini não configurada."
        case .badResponse(let c): return "Erro da API (\(c)). Tente novamente."
        case .parsingFailed:      return "Não foi possível interpretar a resposta da IA."
        }
    }
}

// MARK: - Resposta Gemini

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]
        }
        let content: Content?
    }
    let candidates: [Candidate]?

    var firstText: String? {
        candidates?.first?.content?.parts.compactMap(\.text).joined()
    }
}

// MARK: - Chamada base

enum GeminiService {
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    /// Envia texto + imagem(ns) opcional(is) e retorna o texto da resposta.
    static func generate(prompt: String, images: [Data] = []) async throws -> String {
        guard GeminiConfig.isAvailable else { throw GeminiError.missingKey }

        let url = URL(string: "\(endpoint)?key=\(GeminiConfig.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var parts: [[String: Any]] = images.map { img in
            ["inline_data": ["mime_type": "image/jpeg",
                             "data": img.base64EncodedString()]]
        }
        parts.append(["text": prompt])

        let body: [String: Any] = ["contents": [["parts": parts]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GeminiError.badResponse(http.statusCode)
        }
        let parsed = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = parsed.firstText else { throw GeminiError.parsingFailed }
        return text
    }

    // MARK: - Scan de comida

    /// Analisa uma imagem de alimento e retorna dados nutricionais estimados.
    static func analyzeFood(imageData: Data) async throws -> FoodScanResult {
        let prompt = """
        Analise esta imagem de comida. Identifique o alimento principal visível.
        Se for um produto industrializado com embalagem/rótulo visível, identifique também a marca/fabricante.
        Responda APENAS com JSON puro, sem explicações, sem blocos de código, sem texto antes ou depois:
        {"name":"nome do alimento em português","brand":"marca/fabricante ou null se não visível","description":"descrição breve em português (máx 60 caracteres)","kcalPer100":NÚMERO_INTEIRO,"proteinPer100":NÚMERO_INTEIRO,"carbsPer100":NÚMERO_INTEIRO,"fatPer100":NÚMERO_INTEIRO}
        Use valores nutricionais REAIS por 100g. Se não conseguir identificar, use {"name":"Alimento não identificado","brand":null,"description":"Não foi possível identificar o alimento","kcalPer100":0,"proteinPer100":0,"carbsPer100":0,"fatPer100":0}
        """

        let raw = try await generate(prompt: prompt, images: [imageData])
        return try parseFoodResult(raw)
    }

    private static func parseFoodResult(_ raw: String) throws -> FoodScanResult {
        // Extrai JSON mesmo se vier com texto ao redor
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { throw GeminiError.parsingFailed }

        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw GeminiError.parsingFailed }

        let name    = obj["name"]          as? String ?? "Alimento"
        let brand   = obj["brand"]         as? String   // null do JSON vira nil
        let desc    = obj["description"]   as? String ?? ""
        let kcal    = (obj["kcalPer100"]   as? Int) ?? (obj["kcalPer100"]   as? Double).map(Int.init) ?? 0
        let protein = (obj["proteinPer100"] as? Int) ?? (obj["proteinPer100"] as? Double).map(Int.init) ?? 0
        let carbs   = (obj["carbsPer100"]  as? Int) ?? (obj["carbsPer100"]  as? Double).map(Int.init) ?? 0
        let fat     = (obj["fatPer100"]    as? Int) ?? (obj["fatPer100"]    as? Double).map(Int.init) ?? 0

        return FoodScanResult(name: name, brand: brand, description: desc,
                              kcalPer100: kcal, proteinPer100: protein,
                              carbsPer100: carbs, fatPer100: fat)
    }

    // MARK: - Análise corporal

    /// Analisa fotos corporais + medidas e gera plano personalizado.
    static func analyzeBody(input: ScanInput) async throws -> ScanResult {
        let prompt = """
        Você é um personal trainer e nutricionista especializado em análise corporal.

        DADOS DO USUÁRIO:
        - Peso: \(String(format: "%.1f", input.weightKg)) kg
        - Altura: \(String(format: "%.0f", input.heightCm)) cm
        - Idade: \(input.ageYears) anos
        - % Gordura estimado: \(String(format: "%.1f", input.bodyFat))%
        - Objetivo: \(input.goal)

        Com base nas fotos (frente e lado) e nos dados acima, analise a composição corporal e crie um plano.

        Responda APENAS com JSON puro (sem blocos de código, sem texto):
        {
          "analysis": {
            "somatotype": "Ectomorfo" ou "Mesomorfo" ou "Endomorfo",
            "estimatedBodyFat": NÚMERO,
            "summary": "parágrafo de 2-3 linhas em português",
            "observations": ["observação 1", "observação 2", "observação 3"],
            "focusAreas": ["área 1", "área 2", "área 3"]
          },
          "plan": {
            "dailyKcal": NÚMERO,
            "proteinG": NÚMERO,
            "carbsG": NÚMERO,
            "fatG": NÚMERO,
            "meals": [
              {"type":"Café da manhã","title":"título","kcal":NÚMERO,"items":["item1","item2","item3"]},
              {"type":"Almoço","title":"título","kcal":NÚMERO,"items":["item1","item2","item3"]},
              {"type":"Lanche","title":"título","kcal":NÚMERO,"items":["item1","item2"]},
              {"type":"Jantar","title":"título","kcal":NÚMERO,"items":["item1","item2","item3"]}
            ],
            "week": [
              {"day":"Segunda","focus":"foco do dia","exercises":["ex1","ex2","ex3","ex4"]},
              {"day":"Terça","focus":"foco do dia","exercises":["ex1","ex2","ex3"]},
              {"day":"Quarta","focus":"foco do dia","exercises":["ex1","ex2","ex3","ex4"]},
              {"day":"Quinta","focus":"foco do dia","exercises":["ex1","ex2","ex3"]},
              {"day":"Sexta","focus":"foco do dia","exercises":["ex1","ex2","ex3","ex4"]},
              {"day":"Sábado","focus":"foco do dia","exercises":["ex1","ex2"]},
              {"day":"Domingo","focus":"Descanso","exercises":["Recuperação"]}
            ],
            "notes": "nota final curta"
          }
        }
        """

        var images: [Data] = []
        if let f = input.frontPhoto { images.append(f) }
        if let s = input.sidePhoto  { images.append(s) }

        let raw = try await generate(prompt: prompt, images: images)
        return try parseBodyResult(raw)
    }

    private static func parseBodyResult(_ raw: String) throws -> ScanResult {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { throw GeminiError.parsingFailed }

        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8) else { throw GeminiError.parsingFailed }

        struct GeminiScanResult: Decodable {
            struct GAnalysis: Decodable {
                let somatotype: String
                let estimatedBodyFat: Double
                let summary: String
                let observations: [String]
                let focusAreas: [String]
            }
            struct GMeal: Decodable {
                let type: String
                let title: String
                let kcal: Int
                let items: [String]
            }
            struct GDay: Decodable {
                let day: String
                let focus: String
                let exercises: [String]
            }
            struct GPlan: Decodable {
                let dailyKcal: Int
                let proteinG: Int
                let carbsG: Int
                let fatG: Int
                let meals: [GMeal]
                let week: [GDay]
                let notes: String
            }
            let analysis: GAnalysis
            let plan: GPlan
        }

        let decoded = try JSONDecoder().decode(GeminiScanResult.self, from: data)
        let soma = Somatotype(rawValue: decoded.analysis.somatotype) ?? .mesomorfo
        let analysis = BodyAnalysis(
            somatotype: soma,
            estimatedBodyFat: decoded.analysis.estimatedBodyFat,
            summary: decoded.analysis.summary,
            observations: decoded.analysis.observations,
            focusAreas: decoded.analysis.focusAreas
        )
        let plan = GeneratedPlan(
            dailyKcal: decoded.plan.dailyKcal,
            proteinG: decoded.plan.proteinG,
            carbsG: decoded.plan.carbsG,
            fatG: decoded.plan.fatG,
            meals: decoded.plan.meals.map { PlannedMeal(type: $0.type, title: $0.title, kcal: $0.kcal, items: $0.items) },
            week: decoded.plan.week.map { PlannedDay(day: $0.day, focus: $0.focus, exercises: $0.exercises) },
            notes: decoded.plan.notes
        )
        return ScanResult(analysis: analysis, plan: plan, isAIGenerated: true)
    }
}
