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
                    // [2026-08-04] "Idade: 0 anos" quando ninguém informou.
                    Stepper(model.ageYears > 0 ? "Idade: \(model.ageYears) anos" : "Idade: —",
                            value: $model.ageYears, in: 12...100)
                }

                Section("Medidas") {
                    measureRow("Peso", value: $model.weightKg, range: 40...160, unit: "kg")
                    measureRow("Altura", value: $model.heightCm, range: 140...210, unit: "cm")
                    measureRow("Gordura corporal", value: $model.bodyFat, range: 5...50, unit: "%")
                }

                // [2026-08-03 — BUG B3] Estes dois campos existiam no modelo,
                // viajavam para a IA e NENHUMA tela do app perguntava por eles.
                // A proteção que eu mesmo escrevi no snapshot — "não sugerir
                // amendoim a quem tem alergia" — não protegia ninguém, porque
                // não havia como declarar a alergia.
                Section {
                    TextField("Ex.: alergia a amendoim, sem lactose", text: $model.dietaryRestrictions, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Ex.: hérnia de disco, joelho operado", text: $model.healthConditions, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Restrições e limitações")
                } footer: {
                    Text("A Alma usa isso para não sugerir o que te faz mal. Fica no seu aparelho e vai junto do resumo só se você autorizar em Perfil.")
                }

                Section {
                    HStack {
                        Text("IMC atual")
                        Spacer()
                        // [2026-08-03 — BUG B5] Com peso e altura zerados (o
                        // padrão honesto que passou a valer ontem), 0/0 dava
                        // NaN: a tela exibia "nan · Obesidade" para quem tinha
                        // acabado de instalar o app. Sem medidas, não há IMC —
                        // e o app diz isso em vez de diagnosticar obesidade.
                        if model.hasBodyProfile {
                            Text(String(format: "%.1f · %@", model.imc, model.imcClassificacao))
                                .foregroundStyle(Theme.primary)
                                .fontWeight(.semibold)
                        } else {
                            Text("informe peso e altura")
                                .foregroundStyle(Theme.inkSoft)
                        }
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
                // [2026-08-04 — varredura visual] Saía "79.5 kg", "178.0 cm",
                // "0.0 %": ponto decimal em PT-BR. E zero não é medida — com
                // o campo em branco a tela mostrava "0.0 kg" como se a pessoa
                // pesasse zero, o mesmo pecado do IMC "nan · Obesidade".
                Text(value.wrappedValue > 0
                     ? "\(CorpoContextFormat.decimal(value.wrappedValue)) \(unit)"
                     : "—")
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
