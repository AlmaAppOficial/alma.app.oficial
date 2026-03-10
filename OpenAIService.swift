
import Foundation

// MARK: - OpenAIService
//
// ⚠️  IMPORTANTE — Segurança:
// Este serviço iOS NÃO deve chamar a API da OpenAI diretamente, pois isso
// exigiria expor a chave da API no cliente (hardcoded ou em arquivo de config).
//
// Use o backend seguro (Firebase Cloud Function /chat) como proxy:
//   1. Obtenha o Firebase ID token do usuário autenticado.
//   2. Faça um POST para a Cloud Function com o token no header Authorization.
//   3. A Function verifica o token, aplica rate limiting e chama a OpenAI
//      usando a chave armazenada somente no servidor (Firebase Secret Manager).
//
// Exemplo de chamada ao backend:
//   let endpoint = URL(string: "https://southamerica-east1-<project-id>.cloudfunctions.net/chat")!
//   var request = URLRequest(url: endpoint)
//   request.httpMethod = "POST"
//   request.addValue("Bearer \(firebaseIdToken)", forHTTPHeaderField: "Authorization")
//   request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//   request.httpBody = try? JSONSerialization.data(withJSONObject: ["message": userMessage])
//
// Consulte DEPLOY.md para instruções completas de configuração.

class OpenAIService {

    // The backend URL is configured at runtime — never hardcode API keys here.
    // Set this to your deployed Cloud Function URL.
    let backendChatURL: URL

    init(backendChatURL: URL) {
        self.backendChatURL = backendChatURL
    }

    /// Sends a message to the Alma backend (Firebase Cloud Function) and returns the reply.
    /// - Parameters:
    ///   - message: The user's message text.
    ///   - firebaseIdToken: A valid Firebase Auth ID token obtained from the signed-in user.
    ///   - completion: Called on the main thread with the reply string, or nil on error.
    func sendMessage(message: String, firebaseIdToken: String, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: backendChatURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(firebaseIdToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["message": message]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["reply"] as? String {
                DispatchQueue.main.async { completion(reply) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}

