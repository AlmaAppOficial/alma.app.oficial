//
//  CorpoPaywallView.swift
//  Corpo & Alma
//
//  Tela de assinatura — plano Premium (modelo freemium, igual ao Alma).
//  Não há oferta introdutória cadastrada no App Store Connect: a cobrança
//  começa na compra. Todo texto de teste gratuito é condicionado a
//  StoreManager.isEligibleForIntroOffer, que só fica true se a oferta existir.
//

import SwiftUI
import StoreKit

struct CorpoPaywallView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .anual
    @State private var working = false

    enum Plan: String, CaseIterable, Identifiable {
        case anual, mensal
        var id: String { rawValue }
        var title: String { self == .anual ? "Anual" : "Mensal" }
        var price: String { self == .anual ? "R$ 199,90/ano" : "R$ 24,99/mês" }
        var highlight: Bool { self == .anual }
    }

    /// [2026-07-28] 3.1.2(c): o subtítulo do plano anual tinha valores FIXOS em
    /// R$ ("Equivale a R$ 16,65/mês · economize 33%") enquanto o preço real vem
    /// do StoreKit no storefront do usuário (ex.: US$ 29,99 no sandbox) —
    /// equivalência em moeda errada é exatamente o "calculated pricing"
    /// enganoso que a guideline proíbe. Agora tudo é derivado do produto real;
    /// sem produto carregado, texto neutro sem números.
    private func subText(_ p: Plan) -> String {
        guard p == .anual else { return "Cobrado mensalmente" }
        guard let annual = store.annualProduct else { return "Melhor valor no ano" }
        let perMonth = annual.price / 12
        var txt = "Equivale a \(perMonth.formatted(annual.priceFormatStyle))/mês"
        if let monthly = store.monthlyProduct, monthly.price > 0 {
            let yearAtMonthly = monthly.price * 12
            let pct = NSDecimalNumber(
                decimal: (yearAtMonthly - annual.price) / yearAtMonthly * 100
            ).intValue
            if pct > 0 { txt += " · economize \(pct)%" }
        }
        return txt
    }

    /// Produto StoreKit do plano escolhido.
    private func storeProduct(_ p: Plan) -> Product? {
        p == .anual ? store.annualProduct : store.monthlyProduct
    }

    private func priceText(_ p: Plan) -> String {
        if let product = storeProduct(p) {
            return product.displayPrice + (p == .anual ? "/ano" : "/mês")
        }
        return p.price
    }

    /// Só conclui a compra com um produto real do StoreKit. Sem produto → não faz nada
    /// (o botão fica desabilitado ou em estado de "tentar novamente"), evitando qualquer
    /// desbloqueio silencioso sem passar pela App Store.
    private func purchase() async {
        guard let product = storeProduct(plan) else { return }
        working = true
        defer { working = false }
        if await store.purchase(product) {
            model.activatePremium()
            dismiss()
        }
    }

    // [2026-07-28] Guideline 4.10: a sincronização com Apple Watch/Saúde é uma
    // capacidade nativa e NUNCA foi bloqueada no código — anunciá-la como
    // benefício pago fez a Apple entender que cobrávamos por ela. Removida da
    // lista; no lugar entrou o scan com IA (este sim, premium de verdade).
    private let benefits: [(String, String)] = [
        ("figure.run", "Planos de treino e refeição personalizados"),
        ("camera.viewfinder", "Scan corporal e de alimentos com IA"),
        ("chart.xyaxis.line", "Insights avançados e relatórios semanais"),
        ("fork.knife", "Banco de alimentos completo + código de barras"),
        ("moon.stars.fill", "Integração total com o app Alma")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Theme.primary, Theme.primaryDeep],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    closeButton

                    VStack(spacing: 10) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                        Text("Corpo & Alma Premium")
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        // [2026-07-28] 3.1.2(c): o trial não pode ser o destaque
                        // do fluxo — o valor cobrado é que deve dominar (abaixo).
                        Text("Desbloqueie a experiência completa.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .padding(.top, 4)

                    if store.partnerHasPremium {
                        Label("Desbloqueado pela sua assinatura Alma 💜", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    benefitsCard
                    plansSelector

                    // [2026-07-28] 3.1.2(c): o VALOR COBRADO é o elemento de preço
                    // mais claro e conspícuo do fluxo (título grande, branco puro,
                    // imediatamente acima do CTA). O trial aparece apenas como nota
                    // subordinada, em fonte menor.
                    VStack(spacing: 4) {
                        Text(priceText(plan))
                            .font(.title.bold())
                            .foregroundStyle(.white)
                        // [2026-07-28] NÃO existe oferta introdutória cadastrada
                        // no App Store Connect — o modelo é freemium (acesso
                        // gratuito limitado + assinatura). A cobrança começa na
                        // compra. A guarda `isEligibleForIntroOffer` fica como
                        // rede de segurança: se um dia a oferta for criada em
                        // ASC, o texto volta sozinho e correto.
                        if store.isEligibleForIntroOffer {
                            Text("7 dias grátis antes da primeira cobrança.")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }

                    ctaButton

                    // [2026-07-28] Guideline 4 (tipografia): caption2 a 70% de opacidade
                    // sobre gradiente era ilegível — subido para footnote a 90%.
                    Text(store.isEligibleForIntroOffer
                         ? "Renovação automática. Você pode cancelar a qualquer momento em Ajustes > Apple ID > Assinaturas. O teste gratuito de 7 dias converte no plano escolhido se não for cancelado."
                         : "Renovação automática. Você pode cancelar a qualquer momento em Ajustes > Apple ID > Assinaturas.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 18) {
                        Button("Restaurar compras") {
                            Task {
                                await store.restore()
                                if store.hasActiveSubscription { model.activatePremium() }
                                dismiss()
                            }
                        }
                        Link("Termos", destination: URL(string: "https://almaappoficial.com/corpo-e-alma/terms")!)
                        Link("Privacidade", destination: URL(string: "https://almaappoficial.com/corpo-e-alma/privacy")!)
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                }
                .padding(20)
            }
        }
        // [2026-07-28] Guideline 4 — CAUSA RAIZ da "hard to read typography":
        // os cards do paywall têm fundo .white FIXO, mas os textos usam
        // Theme.ink, que é adaptativo (dark mode → ECF0E8, quase branco).
        // No modo escuro ficava texto branco sobre card branco — ilegível,
        // exatamente o que os screenshots do App Review mostram. Como este
        // design é fixo (gradiente verde + cards brancos), o paywall inteiro
        // é travado no esquema CLARO: todas as cores adaptativas internas
        // resolvem para as variantes legíveis, em qualquer aparência.
        .environment(\.colorScheme, .light)
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(benefits, id: \.1) { icon, text in
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(Theme.primary)
                        .frame(width: 28)
                    Text(text)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(18)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private var plansSelector: some View {
        VStack(spacing: 12) {
            ForEach(Plan.allCases) { p in
                Button { plan = p } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(p.title)
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                if p.highlight {
                                    Text("MAIS POPULAR")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(Theme.coral)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(subText(p))
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Text(priceText(p))
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.ink)
                        Image(systemName: plan == p ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(plan == p ? Theme.primary : Theme.inkSoft.opacity(0.4))
                    }
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .stroke(plan == p ? Theme.primary : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ctaButton: some View {
        Button {
            Task {
                if store.loadState == .failed { await store.load() }
                else { await purchase() }
            }
        } label: {
            HStack(spacing: 8) {
                if working || store.loadState == .loading {
                    ProgressView().tint(Theme.primaryDeep)
                }
                Text(ctaTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white)
            .foregroundStyle(Theme.primaryDeep)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
        .disabled(ctaDisabled)
        .task { await store.load() }
    }

    private var ctaTitle: String {
        switch store.loadState {
        case .loading: return "Carregando planos…"
        case .failed:  return "Tentar novamente"
        // [2026-07-28] 3.1.2(c): CTA sem promoção do trial — o preço dominante
        // está logo acima do botão; o trial é nota subordinada.
        default:       return "Assinar agora"
        }
    }

    /// A compra só habilita com um produto real carregado. Em falha de carregamento,
    /// o botão habilita para permitir nova tentativa (retry manual), nunca uma compra falsa.
    private var ctaDisabled: Bool {
        if store.loadState == .failed { return false }
        return working || store.loadState == .loading || storeProduct(plan) == nil
    }
}

#Preview {
    CorpoPaywallView()
        .environmentObject(AppModel())
        .environmentObject(StoreManager())
}
