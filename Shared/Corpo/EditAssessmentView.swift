//
//  EditAssessmentView.swift
//  Corpo & Alma
//
//  Sheet para editar a avaliação corporal. Grava direto no AppModel (persistido).
//

import SwiftUI

struct EditAssessmentView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Perfil") {
                    TextField("Nome", text: $model.userName)
                    Picker("Objetivo", selection: $model.goal) {
                        ForEach(Goal.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    Stepper("Idade: \(model.ageYears) anos", value: $model.ageYears, in: 12...100)
                }

                Section("Medidas") {
                    measureRow("Peso", value: $model.weightKg, range: 40...160, unit: "kg")
                    measureRow("Altura", value: $model.heightCm, range: 140...210, unit: "cm")
                    measureRow("Gordura corporal", value: $model.bodyFat, range: 5...50, unit: "%")
                }

                Section {
                    HStack {
                        Text("IMC atual")
                        Spacer()
                        Text(String(format: "%.1f · %@", model.imc, model.imcClassificacao))
                            .foregroundStyle(Theme.primary)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Editar avaliação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Concluir") { dismiss() }
                }
            }
        }
    }

    private func measureRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(String(format: "%.1f", value.wrappedValue)) \(unit)")
                    .foregroundStyle(Theme.inkSoft)
            }
            Slider(value: value, in: range, step: 0.1)
                .tint(Theme.primary)
        }
    }
}

#Preview {
    EditAssessmentView().environmentObject(AppModel())
}
