import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    @State private var page = 0
    @State private var nameInput = ""

    private let pages: [OPage] = [
        OPage(emoji: "💜", title: "Bem-vindo ao Alma",
              subtitle: "Seu companheiro de bem-estar mental. Comece sua jornada para uma vida mais tranquila e equilibrada."),
        OPage(emoji: "🧘", title: "Medite Todo Dia",
              subtitle: "Meditações guiadas para todos os níveis — do iniciante ao avançado, a qualquer hora do dia."),
        OPage(emoji: "🌬️", title: "Respire Melhor",
              subtitle: "Técnicas de respiração baseadas em evidências para reduzir o estresse em minutos."),
        OPage(emoji: "📊", title: "Acompanhe seu Humor",
              subtitle: "Registre como você se sente cada dia e descubra padrões que melhoram seu bem-estar."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.almaBackground, Color.almaCard],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count + 1, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i == page ? Color.almaPrimary : Color.almaPrimary.opacity(0.25))
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: page)
                    }
                }
                .padding(.top, 64)

                Spacer()

                // Page content
                Group {
                    if page < pages.count {
                        let p = pages[page]
                        VStack(spacing: 24) {
                            Text(p.emoji).font(.system(size: 80))
                            Text(p.title)
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)
                            Text(p.subtitle)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        VStack(spacing: 24) {
                            Text("👤").font(.system(size: 80))
                            Text("Como posso te chamar?")
                                .font(.system(size: 28, weight: .bold))
                                .multilineTextAlignment(.center)
                            Text("Vamos personalizar sua experiência no Alma.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            TextField("Seu nome", text: $nameInput)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                                .padding(.horizontal, 40)
                                .padding(.top, 8)
                        }
                    }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer()

                // Buttons
                VStack(spacing: 14) {
                    Button(action: advance) {
                        HStack {
                            Text(page < pages.count ? "Continuar" : "Começar Jornada")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(canAdvance ? Color.almaPrimary : Color.almaPrimary.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(!canAdvance)

                    if page > 0 {
                        Button("Voltar") {
                            withAnimation(.easeInOut(duration: 0.3)) { page -= 1 }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private var canAdvance: Bool {
        page < pages.count ? true : !nameInput.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func advance() {
        if page < pages.count {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            userName = nameInput.trimmingCharacters(in: .whitespaces)
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Helpers

private struct OPage {
    let emoji: String
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingView()
}
