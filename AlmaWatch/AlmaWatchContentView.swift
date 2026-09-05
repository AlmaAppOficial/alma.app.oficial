// AlmaWatchContentView.swift
// Alma Watch 2.0 — raiz do app: páginas verticais navegadas pela coroa.
//
// Estrutura (HIG "Designing for watchOS": hierarquia rasa, uma coisa por
// tela, Digital Crown como navegação vertical):
//   Hoje → Água → Humor → Respirar → Treino → Jejum → Meditações
//
// As telas vivem em arquivos próprios (TodayView, WaterView, MoodView,
// BreatheView, WorkoutView, MeditationsWatchView). A versão 1 deste arquivo
// (4 telas, lista fixa de 5 meditações, respiração sem sessão estendida)
// foi substituída em 04/08/2026.

import SwiftUI

enum PaginaWatch: Int, Hashable {
    case hoje = 0, agua, humor, respirar, treino, jejum, meditacoes
}

struct AlmaWatchContentView: View {
    // A página inicial pode vir de argumento de lançamento (-paginaInicial agua)
    // — usado só pelo harness de captura de telas; sem argumento, abre em Hoje.
    @State private var pagina: PaginaWatch = {
        switch UserDefaults.standard.string(forKey: "paginaInicial") {
        case "agua": return .agua
        case "humor": return .humor
        case "respirar": return .respirar
        case "treino": return .treino
        case "jejum": return .jejum
        case "meditacoes": return .meditacoes
        default: return .hoje
        }
    }()

    var body: some View {
        NavigationStack {
            TabView(selection: $pagina) {
                TodayView().tag(PaginaWatch.hoje)
                WaterView().tag(PaginaWatch.agua)
                MoodView().tag(PaginaWatch.humor)
                BreatheView().tag(PaginaWatch.respirar)
                WorkoutView().tag(PaginaWatch.treino)
                JejumWatchView().tag(PaginaWatch.jejum)
                MeditationsWatchView().tag(PaginaWatch.meditacoes)
            }
            .tabViewStyle(.verticalPage)
        }
        .onOpenURL { url in
            // Deep links das complicações: alma://watch/<pagina>
            guard url.scheme == "alma", url.host == "watch" else { return }
            switch url.lastPathComponent {
            case "hoje": pagina = .hoje
            case "agua": pagina = .agua
            case "humor": pagina = .humor
            case "respirar": pagina = .respirar
            case "treino": pagina = .treino
            case "jejum": pagina = .jejum
            case "meditacoes": pagina = .meditacoes
            default: break
            }
        }
    }
}
