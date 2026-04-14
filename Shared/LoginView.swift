import SwiftUI
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit

struct LoginView: View {

    @Binding var logged: Bool
    @State private var currentPage = 0
    @State private var showAuthSheet = false
    @State private var authMode: AuthMode = .login

    enum AuthMode { case login, register }

    let slides: [(icon: String, title: String, subtitle: String)] = [
        ("heart.fill",       "Bem-vindo à Alma",       "O teu espaço seguro para cuidar da saúde mental."),
        ("bubble.left.fill", "Fala com a Alma IA",     "Uma mentora empática disponível a qualquer hora."),
        ("chart.bar.fill",   "Acompanha o teu humor",  "Descobre padrões e evolui dia após dia."),
    ]

    var body: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                // Logo with AlmaLogo component
                AlmaLogo(size: 84)
                    .padding(.bottom, 12)
                Text("Alma")
                    .font(.largeTitle.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Fale com a sua alma, ouça a sua alma.")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 0.33, green: 0.27, blue: 0.52))
                    .padding(.bottom, 32)
                // Slides
                TabView(selection: $currentPage) {
                    ForEach(slides.indices, id: \.self) { i in
                        VStack(spacing: 16) {
                            Image(systemName: slides[i].icon)
                                .font(.system(size: 56))
                                .foregroundColor(CalmTheme.primary)
                            Text(slides[i].title)
                                .font(.title3.bold())
                                .foregroundColor(CalmTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            Text(slides[i].subtitle)
                                .font(.body)
                                .foregroundColor(Color(red: 0.33, green: 0.27, blue: 0.52))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 280)
                Spacer()
                // Buttons
                VStack(spacing: 12) {
                    Button { authMode = .login; showAuthSheet = true } label: {
                        Text("Entrar na minha conta")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                    }
                    .background(CalmTheme.heroGradient)
                    .cornerRadius(CalmTheme.rMedium)
                    Button { authMode = .register; showAuthSheet = true } label: {
                        Text("Criar conta grátis")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(CalmTheme.primary)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                            .strokeBorder(CalmTheme.primary, lineWidth: 1.5)
                    )
                        Text("Ao continuar, aceitas os Termos de Uso e Política de Privacidade.")
                        .font(.caption2)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    // Epicom branding
                    HStack(spacing: 4) {
                        Text("desenvolvido por")
                            .font(.system(size: 10))
                            .foregroundColor(CalmTheme.textSecondary.opacity(0.5))
                        Text("Felipe Assis Lara")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(CalmTheme.primary.opacity(0.55))
                            .kerning(1.5)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAuthSheet) {
            AuthSheet(mode: $authMode, logged: $logged)
        }
    }
}

struct AuthSheet: View {
    @Binding var mode: LoginView.AuthMode
    @Binding var logged: Bool
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentNonce: String? = nil
    var isRegister: Bool { mode == .register }

    var body: some View {
        NavigationView {
            ZStack {
                CalmTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            AlmaLogo(size: 64)
                            Text(isRegister ? "Criar conta" : "Entrar na Alma")
                                .font(.title2.bold()).foregroundColor(CalmTheme.textPrimary)
                        }
                        .padding(.top, 24)
                        VStack(spacing: 14) {
                            authField(icon: "envelope.fill", placeholder: "Email", text: $email, isSecure: false)
                            authField(icon: "lock.fill", placeholder: "Senha", text: $password, isSecure: true)
                            if isRegister {
                                authField(icon: "lock.fill", placeholder: "Confirmar senha", text: $confirmPassword, isSecure: true)
                            }
                        }
                        .padding(.horizontal, 24)
                        if let err = errorMessage {
                            Text(err).font(.caption).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal, 24)
                        }
                        Button(action: performAuth) {
                            Group {
                                if isLoading { ProgressView().tint(.white) }
                                else { Text(isRegister ? "Criar conta" : "Entrar").font(.headline) }
                            }
                            .frame(maxWidth: .infinity).frame(height: 52).foregroundColor(.white)
                        }
                        .background(CalmTheme.heroGradient)
                        .cornerRadius(CalmTheme.rMedium)
                        .disabled(isLoading)
                        .padding(.horizontal, 24)
                        Button {
                            withAnimation { mode = isRegister ? .login : .register; errorMessage = nil }
                        } label: {
                            Text(isRegister ? "Já tem conta? Entre aqui" : "Não tens conta? Cria uma")
                                .font(.subheadline).foregroundColor(CalmTheme.primary)
                        }
                        if !isRegister {
                            Button { sendPasswordReset() } label: {
                                Text("Esqueceu a senha?").font(.subheadline).foregroundColor(CalmTheme.textSecondary)
                            }
                        }

                        // Social Sign-In Buttons
                        VStack(spacing: 12) {
                            HStack {
                                Rectangle().frame(height: 0.5).foregroundColor(CalmTheme.textSecondary.opacity(0.4))
                                Text("ou continua com")
                                    .font(.caption)
                                    .foregroundColor(CalmTheme.textSecondary)
                                    .fixedSize()
                                Rectangle().frame(height: 0.5).foregroundColor(CalmTheme.textSecondary.opacity(0.4))
                            }
                            .padding(.vertical, 8)

                            // Sign in with Apple (nativo, sem SDK extra)
                            SignInWithAppleButton(
                                onRequest: { request in
                                    let nonce = randomNonceString()
                                    currentNonce = nonce
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = sha256(nonce)
                                },
                                onCompletion: handleAppleSignIn
                            )
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 48)
                            .cornerRadius(CalmTheme.rSmall)

                            socialButton(
                                icon: "G",
                                iconColor: Color(red: 0.85, green: 0.26, blue: 0.21),
                                label: "Continuar com Google",
                                backgroundColor: .white,
                                action: signInWithGoogle
                            )

                            socialButton(
                                icon: "f",
                                iconColor: Color(red: 0.26, green: 0.40, blue: 0.70),
                                label: "Continuar com Facebook",
                                backgroundColor: .white,
                                action: signInWithFacebook
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                        // Epicom branding footer
                        VStack(spacing: 2) {
                            Text("desenvolvido por")
                                .font(.system(size: 10))
                                .foregroundColor(CalmTheme.textSecondary.opacity(0.5))
                            Text("Felipe Assis Lara")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(CalmTheme.primary.opacity(0.6))
                                .kerning(2)
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }.foregroundColor(CalmTheme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func authField(icon: String, placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(CalmTheme.primary).frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: text)
                    .autocapitalization(.none)
                    .foregroundColor(.black)
            } else {
                TextField(placeholder, text: text)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .foregroundColor(.black)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(CalmTheme.rSmall)
        .overlay(RoundedRectangle(cornerRadius: CalmTheme.rSmall).strokeBorder(CalmTheme.primary.opacity(0.3), lineWidth: 1))
    }

    @ViewBuilder
    private func socialButton(icon: String, iconColor: Color = .black, label: String, backgroundColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.black)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 16)
        }
        .background(backgroundColor)
        .cornerRadius(CalmTheme.rSmall)
        .overlay(RoundedRectangle(cornerRadius: CalmTheme.rSmall).strokeBorder(Color.gray.opacity(0.3), lineWidth: 1))
    }

    private func performAuth() {
        errorMessage = nil
        let e = email.trimmingCharacters(in: .whitespaces)
        let p = password.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty, !p.isEmpty else { errorMessage = "Preencha o e-mail e a senha."; return }
        if isRegister {
            guard p == confirmPassword.trimmingCharacters(in: .whitespaces) else { errorMessage = "As senhas não coincidem."; return }
            guard p.count >= 6 else { errorMessage = "A senha deve ter no mínimo 6 caracteres."; return }
            createAccount(email: e, password: p)
        } else {
            signIn(email: e, password: p)
        }
    }

    private func signIn(email: String, password: String) {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false
            if let error = error { errorMessage = firebaseMessage(error) } else { logged = true; dismiss() }
        }
    }

    private func createAccount(email: String, password: String) {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            isLoading = false
            if let error = error {
                errorMessage = firebaseMessage(error)
            } else {
                // Send email verification
                Auth.auth().currentUser?.sendEmailVerification { verificationError in
                    if verificationError == nil {
                        errorMessage = "Conta criada! Verifica o teu email para confirmar."
                    }
                }
                logged = true
                dismiss()
            }
        }
    }

    private func sendPasswordReset() {
        let t = email.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { errorMessage = "Escreve o teu email primeiro."; return }
        Auth.auth().sendPasswordReset(withEmail: t) { error in
            errorMessage = error == nil ? "Email de recuperação enviado para \(t)" : firebaseMessage(error!)
        }
    }

    // MARK: - Sign in with Apple
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Erro ao obter credenciais da Apple."
                return
            }
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            isLoading = true
            Auth.auth().signIn(with: credential) { _, error in
                isLoading = false
                if let error = error {
                    errorMessage = firebaseMessage(error)
                } else {
                    logged = true
                    dismiss()
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Sign in com Apple falhou: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Google Sign In
    private func signInWithGoogle() {
        isLoading = true
        Task {
            do {
                let provider = OAuthProvider(providerID: "google.com")
                provider.customParameters = ["prompt": "select_account"]
                let credential = try await provider.credential(with: nil)
                try await Auth.auth().signIn(with: credential)
                await MainActor.run {
                    self.isLoading = false
                    self.logged = true
                    self.dismiss()
                }
            } catch let error as NSError {
                await MainActor.run {
                    self.isLoading = false
                    if error.code != AuthErrorCode.webContextCancelled.rawValue {
                        self.errorMessage = self.firebaseMessage(error)
                    }
                }
            }
        }
    }

    // MARK: - Facebook Sign In
    private func signInWithFacebook() {
        isLoading = true
        Task {
            do {
                let provider = OAuthProvider(providerID: "facebook.com")
                provider.scopes = ["email", "public_profile"]
                let credential = try await provider.credential(with: nil)
                try await Auth.auth().signIn(with: credential)
                await MainActor.run {
                    self.isLoading = false
                    self.logged = true
                    self.dismiss()
                }
            } catch let error as NSError {
                await MainActor.run {
                    self.isLoading = false
                    if error.code != AuthErrorCode.webContextCancelled.rawValue {
                        self.errorMessage = self.firebaseMessage(error)
                    }
                }
            }
        }
    }

    private func sendEmailLink() {
        let t = email.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { errorMessage = "Escreve o teu email primeiro."; return }
        errorMessage = "Sign in com Email link será ativado em breve."
    }

    // MARK: - Helpers Apple Sign In
    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func firebaseMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case AuthErrorCode.emailAlreadyInUse.rawValue: return "Este email já está em uso."
        case AuthErrorCode.invalidEmail.rawValue:      return "Email inválido."
        case AuthErrorCode.wrongPassword.rawValue:     return "Password incorreta."
        case AuthErrorCode.userNotFound.rawValue:      return "Conta não encontrada."
        case AuthErrorCode.weakPassword.rawValue:      return "Password demasiado fraca."
        case AuthErrorCode.networkError.rawValue:      return "Sem ligação à internet."
        default:                                        return error.localizedDescription
        }
    }
}
