//
//  MealDetailView.swift
//  Corpo & Alma
//
//  Detalhe de uma refeição — macros, status e remoção.
//

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
