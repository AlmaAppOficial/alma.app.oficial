//
//  NutritionEngine.swift
//  Corpo & Alma
//
//  Fonte única de verdade da meta calórica e dos macros.
//  Mifflin-St Jeor (peso, altura, idade, sexo) × fator de atividade,
//  com ajuste por objetivo (perder −450 / manter 0 / ganhar +300).
//  A meta é orientativa e não substitui acompanhamento profissional.
//

import SwiftUI

// MARK: - Sexo biológico (usado apenas na fórmula, 100% local)

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case masculino = "Masculino"
    case feminino  = "Feminino"

    var id: String { rawValue }
}

// MARK: - Nível de atividade

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentario = "Sedentário"
    case leve       = "Leve (1–3x/semana)"
    case moderado   = "Moderado (3–5x/semana)"
    case intenso    = "Intenso (6–7x/semana)"

    var id: String { rawValue }

    /// Fator multiplicador do gasto basal (valores clássicos de Harris/Mifflin).
    var factor: Double {
        switch self {
        case .sedentario: return 1.2
        case .leve:       return 1.375
        case .moderado:   return 1.55
        case .intenso:    return 1.725
        }
    }
}

// MARK: - Motor de cálculo

enum NutritionEngine {

    /// Piso de segurança: metas abaixo disso são recusadas.
    static let minKcal = 1200
    /// Teto de sanidade para meta manual.
    static let maxKcal = 6000

    /// Taxa metabólica basal — Mifflin-St Jeor.
    static func bmr(weightKg: Double, heightCm: Double, ageYears: Int, sex: BiologicalSex) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        return base + (sex == .masculino ? 5 : -161)
    }

    /// Meta calórica sugerida: BMR × atividade, ajustada pelo objetivo.
    static func suggestedKcal(weightKg: Double, heightCm: Double, ageYears: Int,
                              sex: BiologicalSex, activity: ActivityLevel, goal: Goal) -> Int {
        let tdee = bmr(weightKg: weightKg, heightCm: heightCm, ageYears: ageYears, sex: sex) * activity.factor
        let adjust: Double
        switch goal {
        case .perder: adjust = -450
        case .manter: adjust = 0
        case .ganhar: adjust = 300
        }
        return max(Int((tdee + adjust).rounded()), minKcal)
    }

    /// Macros derivados da meta: proteína ~1,8 g/kg, gordura ~25% das kcal, carbo no resto.
    static func macros(kcal: Int, weightKg: Double) -> (protein: Int, carbs: Int, fat: Int) {
        let protein = Int((1.8 * weightKg).rounded())
        let fat     = Int(((Double(kcal) * 0.25) / 9).rounded())
        let carbs   = max(Int((Double(kcal - protein * 4 - fat * 9) / 4).rounded()), 0)
        return (protein, carbs, fat)
    }
}

// MARK: - Editor da meta calórica (Dieta → "Meta")

struct GoalEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var customText = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    suggestedCard
                    profileSection
                    customSection
                    disclaimer
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Meta calórica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } }
            }
        }
    }

    // Meta sugerida (sempre visível, recalculada ao vivo)
    private var suggestedCard: some View {
        VStack(spacing: 6) {
            Text(model.customKcalGoal == nil ? "Meta sugerida (em uso)" : "Meta sugerida")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
            Text("\(model.suggestedKcalGoal) kcal")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.primary)
            Text("Calculada pelo seu peso, altura, idade, sexo, atividade e objetivo (\(model.goal.rawValue.lowercased())).")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // Sexo + nível de atividade (entram na fórmula)
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Perfil para o cálculo").font(.headline).foregroundStyle(Theme.ink)

            Picker("Sexo", selection: $model.sex) {
                ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("Nível de atividade").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                Picker("Atividade", selection: $model.activityLevel) {
                    ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Theme.primary)
            }

            Text("Peso, altura e idade vêm da sua avaliação corporal (aba Saúde).")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .cardStyle()
    }

    // Meta personalizada (sobrescreve a sugerida)
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meta personalizada").font(.headline).foregroundStyle(Theme.ink)
                Spacer()
                if model.customKcalGoal != nil {
                    Text("em uso")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.gold.opacity(0.2))
                        .foregroundStyle(Theme.gold)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                TextField("Ex.: 2000", text: $customText)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                Text("kcal").foregroundStyle(Theme.inkSoft)
                Button("Usar") { applyCustom() }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
            }

            if let err = validationError {
                Text(err).font(.caption).foregroundStyle(Theme.coral)
            }

            if model.customKcalGoal != nil {
                Button {
                    model.customKcalGoal = nil
                    customText = ""
                    validationError = nil
                } label: {
                    Label("Voltar à meta sugerida", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .tint(Theme.azure)
            }
        }
        .cardStyle()
        .onAppear { if let c = model.customKcalGoal { customText = "\(c)" } }
    }

    private var disclaimer: some View {
        Text("A meta calórica é uma estimativa orientativa e não substitui a orientação de um médico ou nutricionista. Metas abaixo de \(NutritionEngine.minKcal) kcal não são aceitas por segurança.")
            .font(.caption2)
            .foregroundStyle(Theme.inkSoft)
    }

    private func applyCustom() {
        guard let value = Int(customText.trimmingCharacters(in: .whitespaces)) else {
            validationError = "Digite um número inteiro de kcal."
            return
        }
        guard value >= NutritionEngine.minKcal else {
            validationError = "Por segurança, o mínimo aceito é \(NutritionEngine.minKcal) kcal."
            return
        }
        guard value <= NutritionEngine.maxKcal else {
            validationError = "Valor acima do limite de \(NutritionEngine.maxKcal) kcal."
            return
        }
        validationError = nil
        model.customKcalGoal = value
    }
}

#Preview {
    GoalEditorView().environmentObject(AppModel())
}
