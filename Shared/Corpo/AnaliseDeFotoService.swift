// AnaliseDeFotoService.swift
// Cliente da Cloud Function `analisarFoto` — análise de corpo e de comida.
//
// ═══════════════════════════════════════════════════════════════════════════
// DUAS DECISÕES DE DESENHO QUE VALE LER ANTES DE MEXER
//
// 1. A CHAVE NÃO ESTÁ AQUI. Este arquivo fala com a nossa Cloud Function, que
//    fala com a OpenAI. A implementação antiga (`GeminiService`) chamava o
//    provedor direto, com a chave no `GoogleService-Info.plist` — qualquer
//    pessoa descompactava o IPA e usava a cota. Mesmo caminho do chat:
//    URLRequest + `Bearer <Firebase ID token>`.
//
// 2. A IA LÊ A FOTO. A MATEMÁTICA DO PLANO CONTINUA NO APARELHO.
//    A versão antiga pedia ao modelo o plano inteiro — calorias, macros,
//    refeições e a semana de treino. Isso é PRESCRIÇÃO, e a regra 3.2 do
//    CLAUDE.md proíbe: a Alma acolhe e encaminha, não prescreve exercício,
//    alimento nem dieta. Além disso, número vindo de modelo de linguagem varia
//    entre chamadas — a mesma pessoa receberia metas diferentes a cada scan.
//
//    Agora a divisão é: a IA faz o que só ela faz (olhar a foto e estimar
//    composição corporal); Mifflin-St Jeor, determinístico e já testado, faz o
//    que já sabia fazer. O scan fica mais barato, mais estável e dentro da regra.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation
import FirebaseAuth

// MARK: - Erros honestos

/// Toda falha vira UMA DESTAS e chega à tela como frase. Nenhuma delas pode
/// virar número — foi exatamente esse o bug B8 (o app caía no cálculo local e
/// mostrava o resultado como se a IA tivesse analisado a foto).
enum ErroDaAnalise: LocalizedError, Equatable {
    case semSessao
    case semConsentimento
    case fotoIlegivel(String)
    case limiteDiario(String)
    case indisponivel(String)

    var errorDescription: String? {
        switch self {
        case .semSessao:
            return "Entre na sua conta para usar a análise por foto."
        case .semConsentimento:
            return "A análise só acontece depois que você autoriza o envio."
        case .fotoIlegivel(let m), .limiteDiario(let m), .indisponivel(let m):
            return m
        }
    }
}

// MARK: - Respostas do servidor

private struct RespostaCorpo: Decodable {
    let legivel: Bool
    let motivo: String?
    let somatotipo: String?
    let gorduraEstimada: Double?
    let resumo: String?
    let observacoes: [String]
    let focos: [String]
}

struct AnaliseDePrato: Decodable, Equatable {
    let nome: String
    let porcaoG: Double
    let kcalPor100: Double
    let proteinaPor100: Double
    let carboPor100: Double
    let gorduraPor100: Double
}

private struct RespostaPrato: Decodable {
    let legivel: Bool
    let motivo: String?
    let nome: String?
    let porcaoG: Double?
    let kcalPor100: Double?
    let proteinaPor100: Double?
    let carboPor100: Double?
    let gorduraPor100: Double?
}

private struct EnvelopeFalha: Decodable {
    let ok: Bool
    let motivo: String?
    let mensagem: String?
}

// MARK: - Serviço

enum AnaliseDeFotoService {

    static let endpoint = URL(string:
        "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/analisarFoto")!

    /// Redimensiona antes de enviar: menos dado saindo do aparelho, menos custo,
    /// menos tempo. 1280 px no maior lado é suficiente para o modelo.
    static let ladoMaximo: CGFloat = 1280

    // MARK: Corpo

    static func analisarCorpo(input: ScanInput, consentimento: Bool) async throws -> ScanResult {
        guard consentimento else { throw ErroDaAnalise.semConsentimento }

        var fotos: [String] = []
        if let f = input.frontPhoto { fotos.append(f.base64EncodedString()) }
        if let s = input.sidePhoto  { fotos.append(s.base64EncodedString()) }
        guard !fotos.isEmpty else {
            throw ErroDaAnalise.fotoIlegivel("Adicione ao menos uma foto para a análise.")
        }

        let medidas: [String: Any] = [
            "pesoKg": input.weightKg,
            "alturaCm": input.heightCm,
            "idade": input.ageYears,
            "objetivo": input.goal
        ]

        let dados = try await chamar(tipo: "corpo", fotos: fotos,
                                     medidas: medidas, consentimento: consentimento)
        let r = try decodificar(RespostaCorpo.self, de: dados)

        guard r.legivel, let gordura = r.gorduraEstimada else {
            throw ErroDaAnalise.fotoIlegivel(
                r.motivo ?? "Não consegui ler essa foto o suficiente para estimar.")
        }

        // A IA entrega a leitura da foto. O plano numérico sai do cálculo local,
        // agora alimentado pela gordura que a IA estimou em vez da informada.
        let comGorduraDaIA = ScanInput(
            weightKg: input.weightKg, heightCm: input.heightCm,
            ageYears: input.ageYears, bodyFat: gordura,
            goal: input.goal, frontPhoto: nil, sidePhoto: nil)
        let base = try await MockAIPlanService().analyze(comGorduraDaIA)

        let analise = BodyAnalysis(
            somatotype: Somatotype(rawValue: r.somatotipo ?? "") ?? base.analysis.somatotype,
            estimatedBodyFat: gordura,
            summary: r.resumo ?? base.analysis.summary,
            observations: r.observacoes.isEmpty ? base.analysis.observations : r.observacoes,
            focusAreas: r.focos.isEmpty ? base.analysis.focusAreas : r.focos
        )

        let plano = GeneratedPlan(
            dailyKcal: base.plan.dailyKcal, proteinG: base.plan.proteinG,
            carbsG: base.plan.carbsG, fatG: base.plan.fatG,
            meals: base.plan.meals, week: base.plan.week,
            notes: "As metas de calorias e macros são calculadas no seu aparelho "
                 + "a partir das suas medidas e da estimativa da análise. "
                 + "Ajuste conforme fome e energia, e reavalie a cada 2–4 semanas."
        )

        return ScanResult(analysis: analise, plan: plano, isAIGenerated: true)
    }

    // MARK: Comida

    static func analisarPrato(foto: Data, consentimento: Bool) async throws -> AnaliseDePrato {
        guard consentimento else { throw ErroDaAnalise.semConsentimento }

        let dados = try await chamar(tipo: "comida", fotos: [foto.base64EncodedString()],
                                     medidas: nil, consentimento: consentimento)
        let r = try decodificar(RespostaPrato.self, de: dados)

        guard r.legivel,
              let nome = r.nome, let kcal = r.kcalPor100,
              let p = r.proteinaPor100, let c = r.carboPor100, let g = r.gorduraPor100 else {
            throw ErroDaAnalise.fotoIlegivel(
                r.motivo ?? "Não consegui identificar a comida nessa foto.")
        }

        return AnaliseDePrato(nome: nome, porcaoG: r.porcaoG ?? 100,
                              kcalPor100: kcal, proteinaPor100: p,
                              carboPor100: c, gorduraPor100: g)
    }

    // MARK: Transporte

    private static func chamar(tipo: String, fotos: [String],
                               medidas: [String: Any]?, consentimento: Bool) async throws -> Data {
        guard let user = Auth.auth().currentUser else { throw ErroDaAnalise.semSessao }
        let token: String
        do { token = try await user.getIDToken() }
        catch { throw ErroDaAnalise.semSessao }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Visão é mais lenta que texto: o chat usa 30 s, aqui 90 s.
        req.timeoutInterval = 90

        var corpo: [String: Any] = ["tipo": tipo, "fotos": fotos,
                                    "consentimento": consentimento]
        if let medidas { corpo["medidas"] = medidas }
        req.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        let (data, resposta): (Data, URLResponse)
        do { (data, resposta) = try await URLSession.shared.data(for: req) }
        catch {
            throw ErroDaAnalise.indisponivel(
                "Não consegui falar com a análise agora. Verifique sua conexão e tente de novo.")
        }

        let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try? JSONDecoder().decode(EnvelopeFalha.self, from: data)

        if envelope?.ok == false || !(200..<300).contains(codigo) {
            let msg = envelope?.mensagem
                ?? "Não consegui analisar sua foto agora. Tente de novo em alguns minutos."
            switch envelope?.motivo {
            case "foto_ilegivel", "foto_nao_e_do_tipo": throw ErroDaAnalise.fotoIlegivel(msg)
            case "limite_diario":                        throw ErroDaAnalise.limiteDiario(msg)
            default:                                     throw ErroDaAnalise.indisponivel(msg)
            }
        }
        return data
    }

    private static func decodificar<T: Decodable>(_ tipo: T.Type, de dados: Data) throws -> T {
        do {
            return try JSONDecoder().decode(EnvelopeOK<T>.self, from: dados).resultado
        } catch {
            throw ErroDaAnalise.indisponivel("A análise voltou incompleta. Tente de novo.")
        }
    }
}

/// `{ "ok": true, "resultado": { … } }` — o formato que a função devolve.
/// Fora do `enum` porque Swift não aceita tipo genérico aninhado em função.
private struct EnvelopeOK<U: Decodable>: Decodable {
    let ok: Bool
    let resultado: U
}

// MARK: - Ponte com o protocolo existente

/// Substitui `GeminiAIPlanService`. Guarda o consentimento daquele envio —
/// sem ele o serviço recusa antes de tocar na rede, e o servidor recusa de novo.
struct NuvemAIPlanService: AIPlanService {
    let consentimento: Bool

    func analyze(_ input: ScanInput) async throws -> ScanResult {
        try await AnaliseDeFotoService.analisarCorpo(input: input,
                                                     consentimento: consentimento)
    }
}
