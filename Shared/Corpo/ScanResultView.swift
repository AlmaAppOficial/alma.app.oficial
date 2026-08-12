//
//  ScanResultView.swift
//  Corpo & Alma
//
//  Resultado do scan corporal — análise da IA + plano de alimentação e treino.
//

import SwiftUI

struct ScanResultView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let result: ScanResult

    @State private var applied = false

    private var analysis: BodyAnalysis { result.analysis }
    private var plan: GeneratedPlan { result.plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if result.isAIGenerated == false {
                    estimateBanner
                }
                analysisCard
                macrosCard
                mealsSection
                weekSection
                applyButton
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Seu plano")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applied = model.planAppliedAt != nil && model.scanResult != nil }
    }

    // [F1] Aviso visível no topo quando o resultado NÃO veio de IA.
    private var estimateBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "ruler")
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimativa por medidas — sem IA")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("Este resultado foi calculado apenas com peso, altura, idade e % de gordura informados. Nenhuma foto foi analisada.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gold.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    /// [2026-08-12] Duas linhas que só aparecem quando têm o que dizer.
    ///
    /// O somatotipo já sumia quando faltava — a IA devolve `null` no rótulo e a
    /// tela deixou de derrubar a análise inteira por causa disso. A gordura
    /// **não** sumia: no caminho sem foto, quem nunca informou o percentual
    /// carregava um `0` vindo do `AppModel`, e a tela imprimia "Gordura
    /// estimada: 0%". Ausência vestida de medição, num app de saúde.
    ///
    /// Agora as duas seguem a mesma regra, e o que some é a linha: sem
    /// travessão, sem "não informado", sem estimar por fora. Esconder já era o
    /// comportamento estabelecido aqui para dado que falta — a régua é a
    /// coerência com o que a tela já fazia.
    ///
    /// Faltando as duas, o cabeçalho inteiro sai. Ícone sozinho ao lado de um
    /// bloco vazio não informa nada. O resumo, as observações e os focos ficam:
    /// não dependem destes dois campos.
    @ViewBuilder
    private var cabecalhoDaAnalise: some View {
        let perfil = analysis.somatotype.map { "Perfil: \($0.rawValue)" }
        let gordura = analysis.estimatedBodyFat.map {
            String(format: "Gordura estimada: %.0f%%", $0)
        }

        if let principal = perfil ?? gordura {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(principal)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    // A gordura só é segunda linha quando o perfil ocupou a
                    // primeira. Sozinha, ela É a primeira.
                    if perfil != nil, let gordura {
                        Text(gordura)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
            }
        }
    }

    // Análise
    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cabecalhoDaAnalise
            Text(analysis.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)

            if !analysis.observations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.observations, id: \.self) { obs in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.primary)
                            Text(obs).font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }

            if !analysis.focusAreas.isEmpty {
                HStack(spacing: 8) {
                    ForEach(analysis.focusAreas, id: \.self) { area in
                        Pill(text: area, tint: Theme.azure)
                    }
                }
            }
        }
        .cardStyle()
    }

    // Macros do plano
    private var macrosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Meta diária").font(.headline).foregroundStyle(Theme.ink)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(plan.dailyKcal)").font(.largeTitle.bold()).foregroundStyle(Theme.coral)
                    Text("kcal por dia").font(.caption).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
            }
            HStack(spacing: 12) {
                macroBox("Proteína", plan.proteinG, Theme.primary)
                macroBox("Carbo", plan.carbsG, Theme.gold)
                macroBox("Gordura", plan.fatG, Theme.azure)
            }
        }
        .cardStyle()
    }

    private func macroBox(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value) g").font(.title3.bold()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.vertical, 2)
    }

    // Plano de refeições
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Plano de alimentação")
            ForEach(plan.meals) { meal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(meal.type).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(meal.kcal) kcal").font(.caption.weight(.semibold)).foregroundStyle(Theme.coral)
                    }
                    Text(meal.title).font(.caption).foregroundStyle(Theme.inkSoft)
                    ForEach(meal.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(Theme.primary).padding(.top, 6)
                            Text(item).font(.caption).foregroundStyle(Theme.ink)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
            }
        }
    }

    // Plano de treino semanal
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Treino da semana")
            ForEach(plan.week) { day in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(day.day).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Pill(text: day.focus, tint: Theme.primary)
                    }
                    Text(day.exercises.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
            }
        }
    }

    // [F6] Aplicar de verdade: popula a Dieta (refeições do plano), o Treino
    // (treinos da semana) e alinha a meta calórica — com opção de desfazer.
    private var applyButton: some View {
        VStack(spacing: 8) {
            Button {
                model.applyPlan(result)
                applied = true
            } label: {
                Label(applied ? "Plano aplicado à Dieta e ao Treino ✓" : "Aplicar este plano",
                      systemImage: applied ? "checkmark" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(applied ? Theme.primary.opacity(0.15) : Theme.primary)
                    .foregroundStyle(applied ? Theme.primary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
            .disabled(applied)

            if applied {
                Text("As refeições estão na aba Dieta, os treinos da semana na aba Treino e sua meta passou a ser \(plan.dailyKcal) kcal.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button(role: .destructive) {
                    model.undoAppliedPlan()
                    applied = false
                } label: {
                    Label("Desfazer aplicação", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .tint(Theme.coral)
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    let mock = ScanResult(
        analysis: BodyAnalysis(somatotype: .mesomorfo, estimatedBodyFat: 18, summary: "Exemplo.", observations: ["IMC saudável"], focusAreas: ["Core"]),
        plan: GeneratedPlan(dailyKcal: 2200, proteinG: 150, carbsG: 220, fatG: 60, meals: [], week: [], notes: "")
    )
    return NavigationStack { ScanResultView(result: mock).environmentObject(AppModel()) }
}
