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

// MARK: - Privacy-first: Meta CAPI desligado em 28/04/2026
// Para reativar, mudar isCAPIEnabled para true.
// Toda chamada externa (trackStartTrial, trackAppOpen, etc.)
// continua existindo, mas vira no-op silencioso quando desligado.
//
// MARK: - Consentimento (LGPD) — espelha o Android (util/MetaTracking)
// Mesmo com isCAPIEnabled = true, NENHUM evento é enviado enquanto o utilizador
// não consentir explicitamente (setConsent(true)). O diálogo de consentimento
// (RootView) chama setConsent. Sem "sim", tudo aqui é no-op silencioso. Nunca
// enviamos humor, ciclo ou dados de saúde — apenas eventos de negócio anónimos.

// MARK: - MetaEventsManager
final class MetaEventsManager {

    static let shared = MetaEventsManager()
    private init() {}

    private let isCAPIEnabled: Bool = false

    // Endpoint da Cloud Function — mesmo base URL do chat
    private let baseURL = "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net"

    // MARK: - Consentimento

    private let consentKey = "meta_consent_granted"
    private let askedKey   = "meta_consent_asked"

    /// `true` se o utilizador autorizou a medição de campanhas.
    var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    /// `true` se o utilizador já respondeu ao pedido (sim OU não) — usado para
    /// mostrar o diálogo de consentimento uma única vez.
    var hasAskedConsent: Bool {
        UserDefaults.standard.bool(forKey: askedKey)
    }

    /// Persiste a decisão de consentimento. Sem consentimento, sendEvent é no-op.
    func setConsent(_ granted: Bool) {
        let d = UserDefaults.standard
        d.set(granted, forKey: consentKey)
        d.set(true, forKey: askedKey)
    }

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
        guard isCAPIEnabled else { return }
        guard hasConsent else { return }   // LGPD: nada sai sem consentimento explícito
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
