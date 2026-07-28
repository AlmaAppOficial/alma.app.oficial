// AccessManager.swift
// Alma App — Gestão de acesso premium
//
// ARQUITECTURA (actualizada para Apple IAP):
//   1. Verifica StoreKit 2 (Apple In-App Purchase) — tem prioridade
//   2. Fallback: Firebase Auth Custom Claim `isPremium: true` (subscritors via web/Stripe)
//
// Isto garante conformidade com a App Store Guideline 3.1.1:
//   o acesso premium é comprado dentro da app via Apple IAP.
//   Os clientes web existentes continuam a funcionar via Firebase claims.

import SwiftUI
import FirebaseAuth
import StoreKit

@MainActor
class AccessManager: ObservableObject {

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var storeKitObserver: NSObjectProtocol?

    @Published var isPremium: Bool = false
    @Published var isChecking: Bool = true
    @Published var isInTrial: Bool = false
    @Published var trialDays: Int = 0

    init() {
        // Ouvir mudanças de autenticação Firebase
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.checkAccess(user: user)
                } else {
                    self?.isPremium = false
                    self?.isChecking = false
                    // Logout: derruba o flag compartilhado para o Corpo & Alma
                    // não continuar desbloqueado por uma sessão antiga do Alma.
                    self?.publishToSharedBridge()
                }
            }
        }

        // Ouvir compras StoreKit concluídas (vindas de qualquer parte da app)
        storeKitObserver = NotificationCenter.default.addObserver(
            forName: .storeKitPurchaseCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    // MARK: - Verificação de Acesso

    /// Verifica acesso via StoreKit (IAP), Firebase Custom Claims ou trial gratuito de 7 dias
    func checkAccess(user: User) async {
        isChecking = true
        let previousValue = isPremium

        // 1. Verificar StoreKit — Apple IAP tem prioridade
        if await checkStoreKitEntitlement() {
            isPremium = true
            isInTrial = false
            trialDays = 0
        } else {
            // 2. Fallback: Firebase Custom Claims (subscritores web / Stripe)
            await checkFirebaseClaims(user: user)

            // 3. Trial gratuito de 7 dias após criação da conta
            if isInFreeTrial(user: user) {
                isInTrial = true
                trialDays = trialDaysRemaining(user: user)
                if !isPremium {
                    isPremium = true
                }
            } else {
                isInTrial = false
                trialDays = 0
            }
        }

        // 4. Ponte App Group — assinatura única: compra feita no Corpo & Alma
        //    desbloqueia o Alma (flag gravado pelo C&A; validade 30 dias). [2026-07-14]
        if !isPremium && Self.corpoAlmaPremiumActive() {
            isPremium = true
        }

        // Publica o estado atual para o Corpo & Alma (lado Alma da ponte).
        publishToSharedBridge()

        isChecking = false

        // 🎯 Meta Ads: dispara StartTrial apenas na transição false → true
        if !previousValue && isPremium {
            MetaEventsManager.shared.trackStartTrial()
        }
    }

    /// Trial gratuito de 7 dias após criação da conta
    private let betaTrialDays = 7

    /// Contas usadas pela Apple App Review — nunca entram em trial automático,
    /// para que o reviewer veja o paywall e consiga testar a compra IAP em sandbox.
    /// Sem isso, a conta cai em trial premium e Apple reporta "IAPs não encontrados no binário".
    private static let appleReviewEmails: Set<String> = [
        "contact@almaappoficial.com"
    ]

    /// Verifica se o utilizador está dentro do período de trial de 7 dias
    private func isInFreeTrial(user: User) -> Bool {
        if let email = user.email?.lowercased(),
           Self.appleReviewEmails.contains(email) {
            return false
        }
        guard let creationDate = user.metadata.creationDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return days < betaTrialDays
    }

    /// Number of days remaining in the free trial (for banner display)
    func trialDaysRemaining(user: User) -> Int {
        guard let creationDate = user.metadata.creationDate else { return betaTrialDays }
        let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return max(0, betaTrialDays - days)
    }

    /// Returns true if the user's access comes from the free trial window (not a paid subscription)
    func isTrialActive(for user: User) -> Bool {
        isInFreeTrial(user: user)
    }

    /// Verifica se existe uma compra activa no StoreKit 2
    private func checkStoreKitEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               StoreKitManager.allIDs.contains(tx.productID) {
                return true
            }
        }
        return false
    }

    /// Lê o Custom Claim `isPremium` do Firebase ID Token
    private func checkFirebaseClaims(user: User) async {
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            isPremium = result.claims["isPremium"] as? Bool ?? false
        } catch {
            // Em erro de rede, usa o token em cache
            if let result = try? await user.getIDTokenResult(forcingRefresh: false) {
                isPremium = result.claims["isPremium"] as? Bool ?? false
            } else {
                isPremium = false
            }
        }
    }

    /// Força refresh — chamar após compra IAP ou volta do site (subscritores web)
    func refresh() async {
        guard let user = Auth.auth().currentUser else {
            isPremium = false
            isChecking = false
            return
        }
        await checkAccess(user: user)
    }

    // MARK: - Ponte App Group — assinatura única Alma ↔ Corpo & Alma (2026-07-14)
    // Contrato definido pelo AlmaBridge do Corpo & Alma (Models.swift):
    //   Alma escreve:  alma_active, alma_isPremium, alma_isPremium_updatedAt
    //   C&A escreve:   corpoealma_isPremium, corpoealma_isPremium_updatedAt
    // Validade dos flags: 30 dias (mesma janela usada pelo C&A).

    private static let sharedBridgeSuite = UserDefaults(suiteName: "group.com.almaapp.shared")
    private static let bridgeFreshness: TimeInterval = 60 * 60 * 24 * 30

    /// O usuário tem premium comprado no Corpo & Alma? (flag gravado pelo C&A)
    private static func corpoAlmaPremiumActive() -> Bool {
        guard let d = sharedBridgeSuite,
              let updated = d.object(forKey: "corpoealma_isPremium_updatedAt") as? Date,
              Date().timeIntervalSince(updated) < bridgeFreshness else { return false }
        return d.bool(forKey: "corpoealma_isPremium")
    }

    /// Publica o estado premium do Alma para o Corpo & Alma ler.
    private func publishToSharedBridge() {
        guard let d = Self.sharedBridgeSuite else { return }
        d.set(true, forKey: "alma_active")
        d.set(isPremium, forKey: "alma_isPremium")
        d.set(Date(), forKey: "alma_isPremium_updatedAt")
    }

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        if let observer = storeKitObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
