import SwiftUI

struct OnboardingBiometricsView: View {

    @AppStorage("onboardingComplete") private var onboardingComplete = false
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
    @State private var selectedGender = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var hasBirthDate = false
    @State private var selectedBirthTimeSlot = ""
    @State private var birthCity = ""
    @State private var birthCountry = ""

    // Step 0: welcome, Step 1: identity, Step 2: health, Step 3: notifications, Step 4: ready
    private let totalSteps = 5

    private var canAdvance: Bool {
        // Identity step requires at minimum a gender selection
        if currentStep == 1 { return !selectedGender.isEmpty }
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

            // ── Género ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Text("Como você se identifica?")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                let genders = ["Feminino", "Masculino", "Não binário", "Prefiro não dizer"]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(genders, id: \.self) { g in
                        identityChoiceButton(g, selected: selectedGender == g) {
                            selectedGender = g
                        }
                    }
                }
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
            // Save identity data
            UserMemoryManager.shared.setIdentity(
                gender: selectedGender,
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
        }
    }
}
