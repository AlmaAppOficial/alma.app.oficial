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
    /// [2026-08-07] Usado para reavaliar a virada do dia — ver o `.onChange` no
    /// `body`. Antes disto o módulo não observava ciclo de vida nenhum.
    @Environment(\.scenePhase) private var scenePhase
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

    /// [2026-08-04] A aparência do app inteiro é ESTA — a mesma chave que o
    /// toggle do Perfil do Alma grava. O módulo Corpo herdou do Corpo & Alma um
    /// `appearanceMode` próprio ("system"/"light"/"dark") em `AppModel`, com
    /// botão de lua na Início do Corpo; só que o `model.colorScheme` que ele
    /// calcula NÃO era aplicado em lugar nenhum — varri o projeto por
    /// `preferredColorScheme` e não havia nenhuma ocorrência dentro de
    /// `Shared/Corpo/`. Resultado: um botão que gravava uma preferência que
    /// ninguém lia, e o módulo aparecendo claro com o Alma escuro.
    ///
    /// Aplicar aqui é idempotente: se o `fullScreenCover` já herdasse a
    /// preferência da raiz, esta linha não muda nada; como não herdava, corrige.
    ///
    /// [2026-08-05] Metade do conserto acima estava certa e metade faltava. O
    /// LEITOR passou a aplicar a preferência aqui dentro — mas a lua da Início
    /// do Corpo continuou ESCREVENDO em `appearanceMode`, uma chave que este
    /// `@AppStorage("isDarkMode")` não lia. Resultado no aparelho do Assis:
    /// tocar na lua trocava o ícone e não trocava a aparência. Agora as duas
    /// pontas passam por `AparenciaDoApp.shared`.
    @ObservedObject private var aparencia = AparenciaDoApp.shared

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
        conteudo
            // Uma fonte de verdade só para aparência, em todo o app.
            .preferredColorScheme(aparencia.colorScheme)
            .task {
                #if os(iOS)
                // [2026-08-04 — Watch] Enquanto o Corpo está aberto, a ponte
                // do relógio aplica eventos (água, treino) NESTA instância —
                // a tela reflete na hora, sem esperar reabrir o módulo.
                WatchBridge.shared.attachCorpoModel(corpoModel)

                // [2026-08-28] Acerta o cronômetro do jejum na tela bloqueada.
                //
                // Fica AQUI, e não na `JejumView`, porque a `JejumView` é uma
                // tela empilhada: exigir que a pessoa navegue até ela para o
                // cronômetro voltar seria pedir o passo que ela justamente não
                // dá — abrir o app e olhar a Dieta é o comportamento normal.
                //
                // Este é o ponto que RECRIA a atividade depois do teto de 8 h
                // do iOS (ver `JejumAoVivo.swift`) e o que remove atividade
                // órfã de um jejum já encerrado.
                await JejumStore.shared.sincronizarCronometroDaTelaBloqueada()
                #endif
            }
            // [2026-08-07] A VIRADA DO DIA. `corpoModel` é @StateObject: nasce
            // uma vez e sobrevive a noite inteira em segundo plano. Sem estes
            // dois gatilhos, o `init` era o único momento em que o app olhava
            // que dia é — e quem não fecha o app via a dieta de ontem hoje.
            //
            // São dois porque cobrem cenários diferentes, e um só deixaria
            // metade do defeito vivo:
            //   • scenePhase .active — app volta do segundo plano (caso do Assis)
            //   • significantTimeChange — meia-noite com o app JÁ em primeiro
            //     plano; aqui o scenePhase não muda e nada mais avisaria.
            // Forma de UM parâmetro de propósito: o alvo de implantação do
            // projeto é anterior ao iOS 17, e `onChange(of:initial:_:)` (dois
            // parâmetros) só existe de lá para cá. Mesmo formato já usado em
            // CorpoHomeView.swift:81.
            .onChange(of: scenePhase) { nova in
                if nova == .active {
                    corpoModel.reavaliarDiaAtual()
                    // [28/08] Mesmo motivo da virada do dia: o `.task` acima
                    // roda uma vez e o módulo sobrevive a noite inteira em
                    // segundo plano. Sem isto, o cronômetro encerrado pelo teto
                    // de 8 h do iOS só voltaria quando a pessoa FECHASSE e
                    // reabrisse o Corpo.
                    Task { await JejumStore.shared.sincronizarCronometroDaTelaBloqueada() }
                    // [2026-08-31] Decisão do Assis: reler a saúde sempre que o
                    // app volta ao primeiro plano — TAMBÉM com o Corpo aberto.
                    // O `refresh()` do HealthManager roda no init e a cada
                    // aparição da SaudeView, mas `onAppear` NÃO dispara no
                    // retorno do segundo plano: quem ficava parado numa aba do
                    // Corpo via os números da abertura anterior. `refresh()`
                    // não limpa nada antes de buscar (cada @Published só é
                    // reatribuído quando a consulta responde) — sem piscar.
                    corpoHealth.refresh()
                }
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.significantTimeChangeNotification
            )) { _ in
                corpoModel.reavaliarDiaAtual()
            }
            #endif
    }

    private var conteudo: some View {
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
