//
//  StoreManager.swift
//  Corpo & Alma
//
//  Assinaturas via StoreKit 2. Funciona com o arquivo Products.storekit (teste local)
//  e com os produtos reais do App Store Connect (mesmos IDs).
//

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedIDs: Set<String> = []
    @Published var loaded = false
    /// Estado do carregamento dos produtos — a paywall reage a isto em vez de cair em fallback silencioso.
    enum LoadState { case idle, loading, loaded, failed }
    @Published var loadState: LoadState = .idle

    /// [2026-07-28] O usuário ainda pode receber os 7 dias grátis?
    ///
    /// A oferta introdutória é consumida uma única vez por Apple ID / grupo de
    /// assinatura. A paywall só menciona o teste quando o StoreKit confirma a
    /// elegibilidade — anunciar um trial que a App Store não vai honrar é
    /// alegação enganosa (Guideline 3.1.2).
    ///
    /// Começa `false` e só vira `true` com confirmação: em falha de rede,
    /// preferimos não anunciar um teste real a anunciar um inexistente.
    @Published var isEligibleForIntroOffer: Bool = false

    // [2026-08-03 — BUG B10 da revisão independente]
    //
    // Aqui estavam `com.almaapp.corpoealma.premium.annual/monthly` — produtos do
    // app Corpo & Alma, que foi DESCONTINUADO, pedidos de dentro do binário do
    // Alma. Como esses IDs não existem no App Store Connect deste app, o
    // StoreKit devolvia lista vazia: o paywall do Corpo ficava eternamente em
    // "Tentar novamente" exibindo preços chumbados no código, e "Restaurar
    // compras" nunca reconhecia a assinatura de quem tinha pago.
    //
    // Agora o módulo Corpo consulta os MESMOS produtos do Alma. Assinatura
    // única, como o Assis decidiu em julho: um produto, um preço, um lugar.
    static let annualID  = StoreKitManager.annualID
    static let monthlyID = StoreKitManager.monthlyID
    private let productIDs = [StoreManager.annualID, StoreManager.monthlyID]

    /// O usuário tem assinatura ativa no Alma? (lido via App Group)
    var partnerHasPremium: Bool { AlmaBridge.shared.almaHasPremium }


    /// Produto mensal a oferecer. Modelo de assinatura única (2026-07-18):
    /// assinante do Alma já desbloqueia este app — não existe oferta paga separada para parceiros.
    func offeredMonthlyProduct() -> Product? {
        return product(StoreManager.monthlyID)
    }

    // Conveniências usadas pela paywall.
    var annualProduct: Product? { product(StoreManager.annualID) }
    /// Mensal já com desconto cross-app aplicado quando elegível.
    var monthlyProduct: Product? { offeredMonthlyProduct() }

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
    }

    deinit { updatesTask?.cancel() }

    /// True se há qualquer assinatura ativa.
    var hasActiveSubscription: Bool { !purchasedIDs.isEmpty }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - Carregamento

    func load() async {
        if loadState == .loaded, !products.isEmpty { return }
        loadState = .loading
        // Tentativas com backoff — o sandbox da App Review pode demorar a propagar os produtos.
        let backoff: [UInt64] = [0, 500_000_000, 1_500_000_000, 3_000_000_000] // 0, 0.5s, 1.5s, 3s
        for (attempt, delay) in backoff.enumerated() {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
            do {
                let fetched = try await Product.products(for: productIDs)
                if !fetched.isEmpty {
                    products = fetched.sorted { $0.price > $1.price }   // anual primeiro
                    await refreshEntitlements()
                    await refreshIntroOfferEligibility()
                    loaded = true
                    loadState = .loaded
                    return
                }
            } catch {
                print("StoreKit — falha ao carregar produtos (tentativa \(attempt + 1)): \(error)")
            }
        }
        await refreshEntitlements()
        await refreshIntroOfferEligibility()
        loaded = true
        loadState = products.isEmpty ? .failed : .loaded
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

    // MARK: - Compra / restauração

    /// Retorna true se a compra foi concluída e verificada.
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return true
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("StoreKit — erro na compra: \(error)")
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                ids.insert(transaction.productID)
            }
        }
        purchasedIDs = ids
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
