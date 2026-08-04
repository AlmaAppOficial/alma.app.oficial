//
//  CorpoPaywallView.swift
//  Corpo & Alma
//
//  Tela de assinatura — plano Premium (modelo freemium, igual ao Alma).
//
//  [2026-08-04 — bug de app relatado pelo Assis]
//  Esta tela carregava DOIS preços escritos à mão ("R$ 199,90/ano" e
//  "R$ 24,99/mês") como fallback de quando o StoreKit não respondia. Nenhum dos
//  dois existe no App Store Connect. Um app que mostra um preço e cobra outro é
//  a infração 3.1.2(c) na veia — e, pior que a infração, é uma mentira para a
//  pessoa que está prestes a pagar.
//
//  Regra agora: TODO preço desta tela vem de `Product.displayPrice`, no
//  storefront e na moeda do usuário. Sem produto carregado não há número
//  nenhum — a tela ADMITE que não conseguiu carregar e oferece nova tentativa.
//  Preço inventado nunca mais.
//
//  Consequência prática: o plano ANUAL não existe no ASC (grupo 22008487 só tem
//  o mensal). Por isso ele simplesmente NÃO aparece — em vez de aparecer com um
//  valor fantasia ou com um botão que leva a lugar nenhum. No dia em que o
//  produto anual for criado, ele aparece sozinho, sem tocar em código.
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
        /// Sufixo do período. O VALOR vem sempre do StoreKit — aqui só o "/ano".
        var sufixo: String { self == .anual ? "/ano" : "/mês" }
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

    /// Planos que a App Store realmente vende agora. Um plano sem produto
    /// carregado não é oferecido — não há preço para mostrar, e mostrar um
    /// plano sem preço é convidar a pessoa para um beco sem saída.
    static func planosVendaveis(anual: Product?, mensal: Product?) -> [Plan] {
        Plan.allCases.filter { $0 == .anual ? anual != nil : mensal != nil }
    }

    private var planosVendaveis: [Plan] {
        Self.planosVendaveis(anual: store.annualProduct, mensal: store.monthlyProduct)
    }

    /// `nil` quando não há produto. Quem chama é obrigado a lidar com a
    /// ausência — é isso que impede o retorno silencioso a um valor inventado.
    private func priceText(_ p: Plan) -> String? {
        guard let product = storeProduct(p) else { return nil }
        return product.displayPrice + p.sufixo
    }

    /// O que a tela diz no lugar do preço quando não há produto.
    /// [2026-08-04] Texto de INDISPONIBILIDADE, nunca um número de reserva.
    static let precoIndisponivel = "Preço indisponível agora"
    static let precoIndisponivelDetalhe =
        "Não consegui falar com a App Store. O valor e o período aparecem aqui "
      + "antes de qualquer cobrança — nada é cobrado sem a Apple confirmar."

    // MARK: - Oferta introdutória
    //
    // [2026-08-04] Aqui havia `if store.isEligibleForIntroOffer { Text("7 dias
    // grátis antes da primeira cobrança.") }`. Dois erros num `if` só:
    //
    //   1. o "7 dias" era escrito à mão e não corresponde a oferta nenhuma —
    //      não existe oferta introdutória cadastrada no ASC;
    //   2. `isEligibleForIntroOffer` responde *"esta pessoa PODERIA receber uma
    //      oferta introdutória"*, e não *"existe uma oferta introdutória"*. Num
    //      produto sem oferta cadastrada — exatamente o nosso caso — ele volta
    //      `true` para todo mundo que nunca assinou. A promessa de trial
    //      aparecia, portanto, para TODO usuário novo.
    //
    // Agora o texto é derivado da oferta que o StoreKit entrega. Sem oferta,
    // sem frase. E o período vem da Apple, não de mim.

    /// Descrição da oferta a partir do que a Apple devolve — nunca escrita à mão.
    static func descricaoDaOferta(_ oferta: Product.SubscriptionOffer) -> String? {
        let periodo = textoDePeriodo(oferta.period)
        if oferta.paymentMode == .freeTrial {
            return "\(periodo) grátis antes da primeira cobrança."
        }
        if oferta.paymentMode == .payUpFront {
            return "\(oferta.displayPrice) pelo primeiro período de \(periodo)."
        }
        if oferta.paymentMode == .payAsYouGo {
            return "\(oferta.displayPrice) por \(periodo) e depois o valor cheio."
        }
        return nil
    }

    static func textoDePeriodo(_ p: Product.SubscriptionPeriod) -> String {
        let n = p.value
        let unidade: String
        switch p.unit {
        case .day:   unidade = n == 1 ? "dia" : "dias"
        case .week:  unidade = n == 1 ? "semana" : "semanas"
        case .month: unidade = n == 1 ? "mês" : "meses"
        case .year:  unidade = n == 1 ? "ano" : "anos"
        @unknown default: unidade = "período"
        }
        return "\(n) \(unidade)"
    }

    private var textoDaOfertaIntrodutoria: String? {
        guard let produto = storeProduct(plan),
              let oferta = produto.subscription?.introductoryOffer,
              store.isEligibleForIntroOffer else { return nil }
        return Self.descricaoDaOferta(oferta)
    }

    /// Se o plano selecionado não é vendável (caso do anual hoje), cai para o
    /// primeiro que é. Sem isto a tela abriria já apontando para um plano sem
    /// preço e com o botão desabilitado.
    private func ajustarPlanoSelecionado() {
        guard !planosVendaveis.contains(plan), let primeiro = planosVendaveis.first else { return }
        plan = primeiro
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
    // [2026-08-03 — BUG B8 da revisão independente]
    //
    // Esta lista vendia duas coisas que não existem neste build:
    //   • "Scan corporal e de alimentos com IA" — não há GEMINI_API_KEY no
    //     GoogleService-Info.plist. O scan de alimento devolve erro SEMPRE, e o
    //     corporal cai num gerador offline por medidas — que ainda simulava
    //     1,3 s de "processamento" sob um overlay dizendo "Analisando com IA…".
    //   • "relatórios semanais" — não existem em build nenhum.
    //
    // A regra do Assis é a mesma de sempre: ou implementa de verdade, ou não
    // vende. Como ligar a IA exige rotear pela Cloud Function (trabalho de
    // outro ciclo), a escolha aqui foi parar de vender e descrever o que o app
    // realmente entrega. Quando a IA entrar, esta lista volta a crescer.
    private let benefits: [(String, String)] = [
        ("figure.run", "Planos de treino e refeição personalizados"),
        ("chart.xyaxis.line", "Histórico completo e evolução ao longo do tempo"),
        ("fork.knife", "Banco de alimentos completo + código de barras"),
        ("drop.fill", "Metas de água e calorias calculadas para o seu corpo"),
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
                    // imediatamente acima do CTA).
                    VStack(spacing: 4) {
                        if let preco = priceText(plan) {
                            Text(preco)
                                .font(.title.bold())
                                .foregroundStyle(.white)
                        } else {
                            // [2026-08-04] Aqui morava o preço inventado. Agora a
                            // tela diz a verdade: não sei o preço, então não te
                            // mostro número nenhum.
                            Text(Self.precoIndisponivel)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Text(Self.precoIndisponivelDetalhe)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        if let intro = textoDaOfertaIntrodutoria {
                            Text(intro)
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }

                    ctaButton

                    // [2026-07-28] Guideline 4 (tipografia): caption2 a 70% de opacidade
                    // sobre gradiente era ilegível — subido para footnote a 90%.
                    // [2026-08-04] A variante longa citava "o teste gratuito de 7
                    // dias" com o número escrito à mão. Saiu junto com o resto.
                    Text("Renovação automática. Você pode cancelar a qualquer momento em Ajustes > Apple ID > Assinaturas.")
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
        // [2026-08-04] Removido o `.environment(\.colorScheme, .light)` que
        // forçava o paywall do Corpo em claro mesmo com o app em escuro — a
        // pegadinha que o CLAUDE.md já registrava. A aparência agora vem de uma
        // fonte só (`isDarkMode`, aplicada em CorpoModuleView).
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
            // [2026-08-04] Era `ForEach(Plan.allCases)`: o plano anual aparecia
            // sempre, com preço chumbado, mesmo não existindo no App Store
            // Connect. Agora só entra na lista o plano que a App Store vende.
            ForEach(planosVendaveis) { p in
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
                        Text(priceText(p) ?? "—")
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
        .task {
            await store.load()
            ajustarPlanoSelecionado()
        }
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
