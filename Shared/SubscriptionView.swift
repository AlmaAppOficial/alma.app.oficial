// SubscriptionView.swift (PremiumWallView)
// Alma App — Ecrã de paywall com Apple In-App Purchase
//
// CONFORMIDADE Apple Guideline 3.1.1:
//   ✅ Compra feita via StoreKit (Apple IAP) — sem links externos para pagamento
//   ✅ Botão "Restaurar compras" para utilizadores que já compraram
//   ✅ Subscritores web existentes podem usar "Já subscrevi" para verificar via Firebase

import SwiftUI
import StoreKit

// MARK: - PremiumWallView

struct PremiumWallView: View {

    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store: StoreKitManager
    @State private var isRefreshing   = false
    @State private var localError: String? = nil

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.14),
                    Color(red: 0.18, green: 0.16, blue: 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                AlmaLogoView(size: 88, animated: true)
                    .padding(.bottom, 24)

                // Título
                Text("Bem-vindo à Alma")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 10)

                // Preço dinâmico (quando carregado do App Store)
                priceHeader
                    .padding(.bottom, 32)

                // Feature list
                VStack(spacing: 14) {
                    featureRow(icon: "bubble.left.and.bubble.right.fill",
                               text: "Conversas ilimitadas com a Alma")
                    featureRow(icon: "waveform.path.ecg",
                               text: "Monitorização de saúde avançada")
                    featureRow(icon: "music.note",
                               text: "Sons binaurais e meditações guiadas")
                    featureRow(icon: "chart.line.uptrend.xyaxis",
                               text: "Insights e diário emocional completo")
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 44)

                Spacer()

                // Mensagem de erro
                if let error = localError ?? store.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 10)
                }

                // CTA principal: comprar via Apple IAP
                subscribeButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                // Restaurar compras
                Button {
                    Task {
                        localError = nil
                        isRefreshing = true
                        let restored = await store.restorePurchases()
                        if restored {
                            await access.refresh()
                        } else if store.purchaseError == nil {
                            localError = "Nenhuma compra encontrada para restaurar."
                        }
                        isRefreshing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRefreshing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isRefreshing ? "A verificar…" : "Restaurar compras")
                    }
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.55))
                .disabled(isRefreshing || store.isPurchasing)
                .padding(.bottom, 8)

                // Termos (obrigatório pela Apple)
                Text("Renovação automática · Cancelamento a qualquer momento\nTermos de serviço · Política de privacidade")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.32))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
            }
        }
        .task {
            await store.loadProducts()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var priceHeader: some View {
        if let product = store.monthlyProduct {
            VStack(spacing: 4) {
                Text("7 dias grátis")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("depois \(product.displayPrice)/mês · Cancele quando quiser")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.65))
            }
        } else {
            Text("Acesso completo a todas as funcionalidades.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
                .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var subscribeButton: some View {
        let label: String = {
            if store.monthlyProduct != nil {
                return "Iniciar 7 dias grátis"
            }
            return "Assinar Alma Plus"
        }()

        Button {
            Task {
                localError = nil
                guard let product = store.monthlyProduct else {
                    localError = "Produto não disponível. Tenta mais tarde."
                    return
                }
                let success = await store.purchase(product)
                if success {
                    await access.refresh()
                }
            }
        } label: {
            Group {
                if store.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(
                            tint: Color(red: 0.22, green: 0.20, blue: 0.45)
                        ))
                } else {
                    Text(label)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .foregroundColor(Color(red: 0.22, green: 0.20, blue: 0.45))
            .cornerRadius(16)
        }
        .disabled(store.isPurchasing)
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.68, green: 0.65, blue: 0.90))
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.88))
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PremiumWallView()
        .environmentObject(AccessManager())
        .environmentObject(StoreKitManager())
}
