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

    @Published var isPremium: Bool = false
    @Published var isChecking: Bool = true

    init() {
        // Ouvir mudanças de autenticação Firebase
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.checkAccess(user: user)
                } else {
                    self?.isPremium = false
                    self?.isChecking = false
                }
            }
        }

        // Ouvir compras StoreKit concluídas (vindas de qualquer parte da app)
        NotificationCenter.default.addObserver(
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
        } else {
            // 2. Fallback: Firebase Custom Claims (subscritores web / Stripe)
            await checkFirebaseClaims(user: user)

            // 3. Trial gratuito de 7 dias após criação da conta
            if !isPremium && isInFreeTrial(user: user) {
                isPremium = true
            }
        }

        isChecking = false

        // 🎯 Meta Ads: dispara StartTrial apenas na transição false → true
        if !previousValue && isPremium {
            MetaEventsManager.shared.trackStartTrial()
        }
    }

    /// Trial gratuito de 7 dias após criação da conta
    private let betaTrialDays = 7

    /// Verifica se o utilizador está dentro do período de trial de 7 dias
    private func isInFreeTrial(user: User) -> Bool {
        guard let creationDate = user.metadata.creationDate else { return true }
        let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return days < betaTrialDays
    }

    /// Número de dias restantes do trial (para exibição no banner)
    func trialDaysRemaining(user: User) -> Int {
        guard let creationDate = user.metadata.creationDate else { return betaTrialDays }
        let days = Calendar.current.dateComponents([.day], from: creationDate, to: Date()).day ?? 0
        return max(0, betaTrialDays - days)
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
}
