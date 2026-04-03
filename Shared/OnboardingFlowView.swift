import SwiftUI

/// Complete redesigned onboarding flow for Alma app
/// Supports 10 screens: Welcome → Value Props → Goal Selection → Experience Level → Permissions → Trial → Health Data → Ready
/// All copy in Portuguese (Brazilian)

struct OnboardingFlowView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var currentStep = 0
    @State private var selectedGoal: String? = nil
    @State private var selectedLevel: String? = nil
    @State private var notificationPermissionRequested = false

    private let totalSteps = 8 // Will adjust if health data is optional

    var body: some View {
        ZStack {
            CalmTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= currentStep ? CalmTheme.primary : CalmTheme.primary.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)

                // Screen content with transitions
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        valuePropMeditationStep
                    case 2:
                        valuePropBreathingStep
                    case 3:
                        valuePropTrackingStep
                    case 4:
                        goalSelectionStep
                    case 5:
                        experienceLevelStep
                    case 6:
                        notificationPermissionStep
                    case 7:
                        trialOfferStep
                    case 8:
                        healthDataStep
                    default:
                        readyStep
                    }
                }
                .id(currentStep)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Navigation buttons
                VStack(spacing: 14) {
                    Button(action: advance) {
                        HStack {
                            Text(buttonText)
                                .font(.headline)
                            if currentStep < 7 {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canAdvance ? CalmTheme.heroGradient : LinearGradient(colors: [CalmTheme.primary.opacity(0.4), CalmTheme.primary.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(CalmTheme.rMedium)
                    }
                    .disabled(!canAdvance)

                    if currentStep > 0 {
                        Button(action: { withAnimation(.easeInOut(duration: 0.3)) { currentStep -= 1 } }) {
                            Text("Voltar")
                                .foregroundColor(CalmTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentStep)
    }

    // MARK: - Step Views

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(CalmTheme.heroGradient)
                        .frame(width: 120, height: 120)

                    Text("A")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: currentStep)
                        .onAppear {
                            // Trigger animation on appear
                            _ = currentStep
                        }
                }
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: UUID())
            }

            VStack(spacing: 12) {
                Text("Bem-vindo a Alma")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("Sua jornada de bem-estar emocional começa agora. Vamos configurar tudo para você.")
                    .font(.body)
                    .foregroundColor(CalmTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var valuePropMeditationStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("🧘‍♀️")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Medite em Qualquer Lugar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Acesso a meditações guiadas para relaxamento, foco e sono. Do iniciante ao avançado, todas as durações (5 a 45 minutos).")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var valuePropBreathingStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("🌬️")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Técnicas de Respiração Baseadas em Ciência")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Reduz estresse e ansiedade em minutos. Métodos adaptados para sua situação: crise, insônia, calma geral.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var valuePropTrackingStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("📊")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Acompanhe seu Progresso")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Registre seu humor diário e veja padrões que melhoram seu bem-estar. Suas respostas guiam recomendações personalizadas.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var goalSelectionStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("O que você quer melhorar?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("(Pode mudar depois)")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                goalButton("☁️ Dormir Melhor", value: "sleep")
                goalButton("🧘 Reduzir Estresse", value: "stress")
                goalButton("🎯 Melhorar Foco", value: "focus")
                goalButton("✨ Bem-estar Geral", value: "wellness")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func goalButton(_ title: String, value: String) -> some View {
        Button(action: { selectedGoal = value }) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if selectedGoal == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(CalmTheme.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(selectedGoal == value ? CalmTheme.surface.opacity(0.8) : CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .overlay(
                RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                    .stroke(selectedGoal == value ? CalmTheme.primary : Color.clear, lineWidth: 2)
            )
        }
    }

    private var experienceLevelStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Qual é seu nível de experiência com meditação?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(CalmTheme.textPrimary)

                Text("(Personalizaremos o conteúdo)")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 12) {
                levelButton("🌱 Iniciante", subtitle: "Novo na meditação", value: "beginner")
                levelButton("🏃 Intermediário", subtitle: "Pratico regularmente", value: "intermediate")
                levelButton("🧘 Avançado", subtitle: "Pratica há muito tempo", value: "advanced")
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func levelButton(_ title: String, subtitle: String, value: String) -> some View {
        Button(action: { selectedLevel = value }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundColor(CalmTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(selectedLevel == value ? CalmTheme.surface.opacity(0.8) : CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .overlay(
                RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                    .stroke(selectedLevel == value ? CalmTheme.primary : Color.clear, lineWidth: 2)
            )
        }
    }

    private var notificationPermissionStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("🔔")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Receba Lembretes Diários")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Notificações nos ajudam a criar hábito. Você define os horários e pode desativar a qualquer momento nas configurações.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                benefitRow("Sons personalizados")
                benefitRow("Horários adaptáveis")
                benefitRow("Sem spam (1-2 por dia)")
                benefitRow("Controle total")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(CalmTheme.primary)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)

            Spacer()
        }
    }

    private var trialOfferStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("🎁")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("7 Dias Grátis Premium")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Explore meditações ilimitadas, recursos de análise e muito mais por 7 dias. Cancele sem custo sempre que quiser.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("Sem publicidades")
                featureRow("Biblioteca completa")
                featureRow("Histórico de meditação")
                featureRow("Planos personalizados")
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 8) {
                Text("Você será cobrado em 7 dias")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)

                Text("Cancelar é fácil e gratuito")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Text("💜")
                .font(.system(size: 16))

            Text(text)
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)

            Spacer()
        }
    }

    private var healthDataStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("❤️‍🔥")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Dados de Saúde (Opcional)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Alma pode usar dados do Apple Health para personalizar recomendações: frequência cardíaca, sono, HRV.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var readyStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Text("✨")
                    .font(.system(size: 72))

                VStack(spacing: 12) {
                    Text("Tudo Pronto!")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(CalmTheme.textPrimary)

                    Text("Alma está pronta para te ajudar. Fale com ela sempre que precisar de apoio emocional.")
                        .font(.body)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Navigation Logic

    private var canAdvance: Bool {
        switch currentStep {
        case 4: return selectedGoal != nil
        case 5: return selectedLevel != nil
        default: return true
        }
    }

    private var buttonText: String {
        switch currentStep {
        case 7:
            return "Começar Teste Grátis"
        case totalSteps - 1:
            return "Começar"
        default:
            return "Continuar"
        }
    }

    private func advance() {
        if currentStep < totalSteps {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            onboardingComplete = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlowView()
}
