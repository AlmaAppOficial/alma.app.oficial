import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var healthKitManager: HealthKitManager

    @State private var selectedMood: String = ""
    @State private var moodNotes: String = ""
    @State private var streakDays: Int = 0
    @State private var isLoading = false
    @State private var showSaveSuccess = false

    let moodEmojis = ["😔", "😕", "😐", "🙂", "😊"]

    var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Bom dia ☀️"
        case 12..<18:
            return "Boa tarde 🌤"
        default:
            return "Boa noite 🌙"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(timeGreeting)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        HStack {
                            Text("Olá, \(authManager.userProfile?.name ?? "Alma")")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("🔥 \(streakDays) dias")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Text("seguidos")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AlmaTheme.paddingPage)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AlmaTheme.accent,
                                AlmaTheme.accent.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(AlmaTheme.radius)

                    // Daily Check-in Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Como você se sente hoje?")
                            .font(.headline)
                            .foregroundColor(AlmaTheme.textPrimary)

                        // Mood Emoji Picker
                        HStack(spacing: 12) {
                            ForEach(moodEmojis, id: \.self) { emoji in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedMood = emoji
                                    }
                                }) {
                                    Text(emoji)
                                        .font(.system(size: 36))
                                        .scaleEffect(selectedMood == emoji ? 1.2 : 1.0)
                                        .frame(height: 50)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            selectedMood == emoji ?
                                            AlmaTheme.accentGradient :
                                            Color.clear
                                        )
                                        .cornerRadius(AlmaTheme.radius)
                                }
                            }
                        }

                        // Notes TextField
                        TextField("Como você está se sentindo? (opcional)", text: $moodNotes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(AlmaTheme.textPrimary)

                        // Save Button
                        Button(action: saveMoodEntry) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Guardar")
                                    .fontWeight(.semibold)
                            }
                        }
                        .almaPrimaryButton()
                        .disabled(selectedMood.isEmpty || isLoading)
                        .opacity(selectedMood.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(AlmaTheme.paddingPage)
                    .almaCard()

                    // Health Summary Card
                    if let healthSummary = healthKitManager.healthSummary {
                        HealthSummaryCardView(healthSummary: healthSummary)
                    }

                    // Quick Actions
                    HStack(spacing: 12) {
                        NavigationLink(destination: MeditationView()) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.crop.circle")
                                Text("Meditar")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(AlmaTheme.card)
                            .foregroundColor(AlmaTheme.accent)
                            .cornerRadius(AlmaTheme.radius)
                        }

                        NavigationLink(destination: BreatheView()) {
                            HStack(spacing: 8) {
                                Image(systemName: "wind")
                                Text("Respirar")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(AlmaTheme.card)
                            .foregroundColor(AlmaTheme.accent)
                            .cornerRadius(AlmaTheme.radius)
                        }
                    }

                    // Chat with Alma Button
                    NavigationLink(destination: ChatView()) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                            Text("Falar com Alma")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(AlmaTheme.accentGradient)
                        .foregroundColor(.white)
                        .cornerRadius(AlmaTheme.radius)
                    }

                    Spacer(minLength: 20)
                }
                .padding(AlmaTheme.paddingPage)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(timeGreeting)
                        .font(.headline)
                        .foregroundColor(AlmaTheme.textPrimary)
                }
            }
            .background(AlmaTheme.background)
            .onAppear {
                loadStreakDays()
                healthKitManager.requestAuthorization()
            }
            .alert("Sucesso!", isPresented: $showSaveSuccess) {
                Button("OK") { }
            } message: {
                Text("Seu check-in foi guardado com sucesso!")
            }
        }
    }

    private func saveMoodEntry() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        isLoading = true
        let db = Firestore.firestore()
        let moodData: [String: Any] = [
            "emoji": selectedMood,
            "text": moodNotes,
            "date": Timestamp(date: Date()),
            "timestamp": Date().timeIntervalSince1970
        ]

        db.collection("users").document(uid).collection("moods").addDocument(data: moodData) { error in
            isLoading = false
            if error == nil {
                showSaveSuccess = true
                selectedMood = ""
                moodNotes = ""
                updateStreakIfNeeded()
            }
        }
    }

    private func loadStreakDays() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() as? [String: Any],
               let streak = data["streakDays"] as? Int {
                DispatchQueue.main.async {
                    self.streakDays = streak
                }
            }
        }
    }

    private func updateStreakIfNeeded() {
        guard let uid = authManager.authManager?.currentUser?.uid else { return }

        let db = Firestore.firestore()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let data = snapshot?.data() as? [String: Any],
               let lastCheckIn = data["lastCheckIn"] as? Timestamp {
                let lastDate = calendar.startOfDay(for: lastCheckIn.dateValue())
                let daysDifference = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0

                var newStreak = data["streakDays"] as? Int ?? 1
                if daysDifference == 1 {
                    newStreak += 1
                } else if daysDifference > 1 {
                    newStreak = 1
                }

                db.collection("users").document(uid).updateData([
                    "streakDays": newStreak,
                    "lastCheckIn": Timestamp(date: Date())
                ])

                DispatchQueue.main.async {
                    self.streakDays = newStreak
                }
            }
        }
    }
}

// MARK: - Health Summary Card View
struct HealthSummaryCardView: View {
    let healthSummary: HealthSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumo de Saúde")
                .font(.headline)
                .foregroundColor(AlmaTheme.textPrimary)

            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text("❤️")
                        .font(.title2)
                    Text("\(Int(healthSummary.heartRate))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AlmaTheme.textPrimary)
                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 4) {
                    Text("🚶")
                        .font(.title2)
                    Text("\(Int(healthSummary.steps))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AlmaTheme.textPrimary)
                    Text("passos")
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 4) {
                    Text("🔥")
                        .font(.title2)
                    Text("\(Int(healthSummary.calories))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AlmaTheme.textPrimary)
                    Text("kcal")
                        .font(.caption)
                        .foregroundColor(AlmaTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AlmaTheme.paddingPage)
        .almaCard()
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
        .environmentObject(HealthKitManager())
        .preferredColorScheme(.dark)
}
