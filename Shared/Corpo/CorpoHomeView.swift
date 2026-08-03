//
//  CorpoHomeView.swift
//  Corpo & Alma
//
//  Aba "Início" — visão geral do dia.
//

import SwiftUI

struct CorpoHomeView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var health: HealthManager
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation { model.appearanceMode = (model.colorScheme == .dark) ? "light" : "dark" }
                    } label: {
                        Image(systemName: model.colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                    }
                    .accessibilityLabel("Alternar modo claro/escuro")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Botão Alma — abre o app de meditação
                    Button {
                        if let url = URL(string: "alma://"), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else if let storeURL = URL(string: "https://apps.apple.com/app/alma/id6504892787") {
                            UIApplication.shared.open(storeURL)
                        }
                    } label: {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(Theme.violet)
                    }
                    .accessibilityLabel("Abrir app Alma — Meditação")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { CorpoPaywallView() }
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
        if model.isPremium {
            Button { AlmaBridge.openAlmaApp() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sua assinatura também desbloqueia o Alma 💜")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Abrir o Alma")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.primary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                }
            }
            .buttonStyle(.plain)
            .cardStyle(padding: 14)
        } else if AlmaBridge.shared.almaHasPremium {
            EmptyView()
        } else if model.isTrialActive {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                Text("Teste Premium ativo — faltam \(model.trialDaysRemaining) dias")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Ver plano") { showPaywall = true }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primary)
            }
            .cardStyle(padding: 14)
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
                        Text("Planos personalizados, scan com IA e insights")
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
                if health.watchConnected {
                    Pill(text: "Conectado", tint: Theme.primary)
                } else {
                    Pill(text: "Desconectado", tint: Theme.inkSoft)
                }
            }
            if health.isAuthorized {
                HStack(spacing: 0) {
                    watchStat(health.steps.map { "\(Int($0))" } ?? "—", "passos", "figure.walk")
                    Divider()
                    watchStat(health.restingHeartRate.map { "\(Int($0))" } ?? "—", "bpm", "heart.fill")
                    Divider()
                    watchStat(health.sleepHours.map { String(format: "%.1fh", $0) } ?? "—", "sono", "bed.double.fill")
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
        VStack(alignment: .leading, spacing: 4) {
            Text(saudacao + ",")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
            Text(model.userName)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
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
                Button {
                    if model.hasPremiumAccess { model.addWater(250) }
                    else { showPaywall = true }
                } label: {
                    Label("250 ml", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.azure)

                Button {
                    if model.hasPremiumAccess { model.addWater(500) }
                    else { showPaywall = true }
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
