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

// MARK: - FreemiumLimits [Build 84 — 2026-07-29; revisto em 2026-07-31]
// Modelo FREEMIUM: não existe mais trial de 7 dias. O app continua com
// bastante coisa grátis (meditações iniciais, sons, práticas, humor/check-in),
// mas o CHAT com a Alma é 100% premium.
//
// [2026-07-31 — decisão do Assis] chatMessagesPerDay = 0: nenhuma mensagem
// grátis. O usuário grátis vê a tela do chat e, ao enviar, encontra um convite
// ao Premium (não um erro nem um bloqueio seco).
// Continua parametrizável: subir para N libera N mensagens/dia sem tocar em
// mais nada — a UI se adapta sozinha (pill de cota some quando é 0).
//
// O contador usa o prefixo "alma_msg_count_" que o LocalDataCleanupService
// JÁ varre no logout/deleção — nenhuma limpeza extra necessária.
enum FreemiumLimits {

    /// Mensagens de chat grátis por dia para não-assinantes. 0 = chat premium puro.
    static let chatMessagesPerDay = 0

    /// Há alguma cota grátis configurada? (false = chat 100% premium)
    static var chatHasFreeQuota: Bool { chatMessagesPerDay > 0 }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "alma_msg_count_\(f.string(from: Date()))"
    }

    static func chatMessagesUsedToday() -> Int {
        UserDefaults.standard.integer(forKey: todayKey)
    }

    static func chatMessagesRemainingToday() -> Int {
        max(0, chatMessagesPerDay - chatMessagesUsedToday())
    }

    static func recordChatMessageSent() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: todayKey) + 1, forKey: todayKey)
    }
}

@MainActor
class AccessManager: ObservableObject {

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    private var storeKitObserver: NSObjectProtocol?

    @Published var isPremium: Bool = false
    @Published var isChecking: Bool = true

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

    /// Verifica acesso via StoreKit (IAP) ou Firebase Custom Claims.
    /// [Build 84 — 2026-07-29] Modelo freemium: o trial automático de 7 dias
    /// foi REMOVIDO. Não-assinante usa o app com limites (FreemiumLimits) e
    /// converte no paywall.
    func checkAccess(user: User) async {
        isChecking = true
        let previousValue = isPremium

        // 1. Verificar StoreKit — Apple IAP tem prioridade
        if await checkStoreKitEntitlement() {
            isPremium = true
        } else {
            // 2. Fallback: Firebase Custom Claims (subscritores web / Stripe)
            await checkFirebaseClaims(user: user)
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

    // [Build 84 — 2026-07-29] Trial automático de 7 dias removido (modelo
    // freemium). As contas de review da Apple deixam de precisar de exceção:
    // sem trial, todo não-assinante vê o paywall naturalmente.

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
