// AddictionFreeView.swift
// Alma App — Livre de Vícios (inspirado no Smoke Free)
// Foco em notificações, streak e vícios em geral

import SwiftUI
import UserNotifications

struct AddictionFreeView: View {

    @AppStorage("alma_addiction_type") private var addictionType: String = "cigarette"
    @AppStorage("alma_addiction_startTimestamp") private var startTimestamp: Double = 0
    @AppStorage("alma_addiction_isActive") private var isActive: Bool = false
    @AppStorage("alma_addiction_cigarettesPerDay") private var cigarettesPerDay: Int = 10
    @AppStorage("alma_addiction_pricePerPack") private var pricePerPack: Double = 12.0

    @State private var showStartPicker = false
    @State private var showSetupSheet = false
    @State private var tempDate = Date()
    @State private var showCravingAlert = false
    /// Apoio em crise: aberto só por toque, nunca automaticamente.
    @State private var showApoio = false
    @State private var lastCravingResisted = false
    // Tipo em edição quando o sheet é aberto pelo "Editar vício" (nil = primeiro setup).
    // Permite preservar a jornada se o usuário só ajustar quantidade/preço.
    @State private var editingFromType: String? = nil

    private let green = Color(red: 0.20, green: 0.70, blue: 0.50)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // Header
                headerSection

                if isActive {
                    // Streak e contador
                    streakSection
                    savingsSection
                    healthBenefitsSection
                    cravingSection
                } else {
                    // Setup inicial
                    setupSection

                    // Tipos de vício — só durante o setup. Após escolher, some;
                    // a edição passa a ser pelo botão "Editar vício" no card de streak.
                    // (Antes ficava sempre visível e trocar o tipo aqui mudava o
                    //  vício no meio da jornada sem confirmação.) [2026-07-14]
                    addictionTypesSection
                }

                // [2026-08-22] Aviso + apoio em crise.
                //
                // No Android esta tela já tinha o disclaimer
                // (`saude_vicio_disclaimer`); no iOS não tinha nenhum — a
                // varredura de 22/08 devolveu zero. Entram os dois aqui.
                //
                // TOM, que aqui importa mais que nas outras telas: recaída é o
                // momento de maior risco e é exatamente quando a pessoa mais
                // evita o app. Por isso é "precisa falar com alguém agora?" e
                // não um alerta — tem de parecer porta aberta, nunca
                // vigilância, cobrança ou julgamento. Nunca aparece sozinho:
                // só quando ela toca.
                AvisoDeApoio { showApoio = true }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showApoio) {
            ApoioEmCriseView()
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Livre de Vícios")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSetupSheet) {
            AddictionSetupSheet(
                addictionType: $addictionType,
                cigarettesPerDay: $cigarettesPerDay,
                pricePerPack: $pricePerPack,
                onConfirm: {
                    // Edição sem troca de tipo preserva a jornada (streak intacto);
                    // primeiro setup ou troca de tipo inicia jornada nova.
                    if editingFromType == nil || editingFromType != addictionType {
                        startTimestamp = Date().timeIntervalSince1970
                        scheduleMotivationalNotifications()
                    }
                    isActive = true
                    editingFromType = nil
                }
            )
        }
        .sheet(isPresented: $showStartPicker) {
            DatePickerSheet(title: "Quando você parou?", date: $tempDate) {
                startTimestamp = tempDate.timeIntervalSince1970
                isActive = true
                scheduleMotivationalNotifications()
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(green.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: addictionIcon)
                    .font(.system(size: 26))
                    .foregroundColor(green)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isActive ? "Continue assim! 💪" : "Pronto para mudar?")
                    .font(.title3.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Cada momento conta")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Streak Section
    private var streakSection: some View {
        let elapsed = elapsedComponents
        return VStack(spacing: 16) {
            Text("SEM \(addictionLabel.uppercased())")
                .font(.caption.bold())
                .foregroundColor(green)
                .kerning(2)

            HStack(spacing: 20) {
                timeUnit(value: elapsed.days, label: "dias")
                timeUnit(value: elapsed.hours, label: "horas")
                timeUnit(value: elapsed.minutes, label: "min")
            }

            // Milestone badge
            if let milestone = currentMilestone {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text(milestone)
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.yellow.opacity(0.12))
                .cornerRadius(20)
            }

            HStack(spacing: 24) {
                Button {
                    editingFromType = addictionType
                    showSetupSheet = true
                } label: {
                    Label("Editar vício", systemImage: "pencil")
                        .font(.caption.bold())
                        .foregroundColor(green)
                }

                Button {
                    showStartPicker = true
                } label: {
                    Text("Ajustar data de início")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
        }
        .padding(20)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .shadow(color: green.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Savings
    private var savingsSection: some View {
        guard addictionType == "cigarette" else { return AnyView(EmptyView()) }

        let days = elapsedComponents.days
        let packs = Double(days) * Double(cigarettesPerDay) / 20.0
        let saved = packs * pricePerPack
        let cigarettesAvoided = days * cigarettesPerDay

        return AnyView(
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("R$ \(String(format: "%.0f", saved))")
                        .font(.title2.bold())
                        .foregroundColor(green)
                    Text("economizados")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(CalmTheme.surface)
                .cornerRadius(CalmTheme.rSmall)

                VStack(spacing: 4) {
                    Text("\(cigarettesAvoided)")
                        .font(.title2.bold())
                        .foregroundColor(Color.red.opacity(0.7))
                    Text("cigarros evitados")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(CalmTheme.surface)
                .cornerRadius(CalmTheme.rSmall)
            }
        )
    }

    // MARK: - Marcos da jornada
    //
    // [2026-08-04 — VARREDURA DE CONFORMIDADE]
    //
    // Isto se chamava "Benefícios alcançados" e afirmava mudanças no CORPO da
    // pessoa a partir do tempo decorrido: "função pulmonar aumenta até 30%",
    // "risco de doença cardíaca cortado pela metade", "monóxido de carbono no
    // sangue cai para níveis normais".
    //
    // Os números vêm da literatura de cessação do tabagismo e são verdadeiros
    // como informação de saúde pública. O problema não é a fonte — é a forma:
    // apresentados como conquista PESSOAL e quantificada, viram alegação médica
    // sobre o organismo de quem lê. O Alma não é dispositivo médico, e este é
    // exatamente o tipo de afirmação que já custou uma suspensão no Google Play.
    //
    // A régua nova: celebrar o TEMPO (que é fato, medido pelo app) e falar do
    // corpo só de forma geral e atribuída, sem número e sem "você alcançou".
    private var healthBenefitsSection: some View {
        let days = elapsedComponents.days
        let hours = days * 24 + elapsedComponents.hours

        let benefits: [(hours: Int, icon: String, title: String, description: String)] = [
            (1, "heart.fill", "Primeira hora", "O começo de tudo é a decisão que você já tomou"),
            (12, "lungs.fill", "12 horas", "Meio dia inteiro sem ceder — o corpo agradece do seu jeito"),
            (48, "nose.fill", "2 dias", "Muita gente relata que cheiro e paladar ficam mais presentes"),
            (168, "figure.walk", "1 semana", "Sete dias. A primeira semana costuma ser a mais dura"),
            (720, "wind", "1 mês", "Um mês inteiro. Respirar fica diferente quando o hábito afrouxa"),
            (8760, "star.fill", "1 ANO LIVRE!", "Um ano. A literatura de saúde associa esse marco a ganhos importantes a longo prazo — converse com seu médico sobre os seus. PARABÉNS!"),
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Marcos da sua jornada")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            ForEach(benefits, id: \.title) { benefit in
                let achieved = hours >= benefit.hours
                HStack(spacing: 12) {
                    Image(systemName: benefit.icon)
                        .foregroundColor(achieved ? green : CalmTheme.textSecondary.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(achieved ? green.opacity(0.1) : Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title)
                            .font(.subheadline.bold())
                            .foregroundColor(achieved ? CalmTheme.textPrimary : CalmTheme.textSecondary.opacity(0.5))
                        Text(benefit.description)
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary.opacity(achieved ? 0.8 : 0.4))
                    }
                    Spacer()
                    if achieved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(green)
                    }
                }
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Craving Help
    /// Abre o apoio a partir de um alerta já na tela.
    ///
    /// [2026-08-26] O atraso não é enfeite: no iOS 16 (nosso
    /// `IPHONEOS_DEPLOYMENT_TARGET`) trocar um alerta por uma folha no mesmo
    /// ciclo faz a folha ser engolida pela animação de saída do alerta — a
    /// pessoa toca, o alerta some e não vem nada. Falha silenciosa, no pior
    /// momento possível. 0,4 s é imperceptível e determinístico.
    private func abrirApoioDepoisDoAlerta() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showApoio = true
        }
    }

    private var cravingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Está com vontade de recair?")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            // [2026-08-26] Saiu daqui um `asyncAfter(+3) { lastCravingResisted
            // = true }` que marcava "resistiu" 3 segundos depois do toque,
            // INDEPENDENTE da resposta. Quem tocasse "Preciso de ajuda" era
            // parabenizado — "Você superou mais uma! Continue! 🎉" — três
            // segundos depois de dizer que não estava bem. Agora só a escolha
            // explícita da pessoa marca.
            Button {
                showCravingAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.heart.fill")
                    Text("Resistir agora (5 min)")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(green)
                .foregroundColor(.white)
                .cornerRadius(CalmTheme.rSmall)
            }

            if lastCravingResisted {
                HStack(spacing: 8) {
                    Image(systemName: "hand.thumbsup.fill").foregroundColor(green)
                    Text("Você superou mais uma! Continue! 🎉")
                        .font(.subheadline)
                        .foregroundColor(green)
                }
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        // [2026-08-26] Este diálogo é o momento de maior risco da tela inteira
        // — é a fissura, é quando a pessoa está prestes a recair — e era o
        // único ponto do fluxo de crise sem a porta de apoio. Pior: já existia
        // um botão chamado "Preciso de ajuda", com `role: .cancel` e corpo
        // VAZIO. A pessoa nomeava a necessidade, tocava, e o diálogo só
        // fechava. Um botão que promete ajuda e não faz nada é pior que a
        // ausência do botão: gasta a coragem de pedir e devolve silêncio.
        //
        // TOM — a mesma regra do rodapé (`ApoioEmCrise.swift:88-91`): o app não
        // declara crise, não alerta e não julga. "Quero falar com alguém" é
        // primeira pessoa e é escolha dela, igual ao "Precisa falar com alguém
        // agora?" do `LinkDeApoio`. Porta aberta, não alarme.
        //
        // E entrou "Agora não": sem uma saída neutra, quem NÃO resistiu só
        // podia sair pelo "Consegui resistir" — o app obrigando a pessoa a
        // mentir sobre a própria recaída para fechar um diálogo.
        .alert("Respire fundo", isPresented: $showCravingAlert) {
            Button("Consegui resistir! ✅") { lastCravingResisted = true }
            Button("Quero falar com alguém") { abrirApoioDepoisDoAlerta() }
            Button("Agora não", role: .cancel) { }
        } message: {
            Text("A vontade dura apenas alguns minutos. Inspire 4 segundos... segure 4... expire 6 segundos. Repita 3 vezes. Está melhor?")
        }
    }

    // MARK: - Setup Section
    private var setupSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 48))
                .foregroundColor(green)
                .padding(.top, 8)

            Text("Comece sua jornada livre")
                .font(.title3.bold())
                .foregroundColor(CalmTheme.textPrimary)

            Text("Registre o dia em que você parou e acompanhe seu progresso. Cada hora conta.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                showSetupSheet = true
            } label: {
                Label("Começar agora", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(green)
                    .foregroundColor(.white)
                    .cornerRadius(CalmTheme.rMedium)
            }
        }
        .padding(20)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Addiction Types
    private var addictionTypesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tipo de vício")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(addictionTypes, id: \.id) { type in
                    Button {
                        addictionType = type.id
                    } label: {
                        VStack(spacing: 8) {
                            Text(type.emoji).font(.system(size: 28))
                            Text(type.name)
                                .font(.caption.bold())
                                .foregroundColor(addictionType == type.id ? green : CalmTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(addictionType == type.id ? green.opacity(0.1) : CalmTheme.surface)
                        .cornerRadius(CalmTheme.rSmall)
                        .overlay(RoundedRectangle(cornerRadius: CalmTheme.rSmall)
                            .strokeBorder(addictionType == type.id ? green : Color.clear, lineWidth: 1.5))
                    }
                }
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Notifications
    private func scheduleMotivationalNotifications() {
        #if DEBUG
        if DebugContextDump.suprimirPermissoes { return }
        #endif
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let messages = [
                (hours: 1, msg: "1 hora livre! Seu corpo já está agradecendo. 💪"),
                (hours: 12, msg: "12 horas! O CO₂ no sangue já baixou. Continue!"),
                (hours: 24, msg: "1 DIA COMPLETO! Fantástico. Você sente a diferença?"),
                (hours: 168, msg: "1 SEMANA SEM VÍCIO! Sua circulação melhorou. 🎉"),
                (hours: 720, msg: "1 MÊS! Seus pulmões estão 30% mais saudáveis. 🌟"),
            ]

            for msg in messages {
                let content = UNMutableNotificationContent()
                content.title = "Alma — Livre de Vícios"
                content.body = msg.msg
                content.sound = .default
                // [2026-08-05] Tocar no marco leva ao contador que o gerou, e
                // não à Início. Ver RotaDaNotificacao.swift.
                content.userInfo = RotaDaNotificacao.carimbo(para: "addiction_\(msg.hours)")

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: Double(msg.hours * 3600),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: "addiction_\(msg.hours)",
                    content: content,
                    trigger: trigger
                )
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Helpers
    private struct ElapsedComponents {
        let days: Int; let hours: Int; let minutes: Int
    }

    private var elapsedComponents: ElapsedComponents {
        guard startTimestamp > 0 else { return .init(days: 0, hours: 0, minutes: 0) }
        let start = Date(timeIntervalSince1970: startTimestamp)
        let diff = Int(Date().timeIntervalSince(start))
        return .init(days: diff / 86400, hours: (diff % 86400) / 3600, minutes: (diff % 3600) / 60)
    }

    private var currentMilestone: String? {
        let days = elapsedComponents.days
        let hours = elapsedComponents.days * 24 + elapsedComponents.hours
        if hours >= 8760 { return "🏆 1 ANO LIVRE!" }
        if days >= 30 { return "🌟 1 MÊS LIVRE!" }
        if days >= 7 { return "🎯 1 SEMANA LIVRE!" }
        if hours >= 24 { return "⭐ 1 DIA LIVRE!" }
        return nil
    }

    private var addictionLabel: String {
        addictionTypes.first { $0.id == addictionType }?.name ?? "vício"
    }

    private var addictionIcon: String {
        addictionTypes.first { $0.id == addictionType }?.icon ?? "lungs.fill"
    }

    private struct AddictionType: Identifiable {
        let id: String; let name: String; let emoji: String; let icon: String
    }

    private let addictionTypes: [AddictionType] = [
        AddictionType(id: "cigarette", name: "Cigarro", emoji: "🚬", icon: "lungs.fill"),
        AddictionType(id: "alcohol", name: "Álcool", emoji: "🍺", icon: "drop.fill"),
        AddictionType(id: "sugar", name: "Açúcar", emoji: "🍬", icon: "fork.knife"),
        AddictionType(id: "social_media", name: "Redes sociais", emoji: "📱", icon: "iphone"),
        AddictionType(id: "gambling", name: "Jogos", emoji: "🎰", icon: "dice.fill"),
        AddictionType(id: "caffeine", name: "Cafeína", emoji: "☕", icon: "cup.and.saucer.fill"),
    ]

    @ViewBuilder
    private func timeUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(green)
            Text(label)
                .font(.caption)
                .foregroundColor(CalmTheme.textSecondary)
        }
        .frame(minWidth: 70)
    }
}

// MARK: - Setup Sheet
struct AddictionSetupSheet: View {
    @Binding var addictionType: String
    @Binding var cigarettesPerDay: Int
    @Binding var pricePerPack: Double
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Tipo de vício") {
                    Picker("Tipo", selection: $addictionType) {
                        Text("Cigarro").tag("cigarette")
                        Text("Álcool").tag("alcohol")
                        Text("Açúcar").tag("sugar")
                        Text("Redes sociais").tag("social_media")
                        Text("Jogos").tag("gambling")
                        Text("Cafeína").tag("caffeine")
                    }
                }
                if addictionType == "cigarette" {
                    Section("Detalhes (para calcular economia)") {
                        Stepper("Cigarros/dia: \(cigarettesPerDay)", value: $cigarettesPerDay, in: 1...60)
                        HStack {
                            Text("Preço por maço (R$)")
                            Spacer()
                            TextField("12.00", value: $pricePerPack, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
            .navigationTitle("Configurar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Começar!") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}
