import Foundation
import FirebaseAuth

// MARK: - AlmaError
enum AlmaError: LocalizedError {
    case noUser
    case tokenFailed
    case serverError(Int)
    case rateLimited
    case parseFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noUser:            return "Nenhum utilizador autenticado."
        case .tokenFailed:       return "Falha ao obter token de autenticacao."
        case .serverError(let c): return "Erro do servidor (\(c))."
        case .rateLimited:       return "Limite de mensagens atingido. Tente novamente amanha."
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
    func sendMessage(_ message: String) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AlmaError.noUser
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw AlmaError.tokenFailed
        }

        return try await callCloudFunction(message: message, token: token)
    }

    // MARK: - Cloud Function
    private func callCloudFunction(message: String, token: String) async throws -> String {
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["message": message]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AlmaError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw AlmaError.rateLimited }
            if http.statusCode >= 400 { throw AlmaError.serverError(http.statusCode) }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = json["reply"] as? String else {
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
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

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
