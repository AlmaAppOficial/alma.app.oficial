//
//  CorpoHomeView.swift
//  Corpo & Alma
//
//  Aba "Início" — visão geral do dia.
//

import SwiftUI

struct CorpoHomeView: View {
    /// [2026-08-04 — B-2] Estático para o harness ler o MESMO texto da tela.
    /// Era literal inline e por isso ficou fora da lista que a assertion B8b
    /// auditava — o sexto texto vendendo IA passou por baixo dela.
    static var subtituloDoBannerPremium: String {
        AIService.isRealAI
        ? "Planos personalizados, scan com IA e insights"
        : "Planos personalizados, acompanhamento e insights"
    }

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var health: HealthManager
    // [2026-08-05 — build 93] O botão da lua SAIU daqui, junto com
    // `aparencia`, `esquemaAtual` e `estaEscuroAgora`, que só existiam para
    // ele. Motivo em Shared/AparenciaDoApp.swift (seção "dívida conhecida"):
    // dentro do `fullScreenCover` do módulo Corpo a troca de aparência não
    // chegava à tela, nos dois sentidos, mesmo com escritor e leitor certos.
    // Um botão que não faz nada é pior que botão nenhum — e é risco de
    // Guideline 2.1 na revisão. A aparência agora tem UM lugar só no app:
    // Alma › Perfil › Modo escuro.
    @State private var showPaywall = false
    @State private var showSettings = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    greeting

                    premiumBanner

                    ringSummary

                    SectionTitle(text: "Seu dia")
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(model.todayMetrics) { metric in
                            MetricCard(metric: metric)
                        }
                    }

                    watchCard

                    waterCard
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .almaBackButton()
            .toolbar {
                // [2026-08-05 — build 93] `topBarLeading` com o botão da lua
                // REMOVIDO. Ver o comentário nas propriedades acima. A asserção
                // A26a reprova se ele voltar.
                // [2026-08-02] Botão que abria `alma://` REMOVIDO — mesma classe
                // do bug do Safari: dentro do app fundido não há app externo
                // para abrir. O caminho de volta é o .almaBackButton() acima,
                // com a logo real da Alma.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallDoCorpo() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            // Sincroniza dados do HealthKit com o model ao surgir e quando os valores mudam
            .onAppear { syncHealthToModel() }
            .onChange(of: health.steps) { _ in syncHealthToModel() }
            .onChange(of: health.activeCalories) { _ in syncHealthToModel() }
            .onChange(of: health.sleepHours) { _ in syncHealthToModel() }
        }
    }

    private func syncHealthToModel() {
        if let steps = health.steps { model.stepsToday = Int(steps) }
        if let cal = health.activeCalories { model.activeCaloriesBurned = Int(cal) }
        model.sleepHoursToday = health.sleepHours
    }

    // Banner de assinatura / teste grátis
    @ViewBuilder
    private var premiumBanner: some View {
        // [2026-08-02] Fusão: o banner "sua assinatura também desbloqueia o
        // Alma" e o de trial saíram. Não há mais dois apps para cruzar
        // assinatura, e o modelo não tem trial — assinante não vê banner algum.
        if model.isPremium || AlmaBridge.shared.almaHasPremium {
            EmptyView()
        } else {
            Button { showPaywall = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conheça o Premium")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        // [2026-07-28] DUAS correções em uma linha:
                        //  • Guideline 4.10 — "Apple Watch" saiu: a sincronização
                        //    com Watch/Saúde é capacidade nativa e NUNCA foi
                        //    bloqueada no código. Anunciá-la como benefício pago
                        //    foi exatamente o que gerou a rejeição de 28/07 — e
                        //    esta linha teria repetido a infração mesmo com a
                        //    paywall corrigida.
                        //  • Não existe oferta introdutória cadastrada no App
                        //    Store Connect (confirmado pelo Felipe em 28/07). O
                        //    modelo é freemium com trial de acesso no app, não
                        //    trial de cobrança. Prometer "7 dias grátis" aqui
                        //    seria alegação falsa.
                        // [2026-08-04 — B-2 da reauditoria] Dizia "Planos
                        // personalizados, scan com IA e insights". Era o SEXTO
                        // texto vendendo IA que a build não tem — e o pior
                        // deles, porque é o botão que leva ao paywall pago. A
                        // correção de ontem cobriu cinco textos e parou uma
                        // tela antes do botão.
                        Text(Self.subtituloDoBannerPremium)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.9))
                }
                .padding(16)
                .background(LinearGradient(colors: [Theme.primary, Theme.primaryDeep], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // Card do Apple Watch / HealthKit
    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Apple Watch", systemImage: "applewatch")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                // [2026-08-05 — build 93] O rótulo vem do HealthManager, que
                // é onde a regra mora: consulta vazia não vira "Desconectado".
                Pill(text: health.rotuloDoRelogio,
                     tint: health.watchConnected ? Theme.primary : Theme.inkSoft)
            }
            if health.isAuthorized {
                HStack(spacing: 0) {
                    watchStat(health.steps.map { "\(Int($0))" } ?? "—", "passos", "figure.walk")
                    Divider()
                    watchStat(health.restingHeartRate.map { "\(Int($0))" } ?? "—", "bpm", "heart.fill")
                    Divider()
                    watchStat(health.sleepHours.map { String(format: "%.1fh", $0) } ?? "—", "sono", "bed.double.fill")
                    Divider()
                    // [2026-08-04] Número compacto da pontuação de sono. "—"
                    // quando faltam os estágios: o card resumido nunca estima.
                    // A conta, a explicação e o aviso de que é estimativa do
                    // Alma ficam no card completo, na aba Saúde.
                    watchStat(pontuacaoDeSonoCompacta ?? "—", "pontuação", "moon.stars.fill")
                }
            } else {
                Text("Conecte o app Saúde para puxar passos, batimentos e sono do seu relógio automaticamente.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Button {
                    health.requestAuthorization()
                } label: {
                    Label("Conectar Saúde e relógio", systemImage: "heart.text.square.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
            }
        }
        .cardStyle()
    }

    /// `nil` quando não há noite com estágios — e aí o card mostra "—".
    /// Nunca cai para uma estimativa a partir da duração pura.
    private var pontuacaoDeSonoCompacta: String? {
        guard let noite = health.noiteDeSono,
              let pontos = PontuacaoDeSono.calcular(noite).pontos else { return nil }
        return "\(pontos)"
    }

    private func watchStat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(Theme.primary)
            Text(value).font(.headline.bold()).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // Saudação
    private var greeting: some View {
        // [2026-08-02] Antes o nome caía no padrão "Felipe" — todo usuário era
        // cumprimentado pelo nome do dono do app. Agora, sem nome informado, a
        // saudação simplesmente não tem nome. Nada é inventado.
        VStack(alignment: .leading, spacing: 4) {
            if let primeiroNome = model.userName.split(separator: " ").first.map(String.init),
               !primeiroNome.isEmpty {
                Text(saudacao + ",")
                    .font(.title3)
                    .foregroundStyle(Theme.inkSoft)
                Text(primeiroNome)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
            } else {
                Text(saudacao)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var saudacao: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Bom dia"
        case 12..<18: return "Boa tarde"
        default: return "Boa noite"
        }
    }

    // Anel grande de calorias
    private var ringSummary: some View {
        HStack(spacing: 20) {
            ZStack {
                // [Honestidade] Sem medidas não há meta — e sem meta não há anel
                // de progresso "contra" um número inventado.
                ProgressRing(
                    progress: model.kcalGoal.map { Double(model.kcalConsumed) / Double($0) } ?? 0,
                    tint: Theme.coral,
                    lineWidth: 12
                )
                .frame(width: 110, height: 110)
                VStack(spacing: 0) {
                    Text("\(model.kcalConsumed)")
                        .font(.title.bold())
                        .foregroundStyle(Theme.ink)
                    if let meta = model.kcalGoal {
                        Text("/ \(meta) kcal")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        Text("kcal hoje")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Energia de hoje")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                if let meta = model.kcalGoal {
                    Text("Faltam \(max(meta - model.kcalConsumed, 0)) kcal para sua meta diária.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text("Complete suas medidas para eu calcular sua meta.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                Pill(text: "\(model.proteinConsumed) g de proteína", tint: Theme.primary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // Hidratação com ação
    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Hidratação", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.azure)
                Spacer()
                Text("\(model.waterMl) / \(model.waterGoalMl) ml")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.azure.opacity(0.16))
                    Capsule().fill(Theme.azure)
                        .frame(width: geo.size.width * min(Double(model.waterMl) / Double(model.waterGoalMl), 1))
                }
            }
            .frame(height: 10)
            HStack(spacing: 10) {
                // [2026-08-03 — BUG B11] Registrar água exigia assinatura: o
                // usuário grátis via "0 / 2500 ml" para sempre. Isso contradizia
                // a régua que eu mesmo escrevi no CorpoAcesso no MESMO commit —
                // e deixava a Alma cega, porque sem registro não há contexto.
                Button {
                    model.addWater(250)
                } label: {
                    Label("250 ml", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.azure)

                Button {
                    model.addWater(500)
                } label: {
                    Label("500 ml", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.azure)
            }
        }
        .cardStyle()
    }

}

#Preview {
    CorpoHomeView()
        .environmentObject(AppModel())
        .environmentObject(HealthManager())
}
