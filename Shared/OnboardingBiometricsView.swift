import SwiftUI

struct OnboardingBiometricsView: View {

    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var currentStep = 0

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
                Text("Conta-nos um pouco sobre você")
                    .font(.title2.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Estas informações personalizam os seus Insights da Alma e tornam a experiência única para você.")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineSpacing(2)
            }

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
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.red)
            Text("Dados de saúde")
                .font(.title2.bold())
                .foregroundColor(CalmTheme.textPrimary)
            Text("A Alma pode usar dados do Apple Health para personalizar suas recomendações de bem-estar, como frequência cardíaca, sono e HRV.")
                .font(.body)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72))
                .foregroundColor(CalmTheme.accent)
            Text("Notificações")
                .font(.title2.bold())
                .foregroundColor(CalmTheme.textPrimary)
            Text("Receba lembretes diários para check-ins de humor e sessões de meditação. Você pode desativar a qualquer momento.")
                .font(.body)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
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
        }
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            onboardingComplete = true
        }
    }
}
