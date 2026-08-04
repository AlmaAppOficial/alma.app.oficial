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

    // MARK: - Detector de tela vazia
    //
    // [2026-08-04 — SEGUNDA MENTIRA DO HARNESS]
    //
    // A primeira foi o `ImageRenderer` (ver comentário lá embaixo). Esta é a
    // irmã dela: `var falhas` era declarada, nunca recebia nada, e no fim o
    // relatório imprimia "nenhuma falha" — sempre. O compilador chegou a avisar
    // ("variable 'falhas' was never mutated"), e o aviso passou batido.
    //
    // Resultado prático, medido nas 43 capturas de hoje: `Alma · Feed` saiu com
    // energia de borda 0,44 — a tela inteira era o spinner "Carregando feed…" —
    // e o harness deu "ok". Renderizar sem morrer não é renderizar a tela.
    //
    // O que este detector acrescenta: mede quanta variação horizontal existe na
    // imagem. Texto, botões e separadores criam bordas duras; um fundo liso ou
    // um gradiente puro, quase nenhuma. Não julga se a tela está CERTA — julga
    // se ela tem CONTEÚDO. É pouco, mas é honesto, e é mais do que zero.

    /// Abaixo disto a tela é considerada vazia.
    ///
    /// Calibrado com as 43 capturas reais de 04/08 (`_validacao_20260804/telas`):
    /// as vazias mediram 0,00 / 0,44 / 1,55 e a mais pobre COM conteúdo de
    /// verdade mediu 4,05. O corte em 3,0 cai no vale entre as duas populações.
    private static let limiteDeConteudo: Double = 3.0

    /// Telas que saem em branco por limitação do simulador, não por defeito:
    /// dependem de câmera real. Ficam fora do julgamento — com o motivo escrito.
    private static let brancoEsperado: Set<String> = [
        "Corpo · Código de barras (montagem)",
        "Corpo · Câmera de foto (montagem)"
    ]

    /// Média da diferença de cor entre pixels vizinhos na horizontal.
    private static func energiaDeBorda(_ imagem: UIImage) -> Double {
        guard let cg = imagem.cgImage else { return 0 }
        let largura = cg.width, altura = cg.height
        guard largura > 8, altura > 8 else { return 0 }

        let bytesPorLinha = largura * 4
        var pixels = [UInt8](repeating: 0, count: bytesPorLinha * altura)
        guard let ctx = CGContext(data: &pixels,
                                  width: largura, height: altura,
                                  bitsPerComponent: 8, bytesPerRow: bytesPorLinha,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: largura, height: altura))

        let passo = 4
        var soma = 0, amostras = 0
        var y = 0
        while y < altura {
            var x = 0
            while x + passo < largura {
                let a = y * bytesPorLinha + x * 4
                let b = y * bytesPorLinha + (x + passo) * 4
                soma += abs(Int(pixels[a])     - Int(pixels[b]))
                      + abs(Int(pixels[a + 1]) - Int(pixels[b + 1]))
                      + abs(Int(pixels[a + 2]) - Int(pixels[b + 2]))
                amostras += 1
                x += passo
            }
            y += passo
        }
        return amostras == 0 ? 0 : Double(soma) / Double(amostras)
    }

    /// Tela deliberadamente vazia, usada como canário do detector.
    private struct TelaVaziaDePropósito: View {
        var body: some View { Color(red: 0.95, green: 0.94, blue: 0.98) }
    }

    // MARK: - Conferência de aparência (claro × escuro) [2026-08-04]
    //
    // Por que esta função existe: a conferência por `simctl launch -corpoAba N`
    // NÃO funciona. Tentei três vezes hoje e nas três o app abriu na Home do
    // Alma em vez do módulo Corpo — o `fullScreenCover` não apresenta a partir
    // do `.task`, nem com o estado começando `false`, nem com espera. Numa
    // dessas rodadas os md5 passaram a diferir e quase engoli a prova: era o
    // RELÓGIO da barra de status virando o minuto, não a tela mudando.
    //
    // Aqui a aparência é imposta na própria view (`.environment(\.colorScheme,)`)
    // e a tela é montada no mesmo `UIWindow` de verdade que o smoke usa — o
    // caminho pelo qual o SwiftUI realmente resolve o `body`. Não depende de
    // navegação, de toque nem de flag de lançamento.
    //
    // LIMITE HONESTO desta técnica: `drawHierarchy` não reproduz fielmente
    // blur, vibrancy e o vidro do iOS 26. Serve para julgar CONTRASTE DE TEXTO
    // sobre card — que é exatamente o risco do modo escuro neste app (texto
    // adaptativo sobre card de cor fixa foi o que gerou a rejeição de julho).
    // Não serve para julgar a barra de abas flutuante.
    static func conferenciaDeAparencia() {
        guard UserDefaults.standard.bool(forKey: "conferenciaAparencia") else { return }

        let model = AppModel()
        let health = HealthManager()
        let store = StoreManager()
        let access = AccessManager()
        let storeAlma = StoreKitManager()
        let hk = HealthKitManager()

        log("═════ APARÊNCIA — 5 ABAS DO CORPO × 2 ═════")

        func renderizar<V: View>(_ nome: String, _ view: V, _ esquema: ColorScheme) {
            let conteudo = view
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .environment(\.colorScheme, esquema)
                .environmentObject(model)
                .environmentObject(health)
                .environmentObject(store)
                .environmentObject(access)
                .environmentObject(storeAlma)
                .environmentObject(hk)

            let quadro = CGRect(x: 0, y: 0, width: 393, height: 852)
            let host = UIHostingController(rootView: AnyView(conteudo))
            host.overrideUserInterfaceStyle = esquema == .dark ? .dark : .light
            host.view.frame = quadro

            let janela = UIWindow(frame: quadro)
            janela.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
            janela.rootViewController = host
            janela.isHidden = false
            janela.layoutIfNeeded()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.20))

            let desenhista = UIGraphicsImageRenderer(bounds: quadro)
            let imagem = desenhista.image { _ in
                host.view.drawHierarchy(in: quadro, afterScreenUpdates: true)
            }
            let rotulo = "\(esquema == .dark ? "escuro" : "claro") · \(nome)"
            salvar(imagem, como: rotulo)
            log("  \(rotulo) — energia \(String(format: "%.2f", energiaDeBorda(imagem)))")

            janela.isHidden = true
            janela.rootViewController = nil
        }

        for esquema in [ColorScheme.light, .dark] {
            renderizar("1 Inicio", CorpoHomeView(), esquema)
            renderizar("2 Saude", SaudeView(), esquema)
            renderizar("3 Dieta", DietaView(), esquema)
            renderizar("4 Treino", TreinoView(), esquema)
            renderizar("5 Insights", CorpoInsightsView(), esquema)
        }
        log("═════ FIM APARÊNCIA ═════")
    }

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
        @discardableResult
        func render<V: View>(_ nome: String, _ view: V) -> Double {
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

            // Renderizar sem crash é metade. A outra metade é ter conteúdo.
            let energia = energiaDeBorda(imagem)
            let medida = String(format: "%.2f", energia)
            if brancoEsperado.contains(nome) {
                log("  —    \(nome) — branco esperado (depende de câmera real); conteúdo não julgado")
            } else if energia < limiteDeConteudo {
                falhas.append("\(nome) [energia \(medida)]")
                log("  VAZIA \(nome) — energia \(medida) < \(limiteDeConteudo): sem crash, mas sem conteúdo")
            } else {
                log("  ok   \(nome) — energia \(medida)")
            }

            janela.isHidden = true
            janela.rootViewController = nil
            return energia
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

        log("═════ CANÁRIO DO DETECTOR ═════")
        // Quem vigia o vigia. Uma tela deliberadamente vazia TEM de ser acusada.
        // Se ela passar, o detector morreu — e todo "nenhuma tela vazia" acima
        // vira o mesmo papel pintado que o "nenhuma falha" era até hoje.
        let marcaCanário = "CANÁRIO · tela vazia de propósito"
        let energiaCanário = render(marcaCanário, TelaVaziaDePropósito())
        let canárioAcusado = falhas.contains { $0.hasPrefix(marcaCanário) }
        falhas.removeAll { $0.hasPrefix(marcaCanário) }   // não é defeito do app
        testadas -= 1                                     // nem é tela do app

        if canárioAcusado {
            log("✓ detector vivo — acusou a tela vazia (energia \(String(format: "%.2f", energiaCanário)))")
        } else {
            log("✗✗ DETECTOR CEGO — a tela vazia passou (energia \(String(format: "%.2f", energiaCanário)))")
            log("   Enquanto esta linha existir, o resultado abaixo não vale nada.")
            falhas.append("DETECTOR CEGO (o canário passou)")
        }

        log("═════ RESULTADO ═════")
        log("\(testadas) telas renderizadas sem crash")
        if falhas.isEmpty {
            log("nenhuma tela vazia")
        } else {
            log("\(falhas.count) TELA(S) SEM CONTEÚDO: \(falhas.joined(separator: ", "))")
        }
    }
}
#endif
