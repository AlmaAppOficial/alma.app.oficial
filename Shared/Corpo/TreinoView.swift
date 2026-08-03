//
//  TreinoView.swift
//  Corpo & Alma
//
//  Aba "Treino" — planos de exercício e treino do dia.
//

import SwiftUI

struct TreinoView: View {
    @EnvironmentObject var model: AppModel
    @State private var showBuilder = false
    @State private var showSession = false
    @State private var showPaywall = false

    // Navegação programática — só chegam aqui usuários premium
    @State private var selectedWorkout: Workout? = nil
    @State private var selectedCustomWorkout: CustomWorkout? = nil
    @State private var selectedExercise: Exercise? = nil
    @State private var showMuscleMap = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Treino", subtitle: "Movimento é remédio")

                    todayWorkoutCard

                    muscleMapEntryCard

                    buildOwnCard

                    if !model.customWorkouts.isEmpty {
                        SectionTitle(text: "Meus treinos")
                        VStack(spacing: 12) {
                            ForEach(model.customWorkouts) { cw in
                                customWorkoutRow(cw)
                            }
                        }
                    }

                    SectionTitle(text: "Planos para você")
                    VStack(spacing: 12) {
                        ForEach(model.workouts) { workout in
                            Button {
                                selectedWorkout = workout
                            } label: {
                                workoutRow(workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .almaBackButton()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if model.hasPremiumAccess { showBuilder = true }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showBuilder) { TreinoBuilderView() }
            .sheet(isPresented: $showPaywall) { PaywallDoCorpo() }
            .fullScreenCover(isPresented: $showSession) {
                if let w = model.workouts.first {
                    NavigationStack {
                        WorkoutSessionView(workout: w)
                            .environmentObject(model)
                    }
                }
            }
            // Destinos de navegação — só alcançáveis com premium.
            // [Fusão 2026-08-02] `navigationDestination(item:)` é iOS 17+; o Alma
            // suporta iOS 16. Trocado pela variante `isPresented:` com binding
            // derivado — mesmo comportamento, sem cortar quem está no iOS 16.
            .navigationDestination(isPresented: Binding(
                get: { selectedWorkout != nil },
                set: { if !$0 { selectedWorkout = nil } }
            )) {
                if let workout = selectedWorkout {
                    WorkoutDetailView(workout: workout)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedCustomWorkout != nil },
                set: { if !$0 { selectedCustomWorkout = nil } }
            )) {
                if let cw = selectedCustomWorkout {
                    WorkoutDetailView(workout: Workout(
                        name: cw.name,
                        focus: "Personalizado · \(cw.exercises.count) exercícios",
                        durationMin: cw.exercises.count * 8,
                        kcal: cw.exercises.count * 45,
                        systemImage: "figure.strengthtraining.traditional",
                        tint: Theme.primary,
                        exercises: cw.exercises
                    ))
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedExercise != nil },
                set: { if !$0 { selectedExercise = nil } }
            )) {
                if let exercise = selectedExercise {
                    ExerciseDetailView(exercise: exercise, tint: Theme.primary)
                }
            }
            .navigationDestination(isPresented: $showMuscleMap) {
                MuscleMapView()
            }
        }
    }

    // Entrada da Biblioteca 2.0 — mapa muscular (gate premium igual ao builder)
    private var muscleMapEntryCard: some View {
        Button {
            if model.hasPremiumAccess { showMuscleMap = true }
        } label: {
            MuscleMapCard()
        }
        .buttonStyle(.plain)
    }

    // Botão de montar treino próprio
    private var buildOwnCard: some View {
        Button {
            if model.hasPremiumAccess { showBuilder = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "slider.horizontal.2.square")
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 48, height: 48)
                    .background(Theme.primary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Montar meu treino")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("Escolha exercícios e equipamentos do seu jeito")
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

    // Linha de treino personalizado — navegação via estado premium
    private func customWorkoutRow(_ cw: CustomWorkout) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3)
                .foregroundStyle(Theme.primary)
                .frame(width: 46, height: 46)
                .background(Theme.primary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(cw.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(cw.exercises.count) exercícios")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button {
                model.removeCustomWorkout(cw)
            } label: {
                Image(systemName: "trash").font(.caption).foregroundStyle(Theme.coral)
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .cardStyle(padding: 14)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedCustomWorkout = cw
        }
    }

    // Treino do dia com lista de exercícios
    private var todayWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Treino de hoje")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text("Full Body — Força")
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 8) {
                        Pill(text: "45 min", tint: Theme.primary)
                        Pill(text: "380 kcal", tint: Theme.coral)
                    }
                }
                Spacer()
            }

            Divider()

            ForEach(model.todayExercises) { ex in
                Button {
                    selectedExercise = ex
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: ex.symbol)
                            .foregroundStyle(Theme.primary)
                            .frame(width: 24)
                        Text(ex.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(ex.sets)× \(ex.reps)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                showSession = true
            } label: {
                Label(
                    "Iniciar treino",
                    systemImage: "play.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primary)
            .padding(.top, 4)
        }
        .cardStyle()
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 14) {
            Image(systemName: workout.systemImage)
                .font(.title3)
                .foregroundStyle(workout.tint)
                .frame(width: 46, height: 46)
                .background(workout.tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(workout.focus)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(workout.durationMin) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(workout.kcal) kcal")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .cardStyle(padding: 14)
    }
}

#Preview {
    TreinoView().environmentObject(AppModel())
}
