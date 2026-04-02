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

    // Endpoint de fallback — OpenAI direto (usa chave do bundle se disponível)
    private let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    // Chave OpenAI de fallback — define em Info.plist como OPENAI_API_KEY ou deixa vazio
    private var openAIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }

    private init() {}

    /// Sends a message to the Alma Cloud Function and returns the reply.
    /// Falls back to direct OpenAI call if the Cloud Function returns a server error.
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

        // 1. Tenta Cloud Function primeiro
        do {
            return try await callCloudFunction(message: message, token: token)
        } catch AlmaError.serverError(let code) {
            // 2. Fallback: OpenAI direto se tiver chave e a função retornar 5xx
            if code >= 500 && !openAIKey.isEmpty {
                return try await callOpenAIDirect(message: message)
            }
            throw AlmaError.serverError(code)
        } catch AlmaError.networkError(_) {
            // 3. Fallback por erro de rede se tiver chave
            if !openAIKey.isEmpty {
                return try await callOpenAIDirect(message: message)
            }
            throw AlmaError.networkError("Sem conexão com o servidor. Verifica a tua ligação à internet.")
        }
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

    // MARK: - OpenAI Direct (fallback)
    private func callOpenAIDirect(message: String) async throws -> String {
        var request = URLRequest(url: openAIURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let systemPrompt = """
        Você é a Alma, uma mentora de bem-estar mental empática e acolhedora. \
        Responde sempre em português (PT-BR), com empatia e sem julgamentos. \
        Ajudas as pessoas a cuidar da saúde mental, lidar com ansiedade, estresse e emoções difíceis. \
        Nunca fazes diagnósticos médicos. Mantém respostas concisas (máx. 3 parágrafos).
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": message]
            ],
            "max_tokens": 400,
            "temperature": 0.7
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw AlmaError.serverError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw AlmaError.parseFailed
        }

        return content
    }

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
