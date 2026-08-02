//
//  RootTabView.swift
//  Corpo & Alma
//
//  Navegação principal — 5 abas.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            CorpoHomeView()
                .tabItem { Label("Início", systemImage: "house.fill") }

            SaudeView()
                .tabItem { Label("Saúde", systemImage: "heart.fill") }

            DietaView()
                .tabItem { Label("Dieta", systemImage: "fork.knife") }

            TreinoView()
                .tabItem { Label("Treino", systemImage: "dumbbell.fill") }

            CorpoInsightsView()
                .tabItem { Label("Insights", systemImage: "sparkles") }
        }
    }
}

#Preview {
    RootTabView().environmentObject(AppModel())
}
