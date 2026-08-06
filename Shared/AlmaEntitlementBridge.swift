// AlmaEntitlementBridge.swift
// Alma App — a ponte entre a compra na Apple e o servidor
//
// ─────────────────────────────────────────────────────────────────────────────
// POR QUE ESTE ARQUIVO EXISTE [2026-08-06]
//
// A Apple manda notificações de assinatura para o nosso servidor falando em
// `originalTransactionId`. Ela NÃO sabe quem é o usuário do Alma — não existe
// e-mail, uid nem nada que ligue a compra a uma conta do Firebase.
//
// Sem essa ligação, o servidor recebia a notificação, verificava a assinatura,
// guardava… e não tinha a quem conceder. `ehAssinante()` lia `entitlements/{uid}`
// e nunca achava nada, então TODO MUNDO — inclusive quem paga — era tratado como
// não-assinante e levava o limite de 20 mensagens por hora no chat, no recurso
// que a pessoa comprou. Este arquivo é o lado do app dessa ponte.
//
// O QUE MANDAMOS: `Transaction.jwsRepresentation` — a compra assinada pela
// própria Apple, não um número solto. O servidor verifica a assinatura na mesma
// cadeia do webhook (até a raiz Apple Root CA G3) antes de acreditar em qualquer
// coisa. Mandar só o `originalTransactionId` seria mandar uma string que qualquer
// um poderia inventar: quem soubesse o id de outra pessoa reivindicaria — e
// TIRARIA — a assinatura dela.
//
// EFEITO COLATERAL BOM: a transação assinada já traz produto e data de validade.
// O servidor grava o entitlement na mesma chamada, então a compra vale na hora,
// sem esperar o webhook. E como isto roda a cada abertura do app, um webhook
// perdido ou atrasado deixa de ser capaz de trancar um assinante do lado de fora.
//
// O QUE ESTE ARQUIVO NÃO FAZ:
//   • não decide se a pessoa é premium — quem decide é o servidor, e no app o
//     gate continua sendo o `AccessManager`;
//   • não avisa quando a assinatura acaba. `Transaction.currentEntitlements` só
//     devolve o que está ATIVO, então uma assinatura expirada simplesmente não
//     aparece aqui e nada é enviado. Quem corta o acesso nesse caso é a
//     notificação `EXPIRED` da Apple, no servidor.
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import StoreKit
import FirebaseAuth

enum AlmaEntitlementBridge {

    private static let endpoint = URL(
        string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/vincularAssinatura"
    )!

    /// Prefixo da marca de "já sincronizei esta transação hoje".
    /// O `LocalDataCleanupService` varre chaves com prefixo `alma_` no logout.
    private static let prefixoUltimoEnvio = "alma_entitlement_sync_"

    /// Uma vez por dia por transação, salvo quando o chamador força.
    private static let intervaloMinimo: TimeInterval = 24 * 60 * 60

    /// Envia ao servidor as assinaturas ativas desta conta.
    ///
    /// - Parameter forcado: `true` logo após comprar ou restaurar — nesses
    ///   momentos a pessoa está esperando o acesso destravar e não faz sentido
    ///   economizar chamada. `false` na abertura do app, onde a reconciliação é
    ///   oportunista e uma vez por dia basta.
    ///
    /// Falha em silêncio de propósito: se a rede cair ou o servidor estiver fora,
    /// não há nada que o usuário possa fazer a respeito e o acesso local (via
    /// StoreKit) continua valendo. Na próxima abertura tenta de novo.
    @discardableResult
    static func sincronizar(forcado: Bool = false) async -> Int {
        guard let user = Auth.auth().currentUser else { return 0 }

        var enviadas = 0
        for await resultado in Transaction.currentEntitlements {
            guard case .verified(let transacao) = resultado,
                  StoreKitManager.allIDs.contains(transacao.productID) else { continue }

            let chave = prefixoUltimoEnvio + String(transacao.originalID)
            if !forcado, sincronizadaRecentemente(chave: chave) { continue }

            if await enviar(jws: transacao.jwsRepresentation, user: user) {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: chave)
                enviadas += 1
            }
        }
        return enviadas
    }

    // MARK: - Privado

    private static func sincronizadaRecentemente(chave: String) -> Bool {
        let ultimo = UserDefaults.standard.double(forKey: chave)
        guard ultimo > 0 else { return false }
        return Date().timeIntervalSince1970 - ultimo < intervaloMinimo
    }

    private static func enviar(jws: String, user: User) async -> Bool {
        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            #if DEBUG
            print("[entitlement] falha ao obter ID token: \(error)")
            #endif
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        // O corpo carrega SÓ o JWS. O uid nunca vai daqui: o servidor o extrai do
        // ID token verificado. Se viesse no corpo, seria só mais um campo que o
        // cliente escolhe — e o cliente não pode escolher de quem é a assinatura.
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["jws": jws])

        do {
            let (dados, resposta) = try await URLSession.shared.data(for: request)
            guard let http = resposta as? HTTPURLResponse else { return false }
            guard http.statusCode == 200 else {
                #if DEBUG
                let corpo = String(data: dados, encoding: .utf8) ?? ""
                print("[entitlement] servidor recusou (\(http.statusCode)): \(corpo)")
                #endif
                return false
            }
            #if DEBUG
            print("[entitlement] assinatura vinculada no servidor")
            #endif
            return true
        } catch {
            #if DEBUG
            print("[entitlement] falha de rede ao vincular: \(error)")
            #endif
            return false
        }
    }
}
