import SwiftUI
import StoreKit

// MARK: - SubscriptionManager
@MainActor
class SubscriptionManager: ObservableObject {
    
    @Published var isPremium = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var product: Product?
    let productId = "alma_premium_monthly" // o ID que criaste no App Store Connect
    
    init() {
        Task {
            await loadProduct()
            await checkSubscriptionStatus()
        }
    }
    
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productId])
            product = products.first
        } catch {
            errorMessage = "Erro ao carregar planos."
        }
    }
    
    func purchase() async {
        guard let product = product else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified:
                    isPremium = true
                case .unverified:
                    errorMessage = "Compra não verificada."
                }
            case .userCancelled:
                break
