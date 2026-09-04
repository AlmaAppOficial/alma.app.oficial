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

    /// Lê de volta o PNG que `salvar` acabou de escrever.
    ///
    /// [2026-09-03] Existe para o canário do padrão do exercício. Duas capturas
    /// rotuladas "antes" e "depois" saíram byte a byte IDÊNTICAS e ninguém
    /// percebeu até o Assis rodar `md5` nelas — o rótulo dizia uma coisa e a
    /// imagem dizia outra. Comparar os bytes é a única forma de o harness saber
    /// que fotografou dois estados, e não o mesmo estado duas vezes.
    private static func dadosDaCaptura(_ nome: String) -> Data? {
        guard let pasta = pastaDeCapturas else { return nil }
        let limpo = nome
            .replacingOccurrences(of: " · ", with: "__")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return try? Data(contentsOf: pasta.appendingPathComponent("\(limpo).png"))
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

    /// [2026-09-02] Hospeda o `RegistroDaSerieCard` com estado já preenchido.
    /// O card precisa de `@FocusState`, que só existe dentro de uma View — daí
    /// esta casca. A linha "Última vez" é literal: é o TEXTO que se confere
    /// aqui, não o store (o store é provado pelo harness e pela auditoria S).
    private struct CartaoDeSerieParaSmoke: View {
        let titulo: String
        let medida: MedidaDaSerie
        let pesoCorporal: Bool
        @State var reps: String
        @State var carga: String
        @State var mostrarCarga: Bool
        @FocusState private var foco: WorkoutSessionView.CampoDaSerie?

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(titulo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                RegistroDaSerieCard(numero: 2, medida: medida, pesoCorporal: pesoCorporal,
                                    textoReps: $reps, textoCarga: $carga,
                                    mostrarCarga: $mostrarCarga, foco: $foco,
                                    tint: Theme.primary,
                                    ultimaVez: "Última vez (28/08): 12 reps × 60 kg")
            }
        }
    }

    /// Os três estados numa tela só (ver o comentário no ponto de chamada).
    private struct TresCartoesDeSerieParaSmoke: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 28) {
                Text("Anotar série — os três estados")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                CartaoDeSerieParaSmoke(titulo: "FORÇA · halteres/barra — reps + kg, preenchida",
                                       medida: .repeticoes, pesoCorporal: false,
                                       reps: "12", carga: "60", mostrarCarga: false)
                CartaoDeSerieParaSmoke(titulo: "PESO CORPORAL — carga recolhida atrás de \"+ peso extra\"",
                                       medida: .repeticoes, pesoCorporal: true,
                                       reps: "15", carga: "", mostrarCarga: false)
                CartaoDeSerieParaSmoke(titulo: "POR TEMPO (\"30 s\") — segundos, com peso extra aberto",
                                       medida: .segundos, pesoCorporal: true,
                                       reps: "30", carga: "10", mostrarCarga: true)
                Spacer()
            }
            .padding(20)
            .background(Theme.background)
        }
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

            // [2026-08-29] Era `CGRect(0,0,393,852)` fixo — o tamanho lógico do
            // iPhone 15/16 Pro. Consequência: rodar o harness num 17 Pro Max
            // continuava produzindo 1179x2556, e não os 1320x2868 que a App
            // Store exige no slot de 6,9". A captura saía com a dimensão do
            // aparelho ERRADO sem nada avisar, porque nenhum passo comparava o
            // PNG com o simulador em que ele nasceu.
            // Agora segue o aparelho: num iPad dá o quadro do iPad, num Max dá
            // o do Max. Código só de DEBUG (todo o arquivo é `#if DEBUG`).
            let quadro = CGRect(origin: .zero, size: UIScreen.main.bounds.size)
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

        conferenciaDoJejum(model: model, renderizar: renderizar)
        conferenciaDoScan(model: model, renderizar: renderizar)
        conferenciaDasFotos(renderizar: renderizar)
    }

    // MARK: - Conferência das fotos dos exercícios [2026-09-03]
    //
    // O harness `_scripts/rodar_testes_fotos.sh` prova que o ARQUIVO existe no
    // caminho que a referência de pasta copia, e o portão de conteúdo prova que
    // ele entrou no `.app`. Nenhum dos dois desenha nada: que a miniatura e o
    // herói APAREÇAM é prova de imagem, e é o que falta.
    //
    // Vai por aqui, e não por navegação no simulador, porque navegar até o
    // módulo Corpo não funciona — está escrito no cabeçalho da
    // `conferenciaDeAparencia` (três tentativas em 04/08, as três pararam na
    // Home do Alma) e foi reproduzido de novo hoje. O `fullScreenCover` não
    // apresenta a partir do `.task` nem por AXPress.
    //
    // LIMITE HONESTO, o mesmo da `conferenciaDeAparencia`: `drawHierarchy` não
    // reproduz blur nem o vidro do iOS 26. Para o que está sob prova aqui —
    // a FOTO desenhar, recortada, com contraste sobre o card nos dois temas —
    // isso não atrapalha: a imagem é opaca e não depende de vibrancy.
    private static func conferenciaDasFotos(
        renderizar: (String, AnyView, ColorScheme) -> Void
    ) {
        log("═════ FOTOS DOS EXERCÍCIOS — LISTA E DETALHE × 2 ═════")

        // Escolhe pelo DADO, não por nome fixo: um id escrito à mão aqui vira
        // print vazio no dia em que o catálogo mudar, e ninguém repara.
        // Precisa das DUAS pontas (início e pico) — é o par que o herói desenha.
        let comParDeFotos = ExerciseCatalog.all.first { ($0.fotos ?? []).count >= 2 }

        // Para a LISTA não basta o grupo TER alguma foto: o que sai no print são
        // as ~6 primeiras linhas. Um grupo com foto só na linha 40 rende uma
        // captura de corpos anatômicos com legenda dizendo "miniatura" — prova
        // do contrário do que afirma. Então escolhe o grupo que mais tem foto
        // JÁ NO TOPO da lista.
        let grupoComFoto = MuscleGroup.allCases.max { a, b in
            func topoComFoto(_ g: MuscleGroup) -> Int {
                ExerciseCatalog.exercises(for: g).prefix(6)
                    .filter { !($0.fotos ?? []).isEmpty }.count
            }
            return topoComFoto(a) < topoComFoto(b)
        }

        // Anti-cegueira: sem exercício com foto, as capturas sairiam com o corpo
        // anatômico e pareceriam corretas. Aí o print PROVA O CONTRÁRIO do que
        // diz a legenda — que é pior do que não ter print.
        guard let ex = comParDeFotos, let grupo = grupoComFoto else {
            log("  ✗✗ CEGO: nenhum exercício com foto no catálogo carregado.")
            log("     As capturas de foto NÃO foram feitas. Não conclua nada.")
            return
        }
        let quantos = ExerciseCatalog.all.filter { !($0.fotos ?? []).isEmpty }.count
        log("  catálogo: \(quantos) de \(ExerciseCatalog.all.count) com foto")
        log("  lista: grupo \(grupo.rawValue) · detalhe: \(ex.namePTBR) \(ex.fotos ?? [])")

        // ── O DIAGNÓSTICO QUE A PRIMEIRA RODADA EXIGIU (03/09) ───────────────
        // A primeira captura saiu com o herói e as duas pontas VAZIOS. Duas
        // explicações rivais, e elas pedem consertos opostos:
        //   (a) o app não acha/não decodifica o .webp  → defeito de produção;
        //   (b) a foto carrega ASSÍNCRONA e este harness desenha 0,2 s depois
        //       do layout, antes de o `.task` terminar → defeito da CAPTURA.
        // Afirmar (a) sem descartar (b) seria exatamente a "afirmação sem
        // contraditório". Então mede-se cada elo, e o log diz qual quebrou.
        for nome in (ex.fotos ?? []) {
            let url = AcervoDeFotosDeExercicio.urlNoBundle(nome)
            let dados = url.flatMap { try? Data(contentsOf: $0) }
            let img = dados.flatMap { UIImage(data: $0) }
            log("  elo · \(nome)")
            log("      Bundle.main acha? \(url != nil ? "SIM" : "NÃO")")
            log("      bytes lidos? \(dados.map { "\($0.count)" } ?? "não")")
            log("      UIImage decodifica .webp? \(img != nil ? "SIM \(Int(img!.size.width))x\(Int(img!.size.height))" : "NÃO")")
        }

        // Aquece o cache ANTES de desenhar. `FotoDoExercicioView.init` lê
        // `emCache` e, com o cache quente, desenha no primeiro frame — está
        // escrito no próprio `FotoDoExercicio.swift`. Sem isto o harness
        // fotografa a reserva, não a foto, e o print não julga o que promete.
        var nomesParaAquecer = Set(ex.fotos ?? [])
        for e in ExerciseCatalog.exercises(for: grupo).prefix(12) {
            nomesParaAquecer.formUnion(e.fotos ?? [])
        }
        let aquecidas = AcervoDeFotosDeExercicio.compartilhado
            .aquecerParaCapturas(Array(nomesParaAquecer))
        log("  cache quente: \(aquecidas) de \(nomesParaAquecer.count) fotos carregadas")
        if aquecidas == 0 {
            log("  ✗✗ NENHUMA foto carregou — as capturas abaixo mostram a")
            log("     RESERVA (corpo anatômico), não a foto. Isto é defeito.")
        }

        for esquema in [ColorScheme.light, .dark] {
            renderizar("F1 Lista de exercicios (miniatura)",
                       AnyView(ExerciseListV2View(group: grupo)), esquema)
            renderizar("F2 Detalhe do exercicio (heroi)",
                       AnyView(ExerciseDetailV2View(exercise: ex)), esquema)
        }
        log("═════ FIM FOTOS ═════")
    }

    // MARK: - Conferência do módulo de jejum [2026-08-26]
    //
    // Reaproveita o `renderizar` da conferência de aparência — mesmo `UIWindow`,
    // mesmo caminho pelo qual o SwiftUI resolve o `body`, mesma limitação
    // declarada lá em cima (`drawHierarchy` não reproduz blur nem vidro).
    //
    // O jejum tem estados que a tela só mostra com dado semeado: cronômetro
    // correndo, meta atingida, histórico com linhas. Sem semear, três das telas
    // deste módulo sairiam vazias no print e ninguém veria o que foi construído
    // — que é o modo de falha do "Alma · Feed" documentado no detector de tela
    // vazia. Por isso `JejumStore.semearParaCapturas`, que só existe em DEBUG.
    private static func conferenciaDoJejum(
        model: AppModel,
        renderizar: (String, AnyView, ColorScheme) -> Void
    ) {
        log("═════ JEJUM — TELAS × 2 ═════")

        let loja = JejumStore.shared
        let agora = Date()
        let cal = Calendar.current

        // Histórico plausível: quatro dias seguidos, um deles abaixo da meta —
        // porque o histórico precisa mostrar que encerrar antes da meta também
        // é registrado, sem rótulo de fracasso.
        func diaAtras(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: agora) ?? agora }
        let historico: [JejumConcluido] = [
            JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: diaAtras(1),
                           terminouEm: diaAtras(1), duracao: 16 * 3600 + 900),
            JejumConcluido(protocolo: .dezoitoPorSeis, comecouEm: diaAtras(2),
                           terminouEm: diaAtras(2), duracao: 18 * 3600 + 2400),
            JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: diaAtras(3),
                           terminouEm: diaAtras(3), duracao: 13 * 3600),   // abaixo da meta
            JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: diaAtras(4),
                           terminouEm: diaAtras(4), duracao: 16 * 3600 + 120)
        ]

        let emCurso = JejumEmCurso(protocolo: .dezoitoPorSeis,
                                   comecouEm: agora.addingTimeInterval(-14 * 3600 - 1920))
        let naMeta = JejumEmCurso(protocolo: .dezesseisPorOito,
                                  comecouEm: agora.addingTimeInterval(-16 * 3600 - 2700))

        for esquema in [ColorScheme.light, .dark] {

            // 1. Sem jejum: a Dieta com o card parado, e a escolha de protocolo.
            loja.semearParaCapturas(emCurso: nil, historico: [])
            renderizar("J1 Dieta sem jejum", AnyView(DietaView()), esquema)
            renderizar("J2 Escolher protocolo", AnyView(JejumView()), esquema)

            // 2. Jejum correndo.
            loja.semearParaCapturas(emCurso: emCurso, historico: historico)
            renderizar("J3 Dieta com jejum em curso", AnyView(DietaView()), esquema)
            renderizar("J4 Cronometro em curso", AnyView(JejumView()), esquema)

            // 3. Meta atingida — o estado em que a ação principal é QUEBRAR,
            //    e em que não existe botão de estender.
            loja.semearParaCapturas(emCurso: naMeta, historico: historico)
            renderizar("J5 Meta atingida", AnyView(JejumView()), esquema)

            // 4. Conteúdo e histórico.
            renderizar("J6 Saber mais", AnyView(JejumView(abaInicial: .saber)), esquema)
            renderizar("J7 Historico", AnyView(JejumView(abaInicial: .historico)), esquema)

            // 5. A quebra, nos dois regimes: jejum longo (dois pratos) e jejum
            //    curto (um prato só). É a diferença de desenho inteira num par
            //    de imagens.
            //
            //    O primeiro par sai SEM medidas de propósito — é o estado em
            //    que a tela precisa dizer "porção padrão" em vez de fingir
            //    cálculo pessoal, e um print é a única forma de conferir que
            //    ela diz. `semearPerfil` roda depois desta função, no
            //    `HomeView.task`, então aqui o perfil está mesmo vazio.
            renderizar("J8 Quebra 19h sem medidas", AnyView(QuebraDeJejumView(duracao: 19 * 3600)), esquema)
            renderizar("J9 Quebra 12h prato unico", AnyView(QuebraDeJejumView(duracao: 12 * 3600)), esquema)

            // 6. Contraindicações.
            renderizar("J10 Quando nao jejuar", AnyView(AvisoDeSaudeDoJejum()), esquema)

            // 7. A MESMA quebra, agora com medidas — o caminho principal, em
            //    que o orçamento sai da meta da pessoa e a tela diz isso. Sem
            //    este par, a única imagem da quebra seria a do estado
            //    degradado.
            model.weightKg = 78
            model.heightCm = 178
            model.ageYears = 38
            model.sex = .masculino
            model.activityLevel = .moderado
            renderizar("J11 Quebra 19h com meta", AnyView(QuebraDeJejumView(duracao: 19 * 3600)), esquema)

            // 8. E com restrição alimentar declarada — inclusive uma que o
            //    leitor NÃO sabe interpretar, que é o aviso que esta tela é
            //    obrigada a mostrar.
            model.dietaryRestrictions = "sem lactose, alergia a jaracatiá"
            renderizar("J12 Quebra com restricao", AnyView(QuebraDeJejumView(duracao: 19 * 3600)), esquema)

            // Devolve o modelo ao estado em que ele chegou, para a volta do
            // laço (o esquema escuro) começar igual ao claro.
            model.dietaryRestrictions = ""
            model.weightKg = 0
            model.heightCm = 0
            model.ageYears = 0
            model.sex = nil
            model.activityLevel = nil
        }

        // Não deixa o estado semeado para trás: o app segue a sessão com o
        // jejum zerado, como numa instalação limpa.
        loja.semearParaCapturas(emCurso: nil, historico: [])
        log("═════ FIM JEJUM ═════")
    }

    // MARK: - Conferência do scan corporal [2026-08-26]
    //
    // Prova visual dos achados P0-2 e P0-3 da auditoria de 26/08.
    //
    // P0-2: com perfil vazio o scan devolvia "Meta diária 1300 kcal" e
    //       "Proteína 0 g" — o piso de segurança `max(…, 1300)` do
    //       `AIBodyScan:361` virando fabricador de meta. S1 tem de mostrar o
    //       botão INATIVO e o que falta, pelo nome.
    // P0-3: a ressalva era escrita em `plan.notes` e nenhuma view a renderizava.
    //       S3 tem de mostrar as duas frases do rodapé.
    //
    // Estas telas dependem do perfil, então o modelo é mexido de propósito e
    // devolvido ao fim — mesma disciplina do laço do jejum acima.
    private static func conferenciaDoScan(
        model: AppModel,
        renderizar: (String, AnyView, ColorScheme) -> Void
    ) {
        log("═════ SCAN CORPORAL — P0-2 e P0-3 ═════")

        let planoComRessalva = GeneratedPlan(
            dailyKcal: 1904, proteinG: 126, carbsG: 190, fatG: 53,
            meals: [], week: [],
            notes: "As metas de calorias e macros são calculadas no seu aparelho "
                 + "a partir das suas medidas e da estimativa da análise. "
                 + "Ajuste conforme fome e energia, e reavalie a cada 2–4 semanas."
        )
        let resultado = ScanResult(
            analysis: BodyAnalysis(
                somatotype: .mesomorfo,
                estimatedBodyFat: 22,
                summary: "Estimativa a partir das fotos enviadas.",
                observations: ["Postura ereta", "Distribuição equilibrada"],
                focusAreas: ["Força de pernas", "Resistência de core"]
            ),
            plan: planoComRessalva,
            isAIGenerated: true
        )

        for esquema in [ColorScheme.light, .dark] {

            // 1. O estado do achado: perfil vazio. O botão fica inativo e a tela
            //    diz o que falta. Antes de hoje ele liberava e devolvia 1300/0 g.
            model.weightKg = 0
            model.heightCm = 0
            model.ageYears = 0
            renderizar("S1 Scan SEM medidas", AnyView(BodyScanView()), esquema)

            // S4 é A prova do P0-2, e S1 não é.
            //
            // Sem foto, `canAnalyze` já é falso pelo gate de FOTO
            // (`AIService.isRealAI` é true fixo), então S1 sai IDÊNTICO com e
            // sem o `guard model.hasBodyProfile` — na primeira rodada de 26/08
            // os dois PNGs deram o mesmo md5. Cego.
            //
            // Com as duas fotos satisfeitas e o perfil ainda vazio, sobra um
            // único motivo para o botão continuar travado: o perfil. É o estado
            // em que a mutação TEM de ficar vermelha.
            renderizar("S4 Scan com fotos e SEM medidas",
                       AnyView(BodyScanView(fotosSemeadas: true)), esquema)

            // 2. Preencheu: o botão libera. Sem este par, a prova do S1 não
            //    distingue "gate funcionando" de "botão quebrado".
            model.weightKg = 78
            model.heightCm = 178
            model.ageYears = 38
            renderizar("S2 Scan COM medidas", AnyView(BodyScanView()), esquema)

            // 3. O rodapé de honestidade, na tela onde a pessoa vê o % de
            //    gordura e a meta.
            renderizar("S3 Resultado com ressalva", AnyView(ScanResultView(result: resultado)), esquema)

            model.weightKg = 0
            model.heightCm = 0
            model.ageYears = 0
        }

        log("═════ FIM SCAN ═════")
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

            // [2026-08-29] Era `CGRect(0,0,393,852)` fixo — o tamanho lógico do
            // iPhone 15/16 Pro. Consequência: rodar o harness num 17 Pro Max
            // continuava produzindo 1179x2556, e não os 1320x2868 que a App
            // Store exige no slot de 6,9". A captura saía com a dimensão do
            // aparelho ERRADO sem nada avisar, porque nenhum passo comparava o
            // PNG com o simulador em que ele nasceu.
            // Agora segue o aparelho: num iPad dá o quadro do iPad, num Max dá
            // o do Max. Código só de DEBUG (todo o arquivo é `#if DEBUG`).
            let quadro = CGRect(origin: .zero, size: UIScreen.main.bounds.size)  // iPhone 15/16 lógico
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
            // ═══════════════════════════════════════════════════════════════
            // [2026-09-03] O padrão do exercício, em TRÊS estados — e o canário
            // que exige que sejam três imagens diferentes.
            //
            // A primeira versão deste bloco produziu "(vazio)" e "(definido)"
            // BYTE A BYTE IDÊNTICAS, e o mesmo com o detalhe "antes"/"(com
            // padrão)". Causa: `AppModel` grava em `UserDefaults.standard`, que
            // SOBREVIVE entre lançamentos do app. Uma execução anterior já
            // tinha deixado 3×8×60 no disco, então o render rotulado "vazio"
            // fotografou a tela COM padrão. O harness herdou o disco e mentiu
            // no rótulo — a mesma família de defeito do `var falhas` que nunca
            // era preenchido.
            //
            // Duas correções, e nenhuma delas é cosmética:
            //   1. o estado é SEMEADO explicitamente antes de cada captura,
            //      inclusive o estado vazio (remover é semear também);
            //   2. o canário abaixo compara os BYTES. Se duas capturas saírem
            //      iguais, o harness acusa em voz alta em vez de entregar uma
            //      prova que não prova nada.
            //
            // O terceiro estado (5×5×100) é o CONTROLE POSITIVO: prova que o
            // que muda na tela é o dado, e não o acaso de dois renders.
            // ═══════════════════════════════════════════════════════════════

            // Estado 1 — SEM padrão. Remover é semear: não se herda o disco.
            model.definirPadrao(exercicio: ex.name, series: nil, reps: nil, cargaKg: nil)
            render("Corpo · Detalhe do exercício", ExerciseDetailView(exercise: ex))
            let detalheSemPadrao = dadosDaCaptura("Corpo · Detalhe do exercício")
            render("Corpo · Meu padrão (vazio)", EditorDePadraoView(exercicioDoCatalogo: ex))
            let editorVazio = dadosDaCaptura("Corpo · Meu padrão (vazio)")

            // Estado 2 — o padrão do Assis: 3 séries × 8 reps × 60 kg.
            model.definirPadrao(exercicio: ex.name, series: 3, reps: "8", cargaKg: 60)
            render("Corpo · Meu padrão (definido 3x8x60)", EditorDePadraoView(exercicioDoCatalogo: ex))
            let editorDefinido = dadosDaCaptura("Corpo · Meu padrão (definido 3x8x60)")
            render("Corpo · Detalhe do exercício (com padrão)", ExerciseDetailView(exercise: ex))
            let detalheComPadrao = dadosDaCaptura("Corpo · Detalhe do exercício (com padrão)")

            // Estado 3 — CONTROLE POSITIVO, valor visivelmente outro.
            model.definirPadrao(exercicio: ex.name, series: 5, reps: "5", cargaKg: 100)
            render("Corpo · Meu padrão (controle 5x5x100)", EditorDePadraoView(exercicioDoCatalogo: ex))
            let editorControle = dadosDaCaptura("Corpo · Meu padrão (controle 5x5x100)")
            render("Corpo · Detalhe do exercício (controle 5x5x100)", ExerciseDetailView(exercise: ex))
            let detalheControle = dadosDaCaptura("Corpo · Detalhe do exercício (controle 5x5x100)")

            // ── O CANÁRIO ───────────────────────────────────────────────────
            // Cada par tem de DIFERIR. Igualdade aqui significa uma de duas
            // coisas, e as duas são graves: ou a tela não relê o padrão (a
            // funcionalidade não funciona), ou o harness não semeou (a prova
            // não prova). Em qualquer dos casos, a captura não vale nada.
            func exigirDiferentes(_ a: Data?, _ b: Data?, _ oQue: String) {
                guard salvarPNGs else { return }
                guard let a, let b else {
                    falhas.append("padrão: captura ausente — \(oQue)")
                    log("  ✗✗ PADRÃO \(oQue): captura não foi escrita; nada a comparar")
                    return
                }
                if a == b {
                    falhas.append("padrão: capturas IDÊNTICAS — \(oQue)")
                    log("  ✗✗ PADRÃO \(oQue): as duas capturas são BYTE A BYTE IGUAIS."
                        + " Ou a tela não relê o padrão, ou o estado não foi semeado."
                        + " A prova está morta — não use estas imagens.")
                } else {
                    log("  ✓ padrão \(oQue): capturas diferem (\(a.count) vs \(b.count) bytes)")
                }
            }
            exigirDiferentes(editorVazio, editorDefinido, "editor vazio × 3x8x60")
            exigirDiferentes(editorDefinido, editorControle, "editor 3x8x60 × controle 5x5x100")
            exigirDiferentes(detalheSemPadrao, detalheComPadrao, "detalhe sem × com padrão")
            exigirDiferentes(detalheComPadrao, detalheControle, "detalhe 3x8x60 × controle 5x5x100")

            // Não deixa o padrão no disco: a próxima execução tem de começar do
            // mesmo lugar que esta. Foi exatamente isto que faltou da primeira vez.
            model.definirPadrao(exercicio: ex.name, series: nil, reps: nil, cargaKg: nil)
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
        // ── A TELA DO PRINT DO ASSIS (2026-09-03) ──────────────────────────
        //
        // "Plano · Segunda — Peito e tríceps", do objetivo Ganhar massa. É onde
        // "Crucifixo" e "Tríceps corda" apareciam como **Peso corporal** com o
        // boneco genérico, porque `resolveExercise` fabricava o exercício
        // quando o nome não casava. Renderizada aqui para que a correção tenha
        // prova visual, e não só argumento.
        //
        // O caminho é o MESMO do app: serviço → `applyPlan` → `customWorkouts`
        // → `WorkoutDetailView`. Nada de montar o treino à mão, que provaria
        // que eu sei escrever o resultado esperado e nada sobre o app.
        // `executar()` é síncrona (roda no main, antes da UI do app). O
        // `analyze` é `async` só por causa do irmão de rede; o Mock calcula na
        // hora. Semáforo em vez de tornar o harness inteiro async: menos
        // superfície mexida num arquivo que já é o coração da validação.
        var planoCalculado: ScanResult?
        let espera = DispatchSemaphore(value: 0)
        Task.detached {
            planoCalculado = try? await MockAIPlanService().analyze(
                ScanInput(weightKg: 78, heightCm: 178, ageYears: 34, bodyFat: 18,
                          goal: Goal.ganhar.rawValue, frontPhoto: nil, sidePhoto: nil))
            espera.signal()
        }
        _ = espera.wait(timeout: .now() + 10)

        if let planoGanhar = planoCalculado {
            model.applyPlan(planoGanhar)
            if let segunda = model.customWorkouts.first(where: { $0.name.contains("Segunda") }) {
                render("Corpo · Plano da Segunda (Peito e tríceps)",
                       WorkoutDetailView(workout: Workout(
                            name: segunda.name,
                            focus: "Personalizado · \(segunda.exercises.count) exercícios",
                            durationMin: segunda.exercises.count * 8,
                            kcal: segunda.exercises.count * 45,
                            systemImage: "figure.strengthtraining.traditional",
                            tint: Theme.primary,
                            exercises: segunda.exercises)))
                log("  plano/Segunda: \(segunda.exercises.map(\.name).joined(separator: " · "))")
                for e in segunda.exercises {
                    log("    · \(e.name) — \(e.equipment.rawValue) — foto: "
                        + (ExerciseCatalog.resolve(legacy: e).fotoDeCapa ?? "NENHUMA"))
                }
            } else {
                log("  ✗✗ plano aplicado mas sem treino de Segunda")
            }

            // O outro lado da mesma correção: um dia cujo exercício NÃO tem
            // ilustração no RepDB. Antes desenhava o mesmo boneco genérico de
            // "defeito"; agora desenha o corpo anatômico, que é o fallback que
            // o catálogo já usava. O Domingo mistura os dois casos de
            // propósito — "Alongamento" tem foto, "Respiração" não — para a
            // captura provar a diferença dentro de UMA tela.
            if let domingo = model.customWorkouts.first(where: { $0.name.contains("Domingo") }) {
                render("Corpo · Plano do Domingo (sem ilustração)",
                       WorkoutDetailView(workout: Workout(
                            name: domingo.name,
                            focus: "Personalizado · \(domingo.exercises.count) exercícios",
                            durationMin: domingo.exercises.count * 8,
                            kcal: domingo.exercises.count * 45,
                            systemImage: "figure.mind.and.body",
                            tint: Theme.primary,
                            exercises: domingo.exercises)))
                for e in domingo.exercises {
                    log("    · \(e.name) — \(e.equipment.rawValue) — foto: "
                        + (ExerciseCatalog.resolve(legacy: e).fotoDeCapa ?? "NENHUMA"))
                }
            }
        } else {
            log("  ✗✗ MockAIPlanService não devolveu plano")
        }

        if let w = treino {
            render("Corpo · Detalhe do treino", WorkoutDetailView(workout: w))
            render("Corpo · Sessão de treino", WorkoutSessionView(workout: w))
            // [2026-09-02] A sessão de um treino POR TEMPO / PESO CORPORAL
            // (HIIT: burpees, "30 s", sem carga) — o card troca "reps" por
            // "segundos" e recolhe a carga atrás de "+ peso extra".
            if model.workouts.count > 1 {
                render("Corpo · Sessão de treino (por tempo, peso corporal)",
                       WorkoutSessionView(workout: model.workouts[1]))
            }
        } else {
            log("  — Detalhe/sessão de treino: sem treino no catálogo")
        }
        // [2026-09-02] O card de anotar a série nos três estados que a tela
        // pode assumir — com valores preenchidos, que a sessão inteira só
        // mostraria depois de toques que nenhum harness daqui dá. Os três
        // numa tela só: um card sozinho num quadro de iPhone inteiro fica
        // abaixo do limiar do detector de tela vazia (medido: 2,3 < 3,0) e
        // apareceria como falso "SEM CONTEÚDO" em toda rodada.
        render("Corpo · Anotar série (3 estados)", TresCartoesDeSerieParaSmoke())
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
