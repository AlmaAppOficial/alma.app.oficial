import Foundation
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct UserProfile {
    let uid: String
    let name: String
    let email: String
    let photoURL: String?
    let createdAt: Date
    let streakDays: Int
    let lastCheckIn: Date?
}

@MainActor
class AuthManager: NSObject, ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isAuthenticated = false

    let authManager: Auth?

    override init() {
        authManager = Auth.auth()
        super.init()
        checkAuthenticationStatus()
    }

    private func checkAuthenticationStatus() {
        if let currentUser = authManager?.currentUser {
            isAuthenticated = true
            loadUserProfile(uid: currentUser.uid)
        } else {
            isAuthenticated = false
        }
    }

    func loadUserProfile(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() as? [String: Any] {
                DispatchQueue.main.async {
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let lastCheckIn = (data["lastCheckIn"] as? Timestamp)?.dateValue()

                    self.userProfile = UserProfile(
                        uid: uid,
                        name: data["name"] as? String ?? "User",
                        email: data["email"] as? String ?? "",
                        photoURL: data["photoURL"] as? String,
                        createdAt: createdAt,
                        streakDays: data["streakDays"] as? Int ?? 0,
                        lastCheckIn: lastCheckIn
                    )
                }
            }
        }
    }

    func signOut() {
        do {
            try authManager?.signOut()
            DispatchQueue.main.async {
                self.userProfile = nil
                self.isAuthenticated = false
            }
        } catch {
            print("Sign out error: \(error)")
        }
    }

    func signUp(email: String, password: String, name: String) async -> Bool {
        do {
            let result = try await authManager?.createUser(withEmail: email, password: password)
            guard let user = result?.user else { return false }

            let db = Firestore.firestore()
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": email,
                "name": name,
                "createdAt": Timestamp(date: Date()),
                "streakDays": 0,
                "photoURL": ""
            ]

            try await db.collection("users").document(user.uid).setData(userData)

            await loadUserProfile(uid: user.uid)
            self.isAuthenticated = true
            return true
        } catch {
            return false
        }
    }

    func signIn(email: String, password: String) async -> Bool {
        do {
            let result = try await authManager?.signIn(withEmail: email, password: password)
            guard let user = result?.user else { return false }

            await loadUserProfile(uid: user.uid)
            self.isAuthenticated = true
            return true
        } catch {
            return false
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Erro ao iniciar Google Sign-In."
            return
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            await createProfileIfNeeded(for: authResult.user)
            self.isAuthenticated = true
        } catch {
            errorMessage = "Google Sign-In falhou."
        }
    }

    // MARK: - Apple Sign In
    func signInWithApple() {
        currentNonce = randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(currentNonce!)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Facebook Sign In (requires facebook-ios-sdk SPM package)
    func signInWithFacebook() async {
        errorMessage = "Para ativar Facebook Login, adiciona o pacote 'facebook-ios-sdk' via SPM e descomenta o código em AuthManager.swift."
    }

    // MARK: - Helpers
    private func createProfileIfNeeded(for user: FirebaseAuth.User) async {
        let ref = Firestore.firestore().collection("users").document(user.uid)
        let doc = try? await ref.getDocument()
        if doc?.exists == true { return }
        let data: [String: Any] = [
            "uid": user.uid,
            "name": user.displayName ?? "Utilizador",
            "email": user.email ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "createdAt": Timestamp(date: Date()),
            "streakDays": 0
        ]
        try? await ref.setData(data)
        loadUserProfile(uid: user.uid)
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Published extras
extension AuthManager {
    // Adiciona as propriedades em falta ao @MainActor class
}

// Adicionar ao topo da classe (dentro do @MainActor class AuthManager):
// @Published var isLoading = false
// @Published var errorMessage: String?
// private var currentNonce: String?

// MARK: - Apple Delegate
extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                              didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8),
                let nonce = self.currentNonce
            else { return }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString, rawNonce: nonce, fullName: credential.fullName)
            if let result = try? await Auth.auth().signIn(with: firebaseCredential) {
                await self.createProfileIfNeeded(for: result.user)
                self.isAuthenticated = true
            }
        }
    }
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {}
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first ?? UIWindow()
    }
}
