//
//  MealDetailView.swift
//  Corpo & Alma
//
//  Detalhe de uma refeição — macros, status e remoção.
//
// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ DÍVIDA DECLARADA [2026-08-06] — ESTA TELA NÃO É ALCANÇÁVEL, E NÃO EDITA.
//
// Quem for fazer a refeição editável (2.1) vai encontrar este arquivo e supor
// que há meio caminho andado. Não há. Duas coisas, as duas verificadas:
//
// 1. NINGUÉM CHEGA AQUI. O arquivo está no target (project.pbxproj), compila e
//    entra no binário, mas não existe NavigationLink, sheet, fullScreenCover
//    nem navigationDestination apontando para ele em lugar nenhum do projeto.
//    A única referência viva é `SmokeTestTelas.swift:376`, que está dentro de
//    `#if DEBUG` e atrás da flag `smokeTelas` — em release ela nem existe.
//    Na interface real, a lista de itens é montada em `DietaView.swift:226-262`
//    e cada linha tem exatamente dois botões: marcar consumido e remover.
//
// 2. ELA NÃO EDITA NADA. As duas ações abaixo são `toggleMeal` e `removeMeal`,
//    as mesmas que a linha da DietaView já oferece. Não há campo, slider nem
//    formulário. Alcançar esta tela como está apenas duplicaria dois botões.
//
// E o obstáculo real da 2.1 não é de tela, é de modelo: `Meal`
// (`Models.swift:45-54`) não guarda gramas nem base por 100 g. O `addFood`
// (`Models.swift:748`) escreve a porção DENTRO da string do nome
// ("Frango · 250 g") e descarta o número. Sem gramas e sem base gravadas, não
// há o que reescalar — editar exigiria fazer parsing do nome.
//
// Ou seja: a 2.1 é (a) acrescentar campos opcionais de porção e base ao `Meal`,
// (b) gravá-los no `addFood`, (c) então dar a esta tela um formulário de
// quantidade — o do `AddFoodView.swift:224-298` serve — e (d) só aí ligar a
// navegação. Nessa ordem. Ligar a navegação primeiro entrega dois botões
// repetidos e nenhuma edição.
//
// Precedente da casa, para quem quiser copiar um padrão que já funciona:
// suplemento TEM editor — `SupplementsView.swift:55`.
// ═══════════════════════════════════════════════════════════════════════════

import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let meal: Meal

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Cabeçalho
                VStack(spacing: 10) {
                    Image(systemName: meal.type.systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 88, height: 88)
                        .background(Theme.coral.opacity(0.14))
                        .clipShape(Circle())
                    Text(meal.type.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(meal.name)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Calorias
                VStack(spacing: 4) {
                    Text("\(meal.kcal)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.coral)
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()

                // Macros
                HStack(spacing: 12) {
                    macroBox("Proteína", meal.protein, Theme.primary)
                    macroBox("Carbo", meal.carbs, Theme.gold)
                    macroBox("Gordura", meal.fat, Theme.azure)
                }

                // Ações
                VStack(spacing: 12) {
                    Button {
                        model.toggleMeal(meal)
                        dismiss()
                    } label: {
                        Label(meal.done ? "Marcar como não consumida" : "Marcar como consumida",
                              systemImage: meal.done ? "circle" : "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary.opacity(0.12))
                            .foregroundStyle(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                    Button(role: .destructive) {
                        model.removeMeal(meal)
                        dismiss()
                    } label: {
                        Label("Remover refeição", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.coral.opacity(0.12))
                            .foregroundStyle(Theme.coral)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Refeição")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func macroBox(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value) g").font(.title3.bold()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

#Preview {
    NavigationStack {
        MealDetailView(meal: AppModel().meals[0]).environmentObject(AppModel())
    }
}
