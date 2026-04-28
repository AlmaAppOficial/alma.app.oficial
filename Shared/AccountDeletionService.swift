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

        // Step 5: Sign out immediately — UI returns to login; cleanup continues server-side
        try? Auth.auth().signOut()
    }

    private func reauthErrorMessage(for error: NSError) -> String {
        switch AuthErrorCode.Code(rawValue: error.code) {
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
