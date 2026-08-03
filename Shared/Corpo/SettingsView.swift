//
//  SettingsView.swift
//  Corpo & Alma
//
//  Perfil e ajustes — assinatura, saúde/dispositivos, conexão Alma e legal.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var store: StoreManager
    // [Fusão] auth removido — a conta é do Alma.
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showDisclaimer = false

    var body: some View {
        NavigationStack {
            Form {
                // Perfil
                Section {
                    HStack(spacing: 14) {
                        Text(initials)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Theme.primary)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.userName).font(.headline)
                            Text(model.goal.rawValue).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusBadge
                    }
                    .padding(.vertical, 4)
                }

                // Assinatura
                Section("Assinatura") {
                    Button { showPaywall = true } label: {
                        Label(model.hasPremiumAccess ? "Gerenciar plano" : "Conhecer o Premium",
                              systemImage: "leaf.circle.fill")
                    }
                    Button {
                        Task {
                            await store.restore()
                            if store.hasActiveSubscription { model.activatePremium() }
                        }
                    } label: {
                        Label("Restaurar compras", systemImage: "arrow.clockwise")
                    }
                    if model.isPremium {
                        Button { AlmaBridge.openAlmaApp() } label: {
                            Label("Sua assinatura também desbloqueia o Alma 💜 — Abrir o Alma",
                                  systemImage: "arrow.up.forward.app.fill")
                        }
                    }
                }

                // Saúde e dispositivos
                Section("Saúde e dispositivos") {
                    HStack {
                        Label("Apple Watch", systemImage: "applewatch")
                        Spacer()
                        Text(health.watchConnected ? "Conectado" : "—").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("App Saúde", systemImage: "heart.fill")
                        Spacer()
                        Text(health.isAuthorized ? "Conectado" : "Desconectado").foregroundStyle(.secondary)
                    }
                    if !health.isAuthorized {
                        Button { health.requestAuthorization() } label: {
                            Label("Conectar agora", systemImage: "heart.text.square.fill")
                        }
                    }
                }

                // Lembretes (notificações locais)
                secaoLembretes

                // Conexão com o Alma
                Section("App Alma") {
                    HStack {
                        Label("Conta Alma", systemImage: "moon.stars.fill")
                        Spacer()
                        Text(AlmaBridge.shared.almaConnected ? "Conectada" : "Não conectada")
                            .foregroundStyle(.secondary)
                    }
                    Text("Tenha Corpo & Alma + Alma juntos: corpo e mente cuidados no mesmo lugar.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Aparência
                Section("Aparência") {
                    Picker(selection: $model.appearanceMode) {
                        Text("Sistema").tag("system")
                        Text("Claro").tag("light")
                        Text("Escuro").tag("dark")
                    } label: {
                        Label("Tema", systemImage: "circle.lefthalf.filled")
                    }
                }

                // Sobre / legal
                Section("Sobre") {
                    Button { showDisclaimer = true } label: {
                        Label("Aviso de saúde", systemImage: "exclamationmark.shield.fill")
                    }
                    Link(destination: URL(string: "https://almaappoficial.com/corpo-e-alma/privacy")!) {
                        Label("Política de privacidade", systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://almaappoficial.com/corpo-e-alma/terms")!) {
                        Label("Termos de uso", systemImage: "doc.text.fill")
                    }
                    HStack {
                        Text("Versão"); Spacer(); Text("1.0 (1)").foregroundStyle(.secondary)
                    }
                }

                // [Fusão 2026-08-02] A seção "Conta" saiu daqui. Dentro do Alma
                // existe UMA conta só, e quem cuida dela é o Perfil do Alma —
                // login, logout e exclusão. Manter dois caminhos de deleção no
                // mesmo app seria confuso e perigoso.
                Section("Conta") {
                    Button(role: .destructive) {
                        model.hasOnboarded = false
                        dismiss()
                    } label: {
                        Label("Refazer avaliação inicial", systemImage: "arrow.counterclockwise")
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Sua conta, assinatura e exclusão de dados ficam no Perfil da Alma.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallDoCorpo() }
            .sheet(isPresented: $showDisclaimer) { HealthDisclaimerView() }
            .onChange(of: model.notifyWater) { _ in Task { await applyNotifications() } }
            .onChange(of: model.notifyMeals) { _ in Task { await applyNotifications() } }
            .onChange(of: model.notifyWorkout) { _ in Task { await applyNotifications() } }
            .onChange(of: model.notifySupplements) { _ in Task { await applyNotifications() } }
            .onChange(of: model.supplementHour) { _ in Task { await applyNotifications() } }
            // [Fusão] alertas de exclusão de conta removidos — fluxo único no Alma.
        }
    }

    // [Fusão 2026-08-02] deleteAccount() removido: a exclusão de conta é do
    // Alma (AccountDeletionService), que apaga servidor + dados locais dos dois
    // módulos num fluxo só.

    /// Extraída numa propriedade própria porque, inline, o corpo do Form ficava
    /// grande demais e o compilador desistia de inferir o tipo
    /// ("unable to type-check this expression in reasonable time").
    @ViewBuilder
    private var secaoLembretes: some View {
        Section {
            Toggle(isOn: $model.notifyWater) { Label("Beber água", systemImage: "drop.fill") }
            Toggle(isOn: $model.notifyMeals) { Label("Registrar refeições", systemImage: "fork.knife") }
            Toggle(isOn: $model.notifyWorkout) { Label("Treino do dia", systemImage: "dumbbell.fill") }
            Toggle(isOn: $model.notifySupplements) { Label("Suplementos", systemImage: "pills.fill") }
            if model.notifySupplements {
                Picker("Horário", selection: $model.supplementHour) {
                    ForEach(horasDisponiveis, id: \.self) { h in
                        Text(rotuloHora(h)).tag(h)
                    }
                }
            }
        } header: {
            Text("Lembretes")
        } footer: {
            // Transparência sobre volume: a pessoa vê o que está ligando.
            Text(resumoDeLembretes)
        }
    }

    private var horasDisponiveis: [Int] { Array(6...22) }

    private func rotuloHora(_ h: Int) -> String {
        String(format: "%02d:00", h)
    }

    /// Quantos avisos por dia as opções ligadas representam. Mostrado no rodapé
    /// da seção: quem liga tudo enxerga o custo antes de reclamar do app.
    private var resumoDeLembretes: String {
        var total = 0
        if model.notifyWater { total += GradeDeLembretes.horariosAgua.count }
        if model.notifyMeals { total += 3 }
        if model.notifyWorkout { total += 1 }
        if model.notifySupplements { total += 1 }

        if total == 0 { return "Nenhum lembrete ativo." }
        return total == 1
            ? "1 lembrete por dia."
            : "\(total) lembretes por dia."
    }

    private func applyNotifications() async {
        let anyOn = model.notifyWater || model.notifyMeals || model.notifyWorkout || model.notifySupplements
        if anyOn {
            _ = await NotificationManager.shared.requestAuthorization()
        }
        NotificationManager.shared.sync(
            water: model.notifyWater,
            meals: model.notifyMeals,
            workout: model.notifyWorkout,
            supplements: model.notifySupplements,
            supplementHour: model.supplementHour
        )
    }

    private var initials: String {
        let parts = model.userName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }

    @ViewBuilder
    private var statusBadge: some View {
        if model.isPremium {
            Pill(text: "Premium", tint: Theme.primary)
        } else if model.isTrialActive {
            Pill(text: "Teste · \(model.trialDaysRemaining)d", tint: Theme.gold)
        } else {
            Pill(text: "Gratuito", tint: Theme.inkSoft)
        }
    }
}

// MARK: - Aviso de saúde (exigido pela App Store)

struct HealthDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.primary)

                    Text("Aviso importante de saúde")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)

                    Text("""
                    O Corpo & Alma tem finalidade informativa e de bem-estar. Ele não substitui avaliação, diagnóstico ou tratamento de profissionais de saúde — médicos, nutricionistas ou educadores físicos.

                    Consulte um profissional antes de iniciar dietas, treinos ou mudanças de hábito, especialmente se você tem alguma condição de saúde, está grávida, amamentando ou faz uso de medicação.

                    As metas, calorias e planos são estimativas gerais e podem não refletir suas necessidades individuais. Em caso de mal-estar, dor ou emergência, interrompa a atividade e procure atendimento médico.
                    """)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entendi") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppModel())
        .environmentObject(HealthManager())
        .environmentObject(StoreManager())
}
