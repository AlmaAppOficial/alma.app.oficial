//
//  DietaView.swift
//  Corpo & Alma
//
//  Aba "Dieta" — plano alimentar do dia agrupado por refeição.
//  Cada card de refeição agrupa múltiplos alimentos e permite adicionar/remover.
//

import SwiftUI

// MARK: - DietaView

struct DietaView: View {
    @EnvironmentObject var model: AppModel
    @State private var activeSheet: DietaSheet? = nil
    @State private var showPaywall = false
    @State private var showGoalEditor = false   // [F4] editor da meta calórica

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Dieta", subtitle: "Seu plano alimentar de hoje")

                    macrosCard

                    SectionTitle(text: "Refeições")
                    VStack(spacing: 12) {
                        ForEach(MealType.allCases) { type in
                            MealGroupCard(
                                type: type,
                                items: model.meals.filter { $0.type == type && $0.kcal > 0 },
                                // [2026-08-02] Registrar, apagar e marcar refeição
                                // são grátis: é o diário da pessoa. Ver CorpoAcesso.
                                onAdd: { activeSheet = .addFood(type) },
                                onDelete: { model.removeMeal($0) },
                                onToggleDone: { model.toggleMeal($0) }
                            )
                        }
                    }

                    // [F5] Suplementos — registro pessoal (100% local)
                    SupplementsSection()

                    // Escanear consome IA paga por foto — segue premium.
                    // [2026-08-03 — B8] E só aparece se a IA existir no build:
                    // sem chave, este botão só sabia devolver erro.
                    if CorpoAcesso.scanDeAlimentoDisponivel {
                    Button {
                        if CorpoAcesso.podeUsarIA(model) { activeSheet = .foodScan }
                        else { showPaywall = true }
                    } label: {
                        Label("Escanear com IA", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Theme.coral, Theme.coral.opacity(0.78)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                    }   // fim do gate scanDeAlimentoDisponivel

                    Button {
                        activeSheet = .addFood(.cafe)
                    } label: {
                        Label("Adicionar alimento", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary.opacity(0.12))
                            .foregroundStyle(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
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
                        activeSheet = .addFood(.cafe)
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addFood(let type):
                    AddFoodView(defaultMealType: type)
                case .foodScan:
                    FoodScanView()
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallDoCorpo() }
            .sheet(isPresented: $showGoalEditor) { GoalEditorView() }
        }
    }

    // MARK: - Macros card

    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.kcalConsumed)")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.ink)
                    // [Honestidade] Sem medidas, nada de meta inventada.
                    if let meta = model.kcalGoal {
                        Text("de \(meta) kcal consumidas")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        Text("kcal consumidas hoje")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    // [F4] Meta editável: sugerida vs personalizada
                    Button { showGoalEditor = true } label: {
                        Label(model.kcalGoal == nil
                              ? "Complete suas medidas para ter uma meta"
                              : (model.customKcalGoal == nil ? "Meta sugerida · editar" : "Meta personalizada · editar"),
                              systemImage: "slider.horizontal.3")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                ProgressRing(
                    progress: model.kcalGoal.map { Double(model.kcalConsumed) / Double($0) } ?? 0,
                    tint: Theme.coral, lineWidth: 9, icon: "flame.fill"
                )
                .frame(width: 56, height: 56)
            }
            if let p = model.proteinGoal, let c = model.carbsGoal, let g = model.fatGoal {
                MacroBar(label: "Proteína",    value: model.proteinConsumed, goal: p, tint: Theme.primary)
                MacroBar(label: "Carboidrato", value: model.carbsConsumed,   goal: c, tint: Theme.gold)
                MacroBar(label: "Gordura",     value: model.fatConsumed,     goal: g, tint: Theme.azure)
            }
        }
        .cardStyle()
    }
}

// MARK: - Sheet enum

private enum DietaSheet: Identifiable {
    case addFood(MealType)
    case foodScan

    var id: String {
        switch self {
        case .addFood(let t): return "food_\(t.rawValue)"
        case .foodScan: return "scan"
        }
    }
}

// MARK: - MealGroupCard

/// Card de uma refeição com lista de alimentos adicionados e botão + para adicionar mais.
struct MealGroupCard: View {
    let type: MealType
    let items: [Meal]
    let onAdd: () -> Void
    let onDelete: (Meal) -> Void
    let onToggleDone: (Meal) -> Void

    private var totalKcal: Int    { items.reduce(0) { $0 + $1.kcal } }
    private var totalProtein: Int { items.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Int   { items.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Int     { items.reduce(0) { $0 + $1.fat } }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Cabeçalho da refeição
            HStack(spacing: 14) {
                Image(systemName: type.systemImage)
                    .font(.title3)
                    .foregroundStyle(Theme.coral)
                    .frame(width: 46, height: 46)
                    .background(Theme.coral.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    if items.isEmpty {
                        Text("Toque em + para adicionar alimentos")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    } else {
                        Text("\(totalKcal) kcal · P\(totalProtein) C\(totalCarbs) G\(totalFat)")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                Spacer(minLength: 8)

                // Botão + para adicionar mais alimentos a esta refeição
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            // MARK: Lista de alimentos
            if !items.isEmpty {
                Divider()
                    .padding(.horizontal, 14)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(item.done ? Theme.ink : Theme.inkSoft)
                                .lineLimit(2)
                            Text("\(item.kcal) kcal · P\(item.protein) C\(item.carbs) G\(item.fat)")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()

                        // Marcar como consumido
                        Button { onToggleDone(item) } label: {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.done ? Theme.primary : Theme.inkSoft.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        // Remover alimento
                        Button { onDelete(item) } label: {
                            Image(systemName: "minus.circle")
                                .font(.title3)
                                .foregroundStyle(Theme.coral.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    DietaView().environmentObject(AppModel())
}
