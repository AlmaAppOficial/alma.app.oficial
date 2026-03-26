import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showDeleteConfirmation = false
    @State private var notificationsEnabled = true
    @State private var totalCheckIns = 0
    @State private var streakDays = 0
    @State private var daysActive = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar and User Info
                    VStack(spacing: 12) {
                        if let photoURL = authManager.userProfile?.photoURL,
                           !photoURL.isEmpty {
                            AsyncImage(url: URL(string: photoURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                case .loading:
                                    ProgressView()
                                        .frame(width: 80, height: 80)
                                case .failure:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 80, height: 80)
                                        .foregroundColor(AlmaTheme.accent)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(AlmaTheme.accent)
                        }

                        Text(authManager.userProfile?.name ?? "Utilizador")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AlmaTheme.textPrimary)

                        Text(authManager.userProfile?.email ?? "")
                            .font(.caption)
                            .foregroundColor(AlmaTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AlmaTheme.paddingPage)

                    // Stats Row
                    HStack(spacing: 12) {
                        StatItem(
                            value: String(streakDays),
                            label: "Dias\nseguidos",
                            icon: "🔥"
                        )

                        StatItem(
                            value: String(totalCheckIns),
                            label: "Check-ins",
                            icon: "✅"
                        )

                        StatItem(
                            value: String(daysActive),
                            label: "Dias desde\nque se juntou",
                            icon: "📅"
                        )
                    }
                    .padding(.horizontal, AlmaTheme.paddingPage)

                    // Conta Section
                    VStack(spacing: 12) {
                        SectionHeader(title: "Conta")

                        NavigationLink(destination: SubscriptionView()) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(AlmaTheme.accent)
                                Text("Fazer upgrade para Premium")
                                    .font(.subheadline)
                                    .foregroundColor(AlmaTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AlmaTheme.textSecondary)
                            }
                            .padding(AlmaTheme.paddingPage)
                            .background(AlmaTheme.card)
                            .cornerRadius(AlmaTheme.radius)
                        }

                        Toggle(isOn: $notificationsEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(AlmaTheme.accent)
                                Text("Notificações")
                                    .font(.subheadline)
                                    .foregroundColor(AlmaTheme.textPrimary)
                            }
                        }
                        .padding(AlmaTheme.paddingPage)
                        .background(AlmaTheme.card)
                        .cornerRadius(AlmaTheme.radius)
                        .tint(AlmaTheme.accent)
                    }
                    .padding(.horizontal, AlmaTheme.paddingPage)

                    // Suporte Section
                    VStack(spacing: 12) {
                        SectionHeader(title: "Suporte")

                        Link(destination: URL(string: "https://alma-wellness.pt/privacidade")!) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(AlmaTheme.accent)
                                Text("Privacidade")
                                    .font(.subheadline)
                                    .foregroundColor(AlmaTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AlmaTheme.textSecondary)
                            }
                            .padding(AlmaTheme.paddingPage)
                            .background(AlmaTheme.card)
                            .cornerRadius(AlmaTheme.radius)
                        }

                        Link(destination: URL(string: "https://alma-wellness.pt/termos")!) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(AlmaTheme.accent)
                                Text("Termos de Uso")
                                    .font(.subheadline)
                                    .foregroundColor(AlmaTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AlmaTheme.textSecondary)
                            }
                            .padding(AlmaTheme.paddingPage)
                            .background(AlmaTheme.card)
                            .cornerRadius(AlmaTheme.radius)
                        }
                    }
                    .padding(.horizontal, AlmaTheme.paddingPage)

                    // Danger Zone Section
                    VStack(spacing: 12) {
                        SectionHeader(title: "Zona de Perigo", isDanger: true)

                        Button(action: {
                            authManager.signOut()
                        }) {
                            HStack {
                                Image(systemName: "arrowtriang.right.fill")
                                    .foregroundColor(.red)
                                Text("Terminar sessão")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(AlmaTheme.paddingPage)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(AlmaTheme.radius)
                        }

                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                Text("Eliminar conta")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(AlmaTheme.paddingPage)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(AlmaTheme.radius)
                        }
                    }
                    .padding(.horizontal, AlmaTheme.paddingPage)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, AlmaTheme.paddingPage)
            }
            .background(AlmaTheme.background)
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadUserStats()
            }
            .alert("Confirmar eliminação", isPresented: $showDeleteConfirmation) {
                Button("Cancelar", role: .cancel) { }
                Button("Eliminar", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Tem a certeza que deseja eliminar a sua conta? Esta ação não pode ser desfeita.")
            }
        }
    }

    private func loadUserStats() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()

        // Load user profile data
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() as? [String: Any] {
                DispatchQueue.main.async {
                    self.streakDays = data["streakDays"] as? Int ?? 0

                    if let createdAt = data["createdAt"] as? Timestamp {
                        let calendar = Calendar.current
                        let daysDifference = calendar.dateComponents(
                            [.day],
                            from: createdAt.dateValue(),
                            to: Date()
                        ).day ?? 0
                        self.daysActive = daysDifference
                    }
                }
            }
        }

        // Count total check-ins
        db.collection("users").document(uid).collection("moods").getDocuments { snapshot, error in
            if let count = snapshot?.documents.count {
                DispatchQueue.main.async {
                    self.totalCheckIns = count
                }
            }
        }
    }

    private func deleteAccount() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()
        let user = Auth.auth().currentUser

        // Delete Firestore data
        db.collection("users").document(uid).delete { error in
            if error == nil {
                // Delete Firebase Auth user
                user?.delete { error in
                    if error == nil {
                        DispatchQueue.main.async {
                            authManager.signOut()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - StatItem Component
struct StatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 20))

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(AlmaTheme.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(AlmaTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AlmaTheme.card)
        .cornerRadius(AlmaTheme.radius)
    }
}

// MARK: - SectionHeader Component
struct SectionHeader: View {
    let title: String
    var isDanger: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isDanger ? .red : AlmaTheme.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
