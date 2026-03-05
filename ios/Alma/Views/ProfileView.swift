import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("notificationsEnabled")   private var notificationsEnabled   = true
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            List {

                // ── Profile header ─────────────────────────────────
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.almaLight, Color.almaPrimary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                            Text(initial)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.title3.bold())
                            Text("Membro do Alma")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // ── Statistics ─────────────────────────────────────
                Section("Suas Estatísticas") {
                    StatRow(icon: "sparkles",    label: "Sessões Totais",
                            value: "\(userViewModel.totalSessions)",        color: .almaPrimary)
                    StatRow(icon: "clock.fill",  label: "Minutos Meditados",
                            value: "\(userViewModel.totalMinutes) min",     color: .blue)
                    StatRow(icon: "flame.fill",  label: "Sequência Atual",
                            value: "\(userViewModel.currentStreak) dias",   color: .orange)
                    StatRow(icon: "trophy.fill", label: "Melhor Sequência",
                            value: "\(userViewModel.longestStreak) dias",   color: .yellow)
                }

                // ── Settings ───────────────────────────────────────
                Section("Configurações") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Lembretes Diários", systemImage: "bell.fill")
                    }
                    .tint(.almaPrimary)
                }

                // ── About ──────────────────────────────────────────
                Section("Sobre") {
                    LabeledContent("Versão") {
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/felipeassislara170/alma.app.oficial")!) {
                        Label("Repositório no GitHub", systemImage: "link")
                    }
                }

                // ── Reset ──────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Redefinir Onboarding", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Perfil")
        }
        .alert("Redefinir app?", isPresented: $showResetAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Redefinir", role: .destructive) {
                hasCompletedOnboarding = false
            }
        } message: {
            Text("O onboarding será reiniciado. Seu histórico e estatísticas serão mantidos.")
        }
    }

    private var displayName: String {
        userViewModel.userName.isEmpty ? "Usuário" : userViewModel.userName
    }

    private var initial: String {
        String((userViewModel.userName.first ?? "U").uppercased())
    }
}

// MARK: - StatRow

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserViewModel())
}
