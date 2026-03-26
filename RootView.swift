import SwiftUI
import FirebaseAuth

// MARK: - RootView
// Redireciona para Login ou App principal baseado no estado de autenticação
struct RootView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if authManager.isLoggedIn {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authManager.isLoggedIn)
        .onAppear {
            // Splash de 1.5 segundos enquanto Firebase inicializa
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSplash = false }
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            AlmaTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AlmaTheme.accentGradient)
                        .frame(width: 90, height: 90)
                        .blur(radius: 20)
                        .opacity(0.4)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 52))
                        .foregroundStyle(AlmaTheme.accentGradient)
                }

                Text("Alma")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Cuide da sua mente")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(AlmaTheme.textSecondary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}
