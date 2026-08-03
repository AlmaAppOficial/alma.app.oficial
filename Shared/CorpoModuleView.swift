// CorpoModuleView.swift
// Alma App — porta de entrada do módulo "Corpo" (fusão com o Corpo & Alma)
//
// [Fusão — 2026-08-02] Bug corrigido: o botão "Corpo" da Início abria
// `corpoealma://` e, sem o app instalado, o iOS jogava no Safari com
// "o endereço não é válido". Com o Corpo & Alma a caminho da descontinuação,
// NENHUM ponto do app pode depender de URL externa para ele.
//
// Esta view é a rota definitiva do módulo. Hoje mostra o estado de transição;
// quando o CorpoKit estiver de pé, o corpo desta view é substituído pela raiz
// real do módulo (`CorpoRootView`) — e nada mais no app precisa mudar, porque
// todos os pontos de entrada já apontam para cá.

import SwiftUI

struct CorpoModuleView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var access: AccessManager
    /// StoreKit do Alma — o módulo Corpo vende o mesmo produto que o resto do app.
    @EnvironmentObject var storeAlma: StoreKitManager

    // [Fusão 2026-08-02] CRASH CORRIGIDO: o módulo Corpo declara três
    // @EnvironmentObject (AppModel, HealthManager, StoreManager) que, no app
    // Corpo & Alma, eram injetados pelo ponto de entrada dele (CorpoEAlmaApp) —
    // arquivo que o port removeu de propósito. Sem eles, tocar em "Corpo"
    // derrubava o app na hora: SwiftUI chama fatalError quando um
    // @EnvironmentObject não está no ambiente.
    //   Stack do crash: EnvironmentObject.error() -> CorpoHomeView.model.getter
    // Como @StateObject, vivem enquanto o módulo estiver aberto e mantêm o
    // estado ao trocar de aba.
    @StateObject private var corpoModel = AppModel()
    @StateObject private var corpoHealth = HealthManager()
    @StateObject private var corpoStore = StoreManager()

    /// [Fusão 2026-08-02] Módulo portado: as 5 abas reais do Corpo & Alma
    /// (Início, Saúde, Dieta, Treino, Insights) rodam dentro do Alma.
    static let isModuleReady = true

    var body: some View {
        // [2026-08-02] SEM NavigationStack aqui. Cada aba do RootTabView tem a
        // sua, e o wrapper externo criava aninhamento — o SwiftUI então
        // engolia a toolbar das views internas, e foi ISSO que fez o botão de
        // editar medidas (ícone de sliders na aba Saúde) sumir da tela.
        // O caminho de volta agora vive dentro de cada aba, via
        // .almaBackButton(), no topo DIREITO — simétrico ao botão "Corpo" da
        // Início do Alma.
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()

            if Self.isModuleReady {
                RootTabView()
                    .environmentObject(corpoModel)
                    .environmentObject(corpoHealth)
                    .environmentObject(corpoStore)
                    // [2026-08-03 — B10] O StoreKit do ALMA desce junto: o
                    // paywall do Corpo passou a vender o produto único do app
                    // (`com.almaapp.app.premium_*`) em vez dos IDs do Corpo &
                    // Alma, que está descontinuado e cujos produtos não existem
                    // mais — a tela ficava presa em "Tentar novamente".
                    .environmentObject(storeAlma)
                    .environmentObject(access)
                    .environment(\.voltarParaAlma, { dismiss() })
            } else {
                NavigationStack {
                    transitionContent
                        .navigationTitle("Corpo")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                BotaoVoltarParaAlma { dismiss() }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Estado de transição

    private var transitionContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer().frame(height: 12)

                ZStack {
                    Circle()
                        .fill(CalmTheme.accent.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(CalmTheme.accent)
                }

                VStack(spacing: 10) {
                    Text("Seu corpo, aqui dentro")
                        .font(.title2.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("O Alma está se tornando um app só — o que cuida da sua mente e o que cuida do seu corpo, no mesmo lugar.")
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                VStack(spacing: 12) {
                    featureRow("dumbbell.fill", "Treinos", "Seu plano, exercício por exercício")
                    featureRow("fork.knife", "Alimentação", "Diário de refeições e calorias reais")
                    featureRow("drop.fill", "Hidratação", "Lembretes no seu ritmo")
                    featureRow("chart.line.uptrend.xyaxis", "Evolução", "Peso, medidas e progresso")
                }
                .padding(16)
                .background(CalmTheme.surface)
                .cornerRadius(CalmTheme.rMedium)
                .padding(.horizontal, 20)

                // Quem veio do Corpo & Alma precisa saber que o acesso está garantido.
                if LegacyEntitlementStore.isGranted {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("Sua assinatura do Corpo & Alma já está reconhecida aqui — você não vai precisar assinar de novo.")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.green.opacity(0.10))
                    .cornerRadius(CalmTheme.rSmall)
                    .padding(.horizontal, 20)
                }

                Text("Em breve, nesta mesma tela.")
                    .font(.footnote)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.top, 4)

                // Segundo caminho de volta, no fim do conteúdo — quem rola até
                // aqui não precisa subir para achar a saída.
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.bold())
                        Text("Voltar para a Alma")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(CalmTheme.primary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(CalmTheme.primary.opacity(0.10))
                    .cornerRadius(22)
                }
                .padding(.top, 6)

                Spacer(minLength: 28)
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(CalmTheme.accent)
                .frame(width: 34, height: 34)
                .background(CalmTheme.accent.opacity(0.12))
                .cornerRadius(9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
        }
    }
}
