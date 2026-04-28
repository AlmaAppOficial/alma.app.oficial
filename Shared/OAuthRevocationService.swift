import Foundation
import FirebaseAuth
import GoogleSignIn
import FacebookLogin

/// Revoga tokens dos provedores OAuth associados ao usuário Firebase
/// antes da deleção da conta. Exigido pela Apple Guideline 5.1.1(v)
/// para Apple Sign In (jun/2023+).
///
/// Estratégia (Híbrido):
/// - Apple:    tenta revogar via authorizationCode salvo no Keychain.
///             Se não houver code (usuário antigo), pula com log.
/// - Google:   chama GIDSignIn.disconnect() (best-effort).
/// - Facebook: chama LoginManager().logOut() (best-effort).
///
/// Falhas individuais não bloqueiam a deleção — a Cloud Function ainda
/// chamará admin.auth().deleteUser(uid) para invalidar o Firebase Auth.
@MainActor
struct OAuthRevocationService {

    enum RevocationOutcome {
        case appleRevoked
        case appleSkippedNoCode     // usuário antigo, sem code salvo
        case appleFailed(Error)
        case googleDisconnected
        case googleFailed(Error)
        case facebookLoggedOut
        case notApplicable
    }

    /// Detecta providers usados pelo currentUser e revoga conforme aplicável.
    /// Retorna lista de outcomes para log de auditoria.
    static func revokeAllProviders() async -> [RevocationOutcome] {
        var outcomes: [RevocationOutcome] = []

        guard let user = Auth.auth().currentUser else {
            return outcomes
        }

        let providerIDs = user.providerData.map { $0.providerID }

        if providerIDs.contains("apple.com") {
            outcomes.append(await revokeApple())
        }

        if providerIDs.contains("google.com") {
            outcomes.append(await revokeGoogle())
        }

        if providerIDs.contains("facebook.com") {
            outcomes.append(revokeFacebook())
        }

        return outcomes
    }

    // MARK: - Apple

    private static func revokeApple() async -> RevocationOutcome {
        guard let code = AppleAuthCodeKeychainStore.read() else {
            print("ℹ️ Apple revoke: sem authorizationCode salvo (usuário antigo) — skip")
            return .appleSkippedNoCode
        }

        do {
            try await Auth.auth().revokeToken(withAuthorizationCode: code)
            AppleAuthCodeKeychainStore.delete()
            print("✅ Apple token revogado com sucesso")
            return .appleRevoked
        } catch {
            print("⚠️ Apple revoke falhou: \(error.localizedDescription)")
            return .appleFailed(error)
        }
    }

    // MARK: - Google

    private static func revokeGoogle() async -> RevocationOutcome {
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                GIDSignIn.sharedInstance.disconnect { error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume()
                    }
                }
            }
            print("✅ Google desconectado")
            return .googleDisconnected
        } catch {
            print("⚠️ Google disconnect falhou: \(error.localizedDescription)")
            return .googleFailed(error)
        }
    }

    // MARK: - Facebook

    private static func revokeFacebook() -> RevocationOutcome {
        LoginManager().logOut()
        print("✅ Facebook logOut concluído")
        return .facebookLoggedOut
    }
}
