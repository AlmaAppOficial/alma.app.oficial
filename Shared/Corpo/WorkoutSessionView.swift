//
//  WorkoutSessionView.swift
//  Corpo & Alma
//
//  Sessão de treino ativa — exibe exercícios um a um com timer de descanso.
//
import SwiftUI

struct WorkoutSessionView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let workout: Workout

    @State private var currentIndex = 0
    @State private var currentSet   = 1
    @State private var phase: Phase = .exercising
    @State private var restSeconds  = 0
    @State private var restTimer: Timer? = nil

    enum Phase { case exercising, resting, done }

    private var currentExercise: Exercise? {
        guard currentIndex < workout.exercises.count else { return nil }
        return workout.exercises[currentIndex]
    }
    private var nextPreview: Exercise? {
        let i = currentIndex + 1
        return i < workout.exercises.count ? workout.exercises[i] : nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .exercising: exerciseView
            case .resting:    restView
            case .done:       completionView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Sair") { stopTimer(); dismiss() }
                    .foregroundStyle(Theme.coral)
            }
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Exercício

    private var exerciseView: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressHeader.padding(.bottom, 4)

                if let ex = currentExercise {
                    Image(systemName: ex.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(workout.tint)
                        .frame(width: 120, height: 120)
                        .background(workout.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

                    VStack(spacing: 8) {
                        Text(ex.name)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 12) {
                            Pill(text: "Série \(currentSet) de \(ex.sets)", tint: workout.tint)
                            Pill(text: ex.reps, tint: Theme.azure)
                        }
                        Text(ex.muscle)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Execução")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft)
                        ForEach(Array(ex.instructions.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(workout.tint)
                                    .clipShape(Circle())
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .cardStyle()

                    Button { completeSerie() } label: {
                        Label("Completar série", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(workout.tint)
                    .controlSize(.large)

                    Button { advanceExercise() } label: {
                        Text(currentIndex + 1 < workout.exercises.count ? "Pular exercício" : "Finalizar treino")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Descanso

    private var restView: some View {
        VStack(spacing: 32) {
            progressHeader.padding(.horizontal, 20)
            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.azure.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: CGFloat(restSeconds) / 60.0)
                    .stroke(Theme.azure, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: restSeconds)
                VStack(spacing: 4) {
                    Text("\(restSeconds)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("descanso")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            if let next = nextPreview {
                VStack(spacing: 4) {
                    Text("A seguir: \(next.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Série \(currentSet) de \(next.sets) · \(next.reps)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            Spacer()

            Button { skipRest() } label: {
                Label("Pular descanso", systemImage: "forward.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.azure)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Conclusão

    private var completionView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(workout.tint)
            VStack(spacing: 8) {
                Text("Treino concluído!")
                    .font(.title.bold())
                    .foregroundStyle(Theme.ink)
                Text("Ótimo trabalho, continue assim!")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: 16) {
                summaryBox("\(workout.exercises.count)", "exercícios", "list.bullet",      workout.tint)
                summaryBox("\(workout.durationMin)",    "minutos",    "clock.fill",        Theme.azure)
                summaryBox("\(workout.kcal)",           "kcal",       "flame.fill",        Theme.coral)
            }
            .padding(.horizontal, 20)
            Spacer()
            Button { dismiss() } label: {
                Text("Fechar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(workout.tint)
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private var progressHeader: some View {
        VStack(spacing: 8) {
            Text("\(currentIndex + 1) de \(workout.exercises.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            ProgressView(value: Double(currentIndex), total: Double(workout.exercises.count))
                .tint(workout.tint)
        }
    }

    private func completeSerie() {
        guard let ex = currentExercise else { return }
        if currentSet < ex.sets {
            currentSet += 1
            startRest()
        } else {
            currentSet = 1
            advanceExercise()
        }
    }

    private func advanceExercise() {
        stopTimer()
        let next = currentIndex + 1
        if next >= workout.exercises.count {
            phase = .done
        } else {
            currentIndex = next
            phase = .exercising
        }
    }

    private func startRest() {
        restSeconds = 60
        phase = .resting
        stopTimer()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if restSeconds > 0 { restSeconds -= 1 }
                else { stopTimer(); phase = .exercising }
            }
        }
    }

    private func skipRest() { stopTimer(); phase = .exercising }
    private func stopTimer() { restTimer?.invalidate(); restTimer = nil }

    private func summaryBox(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
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
        WorkoutSessionView(workout: AppModel().workouts[0])
            .environmentObject(AppModel())
    }
}
