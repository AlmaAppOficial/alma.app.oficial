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
    // [2026-08-04] Injetados pelo CorpoModuleView. `access` é a fonte única do
    // "esta pessoa assina?" no app inteiro; `storeAlma` é o StoreKit do Alma,
    // que a gestão do plano usa para restaurar compras.
    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var storeAlma: StoreKitManager
    /// [2026-08-05] Fonte única de aparência — ver AparenciaDoApp.swift.
    @ObservedObject private var aparencia = AparenciaDoApp.shared
    // [Fusão] auth removido — a conta é do Alma.
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var showGestaoDoPlano = false
    @State private var showDisclaimer = false
    @State private var showEditAssessment = false

    /// Versão real do bundle — nunca um número escrito à mão.
    static var versaoDoApp: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

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
                //
                // [2026-08-04] O botão já dizia "Gerenciar plano" para o
                // assinante — e abria o paywall de VENDA. Rótulo certo, destino
                // errado: a pessoa que paga tocava em "gerenciar" e recebia
                // "Assinar Alma Premium". Agora cada rótulo leva ao seu lugar.
                //
                // A fonte da verdade aqui passou a ser `access.isPremium`, a
                // mesma que libera as telas no app inteiro. `hasPremiumAccess`
                // do AppModel é uma leitura própria do módulo Corpo e podia
                // divergir — dois donos da mesma pergunta.
                Section("Assinatura") {
                    Button {
                        if access.isPremium { showGestaoDoPlano = true } else { showPaywall = true }
                    } label: {
                        Label(access.isPremium ? "Ver e gerenciar seu plano" : "Conhecer o Premium",
                              systemImage: "leaf.circle.fill")
                    }
                    // [2026-08-04] "Restaurar compras" saiu daqui: para o
                    // assinante ele vive dentro da gestão do plano, e para o não
                    // assinante ele já existe no paywall. Duplicado, ele fazia
                    // `model.activatePremium()` — o caminho que carimba o
                    // entitlement permanente no Keychain e nunca mais sai.
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

                // [2026-08-03] Seção "App Alma" REMOVIDA. Era da era em que
                // existiam dois apps: mostrava se a "conta Alma" estava
                // conectada e convidava a "ter os dois juntos". Dentro do app
                // fundido a pergunta não faz sentido — a conta É a do Alma, e
                // o usuário já está nele.

                // Aparência
                // [2026-08-05] Este picker escrevia `model.appearanceMode`, a
                // mesma chave morta da lua: mudava a seleção e não mudava a
                // tela. Agora escreve a fonte única, e é a mesma coisa que o
                // toggle do Perfil do Alma controla.
                Section("Aparência") {
                    Picker(selection: $aparencia.modo) {
                        ForEach(ModoDeAparencia.allCases, id: \.self) { modo in
                            Text(modo.rotulo).tag(modo)
                        }
                    } label: {
                        Label("Tema", systemImage: "circle.lefthalf.filled")
                    }
                }

                secaoSobre

                // [Fusão 2026-08-02] A seção "Conta" saiu daqui. Dentro do Alma
                // existe UMA conta só, e quem cuida dela é o Perfil do Alma —
                // login, logout e exclusão. Manter dois caminhos de deleção no
                // mesmo app seria confuso e perigoso.
                Section("Conta") {
                    // [2026-08-03] "Refazer avaliação inicial" só zerava
                    // `hasOnboarded`, uma flag órfã que nenhuma tela do app
                    // fundido lê: o botão não fazia absolutamente nada. Agora
                    // leva para onde a pessoa realmente edita seus dados.
                    Button {
                        showEditAssessment = true
                    } label: {
                        Label("Revisar minhas medidas e objetivo", systemImage: "arrow.counterclockwise")
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
            .sheet(isPresented: $showGestaoDoPlano) {
                GestaoDoPlanoView()
                    .environmentObject(access)
                    .environmentObject(storeAlma)
            }
            .sheet(isPresented: $showDisclaimer) { HealthDisclaimerView() }
            .sheet(isPresented: $showEditAssessment) { EditAssessmentView() }
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

    /// Extraída porque, inline, o Form estourava o type-checker.
    @ViewBuilder
    private var secaoSobre: some View {
        Section("Sobre") {
            Button { showDisclaimer = true } label: {
                Label("Aviso de saúde", systemImage: "exclamationmark.shield.fill")
            }
            // [2026-08-03] Os links apontavam para /corpo-e-alma/privacy e
            // /corpo-e-alma/terms — as páginas do app DESCONTINUADO. Dentro do
            // Alma, a política que vale é a do Alma; mandar o usuário para a
            // página de outro produto é informação legal errada.
            Link(destination: URL(string: "https://almaappoficial.com/politica")!) {
                Label("Política de privacidade", systemImage: "hand.raised.fill")
            }
            Link(destination: URL(string: "https://almaappoficial.com/termos")!) {
                Label("Termos de uso", systemImage: "doc.text.fill")
            }
            HStack {
                Text("Versão")
                Spacer()
                // Era "1.0 (1)" chumbado — a versão do Corpo & Alma congelada
                // no código, que dentro do Alma não correspondia a nada.
                Text(Self.versaoDoApp).foregroundStyle(.secondary)
            }
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
        // [2026-08-03] O badge "Teste · Xd" saiu. O modelo não tem trial desde
        // julho (decisão do Assis: freemium, sem período de teste), mas a
        // máquina local de trial continuava no código e podia acender um selo
        // prometendo dias grátis que não existem. A metadata e a copy já tinham
        // sido limpas; a UI ainda não.
        if model.hasPremiumAccess {
            Pill(text: "Premium", tint: Theme.primary)
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
