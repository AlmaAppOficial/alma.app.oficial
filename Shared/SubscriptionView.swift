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
                               // [2026-08-04] "Monitorização" é PT-PT; em
                               // PT-BR é "monitoramento". Passou por dois
                               // pentes finos de PT-PT porque meu checador não
                               // tinha a palavra na lista — e ela estava no
                               // paywall, uma das telas mais vistas do app.
                               text: "Monitoramento de saúde avançado")
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

                // Auto-renewal disclosure (Apple Guideline 3.1.2)
                Text("Assinatura renovada automaticamente. Cancele a qualquer momento nas configurações da sua conta Apple.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

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

                // Termos (obrigatório pela Apple — Guideline 3.1.2(c) EULA + Privacy)
                HStack(spacing: 16) {
                    Link("Termos de Uso",
                         destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Text("·")
                        .foregroundColor(.white.opacity(0.4))
                    Link("Política de Privacidade",
                         destination: URL(string: "https://almaappoficial.com/privacy-policy")!)
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .task {
            await store.loadProducts()
        }
    }

    // MARK: - Subviews

    // [2026-07-28] Guideline 3.1.2(c) — hierarquia invertida.
    // Estava: "7 dias grátis" em 20pt bold branco (dominante) e o preço em
    // subheadline a 65% de opacidade (subordinado) — exatamente o que a Apple
    // rejeitou no Corpo & Alma em 28/07. Agora o VALOR COBRADO é o elemento de
    // preço mais claro e conspícuo, e o trial é nota subordinada.
    @ViewBuilder
    private var priceHeader: some View {
        if let product = store.monthlyProduct {
            VStack(spacing: 4) {
                Text("\(product.displayPrice)/mês")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                // [Build 84 — 2026-07-29] Freemium: nenhuma promessa de trial
                // em copy do app. Se a oferta introdutória do ASC estiver ativa,
                // a folha de pagamento da Apple a exibe por conta própria.
                Text("Cancele quando quiser.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
        // [2026-07-28] 3.1.2(c): CTA sem promoção do trial — o preço dominante
        // está no priceHeader; o trial é nota subordinada.
        let label: String = {
            if store.monthlyProduct != nil {
                return "Assinar agora"
            }
            // [2026-08-04] Era "Assinar Alma Plus" — nome que não existe em
            // lugar nenhum do app (Perfil e Início dizem "Alma Premium"), e
            // que aparecia justamente quando o produto do StoreKit NÃO
            // carregou: o usuário via um CTA sem preço, com nome errado.
            return "Assinar Alma Premium"
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
