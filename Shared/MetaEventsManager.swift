// MetaEventsManager.swift
// Alma App — Rastreamento de eventos Meta Ads (Facebook Conversions API)
//
// ARQUITECTURA: Server-Side via Firebase Cloud Function
// - NÃO usa Facebook iOS SDK (não é necessário alterar pbxproj)
// - NÃO requer App Tracking Transparency (ATT) permission
// - GDPR/LGPD compliant: email é enviado em hash SHA256, nunca em claro
//
// COMO FUNCIONA:
//   iOS → Cloud Function "trackConversion" → Facebook Conversions API
//
// SETUP NECESSÁRIO (1x no Firebase):
//   firebase functions:secrets:set META_PIXEL_ID
//   firebase functions:secrets:set META_ACCESS_TOKEN
//
// Pixel ID: Meta Business → Gestor de Eventos → teu Pixel → Settings
// Access Token: Meta Business → Gestor de Eventos → Pixel → Settings →
//               "Generate Access Token" (System User, permissão de anúncios)

import Foundation
import FirebaseAuth
import CryptoKit

// MARK: - MetaEventsManager
final class MetaEventsManager {

    static let shared = MetaEventsManager()
    private init() {}

    // Endpoint da Cloud Function — mesmo base URL do chat
    private let baseURL = "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net"

    // MARK: - Eventos públicos

    /// Disparar quando utilizador activa o premium pela primeira vez
    /// Chamar em AccessManager.checkClaims() quando isPremium muda de false → true
    func trackStartTrial() {
        sendEvent(name: "StartTrial", value: nil, currency: nil)
    }

    /// Disparar quando utilizador completa o registo/login inicial
    func trackCompleteRegistration() {
        sendEvent(name: "CompleteRegistration", value: nil, currency: nil)
    }

    /// Disparar em cada abertura do app (ajuda o algoritmo Meta a aprender)
    func trackAppOpen() {
        sendEvent(name: "ViewContent", value: nil, currency: nil)
    }

    // MARK: - Implementação privada

    private func sendEvent(name: String, value: Double?, currency: String?) {
        guard let user = Auth.auth().currentUser else { return }

        // Hash SHA256 do email para privacidade (padrão Meta CAPI)
        let emailHash = hashEmail(user.email ?? "")

        var payload: [String: Any] = [
            "event": name,
            "user_id": user.uid,
            "email_hash": emailHash,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        if let value = value { payload["value"] = value }
        if let currency = currency { payload["currency"] = currency }

        guard let url = URL(string: "\(baseURL)/trackConversion") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        // Adicionar Authorization header com Firebase ID Token
        user.getIDToken { token, _ in
            guard let token = token else { return }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
            request.httpBody = body

            // Fire-and-forget: não bloqueamos a UI
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("[Meta] ⚠️ Erro ao enviar evento \(name): \(error.localizedDescription)")
                } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    print("[Meta] ✅ Evento \(name) enviado com sucesso")
                } else {
                    print("[Meta] ⚠️ Resposta inesperada para evento \(name)")
                }
            }.resume()
        }
    }

    /// SHA256 hash do email (lowercase + trimmed) — padrão Meta CAPI
    private func hashEmail(_ email: String) -> String {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return "" }
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
