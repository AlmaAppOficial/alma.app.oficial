import SwiftUI
import FirebaseAuth

// MARK: - DeleteAccountView
// Presented as a sheet from ProfileView.
// Apple Guideline 5.1.1(v): account deletion must be accessible in-app,
// show clear warnings, require confirmation, and permanently delete all data.
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AccountDeletionService()

    @State private var password = ""
    @State private var showFinalConfirm = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    warningHeader
                    deletionInfoCard

                    if service.isPasswordProvider {
                        passwordSection
                    } else {
                        oauthWarning
                    }

                    if let error = service.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    confirmButton

                    Button("Cancelar") { dismiss() }
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textSecondary)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .background(CalmTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Excluir conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(CalmTheme.primary)
                        .disabled(service.isDeleting)
                }
            }
        }
        .alert("Tem certeza absoluta?", isPresented: $showFinalConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir permanentemente", role: .destructive) {
                Task { await service.requestDeletion(password: password) }
            }
        } message: {
            Text("Todos os seus dados serão apagados para sempre. Esta ação não pode ser desfeita.")
        }
        .disabled(service.isDeleting)
        .interactiveDismissDisabled(service.isDeleting)
    }

    // MARK: - Warning Header

    private var warningHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Excluir minha conta")
                .font(.title2.bold())
                .foregroundColor(CalmTheme.textPrimary)

            Text("Esta ação é permanente e não pode ser desfeita. Todos os seus dados pessoais serão apagados.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Deletion Info Card

    private var deletionInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("O que será excluído:")
                .font(.subheadline.bold())
                .foregroundColor(CalmTheme.textPrimary)

            ForEach(deletionItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 2)
                    Text(item)
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    private let deletionItems = [
        "Perfil e dados pessoais",
        "Todo o histórico de conversas com a Alma",
        "Registros de humor e bem-estar",
        "Memória e contexto da jornada emocional",
        "Dados de consentimento",
        "Conta de acesso ao app"
    ]

    // MARK: - Password Section (email/password users)

    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confirme sua senha para continuar")
                .font(.subheadline.bold())
                .foregroundColor(CalmTheme.textPrimary)

            SecureField("Senha atual", text: $password)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .disabled(service.isDeleting)
        }
    }

    // MARK: - OAuth Warning (non-password users)

    private var oauthWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            Text("Sua conta utiliza login social. A exclusão é irreversível e todos os dados serão apagados permanentemente.")
                .font(.caption)
                .foregroundColor(CalmTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        Button {
            if service.isPasswordProvider && password.isEmpty {
                service.errorMessage = "Digite sua senha para confirmar."
                return
            }
            showFinalConfirm = true
        } label: {
            HStack(spacing: 10) {
                if service.isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "trash.fill")
                }
                Text(service.isDeleting ? "Excluindo conta..." : "Excluir minha conta")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(service.isDeleting ? Color.red.opacity(0.6) : Color.red)
            .foregroundColor(.white)
            .cornerRadius(CalmTheme.rMedium)
        }
        .disabled(service.isDeleting)
    }
}

// MARK: - Preview

#Preview {
    DeleteAccountView()
}
