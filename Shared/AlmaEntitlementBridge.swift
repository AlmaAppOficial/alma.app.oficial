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
import os

enum AlmaEntitlementBridge {

    // ─────────────────────────────────────────────────────────────────────────
    // [2026-08-28 — Opção 3 do laudo do 403] LOG VISÍVEL EM PRODUÇÃO
    //
    // Antes, TODO o diagnóstico daqui vivia dentro de `#if DEBUG`: no build da
    // App Store, uma falha de vínculo era literalmente invisível. Foi assim que
    // uma assinante real de iOS ficou sem `apple_transaction_links` de 17/06 a
    // 17/08 sem ninguém ver — o servidor registrou "sem vínculo para a
    // transação" e o app não registrou nada.
    //
    // `os.Logger` é o mecanismo certo: sai no Console.app e no sysdiagnose do
    // aparelho, custa quase nada quando ninguém está olhando, e NÃO passa por
    // servidor nenhum (não é analytics, não é Crashlytics, não sai do device
    // por conta própria — o que mantém a regra de privacidade do CLAUDE.md).
    //
    // O QUE NUNCA ENTRA NO LOG: o JWS, o token, o uid e o e-mail. Só status
    // HTTP, `originalID` da transação (que é da Apple, não da pessoa) e a
    // contagem de tentativas. `privacy: .public` é explícito nos campos que
    // podem aparecer — sem isso o os_log mascara tudo como `<private>` e o log
    // vira inútil justamente quando alguém precisa dele.
    // ─────────────────────────────────────────────────────────────────────────
    private static let log = Logger(subsystem: "com.almaapp.app",
                                    category: "entitlement")

    private static let endpoint = URL(
        string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/vincularAssinatura"
    )!

    /// [2026-08-28] Tentativas por transação, com espera crescente entre elas.
    ///
    /// Três, e não mais: o `sincronizar()` roda a cada abertura do app, então a
    /// quarta tentativa já é a próxima vez que a pessoa abre. Insistir mais
    /// dentro da mesma sessão só gasta bateria para resolver o mesmo caso.
    private static let tentativasMax = 3
    private static let esperaBase: UInt64 = 2_000_000_000   // 2 s, dobrando

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

            // [2026-08-06] Era `transacao.jwsRepresentation`, que não compila:
            // o JWS é do ENVELOPE, não do conteúdo. `VerificationResult` é quem
            // guarda a representação assinada; `Transaction` é o que sobra
            // depois de abrir o envelope, e um payload já aberto não teria como
            // provar nada ao servidor. Como o servidor verifica a assinatura
            // (é o mesmo caminho do `appleNotifications`), é o envelope que
            // precisa viajar.
            // [2026-08-28] Retry com espera crescente. Antes era uma tentativa
            // só: um 503 momentâneo ou uma rede ruim no segundo exato da
            // abertura custava um dia inteiro de vínculo — e em silêncio.
            var ok = false
            for tentativa in 1...tentativasMax {
                ok = await enviar(jws: resultado.jwsRepresentation,
                                  user: user,
                                  originalID: transacao.originalID,
                                  tentativa: tentativa)
                if ok { break }
                if tentativa < tentativasMax {
                    try? await Task.sleep(nanoseconds: esperaBase << (tentativa - 1))
                }
            }

            if ok {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: chave)
                enviadas += 1
            } else {
                // A marca NÃO é gravada: sem ela, a próxima abertura tenta de
                // novo em vez de esperar 24 h. Falhar não pode virar silêncio
                // de um dia.
                log.error("""
                    vínculo NÃO estabelecido após \(tentativasMax, privacy: .public) \
                    tentativas · originalID=\(transacao.originalID, privacy: .public) \
                    · produto=\(transacao.productID, privacy: .public) \
                    — assinatura paga sem acesso no servidor
                    """)
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

    private static func enviar(jws: String,
                               user: User,
                               originalID: UInt64,
                               tentativa: Int) async -> Bool {
        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            log.error("""
                falha ao obter ID token (tentativa \(tentativa, privacy: .public)) \
                · originalID=\(originalID, privacy: .public) \
                · \(error.localizedDescription, privacy: .public)
                """)
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
            guard let http = resposta as? HTTPURLResponse else {
                log.error("""
                    resposta sem HTTP (tentativa \(tentativa, privacy: .public)) \
                    · originalID=\(originalID, privacy: .public)
                    """)
                return false
            }
            guard http.statusCode == 200 else {
                // O corpo pode trazer texto do servidor; fica em DEBUG porque é
                // o único campo aqui que não controlamos e poderia, um dia,
                // carregar algo que não queremos em log de produção.
                #if DEBUG
                let corpo = String(data: dados, encoding: .utf8) ?? ""
                log.debug("corpo da recusa: \(corpo, privacy: .public)")
                #endif
                log.error("""
                    servidor recusou o vínculo · HTTP \(http.statusCode, privacy: .public) \
                    · tentativa \(tentativa, privacy: .public) \
                    · originalID=\(originalID, privacy: .public)
                    """)
                return false
            }
            log.info("""
                assinatura vinculada no servidor \
                · originalID=\(originalID, privacy: .public) \
                · tentativa \(tentativa, privacy: .public)
                """)
            return true
        } catch {
            log.error("""
                falha de rede ao vincular (tentativa \(tentativa, privacy: .public)) \
                · originalID=\(originalID, privacy: .public) \
                · \(error.localizedDescription, privacy: .public)
                """)
            return false
        }
    }
}
