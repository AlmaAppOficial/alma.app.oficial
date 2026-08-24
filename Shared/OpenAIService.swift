import Foundation
import FirebaseAuth

// MARK: - Limites do chat
// [Build 84 — 2026-07-28] Espelha o limite da Cloud Function `chat`
// (functions/src/index.ts, MAX_MESSAGE_CHARS). Se mudar lá, mudar aqui.
enum ChatLimits {
    /// Máximo de caracteres por mensagem aceito pelo servidor.
    static let maxMessageLength = 4000
    /// A partir de quantos caracteres o contador aparece no input.
    static let counterVisibleFrom = 3400
}

// MARK: - AlmaError
enum AlmaError: LocalizedError {
    case noUser
    case tokenFailed
    case serverError(Int)
    /// [Build 84] Erro HTTP com mensagem amigável vinda do corpo JSON do
    /// servidor (`{"error": "..."}`) — ex.: validação de mensagem muito longa.
    case serverRejected(Int, String)
    case rateLimited
    case parseFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noUser:            return "Nenhum usuário autenticado."
        case .tokenFailed:       return "Falha ao obter token de autenticacao."
        case .serverError(let c): return "Erro do servidor (\(c))."
        case .serverRejected(_, let m): return m
        case .rateLimited:       return "Limite de mensagens atingido. Tente novamente amanhã."
        case .parseFailed:       return "Resposta inesperada do servidor."
        case .networkError(let m): return "Erro de rede: \(m)"
        }
    }
}

// MARK: - OpenAIService (Singleton)
class OpenAIService {

    static let shared = OpenAIService()

    // Endpoint principal — Firebase Cloud Function
    private let cloudFunctionURL = URL(string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat")!

    // ⚠️ DESATIVADO por motivos de segurança.
    //
    // O fallback original chamava OpenAI directamente a partir do cliente, usando
    // uma chave lida do Info.plist. Em producao, essa chave estaria empacotada no
    // bundle e qualquer pessoa com o IPA conseguia extrai-la — risco de abuso e
    // custo runaway. TODA a comunicacao com a OpenAI passa pela Cloud Function
    // autenticada (verifyIdToken + rate-limit em `rate_limits/{uid}`).
    //
    // Se um dia precisares de resiliencia extra, implementa retry exponencial
    // contra a Cloud Function — NUNCA embutas a chave OpenAI no cliente.

    private init() {}

    /// Envia uma mensagem para a Cloud Function Alma e devolve a resposta.
    /// Sem fallback directo: se a Cloud Function falhar, o erro e propagado.
    /// - Parameter healthContext: resumo do dia montado NO APARELHO
    ///   (HealthContextBuilder). Vai no prompt daquela chamada e o servidor NÃO
    ///   o grava no histórico. `nil` quando o usuário não deu consentimento.
    func sendMessage(_ message: String, healthContext: String? = nil) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AlmaError.noUser
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw AlmaError.tokenFailed
        }

        return try await callCloudFunction(message: message, token: token, healthContext: healthContext)
    }

    // MARK: - Cloud Function
    private func callCloudFunction(message: String, token: String, healthContext: String? = nil) async throws -> String {
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = ["message": message]
        // [Build 85 / 2.0] Contexto de saúde: só vai quando existe consentimento
        // e dado real. Efêmero — o servidor injeta no prompt e não persiste.
        if let healthContext, !healthContext.isEmpty {
            body["healthContext"] = healthContext
        }
        // [2026-08-22] Região do aparelho, e SÓ para o servidor escolher qual
        // linha de apoio em crise oferecer (`functions/src/apoioEmCrise.ts`).
        // Dar o número do país errado é pior do que não dar número: a pessoa
        // liga e não atende.
        //
        // O `Locale` foi escolhido por ser o caminho MENOS invasivo que funciona
        // — já está no aparelho, não pede permissão, não é dado sensível.
        // Geolocalização por IP no servidor seria pior (erra com VPN e cria
        // tratamento de dado que hoje não existe).
        //
        // ⚠️ NÃO É RASTREAMENTO. Vai no corpo desta requisição e acaba aí: não
        // é gravado, não vira evento de analytics, não vai para a Meta (ver
        // `MetaEventsManager`) e não entra em log.
        if let regiao = Locale.current.region?.identifier,
           regiao.count == 2 {
            body["regiao"] = regiao.uppercased()
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao serializar body do chat: \(error)")
            #endif
            throw AlmaError.networkError(error.localizedDescription)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AlmaError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw AlmaError.rateLimited }
            if http.statusCode >= 400 {
                // [Build 84] A Cloud Function devolve {"error": "<texto em PT-BR>"}.
                // Propaga esse texto para a UI mostrar algo útil em vez de
                // "Algo deu errado (erro 400)". 401 continua como serverError
                // para preservar o fluxo de retry de token no ChatView.
                if http.statusCode != 401,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverText = json["error"] as? String,
                   !serverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw AlmaError.serverRejected(http.statusCode, serverText)
                }
                throw AlmaError.serverError(http.statusCode)
            }
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao decodificar resposta do chat: \(error)")
            #endif
            throw AlmaError.parseFailed
        }

        guard let json = jsonObject as? [String: Any],
              let reply = json["reply"] as? String else {
            #if DEBUG
            print("OpenAIService: resposta do chat sem campo 'reply' esperado")
            #endif
            throw AlmaError.parseFailed
        }

        return reply
    }

    // MARK: - OpenAI Direct (REMOVIDO)
    // Função removida por motivos de seguranca — ver comentario no topo do ficheiro.
    // Toda a comunicacao com OpenAI passa pela Cloud Function autenticada.

    // MARK: - Text-to-Speech (via Firebase Cloud Function)

    /// Generates natural speech audio via the Alma TTS Cloud Function.
    /// Uses OpenAI's "nova" voice on the server side — no API key needed in the app.
    /// Returns raw MP3 data suitable for AVAudioPlayer.
    func generateSpeech(
        text: String,
        voice: String = "nova",
        speed: Double = 0.88
    ) async throws -> Data {
        guard let user = Auth.auth().currentUser else {
            throw AlmaError.noUser
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw AlmaError.tokenFailed
        }

        let ttsURL = URL(string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/tts")!
        var request = URLRequest(url: ttsURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "voice": voice,
            "speed": speed
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao serializar body do TTS: \(error)")
            #endif
            throw AlmaError.networkError(error.localizedDescription)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AlmaError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AlmaError.serverError(code)
        }

        return data
    }
}
