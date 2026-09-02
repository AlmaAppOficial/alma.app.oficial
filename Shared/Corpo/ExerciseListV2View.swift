//
//  ExerciseListV2View.swift
//  CorpoEAlma
//
//  Biblioteca 2.0, iteração 2 — lista por músculo com thumbnail programática
//  (corpo anatômico com a musculatura do exercício acesa; zero assets) e
//  detalhe centrado no corpo destacado, no estilo da referência do Assis.
//  As fotos do EDB saíram da UI a pedido dele (mídia de movimento virá das
//  amostras IA — decisão 2b).
//

import SwiftUI

// MARK: - Lista por músculo

struct ExerciseListV2View: View {
    let group: MuscleGroup

    @State private var searchText = ""
    @State private var equipmentFilter: Equipment? = nil
    @State private var difficultyFilter: Difficulty? = nil
    @State private var selectedExercise: ExerciseV2? = nil

    private var exercises: [ExerciseV2] {
        var list = ExerciseCatalog.exercises(for: group)
        if let e = equipmentFilter { list = list.filter { $0.equipment == e } }
        if let d = difficultyFilter { list = list.filter { $0.difficulty == d } }
        list = list.filter { $0.matches(search: searchText) }
        return list
    }

    private var availableEquipment: [Equipment] {
        let set = Set(ExerciseCatalog.exercises(for: group).map(\.equipment))
        return Equipment.allCases.filter { set.contains($0) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                filterBar

                Text("\(exercises.count) exercício\(exercises.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                ForEach(exercises) { ex in
                    Button { selectedExercise = ex } label: {
                        ExerciseV2Row(exercise: ex)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(group.namePTBR)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Buscar exercício")
        // [Fusão] variante iOS 16 de navigationDestination(item:)
        .navigationDestination(isPresented: Binding(
            get: { selectedExercise != nil },
            set: { if !$0 { selectedExercise = nil } }
        )) {
            if let ex = selectedExercise {
                ExerciseDetailV2View(exercise: ex)
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Todos", isOn: equipmentFilter == nil) { equipmentFilter = nil }
                    ForEach(availableEquipment) { eq in
                        chip(eq.rawValue, isOn: equipmentFilter == eq) {
                            equipmentFilter = (equipmentFilter == eq) ? nil : eq
                        }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Qualquer nível", isOn: difficultyFilter == nil) { difficultyFilter = nil }
                    ForEach(Difficulty.allCases) { d in
                        chip(d.namePTBR, isOn: difficultyFilter == d) {
                            difficultyFilter = (difficultyFilter == d) ? nil : d
                        }
                    }
                }
            }
        }
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOn ? .white : Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? Theme.primary : Theme.inkSoft.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Linha da lista (thumbnail programática — corpo com músculos acesos)

struct ExerciseV2Row: View {
    let exercise: ExerciseV2

    var body: some View {
        HStack(spacing: 12) {
            // [2026-09-02] Era `ExerciseMuscleThumb` fixo. Agora é a foto do
            // exercício quando ela existe (514 dos 1.095) e o corpo anatômico
            // quando não — `FiguraDoExercicio` é o único lugar que decide.
            // Geometria intocada: 56×74 dentro do well de 68×78, raio 12.
            FiguraDoExercicio(exercise: exercise)
                .frame(width: 56, height: 74)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(Theme.inkSoft.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.namePTBR)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                Text(exercise.difficulty.namePTBR)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(exercise.difficulty.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(exercise.difficulty.tint.opacity(0.12))
                    .clipShape(Capsule())
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 12)
    }

    private var subtitle: String {
        var parts = [exercise.equipment.rawValue]
        let secondary = exercise.secondaryMuscles.map(\.namePTBR).joined(separator: ", ")
        if !secondary.isEmpty { parts.append("+ \(secondary)") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Detalhe (hero = corpo anatômico destacado; layout centrado)

struct ExerciseDetailV2View: View {
    let exercise: ExerciseV2
    @EnvironmentObject var model: AppModel

    private var showsFrontFirst: Bool {
        let all = exercise.primaryMuscles + exercise.secondaryMuscles
        let front = all.filter(\.isFront).count
        return front >= all.count - front
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // HERO — a foto do exercício (quando existe) ao lado do corpo
                // anatômico com a musculatura acesa. Quem não tem foto continua
                // com o corpo dos dois lados, exatamente como antes.
                //
                // [2026-09-02] A "mídia da decisão 2b" prometida no comentário
                // antigo chegou — e não veio de IA: são as fotos do RepDB,
                // chaveadas e reenquadradas. Ver `FotoDoExercicio.swift` para a
                // licença (em especial o termo 5, que PROÍBE passar estas
                // imagens por qualquer modelo generativo).
                HStack(alignment: .center, spacing: 18) {
                    FiguraDoExercicio(exercise: exercise)
                        .frame(height: 210)

                    BodyMapCanvas(isFront: !showsFrontFirst,
                                  highlightedPrimary: Set(exercise.primaryMuscles),
                                  highlightedSecondary: Set(exercise.secondaryMuscles))
                        .frame(height: 150)
                        .allowsHitTesting(false)
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
                .background(Theme.inkSoft.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Legenda primário/secundário
                HStack(spacing: 14) {
                    legend(color: Color(red: 0.86, green: 0.28, blue: 0.25),
                           text: exercise.primaryMuscles.map(\.namePTBR).joined(separator: ", "))
                    if !exercise.secondaryMuscles.isEmpty {
                        legend(color: Color(red: 0.95, green: 0.62, blue: 0.30),
                               text: exercise.secondaryMuscles.map(\.namePTBR).joined(separator: ", "))
                    }
                    Spacer(minLength: 0)
                }

                // Chips de metadados
                HStack(spacing: 8) {
                    metaChip(exercise.difficulty.namePTBR, tint: exercise.difficulty.tint)
                    metaChip(exercise.equipment.rawValue, tint: Theme.primary)
                    if let m = exercise.mechanics { metaChip(m.capitalized, tint: Theme.inkSoft) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Sugestão: \(exercise.defaultSets) séries · \(exercise.defaultReps)")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                // As duas pontas do movimento. Só aparece para quem tem as duas
                // fotos (439 dos 514); quem tem uma só mostra a do herói e nada
                // mais. `InicioEPicoView` some sozinha quando não há par.
                InicioEPicoView(exercise: exercise)

                // Como fazer
                VStack(alignment: .leading, spacing: 10) {
                    Text("Como fazer")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Theme.primary)
                                .clipShape(Circle())
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                Text("Fonte: \(exercise.sourceAttribution)")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(exercise.namePTBR)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
        }
    }

    private func metaChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}
