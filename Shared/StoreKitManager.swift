// StoreKitManager.swift
// Alma App — In-App Purchase via Apple StoreKit 2
//
// Product IDs no App Store Connect:
//   com.almaapp.app.premium_monthly  → Assinatura mensal (grupo 22008487)
//   com.almaapp.app.premium_annual   → Assinatura anual — AINDA NÃO EXISTE no
//                                      ASC. O app já sabe carregá-la; enquanto
//                                      o produto não for criado, o StoreKit
//                                      devolve só o mensal e nenhuma tela
//                                      oferece o anual.
//
// [2026-08-04] Este cabeçalho dizia "Assinatura mensal com 7 dias grátis" e
// "Assinatura anual com 7 dias grátis". NÃO HÁ TRIAL. Nunca houve oferta
// introdutória cadastrada neste grupo de assinatura. O modelo é freemium:
// parte do app é grátis, o Premium é pago desde a primeira cobrança. Comentário
// errado vira copy errada na próxima pessoa que ler o arquivo — foi assim que
// a promessa de 7 dias sobreviveu a três limpezas.
//
// Como verificar no App Store Connect:
//   App Store Connect → Alma App Oficial → Monetização → Assinaturas

import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {

    // MARK: - Product IDs

    static let monthlyID = "com.almaapp.app.premium_monthly"
    static let annualID  = "com.almaapp.app.premium_annual"
    static let allIDs: Set<String> = [monthlyID, annualID]

    // MARK: - Published State

    @Published var products: [Product]    = []
    @Published var isPurchasing: Bool     = false
    @Published var purchaseError: String? = nil

    /// O usuário ainda teria direito a uma oferta introdutória, SE existisse uma?
    ///
    /// ⚠️ Leia o nome com cuidado: `isEligibleForIntroOffer` responde sobre a
    /// ELEGIBILIDADE DA PESSOA (ela já consumiu uma oferta neste grupo?), e não
    /// sobre a EXISTÊNCIA da oferta. Num produto sem oferta cadastrada — o nosso
    /// caso — ele devolve `true` para todo mundo que nunca assinou.
    ///
    /// Portanto esta propriedade sozinha NUNCA autoriza uma frase de trial na
    /// tela. Quem quiser anunciar oferta tem de checar também
    /// `product.subscription?.introductoryOffer != nil` e tirar o período e o
    /// valor de lá. Ver `CorpoPaywallView.descricaoDaOferta`.
    @Published var isEligibleForIntroOffer: Bool = false

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            // Mensal primeiro, anual depois
            products = loaded.sorted { lhs, rhs in
                if lhs.id == Self.monthlyID { return true }
                if rhs.id == Self.monthlyID { return false }
                return false
            }
            await refreshIntroOfferEligibility()
        } catch {
            print("[StoreKit] Erro ao carregar produtos: \(error)")
        }
    }

    /// Pergunta ao StoreKit se o usuário ainda tem direito à oferta introdutória.
    /// A elegibilidade é por **grupo de assinatura**, então basta consultar um
    /// produto. Em qualquer falha, mantém `false` — nunca prometemos por engano.
    func refreshIntroOfferEligibility() async {
        guard let subscription = products.first?.subscription else {
            isEligibleForIntroOffer = false
            return
        }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                NotificationCenter.default.post(name: .storeKitPurchaseCompleted, object: nil)
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Compra pendente de aprovação."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Erro ao processar compra. Tente novamente."
            print("[StoreKit] Erro de compra: \(error)")
            return false
        }
    }

    // MARK: - Restore Purchases

    @discardableResult
    func restorePurchases() async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            let active = await hasActiveEntitlement()
            if active {
                NotificationCenter.default.post(name: .storeKitPurchaseCompleted, object: nil)
            }
            return active
        } catch {
            purchaseError = "Erro ao restaurar compras. Verifique sua conexão."
            print("[StoreKit] Erro restore: \(error)")
            return false
        }
    }

    // MARK: - Check Entitlement

    func hasActiveEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               Self.allIDs.contains(tx.productID) {
                return true
            }
        }
        return false
    }

    // MARK: - Convenience

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct:  Product? { products.first { $0.id == Self.annualID } }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if let tx = try? await MainActor.run(body: { try self.checkVerified(result) }) {
                    await tx.finish()
                    NotificationCenter.default.post(name: .storeKitPurchaseCompleted, object: nil)
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let storeKitPurchaseCompleted = Notification.Name("storeKitPurchaseCompleted")
}
