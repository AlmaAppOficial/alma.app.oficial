// StoreKitManager.swift
// Alma App — In-App Purchase via Apple StoreKit 2
//
// Product IDs a criar no App Store Connect:
//   com.almaapp.app.monthly   → Assinatura mensal renovável (com 7 dias grátis)
//   com.almaapp.app.lifetime  → Compra única vitalícia
//
// Como criar no App Store Connect:
//   App Store Connect → Teu App → Monetização → Compras no Aplicativo
//   Adicionar cada produto, definir preço e período de trial

import StoreKit
import SwiftUI

@MainActor
class StoreKitManager: ObservableObject {

    // MARK: - Product IDs

    static let monthlyID  = "com.almaapp.app.monthly"
    static let lifetimeID = "com.almaapp.app.lifetime"
    static let allIDs: Set<String> = [monthlyID, lifetimeID]

    // MARK: - Published State

    @Published var products: [Product]   = []
    @Published var isPurchasing: Bool    = false
    @Published var purchaseError: String? = nil

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
            // monthly primeiro, lifetime depois
            products = loaded.sorted { $0.id == Self.monthlyID && $1.id != Self.monthlyID }
        } catch {
            print("[StoreKit] Erro ao carregar produtos: \(error)")
        }
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
            purchaseError = "Erro ao processar compra. Tenta novamente."
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
            purchaseError = "Erro ao restaurar compras. Verifica a tua ligação."
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
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) {
            for await result in Transaction.updates {
                if let tx = try? await MainActor.run(body: { self.checkVerified(result) }) {
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
