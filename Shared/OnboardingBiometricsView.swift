import SwiftUI

struct OnboardingBiometricsView: View {

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    /// [2026-08-03 — A5] Faltava: apresentado como sheet pelo card "Complete
    /// seu perfil", o botão "Começar" não fechava nada — só saía por swipe.
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    // [2026-08-02] Onboarding ÚNICO, cobrindo Alma e Corpo.
    // Este fluxo já existia e pedia gênero, nascimento, horário e local — mas
    // nunca perguntava o NOME. Resultado: a Home só sabia dizer "Bom dia" e o
    // módulo Corpo chamava todo mundo de "Felipe" (o valor padrão herdado).
    // Em vez de criar um segundo onboarding, os campos que faltavam entraram
    // aqui: nome (passo 1), peso e altura (passo 2) e o consentimento por
    // categoria do contexto de saúde (passo 3).
    @StateObject private var corpo = AppModel()
    @State private var nomeDigitado = ""
    @State private var pesoTexto = ""
    @State private var alturaTexto = ""

    // Identity step state
    // [2026-08-14] `selectedGender` (identidade, 4 opções) saiu. No lugar,
    // a fisiologia: "Feminino" | "Masculino" | "Prefiro não informar" | "".
    @State private var selectedBiologicalSex = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var hasBirthDate = false
    @State private var selectedBirthTimeSlot = ""
    @State private var birthCity = ""
    @State private var birthCountry = ""

    // Step 0: welcome, Step 1: identity, Step 2: health, Step 3: notifications, Step 4: ready
    private let totalSteps = 5

    private var canAdvance: Bool {
        // O passo 1 exige a fisiologia respondida — e "Prefiro não informar"
        // satisfaz. O portão continua existindo para que a pergunta não passe
        // batida, não para arrancar um dado de quem não quer dá-lo.
        if currentStep == 1 { return !selectedBiologicalSex.isEmpty }
        return true
    }

    var body: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? CalmTheme.primary : CalmTheme.primary.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 24)

                // Step content
                ScrollView(showsIndicators: false) {
                    Group {
                        switch currentStep {
                        case 0: welcomeStep
                        case 1: identityStep
                        case 2: healthStep
                        case 3: notificationsStep
                        default: readyStep
                        }
                    }
                    .id(currentStep)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .adaptiveContentWidth()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }

                Spacer(minLength: 0)
            }

            // Continue button — pinned to bottom
            VStack {
                Spacer()
                Button(action: advance) {
                    Text(currentStep == totalSteps - 1 ? "Começar" : "Continuar")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canAdvance ? CalmTheme.heroGradient : LinearGradient(colors: [CalmTheme.primary.opacity(0.35), CalmTheme.primary.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(CalmTheme.rMedium)
                }
                .disabled(!canAdvance)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
        // [2026-08-03 — A4] Pré-carrega o que já existe. Reaberto pelo card
        // "Complete seu perfil", este fluxo abria com tudo em branco e regravava
        // por cima — quem voltava só para pôr o peso perdia cidade e horário.
        .onAppear(perform: precarregar)
    }

    private func precarregar() {
        let memoria = UserMemoryManager.shared
        if nomeDigitado.isEmpty { nomeDigitado = UserProfileStore.shared.nome ?? corpo.userName }
        // [2026-08-14] Ao REABRIR o onboarding (card "Complete seu perfil"), a
        // resposta de fisiologia já dada é pré-selecionada. E quem só tem o
        // gênero legado gravado vê a tradução dele já marcada — "Feminino" e
        // "Masculino" viram a opção correspondente; "Não binário" e "Prefiro
        // não dizer" NÃO viram nada, porque não carregam fisiologia, e a pessoa
        // decide na hora. Mesma regra do cálculo, pela mesma função pura.
        if selectedBiologicalSex.isEmpty {
            selectedBiologicalSex = memoria.sexoBiologicoBruto.isEmpty
                ? (RegrasDeSaude.sexoDoGeneroLegado(memoria.gender)?.rawValue ?? "")
                : memoria.sexoBiologicoBruto
        }
        if selectedBirthTimeSlot.isEmpty { selectedBirthTimeSlot = memoria.birthTimeSlot }
        if birthCity.isEmpty { birthCity = memoria.birthCity }
        if birthCountry.isEmpty { birthCountry = memoria.birthCountry }

        // Data de nascimento: o perfil novo (App Group) é a referência, mas
        // usuário antigo só tem a data no UserMemoryManager. [A6b]
        if let doPerfil = UserProfileStore.shared.dataNascimento {
            birthDate = doPerfil
            hasBirthDate = true
        } else if let daMemoria = memoria.birthDate {
            birthDate = daMemoria
            hasBirthDate = true
            // Migra para o perfil único, senão o card cobra para sempre uma
            // data que o app já tem.
            UserProfileStore.shared.dataNascimento = daMemoria
        }

        if corpo.weightKg > 0, pesoTexto.isEmpty { pesoTexto = String(format: "%.1f", corpo.weightKg) }
        if corpo.heightCm > 0, alturaTexto.isEmpty { alturaTexto = String(format: "%.0f", corpo.heightCm) }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            ZStack {
                Circle()
                    .fill(CalmTheme.heroGradient)
                    .frame(width: 100, height: 100)
                Text("A")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Bem-vindo à Alma")
                .font(.title.bold())
                .foregroundColor(CalmTheme.textPrimary)
            Text("Sua jornada de bem-estar emocional começa agora. Vamos configurar tudo para você em poucos passos.")
                .font(.body)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("✨")
                    .font(.system(size: 36))
                // [2026-08-02] Era "Conta-nos" e "os seus Insights" — português
                // de Portugal. O projeto é PT-BR, sem exceção.
                Text("Conte um pouco sobre você")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Estas informações personalizam seus insights da Alma e tornam a experiência única para você.")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineSpacing(2)
            }

            // ── Nome ──────────────────────────────────────────────────
            // O campo que faltava. Sem ele a Alma fala com um usuário genérico.
            VStack(alignment: .leading, spacing: 10) {
                Text("Como você quer ser chamado?")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                TextField("Seu nome", text: $nomeDigitado)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(CalmTheme.surface)
                    .cornerRadius(10)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textPrimary)
            }

            Divider().opacity(0.3)

            // ── Sexo biológico ────────────────────────────────────────
            //
            // [2026-08-14] SUBSTITUI a pergunta de identidade ("Como você se
            // identifica?", 4 opções, gravada em `alma_user_gender`). Decisão
            // do Assis: *"não deveria ser como se identifica, e sim sua
            // fisiologia, homem ou mulher"*.
            //
            // É substituição, não acréscimo: duas perguntas parecidas no mesmo
            // passo criariam atrito e ambiguidade sobre qual manda no cálculo.
            // A pergunta antiga tinha um único consumidor em todo o app — o
            // portão da saúde feminina (`HomeView:98`) — e ele passou a ler a
            // fisiologia. Nada mais lia o campo (enumerado em 14/08).
            //
            // A LINHA DE PROPÓSITO NÃO É ENFEITE. Pergunta de fisiologia em app
            // de bem-estar, sem contexto, parece intrusiva e faz gente
            // responder qualquer coisa para passar da tela — e aí o dado que
            // motivou a mudança nasce errado. Dizer para que serve é o que
            // torna a resposta confiável, e é literalmente verdade: metabolismo
            // é o Mifflin-St Jeor, "acompanhar sua saúde" é ciclo e gravidez.
            //
            // A TERCEIRA OPÇÃO existe porque o passo é obrigatório para
            // avançar. Com só duas saídas, quem não se encaixa escolhe qualquer
            // uma para passar — e o dado nasce falso, sem que ninguém saiba
            // quem. "Prefiro não informar" é resposta de verdade: ela distingue
            // recusa de silêncio (ver `UserMemoryManager.respondeuFisiologia`)
            // e leva à meta declarada como estimativa, nunca a um número
            // apresentado como cálculo pessoal.
            VStack(alignment: .leading, spacing: 10) {
                Text("Sexo biológico")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Para calcular seu metabolismo e acompanhar sua saúde. A fórmula de calorias muda conforme a fisiologia.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                let opcoes = ["Feminino", "Masculino", UserMemoryManager.recusaFisiologia]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(opcoes, id: \.self) { opcao in
                        identityChoiceButton(opcao, selected: selectedBiologicalSex == opcao) {
                            selectedBiologicalSex = opcao
                        }
                    }
                }
                Text("Fica no seu aparelho. Você pode mudar depois em Dieta → Meta.")
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            Divider().opacity(0.3)

            // ── Data de nascimento ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Data de nascimento")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Spacer()
                    Text("Opcional")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Text("Cada data guarda um convite. Ajuda a Alma a te encontrar.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                Toggle("Definir minha data de nascimento", isOn: $hasBirthDate)
                    .tint(CalmTheme.primary)
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textPrimary)
                if hasBirthDate {
                    DatePicker("", selection: $birthDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(CalmTheme.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut, value: hasBirthDate)
                }
            }

            Divider().opacity(0.3)

            // ── Horário aproximado de nascimento ──────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Horário aproximado de nascimento")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Spacer()
                    Text("Opcional")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Text("Aumenta a precisão dos seus insights astrológicos e energéticos.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                let timeSlots = ["Madrugada (0h–6h)", "Manhã (6h–12h)", "Tarde (12h–18h)", "Noite (18h–24h)", "Não sei"]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(timeSlots, id: \.self) { slot in
                        identityChoiceButton(slot, selected: selectedBirthTimeSlot == slot) {
                            selectedBirthTimeSlot = selectedBirthTimeSlot == slot ? "" : slot
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // ── Cidade e país de nascimento ──────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Cidade e país de nascimento")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Spacer()
                    Text("Opcional")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Text("Usados para calcular a posição energética no seu mapa pessoal.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                HStack(spacing: 10) {
                    TextField("Cidade", text: $birthCity)
                        .padding(12)
                        .background(CalmTheme.surface)
                        .cornerRadius(10)
                        .font(.subheadline)
                    TextField("País", text: $birthCountry)
                        .padding(12)
                        .background(CalmTheme.surface)
                        .cornerRadius(10)
                        .font(.subheadline)
                }
            }
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.red)
                Text("Seu corpo")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("A Alma pode usar dados do Apple Health — sono, passos, exercício — para entender seu dia.")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            Divider().opacity(0.3)

            // [2026-08-02] Peso e altura passam a ser pedidos aqui. Antes, o
            // módulo Corpo assumia 78,4 kg e 1,78 m como padrão e calculava
            // metas de caloria e água em cima de um corpo que não existia.
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Peso e altura")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Spacer()
                    Text("Opcional")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Text("Sem isso, as metas de calorias e água seriam chute. Fica só no seu aparelho.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)

                HStack(spacing: 10) {
                    TextField("Peso (kg)", text: $pesoTexto)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(CalmTheme.surface)
                        .cornerRadius(10)
                        .font(.subheadline)
                    TextField("Altura (cm)", text: $alturaTexto)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(CalmTheme.surface)
                        .cornerRadius(10)
                        .font(.subheadline)
                }
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 44))
                    .foregroundColor(CalmTheme.primary)
                Text("O que a Alma pode ver")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Ela recebe um resumo curto do seu dia — nunca seus registros, nunca o que você escreveu. Você escolhe o que entra.")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }

            // [2026-08-02] O consentimento por categoria estava escondido no
            // Perfil. Quem nunca foi lá deixava a Alma cega sem saber disso.
            VStack(spacing: 10) {
                ForEach(HealthConsentCategory.allCases.filter(\.isAvailableNow)) { categoria in
                    consentimentoRow(categoria)
                }
            }

            Text("Pode desligar tudo quando quiser, no Perfil.")
                .font(.caption2)
                .foregroundColor(CalmTheme.textSecondary)
        }
    }

    private func consentimentoRow(_ categoria: HealthConsentCategory) -> some View {
        Toggle(isOn: Binding(
            get: { HealthContextConsent.isGranted(categoria) },
            set: { HealthContextConsent.set($0, for: categoria) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoria.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(CalmTheme.textPrimary)
                Text(categoria.explanation)
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .tint(CalmTheme.primary)
        .padding(12)
        .background(CalmTheme.surface)
        .cornerRadius(12)
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Image(systemName: "sparkles")
                .font(.system(size: 72))
                .foregroundColor(CalmTheme.primary)
            Text("Tudo pronto!")
                .font(.title.bold())
                .foregroundColor(CalmTheme.textPrimary)
            Text("A Alma está pronta para te ajudar. Fale com ela sempre que precisar de apoio emocional.")
                .font(.body)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - UI Helpers

    private func identityChoiceButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(selected ? .white : CalmTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(selected ? CalmTheme.primary : CalmTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? CalmTheme.primary : CalmTheme.primary.opacity(0.15), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    // MARK: - Advance

    private func advance() {
        if currentStep == 1 {
            // [2026-08-14] A fisiologia vai para a chave nova
            // (`alma_user_biological_sex`). O `alma_user_gender` NÃO é
            // escrito nem apagado aqui: ele é a ponte que faz quem já usa o
            // app manter a saúde feminina e ganhar a meta certa sem refazer
            // nada (`RegrasDeSaude.sexoEfetivo`, terceira posição da cadeia).
            //
            // Vazio não sobrescreve — mesma guarda do `setIdentity`, pelo mesmo
            // motivo: o onboarding pode ser reaberto pelo card "Complete seu
            // perfil" e não pode apagar o que já foi respondido.
            if !selectedBiologicalSex.isEmpty {
                UserMemoryManager.shared.sexoBiologicoBruto = selectedBiologicalSex
                // O AppModel resolve a cadeia no `init`; esta é a instância
                // já viva, que precisa acompanhar na mesma hora.
                corpo.sex = BiologicalSex(rawValue: selectedBiologicalSex)
            }

            // Save identity data
            UserMemoryManager.shared.setIdentity(
                gender: "",   // a pergunta de identidade saiu do onboarding
                birthDate: hasBirthDate ? birthDate : nil,
                birthTimeSlot: selectedBirthTimeSlot,
                birthCity: birthCity,
                birthCountry: birthCountry
            )

            // [2026-08-02] Nome e nascimento vão para o perfil único, que a Home
            // e o módulo Corpo leem. Campo vazio não grava nada — sem chute.
            let nome = nomeDigitado.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nome.isEmpty {
                UserProfileStore.shared.nome = nome
                corpo.userName = nome
            }
            if hasBirthDate {
                UserProfileStore.shared.dataNascimento = birthDate
                if let idade = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year {
                    corpo.ageYears = idade
                }
            }
        }
        // [A6c] Passou pela tela de consentimento: a decisão foi tomada, ligando
        // algo ou não. O card para de cobrar quem exerceu o direito de recusar.
        if currentStep == 3 {
            UserProfileStore.shared.decidiuSobreContexto = true
        }
        if currentStep == 2 {
            if let peso = Double(pesoTexto.replacingOccurrences(of: ",", with: ".")), peso > 0 {
                corpo.weightKg = peso
            }
            if let altura = Double(alturaTexto.replacingOccurrences(of: ",", with: ".")), altura > 0 {
                corpo.heightCm = altura
            }
        }
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            UserProfileStore.shared.onboardingConcluido = true
            onboardingComplete = true
            dismiss()   // [A5] fecha quando veio como sheet; inofensivo no RootView
        }
    }
}
