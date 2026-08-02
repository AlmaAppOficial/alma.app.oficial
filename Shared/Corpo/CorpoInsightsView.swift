//
//  CorpoInsightsView.swift
//  Corpo & Alma
//
//  Aba "Insights" — tendências e descobertas sobre o corpo.
//

import SwiftUI
import Charts

struct CorpoInsightsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showPaywall = false
    @State private var selectedInsight: Insight? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Insights", subtitle: "O que seu corpo está te contando")

                    weightCard

                    caloriesCard

                    SectionTitle(text: "Descobertas da semana")
                    VStack(spacing: 12) {
                        ForEach(model.insights) { insight in
                            Button {
                                if model.hasPremiumAccess { selectedInsight = insight }
                                else { showPaywall = true }
                            } label: {
                                insightRow(insight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) { CorpoPaywallView() }
                        // [Fusão] variante iOS 16 de navigationDestination(item:)
            .navigationDestination(isPresented: Binding(
                get: { selectedInsight != nil },
                set: { if !$0 { selectedInsight = nil } }
            )) {
                if let insight = selectedInsight {
                InsightDetailView(insight: insight)
                }
            }
        }
    }

    // Tendência de peso (linha)
    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Peso · 7 dias", systemImage: "scalemass.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Pill(text: "-0,8 kg", tint: Theme.primary)
            }
            Chart(model.weightTrend) { point in
                LineMark(x: .value("Dia", point.label), y: .value("Peso", point.value))
                    .foregroundStyle(Theme.primary)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Dia", point.label), y: .value("Peso", point.value))
                    .foregroundStyle(LinearGradient(colors: [Theme.primary.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Dia", point.label), y: .value("Peso", point.value))
                    .foregroundStyle(Theme.primary)
            }
            .chartYScale(domain: 78...79.5)
            .frame(height: 160)
        }
        .cardStyle()
    }

    // Calorias da semana (barras)
    private var caloriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Calorias · 7 dias", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Pill(text: "média 2.167", tint: Theme.coral)
            }
            Chart(model.caloriesWeek) { point in
                BarMark(x: .value("Dia", point.label), y: .value("kcal", point.value))
                    .foregroundStyle(Theme.coral.gradient)
                    .cornerRadius(6)
            }
            .frame(height: 160)
        }
        .cardStyle()
    }

    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: 14) {
            Image(systemName: insight.systemImage)
                .font(.title3)
                .foregroundStyle(insight.tint)
                .frame(width: 46, height: 46)
                .background(insight.tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }
}

#Preview {
    CorpoInsightsView().environmentObject(AppModel())
}
