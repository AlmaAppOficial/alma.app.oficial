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

// [2026-08-14] `BiologicalSex`, `ActivityLevel`, `termoDeSexo`,
// `fatorQuandoNaoInformado`, `metaEhEstimada`, `oQueFaltaNaMeta` e `bmr`
// MUDARAM DE ARQUIVO — foram para `Shared/RegrasDeSaude.swift`.
//
// **O motivo é o de sempre neste projeto: uma regra que só roda com SwiftUI
// montado é uma regra que ninguém exercita.** Este arquivo tem uma `View` no
// fim, então importa SwiftUI, então não compila sozinho — e nenhuma asserção
// conseguia chamar a Mifflin-St Jeor sem subir o app inteiro. Com o termo de
// sexo em `RegrasDeSaude` (que só importa Foundation), a decisão que dá `−161`
// a uma mulher e `+5` a um homem passa a ser executável num binário de linha de
// comando, e portanto reprovável por mutação (Regra 1 do `CLAUDE.md`).
//
// O que ficou aqui: `suggestedKcal` (depende de `Goal`, que mora em
// `Models.swift`), `macros`, os limites, e a tela. Nada foi duplicado — os
// nomes movidos não existem mais neste arquivo.

// MARK: - Motor de cálculo

enum NutritionEngine {

    /// Piso de segurança: metas abaixo disso são recusadas.
    static let minKcal = 1200
    /// Teto de sanidade para meta manual.
    static let maxKcal = 6000

    /// Meta calórica sugerida: BMR × atividade, ajustada pelo objetivo.
    ///
    /// `sex` e `activity` são opcionais desde 14/08: `nil` = **não informado**,
    /// e o valor declarado entra no lugar — sempre acompanhado do rótulo de
    /// `metaEhEstimada`.
    static func suggestedKcal(weightKg: Double, heightCm: Double, ageYears: Int,
                              sex: BiologicalSex?, activity: ActivityLevel?, goal: Goal) -> Int {
        let tdee = RegrasDeSaude.bmr(weightKg: weightKg, heightCm: heightCm, ageYears: ageYears, sex: sex)
            * RegrasDeSaude.fatorDeAtividade(activity)
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
            // [2026-08-03 — A10] `suggestedKcalGoal` virou `Int?` na faxina de
            // honestidade e esta interpolação não acompanhou: a tela exibia
            // "Optional(2231) kcal" em fonte 40 bold. Sem perfil completo não há
            // meta — e é isso que o texto passa a dizer.
            Text(model.suggestedKcalGoal.map { "\($0) kcal" } ?? "informe suas medidas")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Theme.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            // [2026-08-14] A legenda passou a ter dois estados, e a diferença
            // entre eles é o ponto inteiro da mudança de hoje.
            //
            // A frase antiga era única e afirmava que a meta fora "calculada
            // pelo seu peso, altura, idade, SEXO, atividade e objetivo" —
            // enquanto o `?? .masculino` e o `?? .leve` inventavam dois desses
            // seis itens. O texto descrevia um cálculo pessoal que, para quem
            // nunca abriu esta tela, não tinha acontecido.
            //
            // Agora: quem informou tudo continua vendo a frase de sempre; quem
            // não informou vê um número honestamente rotulado como estimativa,
            // com o que falta NOMEADO e um seletor logo abaixo para resolver.
            if model.metaEhEstimada {
                Text("Estimativa — ainda não sabemos \(Self.listarEmPortugues(model.oQueFaltaNaMeta)). O resto vem do seu peso, altura, idade e objetivo (\(model.goal.rawValue.lowercased())).")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            } else {
                Text("Calculada pelo seu peso, altura, idade, sexo, atividade e objetivo (\(model.goal.rawValue.lowercased())).")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    /// "a e b" · "a" · "" — para a frase da estimativa não sair com vírgula solta.
    static func listarEmPortugues(_ itens: [String]) -> String {
        switch itens.count {
        case 0:  return ""
        case 1:  return itens[0]
        default: return itens.dropLast().joined(separator: ", ") + " e " + itens[itens.count - 1]
        }
    }

    // Sexo + nível de atividade (entram na fórmula)
    //
    // [2026-08-14] ESTA SEÇÃO CONTINUA EXISTINDO, E É DECISÃO, NÃO INÉRCIA.
    // A coleta do sexo subiu para o onboarding, o que tornaria tentador apagar
    // daqui. Dois motivos concretos contra:
    //
    //  1. `sexBiological` é a PRIMEIRA posição da cadeia de `sexoEfetivo` — tem
    //     precedência sobre o onboarding, porque é resposta direta à pergunta
    //     que a fórmula faz. Existe gente com esse valor gravado. Apagar a tela
    //     deixaria esse dado mandando no cálculo sem nenhuma tela que o mostre
    //     ou permita corrigir: pior que hoje.
    //  2. O seletor de atividade mora aqui e não tem outra casa. Apagar a seção
    //     apagaria junto o único controle do maior chute da fórmula (806 kcal
    //     contra 228 do sexo).
    //
    // O que mudou é o PAPEL: de fonte primária escondida para ajuste declarado.
    // Por isso o título deixou de ser "Perfil para o cálculo" e os dois
    // seletores passaram a admitir "não informado" em vez de exibir uma
    // seleção que ninguém fez.
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ajustar o cálculo").font(.headline).foregroundStyle(Theme.ink)

            VStack(alignment: .leading, spacing: 6) {
                Text("Sexo biológico").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                // [2026-08-14] `selection` é `BiologicalSex?` e existe uma
                // opção "Não informado" com `tag(nil)`. Sem ela, o Picker
                // exibiria um dos dois lados marcado para quem nunca respondeu
                // — que é a mentira de interface equivalente ao `?? .masculino`
                // que acabou de sair do código.
                Picker("Sexo biológico", selection: $model.sex) {
                    Text("Não informado").tag(BiologicalSex?.none)
                    ForEach(BiologicalSex.allCases) { Text($0.rawValue).tag(BiologicalSex?.some($0)) }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nível de atividade").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                Picker("Atividade", selection: $model.activityLevel) {
                    Text("Não informado").tag(ActivityLevel?.none)
                    ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag(ActivityLevel?.some($0)) }
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
