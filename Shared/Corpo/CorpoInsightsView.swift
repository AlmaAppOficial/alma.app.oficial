//
//  CorpoInsightsView.swift
//  Alma — Corpo
//
//  [Honestidade 2026-08-02] Reescrita. A versão anterior exibia quatro frases
//  hardcoded ("sua média de sono subiu 6% nos últimos 7 dias…") e dois gráficos
//  com séries inventadas. Agora tudo vem de CorpoInsightsEngine, calculado dos
//  registros reais — e sem base, a tela diz o que falta registrar.
//

import SwiftUI
import Charts

struct CorpoInsightsView: View {
    @EnvironmentObject var model: AppModel

    private var metricas: [CorpoMetric] { CorpoInsightsEngine.metricas(model: model) }
    private var faltas: [String] { CorpoInsightsEngine.oQueFalta(model: model) }
    private var serieKcal: [DayPoint] { CorpoInsightsEngine.serieCalorias(kcalByDay: model.kcalByDay) }
    private var seriePeso: [DayPoint] { CorpoInsightsEngine.seriePeso(weightLog: model.weightLog) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenHeader(title: "Insights", subtitle: "O que os seus registros mostram")

                    if metricas.isEmpty && serieKcal.isEmpty && seriePeso.isEmpty {
                        estadoSemDados
                    } else {
                        ForEach(metricas) { m in cardMetrica(m) }
                        if !serieKcal.isEmpty { graficoCalorias }
                        if !seriePeso.isEmpty { graficoPeso }
                        if !faltas.isEmpty { cardComoMelhorar }
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Métrica real

    private func cardMetrica(_ m: CorpoMetric) -> some View {
        HStack(spacing: 14) {
            Image(systemName: m.systemImage)
                .font(.title3)
                .foregroundStyle(Theme.primary)
                .frame(width: 44, height: 44)
                .background(Theme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(m.titulo).font(.caption).foregroundStyle(Theme.inkSoft)
                Text(m.valor).font(.title3.bold())
                if let v = m.variacao {
                    Text(v).font(.caption).foregroundStyle(Theme.primary)
                }
                // A base do número fica à vista — o usuário sabe de onde saiu.
                Text("com base em \(m.diasDeDados) \(m.diasDeDados == 1 ? "registro" : "registros")")
                    .font(.caption2).foregroundStyle(Theme.inkSoft.opacity(0.7))
            }
            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Gráficos (desenhados só com dado real)

    private var graficoCalorias: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calorias registradas").font(.headline)
            Chart(serieKcal) { p in
                BarMark(x: .value("Dia", p.label), y: .value("kcal", p.value))
                    .foregroundStyle(Theme.coral)
            }
            .frame(height: 170)
            Text("Só aparecem os dias em que você registrou refeições.")
                .font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .cardStyle()
    }

    private var graficoPeso: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Seu peso").font(.headline)
            Chart(seriePeso) { p in
                LineMark(x: .value("Data", p.label), y: .value("kg", p.value))
                    .foregroundStyle(Theme.primary)
                PointMark(x: .value("Data", p.label), y: .value("kg", p.value))
                    .foregroundStyle(Theme.primary)
            }
            .frame(height: 170)
            Text("Cada ponto é uma pesagem que você registrou.")
                .font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .cardStyle()
    }

    // MARK: - Estados honestos

    private var estadoSemDados: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)

            Text("Ainda não tenho o que te mostrar").font(.title3.bold())

            Text("Estes insights são calculados a partir do que você registra — nada de números de exemplo. Assim que houver dados, eles aparecem aqui.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)

            listaDeFaltas
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var cardComoMelhorar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Para eu enxergar mais").font(.headline)
            listaDeFaltas
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var listaDeFaltas: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(faltas, id: \.self) { f in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Theme.primary)
                        .padding(.top, 6)
                    Text(f).font(.footnote).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    CorpoInsightsView().environmentObject(AppModel())
}
