import Foundation
import FirebaseAuth
import FirebaseFirestore

// Handles the account deletion flow:
// 1. Reauthenticates the user (password providers only)
// 2. Marks deletionRequested=true on Firestore (triggers Cloud Function cleanup)
// 3. Signs out immediately — backend deletion is async
@MainActor
final class AccountDeletionService: ObservableObject {
    @Published var isDeleting = false
    @Published var errorMessage: String?

    // True if the user signed up with email/password (requires password reauth)
    var isPasswordProvider: Bool {
        Auth.auth().currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    func requestDeletion(password: String) async {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Sessão expirada. Faça login novamente."
            return
        }

        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        // Step 1: Reauthenticate (required for email/password accounts)
        if isPasswordProvider {
            guard !password.isEmpty else {
                errorMessage = "Digite sua senha para confirmar."
                return
            }
            guard let email = user.email else {
                errorMessage = "Não foi possível verificar o e-mail da conta."
                return
            }
            do {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                try await user.reauthenticate(with: credential)
            } catch let error as NSError {
                errorMessage = reauthErrorMessage(for: error)
                return
            }
        }

        // ── [2026-08-04 — D-1, apontado na reauditoria] ─────────────────────
        //
        // A ordem estava invertida e criava perda PERMANENTE de dados: a
        // escrita de `deletionRequested` (abaixo) é irreversível — a Cloud
        // Function dispara nela e apaga Firestore + Auth. A limpeza local só
        // vinha três passos depois, atrás de uma chamada de rede sem timeout.
        // Se o app morresse, perdesse rede ou a revogação pendurasse, o
        // servidor apagava tudo e o APARELHO ficava com peso, altura,
        // alergias, condições de saúde, humor e o histórico do chat. Para
        // sempre — e a tela promete "apagados para sempre".
        //
        // Agora: (1) marca-se a limpeza como PENDENTE antes de qualquer coisa
        // irreversível; (2) limpa-se o local ANTES da escrita remota; (3) a
        // marca só sai no fim. Se o processo morrer em qualquer ponto, o boot
        // seguinte encontra a marca e termina o serviço (ver `AlmaApp`).
        Self.executarLimpezaLocal()

        // Step 2: Write deletion flag — Cloud Function picks this up and deletes all data
        let uid = user.uid
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .setData([
                    "deletionRequested": true,
                    "deletionRequestedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            errorMessage = "Erro ao registrar pedido de exclusão. Verifique a conexão e tente novamente."
            return
        }

        // Step 3: Revoga tokens OAuth (Apple obrigatório, Google/FB best-effort)
        // antes do signOut. Falhas não bloqueiam a deleção — Cloud Function
        // chamará admin.auth().deleteUser(uid) de qualquer forma.
        let outcomes = await OAuthRevocationService.revokeAllProviders()
        for outcome in outcomes {
            print("Deletion revoke outcome: \(outcome)")
        }

        // Step 4: Sign out — a UI volta ao login; o servidor segue apagando.
        try? Auth.auth().signOut()

        Self.finalizarLimpezaLocal()
    }

    // MARK: - Limpeza local (entradas testáveis)
    //
    // [2026-08-04 — REAUDITORIA] A revisora comentou `clearAll()` na linha 72 e
    // as quatro asserções B9 continuaram verdes: elas chamavam
    // `LocalDataCleanupService.clearAll()` DIRETO, provando que o serviço
    // funciona quando chamado — nunca que a exclusão de conta o chama.
    //
    // Estes dois métodos são o nível certo para o harness entrar: são o que a
    // `requestDeletion` executa. Apagar a chamada de dentro daqui deixa a
    // asserção B9e VERMELHA, que é o teste que a prova precisava passar.

    /// Tudo que precisa acontecer no aparelho ANTES do ponto de não retorno.
    static func executarLimpezaLocal() {
        LocalDataCleanupService.marcarLimpezaPendente()
        LocalDataCleanupService.clearAll()
    }

    /// Roda DEPOIS do `signOut()`: ele dispara o listener do AccessManager, que
    /// republica `alma_isPremium`/`alma_active` no App Group e desfaz parte da
    /// limpeza (D-3). Só então a marca de pendência sai.
    static func finalizarLimpezaLocal() {
        LocalDataCleanupService.clearAll()
        LocalDataCleanupService.concluirLimpezaPendente()
    }

    private func reauthErrorMessage(for error: NSError) -> String {
        switch AuthErrorCode(rawValue: error.code) {
        case .wrongPassword:
            return "Senha incorreta. Verifique e tente novamente."
        case .tooManyRequests:
            return "Muitas tentativas incorretas. Aguarde alguns minutos e tente de novo."
        case .requiresRecentLogin:
            return "Por segurança, faça login novamente antes de excluir a conta."
        case .networkError:
            return "Sem conexão com a internet. Verifique e tente novamente."
        default:
            return "Não foi possível verificar a senha. Tente novamente."
        }
    }
}
