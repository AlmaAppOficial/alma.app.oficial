import Foundation
import StoreKit

class SubscriptionManager: NSObject, ObservableObject {
    @Published var isPremium = false
    @Published var products: [Product] = []

    override init() {
        super.init()
        Task {
            await checkSubscriptionStatus()
            await loadProducts()
        }
    }

    @MainActor
    func checkSubscriptionStatus() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                self.isPremium = true
            }
        }
    }

    @MainActor
    func loadProducts() async {
        do {
            let products = try await Product.products(for: ["com.alma.premium"])
            self.products = products
        } catch {
            print("Error loading products: \(error)")
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified = verification {
                    self.isPremium = true
                    return true
                }
            default:
                break
            }
        } catch {
            print("Purchase error: \(error)")
        }
        return false
    }
}
