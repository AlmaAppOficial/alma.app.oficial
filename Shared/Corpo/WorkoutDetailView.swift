//
//  WorkoutDetailView.swift
//  Corpo & Alma
//
//  Detalhe de um plano de treino, com lista de exercicios.
//
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var model: AppModel
    @State private var showSession = false
    let workout: Workout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                HStack(spacing: 12) {
                    statBox("\(workout.durationMin)", "minutos",    "clock.fill",   workout.tint)
                    statBox("\(workout.kcal)",        "kcal",       "flame.fill",   Theme.coral)
                    statBox("\(workout.exercises.count)", "exercicios", "list.bullet", Theme.azure)
                }
                SectionTitle(text: "Exercicios")
                VStack(spacing: 12) {
                    ForEach(workout.exercises) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex, tint: workout.tint)
                        } label: {
                            HStack(spacing: 14) {
                                FiguraDeExercicioLegado(exercise: ex, tint: workout.tint,
                                                        tamanhoDoSimbolo: 20)
                                    .padding(3)
                                    .frame(width: 46, height: 46)
                                    .background(workout.tint.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text("\(ex.sets) series . \(ex.reps) . \(ex.equipment.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .cardStyle(padding: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { showSession = true } label: {
                    Label("Iniciar treino", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(workout.tint)
                .controlSize(.large)
                .navigationDestination(isPresented: $showSession) {
                    WorkoutSessionView(workout: workout)
                        .environmentObject(model)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: workout.systemImage)
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(workout.tint)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text(workout.focus)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
    }

    private func statBox(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: AppModel().workouts[0])
            .environmentObject(AppModel())
    }
}
