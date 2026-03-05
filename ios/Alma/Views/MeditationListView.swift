import SwiftUI

struct MeditationListView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var selectedCategory: Meditation.Category = .all
    @State private var selectedMeditation: Meditation?

    private var filtered: [Meditation] {
        selectedCategory == .all
            ? Meditation.all
            : Meditation.all.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Category chips ─────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Meditation.Category.allCases, id: \.self) { cat in
                            CategoryChip(category: cat, isSelected: selectedCategory == cat) {
                                withAnimation { selectedCategory = cat }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                // ── List ──────────────────────────────────────────────
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filtered) { med in
                            MeditationRow(meditation: med) {
                                selectedMeditation = med
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Meditar")
            .background(Color.almaBackground.ignoresSafeArea())
        }
        .sheet(item: $selectedMeditation) { med in
            MeditationPlayerView(meditation: med)
                .environmentObject(userViewModel)
        }
    }
}

// MARK: - CategoryChip

struct CategoryChip: View {
    let category: Meditation.Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon).font(.caption)
                Text(category.rawValue).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.almaPrimary : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MeditationRow

struct MeditationRow: View {
    let meditation: Meditation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(meditation.gradient)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: meditation.category.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(meditation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(meditation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(meditation.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.almaPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MeditationListView()
        .environmentObject(UserViewModel())
}
