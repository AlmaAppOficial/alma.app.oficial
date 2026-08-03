//
//  RootTabView.swift
//  Corpo & Alma
//
//  Navegação principal — 5 abas.
//

import SwiftUI

struct RootTabView: View {
    /// [Fusão] Aba inicial. Normalmente 0 (Início); a flag `-corpoAba N`
    /// permite abrir direto numa aba pela linha de comando, o que torna cada
    /// aba verificável sem automação de toque (`xcrun simctl launch … -corpoAba 3`).
    /// [2026-08-03 — A13] Só em DEBUG. Em Release a flag ficava lida do
    /// UserDefaults: um valor fora de 0–4 deixava o TabView sem aba selecionada
    /// — tela em branco, sem nenhuma forma de recuperar pela interface.
    #if DEBUG
    @State private var selection = min(max(UserDefaults.standard.integer(forKey: "corpoAba"), 0), 4)
    #else
    @State private var selection = 0
    #endif

    var body: some View {
        TabView(selection: $selection) {
            CorpoHomeView()
                .tabItem { Label("Início", systemImage: "house.fill") }
                .tag(0)

            SaudeView()
                .tabItem { Label("Saúde", systemImage: "heart.fill") }
                .tag(1)

            DietaView()
                .tabItem { Label("Dieta", systemImage: "fork.knife") }
                .tag(2)

            TreinoView()
                .tabItem { Label("Treino", systemImage: "dumbbell.fill") }
                .tag(3)

            CorpoInsightsView()
                .tabItem { Label("Insights", systemImage: "sparkles") }
                .tag(4)
        }
    }
}

#Preview {
    RootTabView().environmentObject(AppModel())
}
