import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var currentSlide: Int = 0

    private let onboardingSlides = [
        OnboardingSlide(
            icon: "brain.head.profile",
            title: "Bem-vindo à Alma",
            subtitle: "O teu espaço seguro para cuidar da mente."
        ),
        OnboardingSlide(
            icon: "bubble.left.fill",
            title: "Fala com a Alma IA",
            subtitle: "Uma mentora empática disponível 24/7."
        ),
        OnboardingSlide(
            icon: "chart.bar.fill",
            title: "Acompanha o teu progresso",
            subtitle: "Insights diários sobre o teu bem-estar."
        )
    ]

    var body: some View {
        ZStack {
            // Background
            AlmaTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Onboarding Slides
                TabView(selection: $currentSlide) {
                    ForEach(0..<onboardingSlides.count, id: \.self) { index in
                        OnboardingSlideView(slide: onboardingSlides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .relative))
                .frame(maxHeight: .infinity)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                VStack(spacing: 12) {
                    // Google Sign In
                    SocialLoginButton(
                        title: "Continuar com Google",
                        icon: "G",
                        backgroundColor: .white,
                        foregroundColor: .black,
                        iconColor: Color(hex: "EA4335")
                    ) {
                        authManager.signInWithGoogle()
                    }

                    // Apple Sign In
                    SocialLoginButton(
                        title: "Continuar com Apple",
                        icon: "apple.logo",
                        backgroundColor: .white,
                        foregroundColor: .black,
                        useSystemIcon: true
                    ) {
                        authManager.signInWithApple()
                    }

                    // Facebook Sign In
                    SocialLoginButton(
                        title: "Continuar com Facebook",
                        icon: "f.circle",
                        backgroundColor: Color(hex: "1877F2"),
                        foregroundColor: .white,
                        useSystemIcon: true
                    ) {
                        authManager.signInWithFacebook()
                    }

                    // Legal Text
                    Text("Ao continuar, aceitas os nossos Termos e Política de Privacidade.")
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(.horizontal, AlmaTheme.paddingPage)
                .padding(.vertical, 24)
            }

            // Loading Overlay
            if authManager.isLoading {
                LoadingOverlay()
            }

            // Error Alert
            if let errorMessage = authManager.errorMessage {
                ErrorAlertView(message: errorMessage) {
                    authManager.errorMessage = nil
                }
            }
        }
    }
}

// MARK: - Onboarding Slide View
struct OnboardingSlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: slide.icon)
                .font(.system(size: 72))
                .foregroundStyle(AlmaTheme.accentGradient)
                .frame(height: 100)

            // Text Content
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AlmaTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(slide.subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AlmaTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(.horizontal, AlmaTheme.paddingPage)

            Spacer()
        }
    }
}

// MARK: - Social Login Button
struct SocialLoginButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    var iconColor: Color? = nil
    var useSystemIcon: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if useSystemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(foregroundColor)
                } else {
                    Text(icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(iconColor ?? foregroundColor)
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(foregroundColor)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .cornerRadius(AlmaTheme.radius)
        }
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                Text("A carregar...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AlmaTheme.textPrimary)
            }
            .padding(32)
            .background(AlmaTheme.card)
            .cornerRadius(AlmaTheme.radius)
        }
    }
}

// MARK: - Error Alert View
struct ErrorAlertView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)

                    Text("Erro")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AlmaTheme.textPrimary)

                    Spacer()
                }

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AlmaTheme.textSecondary)
                    .multilineTextAlignment(.leading)

                Button(action: onDismiss) {
                    Text("OK")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red)
                        .cornerRadius(AlmaTheme.radius)
                }
            }
            .padding(20)
            .background(AlmaTheme.card)
            .cornerRadius(AlmaTheme.radius)
            .padding(AlmaTheme.paddingPage)
        }
    }
}

// MARK: - Models
struct OnboardingSlide {
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Preview
#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
