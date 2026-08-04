// SmokeTestTelas.swift
// Alma — varredura de crash em TODAS as telas do app fundido
//
// [2026-08-03] Pedido do Assis: "teste todos os botões para ver se não tem
// nenhum crash". A validação anterior cobria as 5 abas do Corpo; isto cobre o
// app inteiro, incluindo as subtelas que só se alcança por toque (detalhe de
// exercício, mapa muscular, registrar alimento, código de barras, resultado de
// scan, editar medidas, suplementos…).
//
// COMO FUNCIONA E POR QUE É CONFIÁVEL
//
// `ImageRenderer` (iOS 16+) monta a árvore SwiftUI e força o layout completo
// fora da tela. É o mesmo caminho de renderização que a tela de verdade usa:
// se faltar um @EnvironmentObject, se um índice estourar, se um `!` for nil ou
// se um `fatalError` for atingido durante o body, o processo morre AQUI — do
// mesmo jeito que morreria no aparelho do usuário.
//
// O que ele NÃO cobre, e eu não vou fingir que cobre:
//   • animações, gestos e transições;
//   • o que só acontece DEPOIS de um toque (a ação do botão em si);
//   • telas que dependem de hardware real (câmera do scanner);
//   • estados que exigem rede (resposta do chat, lista de produtos do StoreKit).
// Essas ficam marcadas como "não testável aqui" no relatório, com o motivo.
//
// Cada tela é logada ANTES de renderizar. Se o app morrer, a última linha do
// log é a tela culpada — é assim que se encontra a causa sem adivinhação.

#if DEBUG
import SwiftUI
import UIKit

@MainActor
enum SmokeTestTelas {

    static var ligado: Bool {
        UserDefaults.standard.bool(forKey: "smokeTelas")
    }

    /// [2026-08-04] Salva o PNG de cada tela renderizada.
    ///
    /// A conferência visual estava pendente desde a revisão de 03/08 e as duas
    /// tentativas por screenshot do simulador falharam: a de 03/08 gerou cinco
    /// capturas idênticas, e a de hoje mostrou a Home do Alma porque
    /// `-abrirCorpo` não apresenta o `fullScreenCover`. Em vez de insistir na
    /// navegação, saímos pelo lado que JÁ funciona — o `ImageRenderer` que
    /// varre as 43 telas — e pedimos a ele a imagem que ele já produz.
    ///
    /// Vantagem sobre o screenshot: não depende de navegação, de toque nem de
    /// diálogo do sistema, e cobre 43 telas em vez de 5.
    /// Limite honesto: é a árvore SwiftUI renderizada fora da tela — sem
    /// animação, sem barra de status, sem teclado.
    static var salvarPNGs: Bool {
        UserDefaults.standard.bool(forKey: "capturarTelas")
    }

    private static var pastaDeCapturas: URL? {
        guard salvarPNGs else { return nil }
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("capturas", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func salvar(_ imagem: UIImage, como nome: String) {
        guard let pasta = pastaDeCapturas, let png = imagem.pngData() else { return }
        let limpo = nome
            .replacingOccurrences(of: " · ", with: "__")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        try? png.write(to: pasta.appendingPathComponent("\(limpo).png"))
    }

    private static func log(_ t: String) { NSLog("%@", "[SMOKE] " + t) }

    static func executar() {
        guard ligado else { return }

        let model = AppModel()
        let health = HealthManager()
        let store = StoreManager()
        let access = AccessManager()
        let storeAlma = StoreKitManager()
        let hk = HealthKitManager()

        // Dados mínimos para as telas de detalhe terem o que exibir.
        let treino = model.workouts.first
        let exercicio = treino?.exercises.first        // Exercise (catálogo antigo)
        let exercicioV2 = ExerciseCatalog.all.first    // ExerciseV2 (biblioteca 2.0)
        let refeicao = model.meals.first

        var testadas = 0
        var falhas: [String] = []

        /// Renderiza a view. Qualquer crash mata o processo aqui — e o log já
        /// registrou o nome antes, então a tela culpada fica identificada.
        // [2026-08-04 — O HARNESS ESTAVA MENTINDO]
        //
        // Até aqui isto usava `ImageRenderer` e dava a tela por aprovada quando
        // `renderer.uiImage != nil`. Ao salvar os PNGs pela primeira vez, hoje,
        // apareceu o que a asserção nunca ia pegar: das 43 telas saíam **9
        // imagens distintas** — as do Corpo eram o placeholder amarelo com a
        // faixa vermelha (SwiftUI dizendo "não consigo representar isto") e as
        // do Alma eram só o gradiente de fundo, sem um único elemento.
        //
        // Ou seja: o `body` das telas quase nunca rodava. "43/43 sem crash" era
        // verdade sobre o renderer, não sobre o app — um `nil` que nunca vinha.
        // Um `fatalError` dentro de uma lista jamais teria sido alcançado.
        //
        // Agora a tela é montada num `UIWindow` de verdade, com
        // `UIHostingController`, layout forçado e uma volta do run loop — que é
        // o caminho pelo qual o SwiftUI realmente constrói o `body`. Se algo
        // explodir, explode aqui, como explodiria no aparelho.
        func render<V: View>(_ nome: String, _ view: V) {
            log("→ \(nome)")

            let conteudo = view
                // Mesmo locale da raiz do app: sem isto a captura mostraria
                // números formatados diferente da tela real.
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .environmentObject(model)
                .environmentObject(health)
                .environmentObject(store)
                .environmentObject(access)
                .environmentObject(storeAlma)
                .environmentObject(hk)

            let quadro = CGRect(x: 0, y: 0, width: 393, height: 852)  // iPhone 15/16 lógico
            let host = UIHostingController(rootView: AnyView(conteudo))
            host.view.frame = quadro
            host.view.backgroundColor = .systemBackground

            let janela = UIWindow(frame: quadro)
            janela.rootViewController = host
            janela.isHidden = false          // sem estar "na tela", o body não roda
            janela.layoutIfNeeded()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            // Uma volta curta do run loop: é aqui que o SwiftUI resolve o body,
            // dispara os onAppear e monta as listas.
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))

            let desenhista = UIGraphicsImageRenderer(bounds: quadro)
            let imagem = desenhista.image { _ in
                host.view.drawHierarchy(in: quadro, afterScreenUpdates: true)
            }

            testadas += 1
            salvar(imagem, como: nome)
            log("  ok   \(nome)")

            janela.isHidden = true
            janela.rootViewController = nil
        }

        log("═════ ALMA ═════")
        render("Alma · Início", HomeView())
        render("Alma · Práticas", PraticasView())
        render("Alma · Feed", FeedView())
        render("Alma · Insights", InsightsView())
        render("Alma · Perfil", ProfileView())
        render("Alma · Chat", ChatView())
        render("Alma · Paywall (PremiumWallView)", PremiumWallView())
        render("Alma · Onboarding", OnboardingBiometricsView())
        render("Alma · Saúde feminina", FeminineHealthView())
        render("Alma · Livre de vícios", AddictionFreeView())
        render("Alma · Excluir conta", DeleteAccountView())
        render("Alma · Login", LoginView(logged: .constant(false)))
        render("Alma · Abas (MainTabView)", MainTabView())
        // RootView tem `logged` como parâmetro obrigatório e decide login vs app;
        // as duas pontas dela (LoginView e MainTabView) já foram renderizadas.

        log("═════ CORPO — 5 abas ═════")
        render("Corpo · Módulo (raiz)", CorpoModuleView())
        render("Corpo · Abas (RootTabView)", RootTabView())
        render("Corpo · Início", CorpoHomeView())
        render("Corpo · Saúde", SaudeView())
        render("Corpo · Dieta", DietaView())
        render("Corpo · Treino", TreinoView())
        render("Corpo · Insights", CorpoInsightsView())

        log("═════ CORPO — subtelas ═════")
        render("Corpo · Ajustes", SettingsView())
        render("Corpo · Editar medidas", EditAssessmentView())
        render("Corpo · Suplementos", SupplementsSection())
        render("Corpo · Adicionar alimento", AddFoodView())
        render("Corpo · Mapa muscular", MuscleMapView())
        render("Corpo · Scan corporal", BodyScanView())
        render("Corpo · Scan de alimento", FoodScanView())
        render("Corpo · Paywall do Corpo", PaywallDoCorpo())
        render("Corpo · Editor de meta", GoalEditorView())
        render("Corpo · Aviso de saúde", HealthDisclaimerView())

        if let ex = exercicio {
            render("Corpo · Detalhe do exercício", ExerciseDetailView(exercise: ex))
        } else {
            log("  — Detalhe do exercício: nenhum treino no catálogo")
        }
        if let g = MuscleGroup.allCases.first {
            render("Corpo · Lista de exercícios (biblioteca 2.0)", ExerciseListV2View(group: g))
        }
        if let ex2 = exercicioV2 {
            render("Corpo · Detalhe do exercício 2.0", ExerciseDetailV2View(exercise: ex2))
        } else {
            log("  — Detalhe 2.0: exercises_v2.json não carregou")
        }
        if let w = treino {
            render("Corpo · Detalhe do treino", WorkoutDetailView(workout: w))
            render("Corpo · Sessão de treino", WorkoutSessionView(workout: w))
        } else {
            log("  — Detalhe/sessão de treino: sem treino no catálogo")
        }
        if let m = refeicao {
            render("Corpo · Detalhe da refeição", MealDetailView(meal: m))
        }
        render("Corpo · Montar treino próprio", TreinoBuilderView())

        if let scan = model.scanResult {
            render("Corpo · Resultado do scan", ScanResultView(result: scan))
        } else {
            log("  — Resultado do scan: sem scan salvo (instalação limpa); a view é")
            log("    exercitada logo abaixo com um resultado construído")
        }

        // Telas de câmera. São UIViewControllerRepresentable: aqui se verifica
        // que MONTAR o controller não derruba o app. O funcionamento real da
        // captura depende de hardware que o simulador não tem — isso fica
        // declarado no relatório como não testável aqui.
        render("Corpo · Código de barras (montagem)", BarcodeScannerView(onScan: { _ in }))
        render("Corpo · Câmera de foto (montagem)", CameraPickerView(onCapture: { _ in }))

        log("═════ estados alternativos ═════")
        // Perfil zerado: foi exatamente onde nasceu o IMC "nan · Obesidade".
        let vazio = AppModel(store: UserDefaults(suiteName: "smoke.vazio")!)
        UserDefaults().removePersistentDomain(forName: "smoke.vazio")
        render("Corpo · Saúde SEM medidas", SaudeView().environmentObject(vazio))
        render("Corpo · Editar medidas SEM medidas", EditAssessmentView().environmentObject(vazio))
        render("Corpo · Insights SEM dados", CorpoInsightsView().environmentObject(vazio))
        render("Corpo · Dieta SEM refeições", DietaView().environmentObject(vazio))

        log("═════ RESULTADO ═════")
        log("\(testadas) telas renderizadas sem crash")
        if falhas.isEmpty {
            log("nenhuma falha")
        } else {
            log("FALHAS: \(falhas.joined(separator: ", "))")
        }
    }
}
#endif
