import SwiftUI

struct HomeView: View {

    @EnvironmentObject var hk: HealthKitManager
    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store: StoreKitManager
    // [2026-08-14] `authorized` foi removido junto com a `healthSection`. Era
    // lido só por ela; o resultado da autorização agora é consumido direto no
    // `.task`, que é onde ele sempre foi decidido.
    @State private var showMoodChat = false
    @State private var showInsightShare = false
    @State private var navigateToPraticas = false
    @State private var showHomePaywall = false
    @State private var showChat = false
    /// [Fusão 2026-08-02] Módulo "Corpo" — tela interna, nunca URL externa.
    /// Abre sozinho quando o app roda com `-abrirCorpo 1`, o que permite validar
    /// o módulo por linha de comando (`xcrun simctl launch … -abrirCorpo 1`)
    /// sem depender de automação de toque.
    /// [2026-08-03 — A13] A flag só existe em DEBUG. Compilada em Release, era
    /// um caminho de teste embarcado no app da loja.
    /// [2026-08-04] Começa SEMPRE `false`, inclusive em DEBUG. Nascer `true` era
    /// o bug: um `.fullScreenCover` que já começa apresentado não apresenta —
    /// SwiftUI só reage à MUDANÇA do binding. O comentário do `.task` já
    /// descrevia esse defeito, mas a correção parou no meio: o `.task` mandava
    /// `true` num estado que já era `true`, ou seja, não mandava nada.
    /// Resultado: `-abrirCorpo 1` continuava caindo na Home do Alma, e as
    /// conferências visuais de 03/08 e 04/08 fotografaram a tela errada duas
    /// vezes. Quem liga a flag agora é só o `.task`.
    @State private var showCorpoModule = false
    /// [2026-08-05] Empilhamento programático do Livre de Vícios. O card usa
    /// `NavigationLink`, que só responde a toque; o marco que chega por
    /// notificação precisa de um destino que se abra por estado.
    @State private var showLivreDeVicios = false
    @ObservedObject private var roteador = RoteadorDeNotificacao.shared

    @ObservedObject private var streakManager = StreakManager.shared
    @ObservedObject private var perfil = UserProfileStore.shared
    @State private var showOnboarding = false
    // [2026-08-03 — B4/MÉDIO] A Home construía um `AppModel()` novo a cada
    // render (2× por passagem) só para saber peso e altura: ~6 blobs JSON
    // decodificados, e o init carimbava `lastWaterDate` — um dos gatilhos da
    // água de ontem virando água de hoje. A correção daquele dia guardou UMA
    // instância num @StateObject.
    //
    // [2026-08-04 — BUG DO CARD] Guardar a instância trocou um bug por outro: a
    // tela que preenche o perfil tem o AppModel dela, gravava no disco, e esta
    // cópia continuava velha — o card nunca sumia. Agora a Home não constrói
    // AppModel nenhum: a completude do perfil é lida do disco pelo
    // UserProfileStore. Os dois problemas somem, e a Home fica mais leve.

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header ─────────────────────────────
                headerSection

                // ── Complete seu perfil ────────────────
                // [2026-08-02] Só aparece quando falta algo de verdade, e some
                // sozinho quando o perfil fica completo.
                if !perfil.pendencias().isEmpty {
                    completeSeuPerfilCard
                }

                // ── Premium banner — [Build 84] freemium: só p/ não-assinante ─
                if !access.isPremium {
                    premiumBanner
                }

                // ── HERO: Quick Start "Meditar Agora" Button (1 tap) ─────
                quickStartButton

                // ── Streak Display (Corrente de Paz) ──────────────────
                streakSection

                // [Build 77 — 12/05/2026] moodCheckInButton removido (era botao redundante
                // que tambem ia pra ChatView; mood check-in real esta em InsightsView).
                // Hero "Fale com sua Alma" segue como unico acesso ao chat na home.

                // ── Fale com sua Alma (Premium) ──────────────────
                heroButton

                // ── Sound Suggestions (acesso mínimo gratuito) ──
                soundSection

                // [2026-08-14] A seção "Saúde hoje" saiu daqui a pedido do
                // Assis: os mesmos números já aparecem no Insights e no módulo
                // Corpo, e repetir na Início não acrescentava nada.
                //
                // O que NÃO saiu, de propósito: a autorização do HealthKit
                // (`.task`, abaixo), o `HealthKitManager` (a seção de Sons lê
                // `stressLevel` dele) e a flag `setHealthConnected`, que passou
                // para o `.task` — ver o comentário lá. Tirar da Início não é
                // desligar saúde.

                // ── Saúde Feminina (Premium + apenas mulheres) ──
                if access.isPremium && UserMemoryManager.shared.isFemale {
                    feminineHealthCard
                }

                // ── Livre de Vícios (Premium) ──────────────────
                if access.isPremium {
                    addictionFreeCard
                }

                // ── Insight Card (Premium) ─────────────────────
                if access.isPremium {
                    insightCard
                }

                Spacer(minLength: 32)
            }
            .adaptiveContentWidth()
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            // [2026-08-04] `-abrirCorpo 1` não abria nada: o @State nascia
            // `true` e um `.fullScreenCover` que já começa apresentado não
            // apresenta — SwiftUI só reage à MUDANÇA do binding. Foi por isso
            // que a conferência visual de 03/08 gerou 5 capturas da Home do
            // Alma achando que eram as 5 abas do Corpo. Agora a flag vira o
            // estado depois da tela existir.
            #if DEBUG
            // [2026-08-04, 3ª tentativa] Só mudar o estado no `.task` também não
            // bastava: o `.task` dispara durante o primeiro layout, antes da
            // view estar na janela, e uma apresentação pedida nesse instante é
            // engolida. As duas conferências anteriores fotografaram a Home do
            // Alma por causa disso — e a segunda me enganou porque os md5
            // diferiam: era o RELÓGIO da barra de status mudando de minuto, não
            // a tela. Meio segundo de espera resolve, e é código de DEBUG.
            if UserDefaults.standard.bool(forKey: "abrirCorpo") {
                try? await Task.sleep(nanoseconds: 600_000_000)
                showCorpoModule = true
            }
            #endif
            // [2026-08-14] `setHealthConnected(true)` vinha de dentro da
            // `healthSection` (era a linha 552), e aquele era o ÚNICO lugar do
            // app inteiro a chamá-la. O `wellnessSummaryCard` do Insights usa a
            // flag como portão (`InsightsView.swift:223` e `:231`): sem ela, a
            // tela paga mostra "Ative o Apple Health" e quatro anéis vazios.
            //
            // Removida a seção sem mover a chamada, o Insights ficaria preso no
            // estado vazio para SEMPRE em instalação nova — mesmo com
            // autorização concedida e dado disponível. Tirar da Início teria
            // desligado saúde no Insights.
            //
            // Este é o lugar certo, não apenas o que sobrou: o comentário A11
            // do próprio Insights (`InsightsView.swift:247-250`) já afirmava que
            // o portão "vira true pela AUTORIZAÇÃO, não por existir dado" — e a
            // chamada morava no ramo do DADO, contradizendo a intenção escrita
            // ao lado dela.
            if await hk.requestAuthorization() {
                await hk.loadAll()
                UserMemoryManager.shared.setHealthConnected(true)
            }
            #if DEBUG
            // [2026-08-04] `-soVisual 1` pula os harnesses pesados. A conferência
            // visual capturava a Home do Alma no lugar das abas do Corpo porque
            // o auditor, o teste de áudio, o smoke de 43 telas e o de
            // persistência rodam AQUI, no MainActor, logo depois de ligar o
            // `fullScreenCover` — e seguravam a apresentação além do tempo da
            // captura. As sementes ficam: sem elas as telas apareceriam vazias.
            let soVisual = UserDefaults.standard.bool(forKey: "soVisual")
            await MainActor.run { SmokeTestTelas.conferenciaDeAparencia() }
            if !soVisual {
                await MainActor.run { AuditoriaBloqueadores.executar() }
                await TesteAudio.executar()
                await MainActor.run { SmokeTestTelas.executar() }
                await MainActor.run { TestePersistencia.executar() }
            }
            await MainActor.run { DebugContextDump.semearPerfil() }
            await MainActor.run { DebugContextDump.semearSaude() }
            if !soVisual { await DebugContextDump.executar(health: hk) }
            #endif
        }
        .fullScreenCover(isPresented: $showCorpoModule) {
            CorpoModuleView()
                .environmentObject(access)
                .environmentObject(store)
        }
        // [2026-08-05] Segunda etapa do encaminhamento por notificação. A
        // MainTabView já trouxe a pessoa para a aba Início e deixou o destino
        // pendente de propósito, porque chat, Corpo e Livre de Vícios não são
        // abas — são telas empilhadas ou apresentadas A PARTIR daqui.
        //
        // As duas chamadas cobrem os dois caminhos do iOS: `onAppear` é a
        // partida fria (a Início nasce e encontra o destino esperando) e
        // `onChange` é o app já vivo. Ver RotaDaNotificacao.swift.
        .onAppear { encaminharNotificacaoPendente() }
        .onChange(of: roteador.pendente) { _ in encaminharNotificacaoPendente() }
        .navigationDestination(isPresented: $showLivreDeVicios) {
            AddictionFreeView()
        }
        // [2026-08-02] O card "Complete seu perfil" reabre o MESMO onboarding
        // da primeira abertura (OnboardingBiometricsView), agora com nome,
        // medidas e consentimento. Um fluxo só — criar um segundo teria deixado
        // dois lugares para editar a mesma informação.
        .sheet(isPresented: $showOnboarding) {
            OnboardingBiometricsView()
        }
        .sheet(isPresented: $showHomePaywall) {
            PremiumWallView()
                .environmentObject(access)
                .environmentObject(store)
        }
    }

    // MARK: - Premium Banner
    private var premiumBanner: some View {
        Button(action: { showHomePaywall = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conheça Alma Premium")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(bannerSubtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [CalmTheme.primary, CalmTheme.primary.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(CalmTheme.rMedium)
        }
    }

    private var bannerSubtitle: String {
        // [Build 84 — 2026-07-29] Modelo freemium: nenhuma promessa de trial
        // em copy do app (decisão do Assis). A oferta introdutória do ASC, se
        // ativa, aparece na folha de pagamento da própria Apple.
        "Acesso completo · Toque para assinar"
    }

    // MARK: - Complete seu perfil
    //
    // [2026-08-02] O app operava no escuro: não sabia o nome, nem a idade, nem
    // as medidas de quem estava do outro lado — e mesmo assim calculava metas e
    // conversava. Este card cobra o que falta, sempre dizendo PARA QUÊ.
    private var completeSeuPerfilCard: some View {
        let pendencias = perfil.pendencias()

        return Button {
            showOnboarding = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.title3)
                        .foregroundColor(CalmTheme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete seu perfil")
                            .font(.headline)
                            .foregroundColor(CalmTheme.textPrimary)
                        // [2026-08-04] Dizia "Faltam 2 informações" e deixava a
                        // pessoa caçar quais. Agora nomeia os campos: quem lê
                        // sabe na hora o que o app ainda não tem.
                        Text(PendenciaPerfil.textoDoQueFalta(pendencias))
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textSecondary)
                }

                // Barra de progresso: quanto do perfil já existe.
                let total = PendenciaPerfil.allCases.count
                let feito = total - pendencias.count
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(CalmTheme.textSecondary.opacity(0.15))
                        Capsule()
                            .fill(CalmTheme.primary)
                            .frame(width: geo.size.width * CGFloat(feito) / CGFloat(total))
                    }
                }
                .frame(height: 6)

                Text(pendencias.first?.porque ?? "")
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CalmTheme.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
            // Botão "Corpo" — módulo interno (fusão).
            // [2026-08-02] Antes abria `corpoealma://` e, sem o app instalado,
            // o iOS jogava no Safari com "endereço não é válido". Com o
            // Corpo & Alma sendo descontinuado, nunca mais URL externa: abre
            // uma tela DENTRO do Alma.
            Button {
                showCorpoModule = true
            } label: {
                // [2026-08-02] Logo real do Corpo (extraída do ícone do app
                // Corpo & Alma) em vez de símbolo genérico. Simétrico ao botão
                // da Alma dentro do Corpo.
                VStack(spacing: 2) {
                    Image("CorpoLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text("Corpo")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(CalmTheme.textSecondary)
                }
                .frame(width: 40, height: 44)
            }
            .accessibilityLabel("Abrir Corpo — treino e alimentação")
            .padding(.trailing, 8)
            AlmaLogo(size: 44)
        }
    }

    // MARK: - Streak Display (Corrente de Paz)
    private var streakSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Corrente de Paz")
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundColor(.orange)

                    Text("\(streakManager.currentStreak) dias")
                        .font(.headline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Total meditado")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)

                Text("\(UserMemoryManager.shared.meditationMinutes) min")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.primary)
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Quick Start Button
    private var quickStartButton: some View {
        ZStack {
            Button(action: { navigateToPraticas = true }) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meditar Agora")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Comece uma sessão guiada de meditação")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [CalmTheme.accent, CalmTheme.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(CalmTheme.rLarge)
                .shadow(color: CalmTheme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 4)
        }
        .navigationDestination(isPresented: $navigateToPraticas) {
            PraticasView()
        }
    }

    // MARK: - Encaminhamento por notificação

    /// Cumpre os destinos que nascem desta tela. Aba do Alma não é tratada aqui
    /// — quem trata é a `MainTabView`, e por isso o predicado do `consumir`
    /// exclui `.almaAba`: duas telas consumindo o mesmo pendente fariam uma
    /// roubar o destino da outra.
    private func encaminharNotificacaoPendente() {
        let destino = roteador.consumir { d in
            switch d {
            case .almaAba:                                     return false
            case .corpoAba, .conversarComAlma, .livreDeVicios:  return true
            }
        }
        guard let destino else { return }

        switch destino {
        case .corpoAba:
            // A aba fica guardada em `abaDoCorpoPendente`: o `RootTabView` só
            // existe depois deste `fullScreenCover` apresentar, e é ele quem
            // consome. Ver o comentário do roteador.
            showCorpoModule = true
        case .conversarComAlma:
            showChat = true
        case .livreDeVicios:
            showLivreDeVicios = true
        case .almaAba:
            break
        }
    }

    // MARK: - Hero Button
    // [Build 77 — 12/05/2026] moodCheckInButton removido (linhas 212-241):
    // botao redundante que tambem ia pra ChatView. Mood check-in real esta em InsightsView.
    // [Build 82 — 2026-07-15] Chat bloqueado para usuários gratuitos — exige Premium.
    // [Build 84 — 2026-07-29] FREEMIUM: chat abre para todos; não-assinante
    // tem N mensagens/dia (FreemiumLimits) e converte dentro do chat.
    private var heroButton: some View {
        Button(action: {
            showChat = true
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fale com sua Alma")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(access.isPremium
                         // [2026-08-04] "esta" sem acento, no card mais visto do
                         // app — apareceu na captura real do modo escuro.
                         ? "Sua mentora de bem-estar está pronta para te ouvir"
                         : (FreemiumLimits.chatHasFreeQuota
                            ? "\(FreemiumLimits.chatMessagesPerDay) mensagens grátis por dia · Toque para conversar"
                            : "Recurso Premium · Toque para conhecer"))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(20)
            .background(CalmTheme.heroGradient)
            .cornerRadius(CalmTheme.rLarge)
            .shadow(color: CalmTheme.primary.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .navigationDestination(isPresented: $showChat) { ChatView() }
    }


    // MARK: - Sound Suggestions
    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sons recomendados")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                Text("para você agora")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            let tracks = recommendedTracks

            if tracks.isEmpty {
                Text("Abra o app de Saúde para ver recomendações personalizadas")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tracks) { track in
                            SoundTile(track: track)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.trailing, 4)
                }
                .frame(height: 140)
            }
        }
    }

    // [Build 77 — 12/05/2026] Atualizado pra retornar [RecommendedSound] (MP3 bundle real,
    // nao mais BinauralTrack/sine wave). Converte StressLevel enum em Double 0-1 pro
    // SmartPlaylistEngine. Generate ja tem fallback interno (mix variado se sem dados).
    private var recommendedTracks: [RecommendedSound] {
        // [2026-08-13] `stressLevel` virou opcional. Sem HRV o parâmetro vai
        // `nil` — que é exatamente o que o `generate` já esperava receber
        // quando não há dado (a assinatura sempre foi `Double? = nil`). Antes,
        // "sem dado" chegava aqui como 0.2, isto é, "relaxado", e a playlist
        // era escolhida com base numa leitura que não existiu.
        let stressDouble: Double? = {
            switch hk.stressLevel {
            case .low:      return 0.2
            case .moderate: return 0.5
            case .high:     return 0.8
            case nil:       return nil
            }
        }()
        return SmartPlaylistEngine.generate(
            stressLevel: stressDouble,
            sleepHours: hk.sleepHours > 0 ? hk.sleepHours : nil,
            heartRate: hk.heartRate > 0 ? hk.heartRate : nil
        )
    }

    // MARK: - Feminine Health Card (apenas mulheres)
    private var feminineHealthCard: some View {
        NavigationLink(destination: FeminineHealthView()) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.stand.dress")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                        Text("Saúde Feminina")
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                    }
                    Text("Ciclo menstrual\ne bem-estar")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Acompanhe seu ciclo\ne saúde reprodutiva")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 0.90, green: 0.45, blue: 0.65).opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.65))
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: Color(red: 0.90, green: 0.45, blue: 0.65).opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Addiction Free Card
    private var addictionFreeCard: some View {
        NavigationLink(destination: AddictionFreeView()) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                        Text("Livre de Vícios")
                            .font(.caption.bold())
                            .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                    }
                    Text("Cigarro, álcool\ne outros vícios")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Conte seus dias livres\ne celebre cada conquista")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.70, blue: 0.50).opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lungs.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(red: 0.20, green: 0.70, blue: 0.50))
                }
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .shadow(color: Color(red: 0.20, green: 0.70, blue: 0.50).opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - AI Insight
    private var insightCard: some View {
        let birthDate = UserMemoryManager.shared.birthDate
        let hasValidBirthDate = birthDate != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(CalmTheme.accent)
                Text("Insights da Alma")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if hasValidBirthDate {
                    Button(action: { showInsightShare = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(CalmTheme.primary)
                    }
                }
            }

            if hasValidBirthDate, let date = birthDate {
                let insight = GuidanceEngine.dailyInsight(birthDate: date)

                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(CalmTheme.primary)
                        .frame(height: 3)
                        .cornerRadius(2)

                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundColor(CalmTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\"\(insight.quote)\"")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary.opacity(0.85))
                        .italic()
                        .padding(.top, 2)
                }
            } else {
                NavigationLink(destination: ProfileView()) {
                    HStack(spacing: 6) {
                        Text("Defina sua data de nascimento no Perfil para receber Insights da Alma personalizados.")
                            .font(.subheadline)
                            .foregroundColor(CalmTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(CalmTheme.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .calmCard()
        .sheet(isPresented: $showInsightShare) {
            if let date = UserMemoryManager.shared.birthDate {
                InsightShareSheet(
                    insight: GuidanceEngine.dailyInsight(birthDate: date),
                    isPresented: $showInsightShare
                )
            }
        }
    }

    // MARK: - Helpers
    /// [2026-08-02] Passa a chamar a pessoa pelo nome — quando ele existe.
    /// Sem nome informado, continua "Bom dia" puro: melhor uma saudação neutra
    /// do que um nome chutado.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        if hour < 12 { base = "Bom dia" }
        else if hour < 18 { base = "Boa tarde" }
        else { base = "Boa noite" }

        if let nome = perfil.primeiroNome {
            return "\(base), \(nome)"
        }
        return base
    }

    /// [2026-08-04 — achado na conferência visual] Saía "Terça-Feira, 4 De
    /// Agosto": `.capitalized` põe maiúscula em TODA palavra, e em português
    /// mês e a segunda parte do dia da semana são minúsculos. O certo é
    /// "Terça-feira, 4 de agosto" — só a primeira letra.
    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return Self.primeiraMaiuscula(f.string(from: Date()))
    }

    static func primeiraMaiuscula(_ texto: String) -> String {
        guard let primeira = texto.first else { return texto }
        return String(primeira).uppercased() + texto.dropFirst()
    }
}


// MARK: - SoundTile
// [Build 77 — 12/05/2026] Migrado de BinauralTrack (frequencias <20 Hz inaudiveis)
// pra RecommendedSound (MP3 real do bundle). Layout visual preservado:
// gradient + play/pause overlay + titulo + subtitulo (antes era "X Hz").
struct SoundTile: View {
    let track: RecommendedSound
    @State private var isPlaying = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var tileWidth:  CGFloat { sizeClass == .regular ? 160 : 120 }
    private var tileHeight: CGFloat { sizeClass == .regular ? 90  : 70  }

    var body: some View {
        Button(action: {
            if isPlaying {
                AudioManager.shared.stop()
                isPlaying = false
            } else {
                AudioManager.shared.playBundledSound(
                    filename: track.bundleFilename,
                    title: track.title,
                    duration: Double(track.durationSeconds),
                    loops: track.category == .sleep
                )
                isPlaying = true
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: isPlaying
                                ? [CalmTheme.accent, CalmTheme.accent.opacity(0.7)]
                                : [CalmTheme.primary, CalmTheme.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: tileWidth, height: tileHeight)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                Text(track.title)
                    .font(.caption.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                    .lineLimit(2)
                    .frame(width: tileWidth, alignment: .leading)

                Text(track.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: tileWidth)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)
//
// [2026-08-04 — TELA PRESA DEPOIS DE COMPARTILHAR]
//
// Sintoma relatado: no "Compartilhar insight", depois de compartilhar, o botão
// Fechar não fazia mais nada e a pessoa ficava presa na tela.
//
// Causa: faltava o `completionWithItemsHandler`. O `UIActivityViewController`
// se fecha SOZINHO quando o compartilhamento termina ou é cancelado — e esse
// fechamento acontece pelo lado do UIKit, sem passar pelo SwiftUI. Resultado: o
// `@State showActivitySheet` que abriu o `.sheet` continuava `true` para sempre.
// Com o SwiftUI ainda acreditando que existe um sheet filho apresentado, o
// pedido de fechar o sheet PAI era engolido.
//
// O handler abaixo é a única via pela qual o UIKit avisa o SwiftUI de que
// terminou. Sem ele, o estado nunca volta.
//
// Nota de escopo: este é o único uso cru de `UIActivityViewController` no
// projeto — o Feed usa `ShareLink`, que gerencia o próprio estado e não sofre
// deste problema.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    /// Estado do `.sheet` que apresenta este share. O handler devolve ele a
    /// `false` quando o UIKit se fecha por conta própria.
    @Binding var isPresented: Bool

    /// Fábrica separada do `makeUIViewController` de propósito: `Context` não
    /// tem inicializador público, então o método do protocolo é impossível de
    /// chamar num teste. Assim o harness exercita o controller de verdade.
    func fazerController() -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items,
                                                  applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            isPresented = false
        }
        return controller
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        fazerController()
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
