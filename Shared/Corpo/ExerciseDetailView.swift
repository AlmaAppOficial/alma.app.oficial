//
//  ExerciseDetailView.swift
//  Corpo & Alma
//
//  Detalhe de um exercício — ilustração do movimento (SF Symbol),
//  equipamento, músculo trabalhado e passo a passo.
//

import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    var tint: Color = Theme.primary

    @State private var animate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Ilustração do movimento
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(tint.opacity(0.12))
                    Image(systemName: exercise.symbol)
                        .font(.system(size: 120))
                        .foregroundStyle(tint)
                        .scaleEffect(animate ? 1.04 : 0.96)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)

                // Tags
                HStack(spacing: 10) {
                    Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(tint.opacity(0.14))
                        .clipShape(Capsule())
                    Label(exercise.muscle, systemImage: "figure.arms.open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.surfaceAlt)
                        .clipShape(Capsule())
                }

                // Volume
                HStack(spacing: 12) {
                    volumeBox("\(exercise.sets)", "séries")
                    volumeBox(exercise.reps, "por série")
                }

                // Passo a passo
                VStack(alignment: .leading, spacing: 14) {
                    Text("Como fazer")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(tint)
                                .clipShape(Circle())
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { animate = true }
    }

    private func volumeBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: AppModel().workouts[0].exercises[0])
    }
}
