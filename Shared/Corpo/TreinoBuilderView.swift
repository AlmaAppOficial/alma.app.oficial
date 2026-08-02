//
//  TreinoBuilderView.swift
//  Corpo & Alma
//
//  Montar seu próprio treino — agora sobre o catálogo completo (1095) com
//  busca por nome (sem acento/caixa, mesma regra da lista do mapa), filtros
//  por equipamento e músculo, e mini-corpos com a musculatura destacada.
//  A persistência NÃO muda: salva no formato legado via asLegacyExercise().
//

import SwiftUI

struct TreinoBuilderView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var search = ""
    @State private var equipmentFilter: Equipment?
    @State private var muscleFilter: MuscleGroup?
    @State private var selected: [ExerciseV2] = []

    private var filtered: [ExerciseV2] {
        var list = ExerciseCatalog.all
        if let eq = equipmentFilter { list = list.filter { $0.equipment == eq } }
        if let m = muscleFilter {
            list = list.filter { $0.primaryMuscles.contains(m) || $0.secondaryMuscles.contains(m) }
        }
        list = list.filter { $0.matches(search: search) }
        return list
    }

    private func isSelected(_ ex: ExerciseV2) -> Bool { selected.contains { $0.id == ex.id } }

    private func toggle(_ ex: ExerciseV2) {
        if let i = selected.firstIndex(where: { $0.id == ex.id }) { selected.remove(at: i) }
        else { selected.append(ex) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                    TextField("Nome do treino (ex.: Peito e tríceps)", text: $name)
                        .padding()
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))

                    // Busca por nome — essencial com 1095 exercícios
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.inkSoft)
                        TextField("Buscar exercício (ex.: supino, rosca…)", text: $search)
                            .autocorrectionDisabled()
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))

                    if !selected.isEmpty {
                        HStack {
                            Image(systemName: "checklist").foregroundStyle(Theme.primary)
                            Text("\(selected.count) exercício(s) selecionado(s)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }

                    equipmentChips
                    muscleChips

                    Text("\(filtered.count) exercício\(filtered.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)

                    ForEach(filtered) { ex in
                        exerciseRow(ex)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Montar treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        // Persistência inalterada: converte V2 -> legado ao salvar
                        model.addCustomWorkout(name: name,
                                               exercises: selected.map { $0.asLegacyExercise() })
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var equipmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Todos", active: equipmentFilter == nil) { equipmentFilter = nil }
                ForEach(Equipment.allCases) { eq in
                    chip(title: eq.rawValue, active: equipmentFilter == eq) {
                        equipmentFilter = (equipmentFilter == eq) ? nil : eq
                    }
                }
            }
        }
    }

    private var muscleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Qualquer músculo", active: muscleFilter == nil) { muscleFilter = nil }
                ForEach(MuscleGroup.allCases) { m in
                    chip(title: m.namePTBR, active: muscleFilter == m) {
                        muscleFilter = (muscleFilter == m) ? nil : m
                    }
                }
            }
        }
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? .white : Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(active ? Theme.primary : Theme.surfaceAlt)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ ex: ExerciseV2) -> some View {
        Button { toggle(ex) } label: {
            HStack(spacing: 12) {
                ExerciseMuscleThumb(exercise: ex)
                    .frame(width: 44, height: 58)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .background(Theme.inkSoft.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.namePTBR)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(ex.primaryMuscles.map(\.namePTBR).joined(separator: ", ")) · \(ex.equipment.rawValue)")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected(ex) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(isSelected(ex) ? Theme.primary : Theme.inkSoft.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .cardStyle(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TreinoBuilderView().environmentObject(AppModel())
}
