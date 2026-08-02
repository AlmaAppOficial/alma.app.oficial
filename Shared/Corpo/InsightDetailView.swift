//
//  InsightDetailView.swift
//  Corpo & Alma
//
//  Detalhe de um insight — texto completo + dica de ação.
//

import SwiftUI

struct InsightDetailView: View {
    let insight: Insight

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ZStack {
                    Circle().fill(insight.tint.opacity(0.14))
                    Image(systemName: insight.systemImage)
                        .font(.system(size: 48))
                        .foregroundStyle(insight.tint)
                }
                .frame(width: 110, height: 110)
                .frame(maxWidth: .infinity)

                Text(insight.title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)

                Text(insight.detail)
                    .font(.body)
                    .foregroundStyle(Theme.inkSoft)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Dica do Corpo & Alma", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(insight.tint)
                    Text("Pequenos ajustes diários geram grandes resultados ao longo das semanas. Use este insight como um lembrete gentil — sem cobrança, com constância.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .cardStyle()
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Insight")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InsightDetailView(insight: AppModel().insights[0])
    }
}
