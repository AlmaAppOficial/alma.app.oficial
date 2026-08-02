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
                Section("Lembretes") {
                    Toggle(isOn: $model.notifyWater) { Label("Beber água", systemImage: "drop.fill") }
                    Toggle(isOn: $model.notifyMeals) { Label("Registrar refeições", systemImage: "fork.knife") }
                    Toggle(isOn: $model.notifyWorkout) { Label("Treino do dia", systemImage: "dumbbell.fill") }
                }

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
            .sheet(isPresented: $showPaywall) { CorpoPaywallView() }
            .sheet(isPresented: $showDisclaimer) { HealthDisclaimerView() }
            .onChange(of: model.notifyWater) { _ in Task { await applyNotifications() } }
            .onChange(of: model.notifyMeals) { _ in Task { await applyNotifications() } }
            .onChange(of: model.notifyWorkout) { _ in Task { await applyNotifications() } }
            // [Fusão] alertas de exclusão de conta removidos — fluxo único no Alma.
        }
    }

    // [Fusão 2026-08-02] deleteAccount() removido: a exclusão de conta é do
    // Alma (AccountDeletionService), que apaga servidor + dados locais dos dois
    // módulos num fluxo só.

    private func applyNotifications() async {
        let anyOn = model.notifyWater || model.notifyMeals || model.notifyWorkout
        if anyOn {
            _ = await NotificationManager.shared.requestAuthorization()
        }
        NotificationManager.shared.sync(
            water: model.notifyWater,
            meals: model.notifyMeals,
            workout: model.notifyWorkout
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
