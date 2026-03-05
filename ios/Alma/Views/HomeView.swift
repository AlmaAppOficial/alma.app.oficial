import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var selectedMeditation: Meditation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Header ──────────────────────────────────────────
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(userViewModel.greeting), \(displayName) \(userViewModel.greetingEmoji)")
                                .font(.title2.bold())
                                .accessibilityLabel("\(userViewModel.greeting), \(displayName)")
                            Text(formattedDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("🔥")
                                .font(.title2)
                            Text("\(userViewModel.currentStreak) dias")
                                .font(.caption.bold())
                                .foregroundColor(.almaPrimary)
                        }
                        .padding(12)
                        .background(Color.almaCard)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // ── Featured meditation ──────────────────────────────
                    if let featured = Meditation.all.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recomendado para você")
                                .font(.headline)
                                .padding(.horizontal)
                            FeaturedCard(meditation: featured) {
                                selectedMeditation = featured
                            }
                            .padding(.horizontal)
                        }
                    }

                    // ── Quick stats ──────────────────────────────────────
                    HStack(spacing: 16) {
                        QuickStatCard(
                            title: "Sessões",
                            value: "\(userViewModel.totalSessions)",
                            icon: "sparkles",
                            color: .almaPrimary
                        )
                        QuickStatCard(
                            title: "Minutos",
                            value: "\(userViewModel.totalMinutes)",
                            icon: "clock.fill",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    // ── Explore ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Explorar")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(Meditation.all.dropFirst()) { med in
                                    SmallCard(meditation: med) {
                                        selectedMeditation = med
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedMeditation) { med in
            MeditationPlayerView(meditation: med)
                .environmentObject(userViewModel)
        }
    }

    // MARK: Helpers

    private var displayName: String {
        userViewModel.userName.isEmpty ? "Amigo" : userViewModel.userName
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: Date()).capitalized
    }
}

// MARK: - FeaturedCard

struct FeaturedCard: View {
    let meditation: Meditation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meditation.category.rawValue.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Text(meditation.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(meditation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(meditation.formattedDuration)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    Label("Iniciar", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("🧘").font(.system(size: 64))
            }
            .padding(20)
            .background(meditation.gradient)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QuickStatCard

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.15))
                .cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.bold())
                Text(title).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - SmallCard

struct SmallCard: View {
    let meditation: Meditation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(meditation.gradient)
                    .frame(width: 130, height: 72)
                    .overlay {
                        Image(systemName: meditation.category.icon)
                            .font(.title)
                            .foregroundColor(.white)
                    }
                Text(meditation.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)
                Text(meditation.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 130)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(UserViewModel())
}
