// AuditoriaBloqueadores.swift
// Alma — verificação automática de cada bloqueador da revisão independente
//
// [2026-08-03] Existe porque "eu corrigi" não é evidência. Cada item aqui é uma
// asserção que roda no app de verdade, com os dados de verdade, e imprime o
// valor observado. Se alguém desfizer uma correção sem querer, este harness
// acusa — em vez de a gente descobrir na próxima auditoria.
//
// Roda com `-auditoria 1`, só em DEBUG.

#if DEBUG
import Foundation
import SwiftUI
import UIKit

@MainActor
enum AuditoriaBloqueadores {

    static var ligado: Bool { UserDefaults.standard.bool(forKey: "auditoria") }

    private static var aprovados = 0
    private static var reprovados: [String] = []

    private static func log(_ t: String) { NSLog("%@", "[AUDIT] " + t) }

    private static func checa(_ id: String, _ desc: String, _ ok: Bool, _ observado: String) {
        if ok {
            aprovados += 1
            log("✓ \(id) \(desc) — \(observado)")
        } else {
            reprovados.append("\(id) \(desc)")
            log("✗ \(id) \(desc) — OBSERVADO: \(observado)")
        }
    }

    /// [2026-08-05 — build 93] Hospeda a view numa UIWindow real e devolve TODO
    /// texto que a tela expõe — rótulo de acessibilidade, texto de UILabel e
    /// título de UIButton. É o que separa "a peça está certa" de "a TELA está
    /// certa". As asserções que faltaram em agosto olhavam só a peça.
    ///
    /// Quem usa isto tem obrigação de acompanhar com uma guarda anti-cegueira
    /// (ver A26d): um coletor que não enxerga nada faz toda asserção de
    /// AUSÊNCIA passar para sempre, que é a pior espécie de teste verde.
    private static func textosDaTela(_ view: AnyView) -> [String] {
        let quadro = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: view)
        host.view.frame = quadro

        let janela = UIWindow(frame: quadro)
        janela.rootViewController = host
        janela.isHidden = false
        janela.layoutIfNeeded()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // A barra de navegação e os itens de toolbar só materializam depois de
        // uma volta do run loop.
        RunLoop.current.run(until: Date().addingTimeInterval(0.60))

        // [2026-08-05] A PRIMEIRA versão disto varria só `subviews` procurando
        // UILabel/UIButton e voltou com "início=0 textos" — A26d acusou na
        // primeira execução, antes de qualquer mutação. O motivo: SwiftUI NÃO
        // constrói UILabel. Ele desenha o texto direto e expõe o conteúdo pela
        // ÁRVORE DE ACESSIBILIDADE. Varrer subviews numa tela SwiftUI é
        // exatamente o instrumento cego que A26d existe para denunciar — e a
        // guarda funcionou contra a própria autora.
        var achados: [String] = []
        var vistos = Set<ObjectIdentifier>()

        func varrer(_ no: Any, _ nivel: Int) {
            guard nivel < 14 else { return }
            guard let obj = no as? NSObject else { return }
            if vistos.contains(ObjectIdentifier(obj)) { return }
            vistos.insert(ObjectIdentifier(obj))

            if let r = obj.accessibilityLabel, !r.isEmpty { achados.append(r) }
            if let v = obj.accessibilityValue, !v.isEmpty { achados.append(v) }
            if let t = (obj as? UILabel)?.text, !t.isEmpty { achados.append(t) }
            if let b = obj as? UIButton, let t = b.title(for: .normal), !t.isEmpty { achados.append(t) }

            // Container de acessibilidade: é por aqui que o texto do SwiftUI sai.
            if let filhos = obj.accessibilityElements {
                filhos.forEach { varrer($0, nivel + 1) }
            } else {
                let n = obj.accessibilityElementCount()
                if n > 0 && n != NSNotFound {
                    for i in 0..<n {
                        if let f = obj.accessibilityElement(at: i) { varrer(f, nivel + 1) }
                    }
                }
            }
            if let v = obj as? UIView { v.subviews.forEach { varrer($0, nivel + 1) } }
        }
        varrer(host.view, 0)

        janela.isHidden = true
        janela.rootViewController = nil
        return achados
    }

    static func executar() {
        guard ligado else { return }
        aprovados = 0
        reprovados = []

        log("═════ AUDITORIA DOS BLOQUEADORES ═════")

        // Domínio isolado: não encosta nos dados reais de ninguém.
        let suite = "auditoria.alma"
        UserDefaults().removePersistentDomain(forName: suite)
        let store = UserDefaults(suiteName: suite)!

        // ── B1 · número do build ────────────────────────────────────────────
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let versao = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        checa("B1", "build != 88 (88 já está no TestFlight)",
              build != "88" && !build.isEmpty,
              "\(versao) (\(build))")

        // ── B2 · humor: palavras do check-in, não emojis ────────────────────
        let seteTristes = Array(repeating: "Triste", count: 7)
        let sinalTriste = CorpoContextFormat.classificarHumor(rotulos: seteTristes)
        checa("B2a", "7× 'Triste' NÃO vira 'semana estável'",
              sinalTriste == "semana emocionalmente pesada",
              sinalTriste ?? "nil")

        let sinalEmoji = CorpoContextFormat.classificarHumor(rotulos: ["😢", "😔", "😰"])
        checa("B2b", "emoji legado não vira afirmação silenciosa",
              sinalEmoji == nil, sinalEmoji ?? "nil")

        // A tela e o classificador têm de ler a MESMA fonte.
        let rotulosDaTela = Mood.allCases.map(\.rawValue)
        checa("B2c", "todo humor da tela é reconhecido pelo classificador",
              rotulosDaTela.allSatisfy { Mood(rawValue: $0) != nil },
              rotulosDaTela.joined(separator: ", "))

        // ── B3 · produtores em produção ─────────────────────────────────────
        do {
            let m = AppModel(store: store)
            m.weightKg = 80
            m.heightCm = 178
            m.ageYears = 38
            m.meals.append(Meal(type: .cafe, name: "Auditoria", kcal: 400,
                                protein: 25, carbs: 30, fat: 12, done: true))
            // [2026-08-04] Era `m.workoutDays.insert(...)` — a própria asserção
            // fabricava o dado que dizia estar verificando. Agora chama o
            // método que o botão "Treino concluído" chama.
            m.registrarTreinoConcluido()
            m.dietaryRestrictions = "alergia a amendoim"
            m.healthConditions = "hérnia de disco"
            m.addWater(750)
        }
        let m2 = AppModel(store: store)   // app "reaberto"

        checa("B3a", "workoutDays gravou e sobreviveu ao fechamento",
              m2.workoutDays.contains(CorpoInsightsEngine.chaveDia(Date())),
              "\(m2.workoutDays.count) dia(s)")
        checa("B3b", "weightLog foi PRODUZIDO ao alterar o peso",
              !m2.weightLog.isEmpty,
              "\(m2.weightLog.count) ponto(s)")
        checa("B3c", "kcalByDay foi PRODUZIDO ao marcar refeição",
              m2.kcalByDay[CorpoInsightsEngine.chaveDia(Date())] == 400,
              "\(m2.kcalByDay)")
        checa("B3d", "dietaryRestrictions persistiu",
              m2.dietaryRestrictions == "alergia a amendoim",
              "'\(m2.dietaryRestrictions)'")
        checa("B3e", "healthConditions persistiu",
              m2.healthConditions == "hérnia de disco",
              "'\(m2.healthConditions)'")

        // ── B4 · água zera no dia novo e não ressuscita ─────────────────────
        store.set(Calendar.current.date(byAdding: .day, value: -1, to: Date()), forKey: "lastWaterDate")
        let diaNovo = AppModel(store: store)
        let segunda = AppModel(store: store)
        checa("B4a", "água zera no dia novo", diaNovo.waterMl == 0, "\(diaNovo.waterMl) ml")
        checa("B4b", "água NÃO ressuscita na 2ª instância do mesmo dia",
              segunda.waterMl == 0, "\(segunda.waterMl) ml")

        // [2026-08-04 — REAUDITORIA] B4a/B4b só testavam o ZERO do rollover.
        // A revisora esvaziou o `didSet` de `waterMl` — a água deixou de
        // chegar ao disco — e as duas continuaram verdes, porque zero é o que
        // elas esperam. Faltava o caso oposto: o registro do dia sobrevive?
        let suiteAgua = "auditoria.agua"
        UserDefaults().removePersistentDomain(forName: suiteAgua)
        let storeAgua = UserDefaults(suiteName: suiteAgua)!
        do {
            let m = AppModel(store: storeAgua)
            m.addWater(750)
        }
        let aguaReaberta = AppModel(store: storeAgua)
        checa("B4c", "água registrada hoje SOBREVIVE ao fechamento do app",
              aguaReaberta.waterMl == 750, "\(aguaReaberta.waterMl) ml")
        UserDefaults().removePersistentDomain(forName: suiteAgua)

        // ── B5 · IMC nunca é NaN nem "Obesidade" sem medidas ────────────────
        let vazio = AppModel(store: UserDefaults(suiteName: "auditoria.vazio")!)
        UserDefaults().removePersistentDomain(forName: "auditoria.vazio")
        checa("B5a", "sem medidas, imcSeguro é nil (não NaN)",
              vazio.imcSeguro == nil, "\(String(describing: vazio.imcSeguro))")
        checa("B5b", "sem medidas, classificação NÃO é 'Obesidade'",
              vazio.imcClassificacao != "Obesidade",
              "'\(vazio.imcClassificacao)'")
        checa("B5c", "com medidas reais o IMC volta a funcionar",
              m2.imcSeguro != nil && (m2.imcSeguro ?? 0) > 20 && (m2.imcSeguro ?? 0) < 30,
              String(format: "%.1f", m2.imcSeguro ?? 0))

        // ── B8 · não vender IA que não existe ───────────────────────────────
        checa("B8a", "scan de alimento só aparece se a IA existir no build",
              CorpoAcesso.scanDeAlimentoDisponivel == AIService.isRealAI,
              "IA disponível: \(AIService.isRealAI)")

        // ── B9 · exclusão apaga tudo ────────────────────────────────────────
        // Sujeira nas duas pontas que o serviço não olhava antes.
        UserDefaults.standard.set("Fulano", forKey: "userName")
        UserDefaults.standard.set(88.8, forKey: "weightKg")
        UserDefaults.standard.set("alergia a frutos do mar", forKey: "dietaryRestrictions")
        let grupo = UserDefaults(suiteName: "group.com.almaapp.shared")
        grupo?.set("Fulano", forKey: "perfil_nome")

        // [2026-08-04 — REAUDITORIA] Era `LocalDataCleanupService.clearAll()`
        // direto. A revisora comentou a chamada DENTRO do
        // AccountDeletionService e as quatro B9 continuaram verdes. Agora a
        // entrada é a mesma que a exclusão de conta usa: apagar a chamada lá
        // dentro deixa estas asserções vermelhas.
        AccountDeletionService.executarLimpezaLocal()
        AccountDeletionService.finalizarLimpezaLocal()

        checa("B9a", "exclusão apaga nome do Corpo (sem prefixo alma_)",
              UserDefaults.standard.string(forKey: "userName") == nil,
              String(describing: UserDefaults.standard.string(forKey: "userName")))
        checa("B9b", "exclusão apaga peso",
              UserDefaults.standard.object(forKey: "weightKg") == nil,
              String(describing: UserDefaults.standard.object(forKey: "weightKg")))
        checa("B9c", "exclusão apaga ALERGIAS",
              UserDefaults.standard.string(forKey: "dietaryRestrictions") == nil,
              String(describing: UserDefaults.standard.string(forKey: "dietaryRestrictions")))
        checa("B9d", "exclusão apaga o perfil do App Group",
              grupo?.string(forKey: "perfil_nome") == nil,
              String(describing: grupo?.string(forKey: "perfil_nome")))

        // ── B10 · produtos do Alma, nunca os do app descontinuado ───────────
        checa("B10a", "StoreManager do Corpo usa o produto mensal do Alma",
              StoreManager.monthlyID == StoreKitManager.monthlyID,
              StoreManager.monthlyID)
        checa("B10b", "nenhum ID do app descontinuado",
              !StoreManager.monthlyID.contains("corpoealma")
                && !StoreManager.annualID.contains("corpoealma"),
              "\(StoreManager.monthlyID) / \(StoreManager.annualID)")

        // ── B11 · freemium: registro livre ──────────────────────────────────
        checa("B11a", "registro manual liberado (régua)",
              CorpoAcesso.registroManualLiberado, "true")
        let semPremium = AppModel(store: UserDefaults(suiteName: "auditoria.free")!)
        UserDefaults().removePersistentDomain(forName: "auditoria.free")
        let aguaAntes = semPremium.waterMl
        semPremium.addWater(250)
        checa("B11b", "usuário SEM premium consegue registrar água",
              semPremium.waterMl == aguaAntes + 250 && !semPremium.hasPremiumAccess,
              "premium=\(semPremium.hasPremiumAccess), água \(aguaAntes)→\(semPremium.waterMl) ml")

        // ── notificações ────────────────────────────────────────────────────
        //
        // [2026-08-04 — REAUDITORIA] N1 e N2 foram REMOVIDAS, não corrigidas.
        //
        // N1 era `X || true` — uma tautologia, aprovado grátis no placar. Eu
        // escrevi o `|| true` como conveniência ("a chave existe no modelo") e
        // com isso inflei o número que eu mesma reportava como evidência.
        //
        // N2 calculava `totalMax` dentro do próprio teste, a partir de duas
        // constantes, e comparava com uma terceira constante. Se o agendador
        // disparar 50 lembretes por dia, N2 continua verde: ela testa
        // aritmética, não o app.
        //
        // A regra nova: uma assertion só entra no placar se ficar VERMELHA
        // quando a linha de produção que ela protege é apagada. Nenhuma das
        // duas passava nesse teste, e nenhuma delas protege um bloqueador.
        // Voltam se e quando houver um agendador real para exercitar.
        // [2026-08-26] Eram 3 donos, agora são 4 — o jejum ganhou o dele. A
        // asserção NÃO foi afrouxada: o número continua fixo (dono novo sem
        // passar por aqui fica vermelho) e a checagem de sobreposição de
        // prefixo, que é o que ela existe para proteger, passou a valer para
        // TODOS os pares em vez de só alma×corpo. Antes, um prefixo repetido
        // entre `corpo` e `vicio` passaria despercebido.
        let paresDeDonos = DonoDoLembrete.allCases.enumerated().flatMap { i, a in
            DonoDoLembrete.allCases.dropFirst(i + 1).map { (a, $0) }
        }
        let prefixosSobrepostos = paresDeDonos.filter { a, b in
            a.prefixos.contains(where: { b.prefixos.contains($0) })
        }
        checa("N3", "cada dono limpa só o que é seu",
              DonoDoLembrete.allCases.count == 4 && prefixosSobrepostos.isEmpty,
              "donos: \(DonoDoLembrete.allCases.map(\.rawValue).joined(separator: ", "))"
                + (prefixosSobrepostos.isEmpty ? "" : " · SOBREPOSTOS: \(prefixosSobrepostos.map { "\($0.0.rawValue)×\($0.1.rawValue)" })"))

        // ── A16 · truncamento por linha, priorizando alergia ────────────────
        let longas = [
            "Movimento: " + String(repeating: "x", count: 200),
            "Sono: " + String(repeating: "y", count: 200),
            "Água: " + String(repeating: "z", count: 200),
            "Perfil: objetivo emagrecer · restrições alimentares: alergia a amendoim"
        ]
        let cortado = HealthContextBuilder.montarComTeto(header: "[teste]", linhas: longas)
        checa("A16a", "sob pressão, a linha de ALERGIA sobrevive",
              cortado.contains("alergia a amendoim"),
              "\(cortado.count) chars")
        checa("A16b", "o corte respeita o teto",
              cortado.count <= HealthContextBuilder.maxCharacters,
              "\(cortado.count) de \(HealthContextBuilder.maxCharacters)")
        checa("A16c", "campo de texto livre é limitado na origem",
              (CorpoContextFormat.perfil(objetivo: "Manter",
                                         restricoes: String(repeating: "a", count: 400),
                                         condicoes: "")?.count ?? 999) < 200,
              "\(CorpoContextFormat.perfil(objetivo: "Manter", restricoes: String(repeating: "a", count: 400), condicoes: "")?.count ?? 0) chars")

        // ── A12 · PT-BR no texto que o usuário REALMENTE recebe ─────────────
        //
        // [2026-08-03] Este teste foi reescrito depois de duas correções minhas:
        //
        // 1. O ALVO estava errado. Eu auditava `GuidedMeditationEngine`, que é o
        //    script de FALLBACK do TTS — caminho morto, porque os 30 .m4a estão
        //    no bundle e `start()` retorna antes de olhar os segments. O que o
        //    usuário ouve é o áudio em PT-BR, gravado com a voz do Felipe.
        //    O que importa auditar é o texto que aparece na TELA.
        //
        // 2. O DETECTOR tinha falso positivo. Usava `contains("tua ")`, que casa
        //    dentro de "flu-TUA Neste espaço". Sem `\b`, meia dúzia de palavras
        //    comuns viram "português europeu".
        func temPTPT(_ texto: String) -> Bool {
            let inequivocos = ["ecrã", "contacto", "acção", "acções", "estás",
                               "telemóvel", "tens", "podes", "queres", "sabes"]
            return inequivocos.contains { termo in
                texto.range(of: "\\b\(termo)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            }
        }

        // ── B8b · nenhuma tela promete IA que a build não tem ───────────────
        //
        // [2026-08-04] O B8 foi dado como fechado em 03/08 e REABRIU: a
        // varredura visual achou QUATRO telas vendendo IA — o banner da Saúde,
        // o topo do scan corporal (que ainda se contradizia com o proprio
        // rodape) e o scan de comida, este sem ressalva nenhuma. A asserção
        // de 03/08 (`B8a`) só checava se o scan de alimento APARECIA; nunca
        // olhou o que os textos prometiam. Agora olha.
        let textosDeIA: [(String, String)] = [
            ("Saúde · banner", SaudeView.tituloDoScan),
            ("Scan corporal · título", BodyScanView.tituloDaTela),
            ("Scan corporal · privacidade", BodyScanView.notaDePrivacidade),
            ("Scan de comida · título", FoodScanView.tituloDaTela),
            ("Scan de comida · chamada", FoodScanView.chamadaDaTela)
        ]
        // [2026-08-04] A primeira versão desta asserção usava
        // `localizedCaseInsensitiveContains("IA")` e reprovou o texto CORRIGIDO:
        // "nenhuma foto é enviada" contém "ia" dentro de "envIAda". É o MESMO
        // erro de substring que eu tinha acabado de criticar no detector de
        // PT-PT ("tua" dentro de "fluTUA") — cometido na asserção escrita para
        // impedir esse tipo de descuido. Fica registrado.
        // Agora "IA" só conta como palavra inteira, maiúscula.
        func prometeIA(_ texto: String) -> Bool {
            texto.range(of: "(?<![\\p{L}])IA(?![\\p{L}])",
                        options: [.regularExpression]) != nil
        }
        let prometemIA = textosDeIA.filter { prometeIA($0.1) }

        // [2026-08-04 — REAUDITORIA] As duas começavam com `AIService.isRealAI
        // || …`: no dia em que a IA ligasse, viravam `true` incondicional —
        // exatamente o dia em que mais precisariam checar. Agora a regra é
        // BICONDICIONAL: prometer IA é permitido se, e somente se, a IA existe.
        // Assim a assertion serve nos dois estados do mundo.
        checa("B8b", "prometer IA se e somente se a IA existe",
              prometemIA.isEmpty != AIService.isRealAI,
              "IA disponível: \(AIService.isRealAI) · \(textosDeIA.count) textos · prometem IA: "
              + (prometemIA.isEmpty ? "nenhum" : prometemIA.map(\.0).joined(separator: ", ")))

        // Idem: a nota de privacidade tem de descrever o que ACONTECE nos dois
        // casos — "nenhuma foto" sem IA, "suas fotos" com IA.
        let notaDizNenhumaFoto = BodyScanView.notaDePrivacidade
            .localizedCaseInsensitiveContains("nenhuma foto")
        checa("B8c", "a nota de privacidade descreve o uso real de foto",
              notaDizNenhumaFoto != AIService.isRealAI,
              String(BodyScanView.notaDePrivacidade.prefix(60)) + "…")

        // [2026-08-04 — B-2] O sexto texto, o que a reauditoria achou: o
        // subtítulo do banner que leva ao paywall. Antes B8b auditava cinco
        // textos e a lista parava uma tela antes do botão.
        checa("B8d", "o banner do Premium no Corpo não vende IA inexistente",
              CorpoHomeView.subtituloDoBannerPremium
                .range(of: "(?<![\\p{L}])IA(?![\\p{L}])", options: [.regularExpression]) == nil
                || AIService.isRealAI,
              CorpoHomeView.subtituloDoBannerPremium)

        // ── CARD · "Complete seu perfil" ────────────────────────────────────
        //
        // [2026-08-04] Bug relatado pelo Assis: preencheu o perfil e o card
        // continuou lá. Estas asserções reproduzem o MECANISMO — duas
        // instâncias de AppModel, uma na Home e outra na tela de edição — e
        // provam que a completude agora é lida do disco, não de uma cópia.
        let suiteCard = "auditoria.card.alma"
        UserDefaults().removePersistentDomain(forName: suiteCard)
        let storeCard = UserDefaults(suiteName: suiteCard)!

        // A instância que a Home guardava (criada ANTES de a pessoa preencher).
        let modelDaHome = AppModel(store: storeCard)

        var faltando = UserProfileStore.shared.pendencias(
            medidas: .persistidas(store: storeCard))
        checa("C1a", "perfil vazio: o card cobra as medidas",
              faltando.contains(.medidas),
              faltando.map(\.rawValue).joined(separator: ", "))

        // A tela de edição tem o SEU PRÓPRIO model — é exatamente isto que
        // acontece em OnboardingBiometricsView (@StateObject próprio).
        let modelDaTela = AppModel(store: storeCard)
        modelDaTela.weightKg = 82
        modelDaTela.heightCm = 180

        // [2026-08-04 — REAUDITORIA] C1b foi REMOVIDA. Ela aprovava quando
        // `modelDaHome.weightKg == 0`, ou seja, EXIGIA que a cópia da Home
        // continuasse desatualizada. Se alguém melhorasse o AppModel para
        // observar o disco, C1b ficaria vermelha: era um teste que punia a
        // melhoria e travava uma regressão como se fosse requisito.
        //
        // O que importa provar é o comportamento do CARD (C1c), não o defeito
        // da instância. A linha abaixo fica só como observação no log.
        log("· contexto C1: peso na cópia velha da Home: \(modelDaHome.weightKg) · no disco: \(storeCard.double(forKey: "weightKg"))")

        // E o card, que agora lê o disco, para de cobrar NA HORA.
        faltando = UserProfileStore.shared.pendencias(
            medidas: .persistidas(store: storeCard))
        checa("C1c", "preencheu medidas → o card para de cobrar sem reabrir o app",
              !faltando.contains(.medidas),
              faltando.isEmpty ? "nenhuma pendência"
                               : "ainda falta: \(faltando.map(\.rawValue).joined(separator: ", "))")

        // App reaberto: model novo lendo do zero, mesmo resultado.
        let modelReaberto = AppModel(store: storeCard)
        checa("C1d", "app reaberto: as medidas sobreviveram",
              modelReaberto.weightKg == 82 && modelReaberto.heightCm == 180,
              "\(modelReaberto.weightKg) kg · \(modelReaberto.heightCm) cm")

        // O texto do card NOMEIA o que falta, em vez de "faltam 2 informações".
        let textoMedidas = PendenciaPerfil.textoDoQueFalta([.medidas])
        checa("C2a", "o card DIZ qual campo falta",
              textoMedidas.contains("peso e altura"),
              textoMedidas)

        let textoDois = PendenciaPerfil.textoDoQueFalta([.nascimento, .medidas])
        checa("C2b", "com dois campos, nomeia os dois",
              textoDois.contains("sua data de nascimento") && textoDois.contains("peso e altura"),
              textoDois)

        checa("C2c", "perfil completo → texto vazio (card não aparece)",
              PendenciaPerfil.textoDoQueFalta([]).isEmpty,
              "\"\(PendenciaPerfil.textoDoQueFalta([]))\"")

        // Só peso, sem altura: continua incompleto — e diz o que falta.
        storeCard.removeObject(forKey: "heightCm")
        let sóPeso = UserProfileStore.shared.pendencias(medidas: .persistidas(store: storeCard))
        checa("C3", "peso sem altura NÃO conta como medidas completas",
              sóPeso.contains(.medidas),
              PendenciaPerfil.textoDoQueFalta(sóPeso))

        UserDefaults().removePersistentDomain(forName: suiteCard)

        let textoDeTela = GuidanceEngine.todosOsTextos
        let telaPTPT = textoDeTela.filter(temPTPT)
        checa("A12", "nenhum texto EXIBIDO em PT-PT (Home e Insights)",
              telaPTPT.isEmpty,
              telaPTPT.isEmpty ? "\(textoDeTela.count) textos verificados"
                               : "\(telaPTPT.count): \(telaPTPT.prefix(2))")

        // ── A15 · nenhuma alegação de saúde no texto EXIBIDO ────────────────
        //
        // [2026-08-04] A régua do Assis: o app registra e mostra os dados da
        // pessoa; não promete resultado clínico. Este checador existe porque a
        // varredura manual de hoje achou "cura", "remédio", "terapêuticos" e
        // "função pulmonar aumenta até 30%" espalhados pela UI — e a manual só
        // acontece quando alguém lembra. Este roda em toda auditoria.
        //
        // Escopo honesto: cobre os textos que `GuidanceEngine.todosOsTextos`
        // expõe (Home e Insights, ~232 strings) e a lista fixa abaixo, que traz
        // as telas onde a varredura achou problema. NÃO varre o app inteiro —
        // dizer que varre seria a mentira que este projeto já cansou de pegar.
        func temAlegacaoDeSaude(_ texto: String) -> Bool {
            // Palavras que, no texto de UI, afirmam efeito clínico.
            // "cuidado", "bem-estar" e "descanso" ficam de fora de propósito:
            // descrevem intenção, não resultado.
            let proibidas = ["cura", "curar", "curação", "curativa", "remédio",
                             "terapêutico", "terapêutica", "terapêuticos",
                             "diagnóstico", "tratamento", "emagrece",
                             "comprovado", "cientificamente", "clinicamente"]
            return proibidas.contains { termo in
                texto.range(of: "\\b\(termo)\\b",
                            options: [.regularExpression, .caseInsensitive]) != nil
            }
        }

        // Os textos gerados (Home/Insights).
        let gerados = GuidanceEngine.todosOsTextos.filter(temAlegacaoDeSaude)
        checa("A15a", "nenhum texto gerado (Home/Insights) alega efeito clínico",
              gerados.isEmpty,
              gerados.isEmpty ? "\(GuidanceEngine.todosOsTextos.count) textos verificados"
                              : "\(gerados.count): \(gerados.prefix(2))")

        // As telas corrigidas hoje. Se alguém reverter uma delas, cai aqui.
        // A frase é copiada da tela; se a tela mudar e esta lista não, o teste
        // deixa de proteger — por isso cada item cita arquivo:linha.
        let copiaDeTelas = [
            // [2026-08-06] Era "Acompanhe sono, passos, peso e alimentação".
            // Saiu do paywall por prometer como pago o que é grátis — ver o
            // comentário em SubscriptionView. As linhas novas entram aqui
            // porque esta lista é o que impede a copy de voltar a mentir.
            "Converse com a Alma",                                     // SubscriptionView
            "Escaneie comida e corpo por foto",                        // SubscriptionView
            "Monte seus treinos e veja o mapa muscular",               // SubscriptionView
            "Meditações do dia 4 ao 30 e os sons para dormir",         // SubscriptionView
            "Insights e diário emocional completo",                    // SubscriptionView
            "Um dia de cada vez",                                      // TreinoView:26
            "Uma pausa de respiração e aterramento para quando a ansiedade aperta", // MoodRouter:281
            "As meditações guiadas e os sons são criados para apoiar momentos de pausa e descanso.", // ProfileView:507
            "Marcos da sua jornada",                                   // AddictionFreeView:217
        ]
        let telasSujas = copiaDeTelas.filter(temAlegacaoDeSaude)
        checa("A15b", "a copy corrigida hoje continua sem alegação clínica",
              telasSujas.isEmpty,
              telasSujas.isEmpty ? "\(copiaDeTelas.count) frases verificadas"
                                 : "\(telasSujas.count): \(telasSujas.prefix(2))")

        // Canário: o detector TEM de acusar uma frase sabidamente proibida.
        // Sem isto, A15a e A15b poderiam estar verdes por o detector estar cego.
        let canarioCopy = "Esta meditação é terapêutica e promove a cura."
        checa("A15c", "canário — o detector de alegação acusa uma frase proibida",
              temAlegacaoDeSaude(canarioCopy),
              temAlegacaoDeSaude(canarioCopy) ? "acusou" : "DETECTOR CEGO")

        // ── A17 · a copy do chat não promete volume que o build não entrega ─
        //
        // [2026-08-04] O paywall vendia "Conversas ilimitadas com a Alma" com
        // `chatMessagesPerDay = 0` para grátis e 20/h para assinante em
        // produção. Era falso nas duas pontas. Enquanto o entitlement não
        // estiver implantado E provado, nenhuma tela pode falar de volume.
        func prometeVolume(_ t: String) -> Bool {
            ["ilimitad", "sem limite", "quantas quiser", "à vontade", "infinit"]
                .contains { t.range(of: $0, options: .caseInsensitive) != nil }
        }

        let copyDoChat = [
            "Converse com a Alma",  // SubscriptionView (linha do featureRow do chat)
            "Converse com a sua mentora de bem-estar, com memória da sua jornada e acolhimento sempre que precisar.", // ChatView
            "Recurso Premium · Toque para conhecer",  // HomeView (sem cota grátis)
        ]
        let prometem = copyDoChat.filter(prometeVolume)
        checa("A17a", "nenhuma copy do chat promete volume ilimitado",
              prometem.isEmpty,
              prometem.isEmpty
                ? "\(copyDoChat.count) frases · cota grátis = \(FreemiumLimits.chatMessagesPerDay)/dia"
                : "\(prometem.count): \(prometem.prefix(1))")

        // Canário: sem ele, A16a poderia estar verde por o detector estar cego.
        checa("A17b", "canário — o detector acusa promessa de volume",
              prometeVolume("Conversas ilimitadas com a Alma"),
              prometeVolume("Conversas ilimitadas com a Alma") ? "acusou" : "DETECTOR CEGO")

        // ── A27 · recurso pago sempre RESPONDE ao toque ──────────────────────
        //
        // [2026-08-06] Em `TreinoView`, "montar treino" e o mapa muscular eram
        // `if model.hasPremiumAccess { ... }` SEM `else`. Para quem não assina,
        // o botão engolia o toque: nada abria, nada era oferecido. O gate
        // funcionava e o convite não existia — a pior combinação, porque a
        // pessoa disposta a pagar batia numa porta que não se anunciava porta.
        //
        // A correção não foi só acrescentar o `else`: a decisão virou
        // `CorpoAcesso.acaoAoTocarRecursoPago`, um enum de duas opções e
        // nenhuma delas "nada". Esta asserção vigia a regra; o tipo vigia o
        // esquecimento, transformando-o em erro de compilação.
        // [2026-08-06] Renomeados de `semPremium`/`comPremium` para
        // `acaoSemPremium`/`acaoComPremium`: `semPremium` já era o AppModel da
        // B11b, na linha 252, no MESMO escopo desta função. Duas declarações
        // com o mesmo nome no mesmo escopo é `Invalid redeclaration` — o alvo
        // Debug inteiro parou de compilar quando este bloco entrou.
        // [2026-08-06] Ids renomeados de A27a/b/c para P1a/b/c (P de pago).
        // A27a/A27b/A27c JÁ EXISTIAM desde 05/08, nas linhas ~1196-1208, e são
        // do HealthKit. Ids repetidos tornam o log ambíguo — quando um reprova,
        // não dá para saber qual dos dois foi. É a mesma razão pela qual o
        // bloco de honestidade virou `H` e não `C`, escrita neste arquivo umas
        // 800 linhas abaixo. Agrava que o cabeçalho do bloco de HealthKit
        // declara `A27g` como VERMELHA de propósito: o log do A27 é exatamente
        // o que alguém lê com atenção.
        let acaoSemPremium = CorpoAcesso.acaoAoTocarRecursoPago(temPremium: false)
        let acaoComPremium = CorpoAcesso.acaoAoTocarRecursoPago(temPremium: true)
        checa("P1a", "sem assinatura, tocar recurso pago OFERECE o Premium",
              acaoSemPremium == .oferecerPremium, "\(acaoSemPremium)")
        checa("P1b", "com assinatura, tocar recurso pago ABRE o recurso",
              acaoComPremium == .abrir, "\(acaoComPremium)")

        // Canário: se as duas respostas fossem iguais, P1a/P1b poderiam estar
        // verdes com a função devolvendo sempre a mesma coisa.
        checa("P1c", "canário — a decisão realmente depende da assinatura",
              acaoSemPremium != acaoComPremium,
              acaoSemPremium != acaoComPremium ? "distingue" : "DETECTOR CEGO: mesma resposta para os dois")

        // ── A20 · ditado: duas rodadas de fala com pausa no meio ────────────
        //
        // [2026-08-04] ESTE é o caminho onde o bug vive e que nenhum teste meu
        // cobria: a pessoa fala, PARA alguns segundos, e fala de novo — SEM
        // tocar no botão. A sequência abaixo é exatamente o que o
        // SFSpeechRecognizer entrega nesse cenário (cresce dentro do enunciado,
        // recomeça do zero no enunciado seguinte), e foi reproduzida a partir
        // dos cinco prints do build 90.
        var acc = AcumuladorDeDitado()
        var saida = ""
        // 1ª rodada
        saida = acc.receber("Vou")
        saida = acc.receber("Vou falar")
        // ── pausa ── o reconhecedor recomeça, trazendo SÓ a fala nova
        saida = acc.receber("Mas")
        saida = acc.receber("Mas não sei")
        saida = acc.receber("Mas não sei se vai ficar salvo aqui")
        checa("A20a", "duas rodadas com pausa: a primeira fala NÃO se perde",
              saida == "Vou falar Mas não sei se vai ficar salvo aqui",
              "\"\(saida)\"")

        // Três rodadas, como nos prints dele.
        var acc3 = AcumuladorDeDitado()
        _ = acc3.receber("Vou falar")
        _ = acc3.receber("Mas não sei se vai ficar salvo aqui")
        let tres = acc3.receber("Se ficou algum segundo sem falar")
        checa("A20b", "três rodadas mantêm tudo, na ordem",
              tres == "Vou falar Mas não sei se vai ficar salvo aqui Se ficou algum segundo sem falar",
              "\"\(tres)\"")

        // Revisão do próprio enunciado NÃO pode virar duplicata.
        var accRev = AcumuladorDeDitado()
        _ = accRev.receber("Vou fala")
        let revisado = accRev.receber("Vou falar")   // o motor corrigiu o final
        checa("A20c", "revisão do enunciado não duplica texto",
              revisado == "Vou falar", "\"\(revisado)\"")

        // O que já estava digitado no campo é preservado.
        var accSem = AcumuladorDeDitado()
        accSem.semear(textoExistente: "Oi Alma")
        let comSemente = accSem.receber("tudo bem")
        checa("A20d", "texto já digitado sobrevive ao ligar o microfone",
              comSemente == "Oi Alma tudo bem", "\"\(comSemente)\"")

        // A regra de fronteira, isolada.
        checa("A20e", "crescer é continuar; recomeçar não é",
              AcumuladorDeDitado.continua(novo: "Vou falar", anterior: "Vou")
                && !AcumuladorDeDitado.continua(novo: "Mas", anterior: "Vou falar"),
              "crescer=true recomeçar=false")

        // ── A19 · UMA verdade sobre o peso ──────────────────────────────────
        // [2026-08-04] O Assis digitou 83,0 e a aba Saúde mostrou 82,7 (Apple
        // Saúde). Precedência decidida: o digitado SEMPRE vence.
        let comAmbos = PesoVigente.decidir(digitado: 83.0, appleSaude: 82.7)
        checa("A19a", "com os dois, vence o que a pessoa digitou",
              comAmbos.kg == 83.0 && comAmbos.origem == .digitado,
              "\(comAmbos.kg) · \(comAmbos.origem.rotulo)")

        let sóHealth = PesoVigente.decidir(digitado: 0, appleSaude: 82.7)
        checa("A19b", "sem nada digitado, o Apple Saúde preenche",
              sóHealth.kg == 82.7 && sóHealth.origem == .appleSaude,
              "\(sóHealth.kg) · \(sóHealth.origem.rotulo)")

        let semPesoNenhum = PesoVigente.decidir(digitado: 0, appleSaude: nil)
        checa("A19c", "sem peso nenhum não inventa número",
              semPesoNenhum.kg == 0 && semPesoNenhum.origem == OrigemDoPeso.ausente,
              "\(semPesoNenhum.kg) · \(semPesoNenhum.origem.rotulo)")

        // O IMC tem de sair do MESMO peso — eram dois IMCs para a mesma pessoa.
        let imcDecidido = PesoVigente.imc(pesoKg: comAmbos.kg, alturaCm: 183)
        checa("A19d", "o IMC usa o peso digitado, não o do Apple Saúde",
              imcDecidido.map { abs($0 - 24.78) < 0.05 } ?? false,
              imcDecidido.map { String(format: "%.2f", $0) } ?? "nil")

        checa("A19e", "sem altura o IMC é nil, nunca NaN",
              PesoVigente.imc(pesoKg: 83, alturaCm: 0) == nil, "nil")

        // Persistência: o peso digitado sobrevive ao fechamento do app.
        let suitePeso = "auditoria.peso"
        UserDefaults().removePersistentDomain(forName: suitePeso)
        let storePeso = UserDefaults(suiteName: suitePeso)!
        let mPeso1 = AppModel(store: storePeso)
        mPeso1.weightKg = 83.0
        let mPeso2 = AppModel(store: storePeso)   // "reabre o app"
        let reaberto = PesoVigente.decidir(digitado: mPeso2.weightKg, appleSaude: 82.7)
        checa("A19f", "peso digitado sobrevive ao reabrir e continua vencendo",
              reaberto.kg == 83.0 && reaberto.origem == OrigemDoPeso.digitado,
              "\(reaberto.kg) · \(reaberto.origem.rotulo)")
        UserDefaults().removePersistentDomain(forName: suitePeso)

        // ── A18 · pontuação de sono ─────────────────────────────────────────
        // [2026-08-04] Regra pura, exercitada com noites fabricadas. O valor de
        // cada asserção é impresso para o Assis conferir a conta na mão.
        let perfeita = NoiteDeSono(totalDormido: 8, rem: 8 * 0.22, profundo: 8 * 0.18,
                                   acordado: 8 * 0.03, despertares: 1)
        let rPerfeita = PontuacaoDeSono.calcular(perfeita)
        checa("A18a", "noite de referência dá 100", rPerfeita.pontos == 100,
              "\(rPerfeita.pontos.map(String.init) ?? "nil") · \(rPerfeita.descricao)")

        let curta = NoiteDeSono(totalDormido: 6, rem: 6 * 0.15, profundo: 6 * 0.10,
                                acordado: 6 * 0.08, despertares: 4)
        let rCurta = PontuacaoDeSono.calcular(curta)
        checa("A18b", "noite curta e fragmentada pontua abaixo da referência",
              (rCurta.pontos ?? 100) < 80,
              "\(rCurta.pontos.map(String.init) ?? "nil") · \(rCurta.descricao)")

        // A REGRA DE HONESTIDADE: sem estágios, NÃO existe pontuação.
        let semEstagios = NoiteDeSono(totalDormido: 7.5, rem: nil, profundo: nil,
                                      acordado: nil, despertares: nil)
        let rSem = PontuacaoDeSono.calcular(semEstagios)
        checa("A18c", "sem estágios NÃO inventa pontuação",
              rSem.pontos == nil && rSem.precisaDeEstagios,
              "pontos=\(rSem.pontos.map(String.init) ?? "nil") · \(rSem.descricao)")

        let semSono = PontuacaoDeSono.calcular(
            NoiteDeSono(totalDormido: 0, rem: nil, profundo: nil, acordado: nil, despertares: nil))
        checa("A18d", "noite sem registro não pontua nem pede estágios",
              semSono.pontos == nil && !semSono.precisaDeEstagios, semSono.descricao)

        // A descrição é descritiva, nunca diagnóstica.
        let julgamentos = ["ruim", "péssim", "insuficiente", "inadequad", "problema", "distúrbio"]
        let textos = [rPerfeita.descricao, rCurta.descricao, rSem.descricao, semSono.descricao,
                      PontuacaoDeSono.explicacao, PontuacaoDeSono.rodape]
        let julga = textos.filter { t in julgamentos.contains { t.lowercased().contains($0) } }
        checa("A18e", "nenhuma frase da pontuação julga o sono da pessoa",
              julga.isEmpty, julga.isEmpty ? "\(textos.count) frases" : "\(julga)")

        // [2026-08-07] Esta checagem exigia a frase "Não vem do Apple Saúde" —
        // e a frase era FALSA. Os dados de sono vêm do Apple Saúde; o que é do
        // Alma é a pontuação. O checador estava travando a redação errada no
        // lugar, que é o pior tipo de teste: um que defende o defeito.
        //
        // Agora ele exige as três coisas que precisam estar ditas:
        //   1. que o DADO vem do Apple Saúde;
        //   2. que a PONTUAÇÃO é cálculo do Alma;
        //   3. que nada disso é avaliação clínica (regra 3.1).
        let rodape = PontuacaoDeSono.rodape
        checa("A18f", "o rodapé separa o DADO (Apple Saúde) da PONTUAÇÃO (Alma)",
              rodape.contains("vêm do Apple Saúde")
                && rodape.contains("cálculo")
                && rodape.contains("do Alma")
                && rodape.contains("não é avaliação clínica"),
              rodape)

        // E o inverso: a frase antiga não pode voltar por descuido.
        checa("A18f2", "o rodapé NÃO nega mais a origem do dado",
              !rodape.contains("Não vem do Apple Saúde"),
              rodape)

        // ── A18 (montagem) · da amostra do aparelho para a noite ────────────
        // [2026-08-04] A UI entrou nesta rodada, e com ela a tradução das
        // amostras. Estas asserções exercitam a função PURA `NoiteDeSono.montar`
        // com noites fabricadas — nenhuma encosta em dado de saúde real.
        let base = Date(timeIntervalSince1970: 1_770_000_000)
        func amostra(_ e: AmostraDeSono.Estagio, _ deHoras: Double, _ ateHoras: Double) -> AmostraDeSono {
            AmostraDeSono(estagio: e,
                          inicio: base.addingTimeInterval(deHoras * 3600),
                          fim: base.addingTimeInterval(ateHoras * 3600))
        }

        // Noite classificada pelo relógio: 8 h no total, 1 despertar.
        let comEstagios = NoiteDeSono.montar([
            amostra(.leve, 0, 4.8),      // 4,8 h
            amostra(.profundo, 4.8, 6.24), // 1,44 h = 18%
            amostra(.rem, 6.24, 8.0),      // 1,76 h = 22%
            amostra(.acordado, 8.0, 8.24)  // 0,24 h = 3%
        ])
        checa("A18g", "amostras com estágio viram noite pontuável",
              comEstagios?.temEstagios == true && comEstagios?.despertares == 1,
              "total=\(comEstagios?.totalDormido ?? -1) despertares=\(comEstagios?.despertares ?? -1)")

        // O aparelho registrou sono mas NÃO classificou: não pode virar score.
        let soIndeterminado = NoiteDeSono.montar([amostra(.indeterminado, 0, 7.5)])
        checa("A18h", "sono sem classificação de estágio não vira pontuação",
              soIndeterminado?.temEstagios == false
                && PontuacaoDeSono.calcular(soIndeterminado!).pontos == nil,
              "total=\(soIndeterminado?.totalDormido ?? -1) rem=\(String(describing: soIndeterminado?.rem))")

        // "Na cama" (caso Garmin) dá duração, jamais pontuação.
        let soNaCama = NoiteDeSono.montar([amostra(.naCama, 0, 7.0)])
        checa("A18i", "'na cama' vira duração e nunca pontuação",
              soNaCama?.totalDormido == 7.0 && soNaCama?.temEstagios == false
                && PontuacaoDeSono.calcular(soNaCama!).pontos == nil,
              "total=\(soNaCama?.totalDormido ?? -1)")

        // [2026-08-04 — furo achado pela própria mutação] A18i sozinha era CEGA
        // para o somatório: fiz `dormido` incluir `naCama` e ela continuou
        // verde, porque a noite caía no ramo "sem classificação" e produzia o
        // mesmo resultado. O caso que separa os dois é a noite MISTA — relógio
        // classificando 6 h enquanto o iPhone registra 8 h "na cama" na mesma
        // madrugada. Aí "na cama" inflar o total muda o número que a pessoa vê.
        let mista = NoiteDeSono.montar([
            amostra(.leve, 0, 3.6),
            amostra(.profundo, 3.6, 4.68),
            amostra(.rem, 4.68, 6.0),
            amostra(.naCama, -0.5, 8.0)     // 8,5 h na cama, 6 h dormidas
        ])
        checa("A18m", "'na cama' NÃO infla o total quando há estágios",
              mista?.totalDormido == 6.0,
              "total=\(mista?.totalDormido ?? -1) (esperado 6.0)")

        // Sem amostra nenhuma não existe noite — e a tela não pode inventar uma.
        checa("A18j", "sem amostras não existe noite",
              NoiteDeSono.montar([]) == nil,
              NoiteDeSono.montar([]) == nil ? "nil" : "objeto fabricado")

        // A linha que a IA recebe: existe com estágios, some sem eles.
        let linhaIA = PontuacaoDeSono.linhaParaIA(PontuacaoDeSono.calcular(comEstagios!))
        checa("A18k", "a linha da IA descreve, se declara estimativa e não recomenda",
              linhaIA?.contains("estimativa do Alma") == true
                && linhaIA?.contains("não é medida clínica") == true
                && linhaIA?.lowercased().contains("tente") == false
                && linhaIA?.lowercased().contains("procure") == false,
              linhaIA ?? "nil")

        checa("A18l", "sem estágios a IA não recebe pontuação nenhuma",
              PontuacaoDeSono.linhaParaIA(PontuacaoDeSono.calcular(soNaCama!)) == nil,
              "nil esperado")

        // ── A23 · nenhum preço sai da cabeça de ninguém ─────────────────────
        // [2026-08-04] O paywall do Corpo tinha "R$ 199,90/ano" e "R$ 24,99/mês"
        // escritos no código, como fallback de quando o StoreKit não responde.
        // Nenhum dos dois existe no App Store Connect. Estas asserções foram
        // validadas por MUTAÇÃO: reintroduzi o `var price` chumbado e as vi
        // ficarem vermelhas (evidência em _validacao_20260804/).

        // A20a exercita a REGRA de quais planos entram na tela. É a única que
        // pode ser exercitada sem App Store: `Product` não é construível fora
        // do StoreKit, então a função recebe os opcionais e decide.
        let semNenhum = CorpoPaywallView.planosVendaveis(anual: nil, mensal: nil)
        checa("A23a", "sem produto carregado, NENHUM plano é oferecido",
              semNenhum.isEmpty, "\(semNenhum.map(\.rawValue))")

        // A20b: o enum não pode ter voltado a carregar preço. `Plan` só conhece
        // título, sufixo de período e destaque — valor, nunca.
        let sufixos = CorpoPaywallView.Plan.allCases.map(\.sufixo)
        let titulos = CorpoPaywallView.Plan.allCases.map(\.title)
        let comMoeda = (sufixos + titulos).filter {
            $0.contains("R$") || $0.contains("$") || $0.rangeOfCharacter(from: .decimalDigits) != nil
        }
        checa("A23b", "o enum de planos não carrega valor em dinheiro",
              comMoeda.isEmpty, comMoeda.isEmpty ? "\(titulos) \(sufixos)" : "\(comMoeda)")

        // A20c: o texto de indisponibilidade não pode conter número nenhum —
        // era exatamente aí que o preço inventado morava.
        let textosDeFalta = [CorpoPaywallView.precoIndisponivel,
                             CorpoPaywallView.precoIndisponivelDetalhe]
        let comNumero = textosDeFalta.filter { $0.rangeOfCharacter(from: .decimalDigits) != nil }
        checa("A23c", "sem produto, a tela não exibe número algum",
              comNumero.isEmpty, comNumero.isEmpty ? "2 textos limpos" : "\(comNumero)")

        // ── A21 · assinante não recebe oferta de compra ─────────────────────
        // [2026-08-04] O Assis é Premium e as duas telas de gestão do plano
        // abriam o paywall de venda. Validadas por mutação (invertendo a
        // condição da porta).
        checa("A21a", "só a origem App Store oferece gestão nativa da Apple",
              OrigemDoAcesso.appStore.temAssinaturaNaApple
                && !OrigemDoAcesso.legado.temAssinaturaNaApple
                && !OrigemDoAcesso.web.temAssinaturaNaApple
                && !OrigemDoAcesso.nenhuma.temAssinaturaNaApple,
              "appStore=\(OrigemDoAcesso.appStore.temAssinaturaNaApple) "
              + "legado=\(OrigemDoAcesso.legado.temAssinaturaNaApple)")

        // O acesso herdado NÃO pode ser descrito como assinatura a gerenciar:
        // mandar essa pessoa para a folha da Apple é um beco sem saída.
        checa("A21b", "o acesso herdado se declara sem cobrança e sem renovação",
              OrigemDoAcesso.legado.explicacao.contains("Não há cobrança nem renovação"),
              OrigemDoAcesso.legado.explicacao)

        // Nenhum rótulo de origem pode prometer valor, período ou trial.
        let textosDeOrigem = OrigemDoAcesso.allCasesDoAlma.flatMap { [$0.rotulo, $0.explicacao] }
        let origemQuePromete = textosDeOrigem.filter {
            $0.contains("R$") || $0.lowercased().contains("grátis")
                || $0.lowercased().contains("teste") || $0.lowercased().contains("dias")
        }
        checa("A21c", "nenhum texto da gestão do plano promete preço, prazo ou teste",
              origemQuePromete.isEmpty,
              origemQuePromete.isEmpty ? "\(textosDeOrigem.count) textos" : "\(origemQuePromete)")

        // ── A22 · o trial não existe em lugar nenhum ────────────────────────
        // [2026-08-04] "7 dias grátis" sobreviveu a três limpezas porque vivia
        // em comentário e em texto guardado por um flag mal entendido
        // (`isEligibleForIntroOffer` diz que a PESSOA é elegível, não que a
        // OFERTA existe). Esta asserção varre os textos de assinatura exibíveis.
        let textosDeAssinatura = [
            CorpoPaywallView.precoIndisponivel,
            CorpoPaywallView.precoIndisponivelDetalhe,
            "Renovação automática. Você pode cancelar a qualquer momento em Ajustes > Apple ID > Assinaturas."
        ] + textosDeOrigem
        let comTrial = textosDeAssinatura.filter {
            let t = $0.lowercased()
            return t.contains("7 dias") || t.contains("sete dias") || t.contains("teste gratuito")
                || t.contains("período gratuito") || t.contains("trial")
        }
        checa("A22a", "nenhuma promessa de teste grátis nos textos de assinatura",
              comTrial.isEmpty, comTrial.isEmpty ? "\(textosDeAssinatura.count) textos" : "\(comTrial)")

        // ── A13 · migração do histórico de menstruação ──────────────────────
        // [2026-08-04] Verifica a REGRA, com entradas fabricadas, sem encostar
        // no Keychain: é dado de saúde real de uma pessoa. Ver o comentário de
        // `decidirHistórico` para por que ela é separada do armazenamento.
        let semNada = FeminineHealthSecureStore.decidirHistórico(bruto: nil, legado: 0)
        checa("A13a", "sem gravado e sem legado, histórico vazio e não grava",
              semNada.lista.isEmpty && !semNada.precisaGravar,
              "\(semNada.lista) gravar=\(semNada.precisaGravar)")

        let sóLegado = FeminineHealthSecureStore.decidirHistórico(bruto: nil, legado: 1_700_000_000)
        checa("A13b", "legado sozinho vira o 1º item E pede gravação",
              sóLegado.lista == [1_700_000_000] && sóLegado.precisaGravar,
              "\(sóLegado.lista) gravar=\(sóLegado.precisaGravar)")

        let jáGravado = FeminineHealthSecureStore.decidirHistórico(bruto: "[111.0,222.0]",
                                                                  legado: 1_700_000_000)
        checa("A13c", "histórico gravado tem precedência sobre o legado e não regrava",
              jáGravado.lista == [111, 222] && !jáGravado.precisaGravar,
              "\(jáGravado.lista) gravar=\(jáGravado.precisaGravar)")

        let corrompido = FeminineHealthSecureStore.decidirHistórico(bruto: "{lixo",
                                                                   legado: 1_700_000_000)
        checa("A13d", "JSON corrompido cai na migração em vez de perder o legado",
              corrompido.lista == [1_700_000_000] && corrompido.precisaGravar,
              "\(corrompido.lista) gravar=\(corrompido.precisaGravar)")

        // ── A14 · tela presa depois de compartilhar ─────────────────────────
        // [2026-08-04] O `UIActivityViewController` se fecha sozinho pelo lado
        // do UIKit. Se ele não avisar o SwiftUI, o `.sheet` fica preso em `true`
        // e o botão Fechar da tela de cima para de funcionar. Estas asserções
        // exercitam o controller DE VERDADE — não uma imitação dele.
        var folhaAberta = true
        let ponte = Binding<Bool>(get: { folhaAberta }, set: { folhaAberta = $0 })
        let controller = ShareSheet(items: [UIImage()], isPresented: ponte).fazerController()

        checa("A14a", "o UIActivityViewController recebe um completionWithItemsHandler",
              controller.completionWithItemsHandler != nil,
              controller.completionWithItemsHandler == nil ? "nil" : "instalado")

        // Simula o fim do compartilhamento, como o UIKit faria.
        controller.completionWithItemsHandler?(nil, true, nil, nil)
        checa("A14b", "terminado o compartilhamento, o estado do sheet volta a false",
              folhaAberta == false,
              "isPresented=\(folhaAberta)")

        // Cancelar também precisa devolver o estado — senão a tela trava igual.
        var folhaCancelada = true
        let ponteCancel = Binding<Bool>(get: { folhaCancelada }, set: { folhaCancelada = $0 })
        let controllerCancel = ShareSheet(items: [UIImage()], isPresented: ponteCancel).fazerController()
        controllerCancel.completionWithItemsHandler?(nil, false, nil, nil)
        checa("A14c", "cancelar o compartilhamento também devolve o estado",
              folhaCancelada == false,
              "isPresented=\(folhaCancelada)")

        // ── A24 · aparência: o interruptor tem de estar ligado em alguma coisa ──
        //
        // Contexto: no build 91 o modo escuro "passou" em 10 capturas do
        // simulador e não funcionou no aparelho do Assis. As capturas usavam
        // `SmokeTestTelas.conferenciaDeAparencia`, que impõe
        // `.environment(\.colorScheme,)` direto na view — provando que os cards
        // sabem escurecer, nunca que o BOTÃO muda alguma coisa. O botão da lua
        // escrevia `appearanceMode`; quem aplicava lia `isDarkMode`. Duas
        // chaves, nenhuma conversa.
        //
        // A24b é a asserção que teria pego aquilo: ela executa a MESMA função
        // que o botão executa e exige que o valor aplicado mude.

        // A24a · o mapa puro modo → o que vai para .preferredColorScheme
        checa("A24a", "escuro=.dark, claro=.light, sistema=nil",
              ModoDeAparencia.escuro.colorScheme == .dark
                && ModoDeAparencia.claro.colorScheme == .light
                && ModoDeAparencia.sistema.colorScheme == nil,
              "escuro=\(String(describing: ModoDeAparencia.escuro.colorScheme)) "
                + "claro=\(String(describing: ModoDeAparencia.claro.colorScheme)) "
                + "sistema=\(String(describing: ModoDeAparencia.sistema.colorScheme))")

        // A24b · A ASSERÇÃO DO BUG DO 91.
        // Chama exatamente o que o botão da lua chama e exige que o esquema
        // aplicado vire. Se alguém reapontar o botão para outro armazenamento,
        // ou fizer `alternar` mexer em algo que ninguém aplica, isto fica
        // vermelho — que foi precisamente o que faltou em agosto.
        let suiteAp = "auditoria.alma.aparencia"
        UserDefaults().removePersistentDomain(forName: suiteAp)
        let storeAp = UserDefaults(suiteName: suiteAp)!
        let aparencia = AparenciaDoApp(defaults: storeAp)
        aparencia.modo = .claro
        let antes = aparencia.colorScheme
        aparencia.alternar(sistemaEstaEscuro: false)
        let depois = aparencia.colorScheme
        checa("A24b", "tocar na lua muda o esquema que o app aplica",
              antes == .light && depois == .dark && antes != depois,
              "antes=\(String(describing: antes)) depois=\(String(describing: depois))")

        // A24c · ida e volta completas — e o meio do caminho tem de ser OUTRA coisa.
        //
        // [2026-08-05] A primeira versão desta asserção olhava só o estado
        // final (`colorScheme == .light`) e passou VERDE com um bug dentro: sob
        // a mutação que fazia `.escuro` mapear para `.light`, ida e volta
        // terminavam as duas no claro, e ela não via diferença nenhuma. Existia,
        // rodava e não protegia nada — exatamente o furo que o A18i teve em
        // 04/08. Agora ela exige que o meio seja DISTINTO das duas pontas, que
        // é o que "alternar" significa.
        let meio = depois
        aparencia.alternar(sistemaEstaEscuro: false)
        let fim = aparencia.colorScheme
        checa("A24c", "ida e volta claro→escuro→claro, com o meio distinto das pontas",
              antes == .light && meio == .dark && fim == .light
                && meio != antes && meio != fim
                && aparencia.modo == .claro,
              "antes=\(String(describing: antes)) meio=\(String(describing: meio)) "
                + "fim=\(String(describing: fim)) modo=\(aparencia.modo.rawValue)")

        // A24d · o que ficou no disco é o que está na tela.
        // Mutação alvo: apagar o `defaults.set` do didSet — a tela mudaria e a
        // escolha se perderia ao reabrir o app, que é um bug invisível em teste
        // de sessão única.
        aparencia.modo = .escuro
        checa("A24d", "a escolha persiste na chave única",
              storeAp.string(forKey: AparenciaDoApp.chave) == "escuro",
              "aparenciaModo=\(storeAp.string(forKey: AparenciaDoApp.chave) ?? "nil")")

        // A24e · saindo do modo Sistema, a lua vai para o OPOSTO do que se vê
        checa("A24e", "de sistema no escuro, alternar leva ao claro",
              AparenciaDoApp.proximoModo(de: .sistema, sistemaEstaEscuro: true) == .claro
                && AparenciaDoApp.proximoModo(de: .sistema, sistemaEstaEscuro: false) == .escuro,
              "escuro→\(AparenciaDoApp.proximoModo(de: .sistema, sistemaEstaEscuro: true)) "
                + "claro→\(AparenciaDoApp.proximoModo(de: .sistema, sistemaEstaEscuro: false))")

        // A24f · migração: quem PEDIU escuro pela lua e nunca recebeu, recebe agora
        checa("A24f", "appearanceMode=dark vira escuro mesmo com isDarkMode=false",
              AparenciaDoApp.modoMigrado(aparenciaModo: nil,
                                         isDarkMode: false,
                                         appearanceMode: "dark") == .escuro,
              "\(AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: false, appearanceMode: "dark"))")

        // A24g · migração: instalação intocada continua clara.
        // "system" é o VALOR PADRÃO do appearanceMode — tratá-lo como escolha
        // faria o app abrir escuro para quem nunca pediu nada.
        checa("A24g", "sem escolha nenhuma, o app abre claro como sempre abriu",
              AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: false, appearanceMode: nil) == .claro
                && AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: false, appearanceMode: "system") == .claro,
              "nil→\(AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: false, appearanceMode: nil)) "
                + "system→\(AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: false, appearanceMode: "system"))")

        // A24h · migração: quem já estava no escuro não é jogado para o claro
        checa("A24h", "isDarkMode=true continua escuro",
              AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: true, appearanceMode: nil) == .escuro,
              "\(AparenciaDoApp.modoMigrado(aparenciaModo: nil, isDarkMode: true, appearanceMode: nil))")

        // A24i · a chave nova manda em cima de qualquer legado
        checa("A24i", "aparenciaModo salvo vence as chaves antigas",
              AparenciaDoApp.modoMigrado(aparenciaModo: "sistema",
                                         isDarkMode: true,
                                         appearanceMode: "dark") == .sistema,
              "\(AparenciaDoApp.modoMigrado(aparenciaModo: "sistema", isDarkMode: true, appearanceMode: "dark"))")

        // A24j · os dois caminhos de exclusão de conta têm de terminar igual.
        // O caminho normal apaga o domínio inteiro (leva a aparência junto); o
        // fallback enumera chaves. Se a chave nova não estiver na lista do
        // fallback, a mesma ação deixa o app em dois estados diferentes.
        checa("A24j", "a deleção total cobre a chave nova da aparência",
              LocalDataCleanupService.chavesDeUINaDelecaoTotal.contains(AparenciaDoApp.chave),
              LocalDataCleanupService.chavesDeUINaDelecaoTotal.joined(separator: ", "))

        // ── A25 · scan por IA: a chave fora do app, consentimento por envio ──
        //
        // A IA do scan ligou em 05/08. O risco que estas asserções vigiam não é
        // "a IA funciona" — é o app voltar a mentir sobre o que faz com a foto.

        // A25a · o endpoint é o NOSSO servidor, por HTTPS.
        // Se alguém reapontar para o provedor direto, isto acusa.
        let url = AnaliseDeFotoService.endpoint
        checa("A25a", "a análise passa pela nossa Cloud Function, por HTTPS",
              url.scheme == "https"
                && url.host?.contains("southamerica-east1-alma-app-7dae6") == true
                && url.lastPathComponent == "analisarFoto",
              url.absoluteString)

        // A25b · NENHUMA chave de IA no bundle.
        // Foi exatamente assim que a versão antiga vazava cota: key no plist,
        // qualquer um descompacta o IPA. O gate do doc dizia "não religar como
        // está" — esta asserção é esse gate virando teste.
        var chavesNoBundle: [String] = []
        if let p = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let d = NSDictionary(contentsOfFile: p) {
            for k in d.allKeys.compactMap({ $0 as? String })
            where k.uppercased().contains("GEMINI") || k.uppercased().contains("OPENAI") {
                chavesNoBundle.append(k)
            }
        }
        checa("A25b", "não há chave de IA embarcada no bundle",
              chavesNoBundle.isEmpty,
              chavesNoBundle.isEmpty ? "nenhuma" : chavesNoBundle.joined(separator: ", "))

        // A25c · SEM CONSENTIMENTO NÃO SAI FOTO — exercitando o caminho real.
        //
        // Não basta assertar um ajudante puro: isso provaria que a função existe,
        // não que o serviço a usa. Aqui o `NuvemAIPlanService` é chamado de
        // verdade, com consentimento falso, e tem de LANÇAR antes de tocar na
        // rede. (Com `consentimento: false` ele sai na primeira linha, então não
        // há trabalho de main actor e o semáforo não trava.)
        let entradaFalsa = ScanInput(weightKg: 70, heightCm: 175, ageYears: 30,
                                     bodyFat: 20, goal: "Manter",
                                     frontPhoto: Data([0xFF, 0xD8, 0xFF]),
                                     sidePhoto: Data([0xFF, 0xD8, 0xFF]))
        var observadoConsentimento = "não respondeu em 5 s"
        var recusouSemConsentimento = false
        let sem = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                _ = try await NuvemAIPlanService(consentimento: false).analyze(entradaFalsa)
                observadoConsentimento = "DEVOLVEU RESULTADO sem consentimento"
            } catch let e as ErroDaAnalise {
                recusouSemConsentimento = (e == .semConsentimento)
                observadoConsentimento = "lançou \(e)"
            } catch {
                observadoConsentimento = "lançou outro erro: \(error)"
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 5)
        checa("A25c", "sem consentimento o envio é recusado antes da rede",
              recusouSemConsentimento, observadoConsentimento)

        // A25d · a copy diz a verdade sobre a retenção.
        // Duas armadilhas ao mesmo tempo: prometer o que não cumprimos
        // ("nada é guardado" — a OpenAI retém até 30 dias) e esconder o envio
        // ("apenas localmente" — a foto vai para a nuvem).
        let nota = BodyScanView.notaDePrivacidade.lowercased()
        let notaComida = FoodScanView.chamadaDaTela.lowercased()
        let prometeDemais = ["nada é guardado", "apagadas logo", "apenas localmente",
                             "não são compartilhadas", "só no seu aparelho"]
            .filter { nota.contains($0) || notaComida.contains($0) }
        checa("A25d", "a nota de privacidade não promete o que não cumprimos",
              prometeDemais.isEmpty && nota.contains("30 dias"),
              prometeDemais.isEmpty ? "sem promessa excessiva; cita 30 dias: \(nota.contains("30 dias"))"
                                    : "PROMETE: \(prometeDemais.joined(separator: ", "))")

        // A25e · o pedido de consentimento existe, é explícito e oferece a saída
        // sem foto. Sem a alternativa, "consentir" vira o único caminho.
        let pedido = BodyScanView.pedidoDeConsentimento.lowercased()
        checa("A25e", "o pedido de consentimento explica e oferece a via sem foto",
              pedido.contains("enviar") && pedido.contains("30 dias")
                && (pedido.contains("sem enviar foto") || pedido.contains("só com as suas medidas")
                    || pedido.contains("suas medidas")),
              BodyScanView.pedidoDeConsentimento.prefix(90) + "…")

        // A25f · resultado de IA e estimativa local continuam distinguíveis.
        // Foi a confusão dos dois que gerou o B8 original.
        let localSemFoto = AIService.semFoto()
        checa("A25f", "a fábrica separa o caminho com foto do caminho sem foto",
              localSemFoto is MockAIPlanService
                && AIService.make(consentimento: true) is NuvemAIPlanService,
              "semFoto=\(type(of: localSemFoto)) comFoto=\(type(of: AIService.make(consentimento: true)))")

        // ══════════════════════════════════════════════════════════════════
        // A26 e A27 · [2026-08-05 — build 93] AS DUAS FALHAS DE HOJE SÃO A
        // MESMA FALHA
        //
        // A24b jurava que o botão da lua funcionava: ela chamava `alternar` e
        // exigia que o esquema virasse. Virava mesmo — no MODELO. Na tela do
        // aparelho o botão não fazia nada. O HealthKit repetiu o padrão: nada
        // no harness olhava se a abertura fria buscava dado, então "toda
        // abertura começa desconectada" passou meses invisível.
        //
        // Em ambos os casos a asserção provava A PEÇA e ninguém provava O ELO
        // entre a tela e a regra. As de baixo olham a tela renderizada de
        // verdade — e A26d existe para provar que o coletor não está cego,
        // porque uma asserção que não enxerga nada fica verde para sempre.
        //
        // ⚠️ ESTADO CONHECIDO NO BUILD 93: A26d e A27g estão VERMELHAS de
        // propósito, e o vermelho é honesto. `textosDaTela` volta com 0 textos
        // porque o SwiftUI não constrói UILabel e só monta a árvore de
        // acessibilidade quando há tecnologia assistiva ativa — fora de um
        // XCUITest, o coletor não enxerga. A26d apanhou isso na PRIMEIRA
        // execução, antes de qualquer mutação, que é exatamente o serviço dela.
        //
        // Não foram apagadas de propósito: A26a e A26b passam VERDES hoje sem
        // provar nada, e apagar A26d devolveria o app ao estado de agosto —
        // verde bonito, cego por dentro. O vermelho é o lembrete de que o elo
        // ainda não está coberto. Decisão de como cobrir (alvo de UI test ou
        // checagem de fonte em build phase) está com o Assis.
        // ══════════════════════════════════════════════════════════════════

        let modelC = AppModel(store: store)
        let healthC = HealthManager(defaults: store)
        let storeC = StoreManager()
        let accessC = AccessManager()
        let storeAlmaC = StoreKitManager()
        let hkC = HealthKitManager()

        func comAmbiente<V: View>(_ v: V) -> AnyView {
            AnyView(v
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .environmentObject(modelC)
                .environmentObject(healthC)
                .environmentObject(storeC)
                .environmentObject(accessC)
                .environmentObject(storeAlmaC)
                .environmentObject(hkC))
        }

        // ── A26 · o módulo Corpo não tem mais interruptor de aparência ──────
        let modoAntes = AparenciaDoApp.shared.modo
        let textosInicio = textosDaTela(comAmbiente(CorpoHomeView()))
        let textosAjustes = textosDaTela(comAmbiente(SettingsView()))

        // A26d vem primeiro de propósito: sem ela, A26a e A26b não valem nada.
        // Mutação alvo: um coletor que devolve lista vazia — o modo exato de
        // "asserção verde que não prova coisa nenhuma" que produziu as 10
        // capturas certas sobre a coisa errada em 04/08.
        checa("A26d", "o coletor ENXERGA as telas do Corpo (guarda anti-cegueira)",
              textosInicio.contains(where: { $0.contains("Apple Watch") })
                && textosAjustes.contains(where: { $0.contains("Assinatura") || $0.contains("Saúde e dispositivos") }),
              "início=\(textosInicio.count) textos, ajustes=\(textosAjustes.count) textos")

        checa("A26a", "a Início do Corpo não expõe mais interruptor de aparência",
              !textosInicio.contains(where: { $0.localizedCaseInsensitiveContains("claro/escuro") }),
              textosInicio.filter { $0.localizedCaseInsensitiveContains("claro") }.joined(separator: " | "))

        checa("A26b", "os Ajustes do Corpo não expõem mais Aparência/Tema",
              !textosAjustes.contains(where: {
                  $0.localizedCaseInsensitiveContains("aparência") || $0 == "Tema"
              }),
              textosAjustes.filter { $0.localizedCaseInsensitiveContains("apar") || $0 == "Tema" }.joined(separator: " | "))

        checa("A26c", "abrir as telas do Corpo não mexe na aparência do app",
              AparenciaDoApp.shared.modo == modoAntes,
              "antes=\(modoAntes.rawValue) depois=\(AparenciaDoApp.shared.modo.rawValue)")

        // ── A27 · HealthKit: a autorização sobrevive a fechar o app ─────────
        let suiteHK = "auditoria.alma.saude"
        UserDefaults().removePersistentDomain(forName: suiteHK)
        let hkStore = UserDefaults(suiteName: suiteHK)!

        let frio = HealthManager(defaults: hkStore)
        checa("A27a", "instalação nova nasce não autorizada e não busca nada",
              frio.isAuthorized == false && frio.buscasDisparadas == 0,
              "autorizado=\(frio.isAuthorized) buscas=\(frio.buscasDisparadas)")

        hkStore.set(true, forKey: HealthManager.chaveAutorizado)
        let quente = HealthManager(defaults: hkStore)
        checa("A27b", "com a marca no disco, a abertura fria JÁ nasce autorizada",
              quente.isAuthorized,
              "autorizado=\(quente.isAuthorized)")

        // A ASSERÇÃO DO BUG. Mutação alvo: apagar o `if isAuthorized { refresh() }`
        // do init — era exatamente esse o estado do build 92, e nada acusava.
        checa("A27c", "e JÁ dispara a busca na partida, sem esperar toque em Conectar",
              quente.buscasDisparadas == 1,
              "buscas=\(quente.buscasDisparadas)")

        UserDefaults().removePersistentDomain(forName: suiteHK)
        let recemAutorizado = HealthManager(defaults: hkStore)
        recemAutorizado.marcarAutorizado()
        checa("A27d", "autorizar deixa marca no disco para a próxima abertura",
              hkStore.bool(forKey: HealthManager.chaveAutorizado) && recemAutorizado.isAuthorized,
              "marca=\(hkStore.bool(forKey: HealthManager.chaveAutorizado)) autorizado=\(recemAutorizado.isAuthorized)")

        let proximaAbertura = HealthManager(defaults: hkStore)
        checa("A27e", "ciclo completo: autorizar → fechar → reabrir continua conectado e buscando",
              proximaAbertura.isAuthorized && proximaAbertura.buscasDisparadas == 1,
              "autorizado=\(proximaAbertura.isAuthorized) buscas=\(proximaAbertura.buscasDisparadas)")

        // A27f · a regra de produto, no mapa puro — vale em qualquer aparelho,
        // com ou sem HealthKit. Consulta vazia NÃO é desconexão.
        checa("A27f", "só 'nunca autorizado' pode dizer Desconectado",
              HealthManager.rotulo(para: .naoConectado) == "Desconectado"
                && HealthManager.rotulo(para: .conectadoSemDados) != "Desconectado"
                && HealthManager.rotulo(para: .conectadoComDados) != "Desconectado"
                && HealthManager.rotulo(para: .indisponivel) != "Desconectado"
                && HealthManager.rotulo(para: .conectadoSemDados).localizedCaseInsensitiveContains("sem dados"),
              "semDados=\"\(HealthManager.rotulo(para: .conectadoSemDados))\" "
                + "naoConectado=\"\(HealthManager.rotulo(para: .naoConectado))\"")

        // A27g · O ELO. A tela tem de FALAR pelo rótulo do manager, não por um
        // literal próprio. Mutação alvo: devolver "Desconectado" literal no
        // SettingsView — a regra continuaria certa no manager e a tela mentiria.
        let hSemDados = HealthManager(defaults: hkStore)
        hSemDados.marcarAutorizado()
        let textosConectado = textosDaTela(AnyView(SettingsView()
            .environment(\.locale, Locale(identifier: "pt_BR"))
            .environmentObject(modelC)
            .environmentObject(hSemDados)
            .environmentObject(storeC)
            .environmentObject(accessC)
            .environmentObject(storeAlmaC)
            .environmentObject(hkC)))
        checa("A27g", "autorizado e sem amostra, a tela NÃO acusa Desconectado",
              textosConectado.contains(hSemDados.rotuloDeConexao)
                && !textosConectado.contains("Desconectado"),
              "esperado=\"\(hSemDados.rotuloDeConexao)\" "
                + "achados=\(textosConectado.filter { $0.contains("onectad") || $0.contains("sponív") })")

        // ── R · toque em notificação leva à tela certa ──────────────────────
        //
        // O que estas asserções cobrem e o que NÃO cobrem está escrito no
        // cabeçalho de RotaDaNotificacao.swift, e repito aqui porque é o tipo
        // de coisa que se perde: elas provam o MAPA (identificador → destino) e
        // a SOBREVIVÊNCIA do destino à partida fria. Elas NÃO provam que o iOS
        // chama o delegate, nem que a aba muda na tela — isso exige XCUITest,
        // que o projeto não tem. O elo tela↔destino é coberto pelo lint de
        // wiring (N-W1..N-W6), que é estático.

        // R0 · GUARDA ANTI-CEGUEIRA, primeiro de todas (lição do A26d).
        // Um catálogo vazio faria R1 e R2 passarem verdes para sempre, varrendo
        // por baixo do tapete exatamente o bug que elas existem para pegar.
        checa("R0", "o catálogo de notificações não está vazio",
              RotaDaNotificacao.catalogo.count >= 11,
              "\(RotaDaNotificacao.catalogo.count) identificadores catalogados")

        // R1 · TODO identificador catalogado resolve para um destino.
        let semDestino = RotaDaNotificacao.catalogo
            .filter { RotaDaNotificacao.destinoPorIdentificador($0.identificador) == nil }
            .map(\.identificador)
        checa("R1", "todo lembrete agendado tem destino ao ser tocado",
              semDestino.isEmpty && !RotaDaNotificacao.catalogo.isEmpty,
              semDestino.isEmpty ? "nenhum órfão" : "SEM DESTINO: \(semDestino)")

        // R2 · o mapa é o esperado, um a um. Mutação alvo: trocar o destino do
        // almoço de .dieta para qualquer outra aba — era o pedido literal.
        let esperado: [(String, DestinoDaNotificacao)] = [
            ("meal-lunch",       .corpoAba(.dieta)),
            ("meal-breakfast",   .corpoAba(.dieta)),
            ("meal-dinner",      .corpoAba(.dieta)),
            ("water-13",         .corpoAba(.inicio)),
            ("workout",          .corpoAba(.treino)),
            ("supplement-daily", .corpoAba(.dieta)),
            ("daily_morning",    .almaAba(.praticas)),
            ("addiction_168",    .livreDeVicios),
        ]
        let errados = esperado.filter {
            RotaDaNotificacao.destinoPorIdentificador($0.0) != $0.1
        }.map(\.0)
        checa("R2", "cada lembrete leva à tela do que ele pede",
              errados.isEmpty,
              errados.isEmpty
                ? "\(esperado.count) rotas conferidas · almoço → Dieta"
                : "ROTA ERRADA: \(errados)")

        // R3 · o push do feed que já existia continua funcionando. A Cloud
        // Function `notifyNewFeedPost` está no ar mandando action=openFeed e
        // não muda de contrato por causa desta refatoração.
        let feed = RotaDaNotificacao.destino(identificador: "qualquer",
                                             userInfo: ["action": "openFeed"])
        checa("R3", "o push legado do feed continua indo para o Feed",
              feed == .almaAba(.feed), "\(String(describing: feed))")

        // R4 · o carimbo do userInfo vence o identificador, e sobrevive à
        // viagem de ida e volta pelo texto (é assim que ele trafega no push).
        let carimbo = RotaDaNotificacao.carimbo(para: "meal-lunch")
        let viaCarimbo = RotaDaNotificacao.destino(identificador: "id-desconhecido",
                                                   userInfo: carimbo)
        checa("R4", "o destino carimbado no userInfo sobrevive à ida e volta",
              viaCarimbo == .corpoAba(.dieta) && !carimbo.isEmpty,
              "carimbo=\(carimbo) → \(String(describing: viaCarimbo))")

        // R5 · O CASO FRIO — a asserção que justifica o desenho todo.
        // Escreve o destino SEM nenhum observador (é o que acontece quando o
        // delegate roteia durante o launch, antes de existir view) e exige que
        // ele ainda esteja lá quando a primeira tela aparecer.
        // Mutação alvo: trocar o estado guardado por um evento
        // (NotificationCenter.post / PassthroughSubject) — o destino some e
        // esta asserção fica vermelha, que é o bug que ninguém testa.
        let roteador = RoteadorDeNotificacao.shared
        roteador.zerarParaAuditoria()
        roteador.rotear(.corpoAba(.dieta))              // ninguém observando
        let sobreviveu = roteador.pendente              // "a tela nasce agora"
        checa("R5", "destino roteado com o app fechado sobrevive até a tela nascer",
              sobreviveu == .corpoAba(.dieta) && roteador.roteados == 1,
              "pendente=\(String(describing: sobreviveu)) roteados=\(roteador.roteados)")

        // R5b · consumir entrega UMA vez e limpa — senão a pessoa que fechar o
        // Corpo à mão seria jogada de volta nele a cada render.
        let primeiraEntrega = roteador.consumir { _ in true }
        let segundaEntrega  = roteador.consumir { _ in true }
        checa("R5b", "o destino é entregue uma vez só",
              primeiraEntrega == .corpoAba(.dieta) && segundaEntrega == nil,
              "1ª=\(String(describing: primeiraEntrega)) 2ª=\(String(describing: segundaEntrega))")

        // R5c · a aba do Corpo continua guardada DEPOIS de o destino ser
        // consumido pela Início — é o intervalo em que o fullScreenCover está
        // apresentando e o RootTabView ainda não existe.
        let abaGuardada = roteador.abaDoCorpoPendente
        let abaConsumida = roteador.consumirAbaDoCorpo()
        checa("R5c", "a aba do Corpo sobrevive à apresentação do módulo",
              abaGuardada == .dieta && abaConsumida == .dieta
                && roteador.abaDoCorpoPendente == nil,
              "guardada=\(String(describing: abaGuardada)) consumida=\(String(describing: abaConsumida))")

        // R6 · os números das abas em RotaDaNotificacao são os MESMOS `tag` das
        // TabViews. Se alguém reordenar as abas numa das duas pontas, a
        // notificação passa a levar à tela errada — pior que não levar.
        checa("R6", "os índices das abas batem com as TabViews",
              AbaDaAlma.feed.rawValue == 1 && AbaDaAlma.praticas.rawValue == 2
                && AbaDoCorpo.dieta.rawValue == 2 && AbaDoCorpo.treino.rawValue == 3
                && AbaDaAlma.allCases.count == 5 && AbaDoCorpo.allCases.count == 5,
              "alma feed=\(AbaDaAlma.feed.rawValue) práticas=\(AbaDaAlma.praticas.rawValue) · "
                + "corpo dieta=\(AbaDoCorpo.dieta.rawValue) treino=\(AbaDoCorpo.treino.rawValue)")

        // ═══════════════════════════════════════════════════════════════════
        // R7 · o catálogo cobre os prefixos que a GradeDeLembretes sabe limpar.
        //
        // [05/08] ESTA ASSERÇÃO NASCEU VERMELHA E O ACHADO ERA VERDADEIRO.
        // `DonoDoLembrete.alma` declara quatro prefixos — `daily_`,
        // `personalized_`, `streak_`, `milestone_` — e só o primeiro existe.
        // Os outros três pertencem ao `HabitNotificationManager`, que NÃO está
        // no `project.pbxproj`, nunca compilou e nunca agendou nada
        // (ver CLAUDE.md, "OS LEMBRETES DE HÁBITO NÃO EXISTEM").
        //
        // Não roteei os três para pintar de verde: rota para notificação que
        // não existe é código morto, e verde comprado assim é o que este
        // projeto passou o dia combatendo. A asserção passa a fixar a verdade
        // ATUAL, com o conjunto exato de órfãos — o que é diferente de afrouxar:
        //   · prefixo novo sem rota      → VERMELHA (o caso que ela pega);
        //   · um órfão ganhar rota       → VERMELHA (alguém ligou o arquivo e
        //                                   tem de passar por aqui de propósito);
        //   · grade esvaziada            → VERMELHA (anti-cegueira).
        // ═══════════════════════════════════════════════════════════════════
        let prefixosDaGrade = DonoDoLembrete.allCases.flatMap(\.prefixos)
        let prefixosSemRota = Set(prefixosDaGrade.filter { prefixo in
            RotaDaNotificacao.destinoPorIdentificador(prefixo + "0") == nil
        })
        let orfaosConhecidos: Set<String> = ["personalized_", "streak_", "milestone_"]
        checa("R7", "os únicos prefixos sem rota são os do HabitNotificationManager (morto)",
              prefixosSemRota == orfaosConhecidos && !prefixosDaGrade.isEmpty,
              "sem rota=\(prefixosSemRota.sorted()) · esperado=\(orfaosConhecidos.sorted()) "
                + "· total na grade=\(prefixosDaGrade.count)")

        // R7b · a outra metade da mesma verdade: os prefixos que SOBRAM depois
        // dos órfãos são exatamente os que os três agendadores vivos usam.
        // Se alguém acrescentar categoria em `NotificationManager`,
        // `LembretesDaAlma` ou `AddictionFreeView` sem passar pelo catálogo,
        // ela cai fora deste conjunto e a asserção acusa.
        let prefixosVivos = Set(prefixosDaGrade).subtracting(orfaosConhecidos)
        // [2026-08-26] `jejum_` entrou aqui junto com o dono novo. A asserção
        // continua pegando o caso que ela existe para pegar: quem acrescentar
        // categoria sem carimbar o destino no catálogo cai fora deste conjunto.
        let esperadosVivos: Set<String> = ["water-", "meal-", "workout",
                                           "supplement-", "daily_", "addiction_",
                                           "jejum_"]
        checa("R7b", "todo prefixo vivo da grade está roteado",
              prefixosVivos == esperadosVivos
                && prefixosVivos.allSatisfy { RotaDaNotificacao.destinoPorIdentificador($0 + "0") != nil },
              "vivos=\(prefixosVivos.sorted())")

        roteador.zerarParaAuditoria()

        // ═══════════════════════════════════════════════════════════════════
        // J · JEJUM INTERMITENTE
        //
        // Prefixo J, livre — não colide com nenhum existente.
        //
        // Cada uma destas fica VERMELHA quando a linha de produção que ela
        // protege é apagada; é a regra que N1/N2 não passaram e por isso foram
        // removidas. Duas delas (J1b e J5b) são guardas anti-cegueira, pela
        // lição do A26d: asserção de AUSÊNCIA sem canário passa para sempre.
        // ═══════════════════════════════════════════════════════════════════

        // J1 · a pausa não come tempo. Um jejum que correu 2 h, pausou 1 h e
        // voltou a correr por 1 h tem 3 h de jejum, não 4.
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let jejumBase = JejumEmCurso(protocolo: .dezesseisPorOito, comecouEm: t0)
        let pausado = jejumBase.pausando(agora: t0.addingTimeInterval(2 * 3600))
        let retomado = pausado.retomando(agora: t0.addingTimeInterval(3 * 3600))
        let decorridoComPausa = retomado.decorrido(agora: t0.addingTimeInterval(4 * 3600))
        checa("J1", "a pausa não conta como jejum",
              Int(decorridoComPausa) == 3 * 3600,
              "correu \(textoDaDuracao(decorridoComPausa)) em 4 h de relógio")

        // J1b · anti-cegueira de J1. Um cronômetro que devolvesse sempre zero
        // faria J1 passar se ela olhasse só "não é 4 h".
        checa("J1b", "o cronômetro anda quando ninguém pausa",
              jejumBase.decorrido(agora: t0.addingTimeInterval(4 * 3600)) == 4 * 3600,
              "4 h de relógio → \(textoDaDuracao(jejumBase.decorrido(agora: t0.addingTimeInterval(4 * 3600))))")

        // J2 · relógio para trás não vira número negativo na tela. Acontece de
        // verdade: fuso de viagem e acerto manual do relógio.
        let comRelogioAtrasado = jejumBase.decorrido(agora: t0.addingTimeInterval(-7200))
        checa("J2", "relógio para trás não produz jejum negativo",
              comRelogioAtrasado >= 0 && jejumBase.progresso(agora: t0.addingTimeInterval(-7200)) >= 0,
              "decorrido=\(comRelogioAtrasado)")

        // ── J3 · O INVARIANTE ANTI-ESCALADA ────────────────────────────────
        //
        // O pedido do Assis: "não gamifique jejum mais longo sem teto". A
        // tradução em código é que a métrica celebrada conta DIAS, e um jejum
        // longo vale o mesmo que um curto. Se alguém trocar `Sequencia.dias`
        // por algo que pontue duração, esta fica vermelha.
        let ontem = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let umDezesseisOito = JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: ontem,
                                             terminouEm: ontem, duracao: 16 * 3600)
        let umOmadLonguissimo = JejumConcluido(protocolo: .omad, comecouEm: Date(),
                                               terminouEm: Date(), duracao: 30 * 3600)
        checa("J3", "um jejum longo vale o mesmo que um curto na sequência",
              Sequencia.dias([umDezesseisOito]) == Sequencia.dias([umOmadLonguissimo]),
              "16/8=\(Sequencia.dias([umDezesseisOito])) · OMAD 30 h=\(Sequencia.dias([umOmadLonguissimo]))")

        // J3b · e a sequência de fato conta dias seguidos (anti-cegueira: uma
        // função que devolvesse sempre 1 faria J3 passar).
        checa("J3b", "dois dias seguidos contam dois",
              Sequencia.dias([umDezesseisOito, umOmadLonguissimo]) == 2,
              "\(Sequencia.dias([umDezesseisOito, umOmadLonguissimo]))")

        // J4 · o app não OFERECE jejum prolongado. Nenhum protocolo do menu
        // passa de 24 h.
        let maisLongoOferecido = ProtocoloDeJejum.allCases.map(\.horasDeJejum).max() ?? 0
        checa("J4", "nenhum protocolo oferecido passa de 24 h",
              maisLongoOferecido <= 24 && !ProtocoloDeJejum.allCases.isEmpty,
              "maior=\(maisLongoOferecido) h em \(ProtocoloDeJejum.allCases.count) protocolos")

        // ── J5 · RESTRIÇÃO ALIMENTAR SOME DA SUGESTÃO ──────────────────────
        //
        // "Sugerir amendoim a quem tem alergia seria pior que não sugerir
        // nada" — CorpoContextSnapshot. Aqui isso vira asserção.
        let comAlergia = QuebraDeJejum.montar(
            duracao: 20 * 3600, horasDeJanela: 4, kcalGoal: 2000, kcalConsumidas: 0,
            restricoesTextoLivre: "alergia a lactose, sem frango",
            catalogo: foodDatabase)
        let nomesComAlergia = comAlergia.componentes.map(\.nome)
        let vazouRestricao = nomesComAlergia.filter {
            let n = LeitorDeRestricoes.normalizar($0)
            return n.contains("iogurte") || n.contains("queijo") || n.contains("cottage")
                || n.contains("frango") || n.contains("peru") || n.contains("whey")
        }
        checa("J5", "restrição declarada não aparece na sugestão",
              vazouRestricao.isEmpty && !nomesComAlergia.isEmpty,
              vazouRestricao.isEmpty ? "sugeriu \(nomesComAlergia.joined(separator: ", "))"
                                     : "VAZOU: \(vazouRestricao)")

        // J5b · ANTI-CEGUEIRA de J5, e ela é obrigatória: um motor que
        // devolvesse lista vazia faria J5 passar para sempre. Sem restrição, os
        // mesmos alimentos TÊM de aparecer.
        let semAlergia = QuebraDeJejum.montar(
            duracao: 20 * 3600, horasDeJanela: 4, kcalGoal: 2000, kcalConsumidas: 0,
            restricoesTextoLivre: "", catalogo: foodDatabase)
        let nomesSemAlergia = semAlergia.componentes.map(\.nome)
        let apareceOQueSeriaBarrado = nomesSemAlergia.contains {
            let n = LeitorDeRestricoes.normalizar($0)
            return n.contains("cottage") || n.contains("frango")
        }
        checa("J5b", "sem restrição, o alimento barrado em J5 aparece",
              apareceOQueSeriaBarrado,
              "sugeriu \(nomesSemAlergia.joined(separator: ", "))")

        // J5c · o que o leitor NÃO entendeu é confessado, não engolido.
        let comTextoEstranho = QuebraDeJejum.montar(
            duracao: 16 * 3600, horasDeJanela: 8, kcalGoal: 2000, kcalConsumidas: 0,
            restricoesTextoLivre: "alergia a jaracatiá", catalogo: foodDatabase)
        checa("J5c", "restrição não interpretada é reportada",
              comTextoEstranho.restricoesNaoLidas.contains { $0.contains("jaracatia") },
              "não lidas: \(comTextoEstranho.restricoesNaoLidas)")

        // J6 · jejum curto não recebe primeiro prato; jejum longo recebe, e ele
        // é pequeno. É a regra de desenho inteira da quebra, em dois números.
        let quebraCurta = QuebraDeJejum.montar(
            duracao: 12 * 3600, horasDeJanela: 12, kcalGoal: 2000, kcalConsumidas: 0,
            catalogo: foodDatabase)
        checa("J6", "abaixo de 14 h não há primeiro prato; acima de 18 h há, e é leve",
              !quebraCurta.temPrimeiroPrato
                && semAlergia.temPrimeiroPrato
                && semAlergia.kcalDoPrimeiroPrato <= 250
                && semAlergia.kcalDoPrimeiroPrato > 0,
              "12 h → \(quebraCurta.kcalDoPrimeiroPrato) kcal · 20 h → \(semAlergia.kcalDoPrimeiroPrato) kcal")

        // J7 · o total da sugestão é a soma dos componentes. Mesmo invariante da
        // `Meal` — e ele importa aqui porque esta sugestão VIRA uma `Meal` no
        // diário da pessoa.
        let somaDeComponentes = semAlergia.componentes.reduce(0) { $0 + $1.kcal }
        checa("J7", "o total da quebra é a soma dos componentes",
              semAlergia.kcalTotal == somaDeComponentes && somaDeComponentes > 0,
              "total=\(semAlergia.kcalTotal) soma=\(somaDeComponentes)")

        // ── J10 e J11 · A ORDEM DOS ALIMENTOS [26/08] ──────────────────────
        //
        // As duas regras que o pedido do Assis ("o que é colocado na boca após
        // a quebra do jejum deve ser proteína") virou depois de a evidência ser
        // apurada. Sem estas asserções, uma refatoração que reordenasse a
        // montagem desfaria a regra em silêncio — e a tela continuaria dizendo
        // "o carboidrato por último" enquanto o carboidrato viria primeiro.
        checa("J10", "no prato principal, o carboidrato é o ÚLTIMO",
              semAlergia.carboidratoPorUltimo
                && semAlergia.pratoPrincipal.contains { $0.papel == .carboidrato },
              "ordem: " + semAlergia.pratoPrincipal.map { $0.papel.rotulo }.joined(separator: " → "))

        checa("J11", "a porção que abre a quebra é SÓ proteína",
              semAlergia.primeiroPratoEhProteico,
              "primeiro prato: " + semAlergia.primeiroPrato
                .map { "\($0.componente.nome) (\($0.papel.rotulo))" }.joined(separator: ", "))

        // J11b · anti-cegueira: um prato principal vazio faria J10 passar
        // (`carboidratoPorUltimo` devolve `true` quando não há carboidrato).
        checa("J11b", "o prato principal tem os quatro papéis",
              Set(semAlergia.pratoPrincipal.map(\.papel)).count == 4,
              "papéis: \(Set(semAlergia.pratoPrincipal.map { $0.papel.rotulo }).sorted())")

        // ── J8 · NENHUMA PROMESSA DE RESULTADO ─────────────────────────────
        //
        // A varredura de política de loja, rodando dentro do app sobre o texto
        // que o app de fato exibe. O lint `_scripts/check_promessas_jejum.py`
        // faz o mesmo sobre a FONTE e prende o commit; esta aqui prende o
        // conteúdo montado em runtime, que é o que a pessoa lê.
        let textoDoModulo: [String] =
            JejumConteudo.oQueALiteraturaObserva.flatMap { [$0.titulo, $0.corpo] }
            + JejumConteudo.dicas.flatMap { [$0.titulo, $0.corpo] }
            + JejumConteudo.contraindicacoes.values.flatMap { [$0.titulo, $0.corpo] }
            + [JejumConteudo.sobreAQuebra.titulo, JejumConteudo.sobreAQuebra.corpo,
               JejumConteudo.disclaimer, JejumConteudo.disclaimerCurto]
            + ProtocoloDeJejum.allCases.map(\.detalhe)
        let promessas = ["emagre", "cura ", "curar", "reverte", "reverter", "garante",
                         "garantido", "queima gordura", "desintoxic", "detox",
                         "acelera o metabolismo", "elimina toxinas", "perca ", "perde peso"]
        let achadas = textoDoModulo.flatMap { frase -> [String] in
            let n = LeitorDeRestricoes.normalizar(frase)
            return promessas.filter { n.contains($0) }
        }
        checa("J8", "o módulo de jejum não promete resultado",
              achadas.isEmpty && textoDoModulo.count > 20,
              achadas.isEmpty ? "\(textoDoModulo.count) textos varridos, nenhuma promessa"
                              : "PROMESSA: \(Set(achadas).sorted())")

        // J9 · toda afirmação de saúde carrega fonte e URL. O tipo já obriga a
        // preencher; esta asserção pega o preenchimento vazio.
        let semFonte = (JejumConteudo.oQueALiteraturaObserva + [JejumConteudo.sobreAQuebra])
            .filter { $0.fonte.trimmingCharacters(in: .whitespaces).isEmpty
                        || !$0.url.hasPrefix("http") }
        checa("J9", "toda afirmação de saúde tem fonte e URL",
              semFonte.isEmpty && JejumConteudo.oQueALiteraturaObserva.count >= 4,
              semFonte.isEmpty ? "\(JejumConteudo.oQueALiteraturaObserva.count + 1) afirmações, todas com fonte"
                               : "SEM FONTE: \(semFonte.map(\.titulo))")

        // ── H · a tela e o registro contam a MESMA coisa ────────────────────
        //
        // Dois bugs da mesma família, achados em 05/08 na varredura do scan:
        // a tela dizia uma coisa e o app fazia outra, sem nada acusando.
        //
        // Prefixo H (de honestidade) e não C: o C já é do card "Complete seu
        // perfil" (C1a..C3). Duas asserções com o mesmo id tornam o log
        // ambíguo — quando uma reprova, não dá para saber qual.

        // H1 · nenhum texto do caminho SEM IA vaza para o resultado COM IA.
        //
        // O `MockAIPlanService` escreve para a tela da estimativa por medidas:
        // "sem análise de fotos", "adicione foto de frente e de lado". Enquanto
        // ele foi a fonte de reserva do caminho de IA, qualquer campo vazio da
        // resposta trazia essas frases para uma tela que analisou foto — e sem
        // banner, porque `isAIGenerated` continuava `true`.
        //
        // Mutação alvo: devolver as observações do mock como reserva de novo.
        let reservaDaIA = AnaliseDeFotoService.observacoesPadraoDaIA
            + AnaliseDeFotoService.focosPadraoDaIA
        let vazamento = reservaDaIA.filter { texto in
            let t = texto.lowercased()
            return t.contains("sem análise") || t.contains("sem ia")
                || t.contains("adicione foto") || t.contains("sem uso de fotos")
        }
        checa("H1", "o caminho de IA não usa texto da tela sem IA",
              vazamento.isEmpty && !reservaDaIA.isEmpty,
              vazamento.isEmpty
                ? "\(reservaDaIA.count) textos próprios, nenhum cita foto ausente"
                : "VAZOU: \(vazamento)")

        // H1b · a guarda anti-cegueira do H1. Se `reservaDaIA` ficasse vazia,
        // H1 passaria verde para sempre sem olhar nada. Aqui provo que o filtro
        // ENXERGA: aplicado à frase real do mock, ele acusa.
        let fraseDoMock = ["Para uma análise mais precisa, adicione foto de frente e de lado."]
        let filtroEnxerga = fraseDoMock.contains { $0.lowercased().contains("adicione foto") }
        checa("H1b", "o filtro do H1 realmente detecta a frase que vazava",
              filtroEnxerga, "detecta=\(filtroEnxerga)")

        // ═══════════════════════════════════════════════════════════════════
        // H2 · O INVARIANTE: o número EXIBIDO e o número REGISTRADO são o mesmo.
        //
        // Era isto que ninguém olhava. A tela do scan de comida mostrava os
        // macros por 100 g debaixo de "Porção estimada na foto: 250 g", e o
        // botão registrava `grams: 100` fixo. Três números diferentes na mesma
        // interação, e a contagem do dia — o valor inteiro desta parte do app —
        // saía errada sem nenhum sinal.
        //
        // A asserção compara o que a tela mostra (`macrosDaPorcao`) com o que
        // sobra em `model.meals` depois do registro. Mutações alvo: voltar
        // `grams: 100` no botão, ou fazer os tiles lerem `kcalPer100` de novo.
        // ═══════════════════════════════════════════════════════════════════
        let modelComida = AppModel(store: UserDefaults(suiteName: "auditoria.alma.comida")!)
        modelComida.meals = []

        let pratoDaIA = FoodScanResult(
            name: "Prato de teste", brand: nil,
            description: "Porção estimada na foto: 250 g",
            kcalPer100: 208, proteinPer100: 27, carbsPer100: 4, fatPer100: 9,
            porcaoG: 250
        )
        let exibido = pratoDaIA.macrosDaPorcao
        modelComida.addFood(pratoDaIA.comoFoodItem, quantidade: pratoDaIA.porcaoG, to: .almoco)
        let registrado = modelComida.meals.last

        let batem = registrado.map {
            $0.kcal == exibido.kcal && $0.protein == exibido.proteina
                && $0.carbs == exibido.carbo && $0.fat == exibido.gordura
        } ?? false

        checa("H2", "o que a tela mostra é exatamente o que entra na dieta",
              batem,
              "exibido=\(exibido.kcal)kcal/\(exibido.proteina)P/\(exibido.carbo)C/\(exibido.gordura)G · "
                + "registrado=\(registrado.map { "\($0.kcal)kcal/\($0.protein)P/\($0.carbs)C/\($0.fat)G" } ?? "NADA")")

        // H2b · GUARDA ANTI-CEGUEIRA do H2. Se `addFood` não registrasse nada,
        // ou se `macrosDaPorcao` devolvesse zeros, H2 poderia passar comparando
        // nada com nada. Aqui exijo que os números sejam os da PORÇÃO e não os
        // por 100 g — 250 g de 208 kcal/100 g são 520 kcal, não 208.
        checa("H2b", "os números são os da porção, não os por 100 g",
              exibido.kcal == 520 && registrado?.kcal == 520
                && exibido.kcal != pratoDaIA.kcalPer100,
              "esperado=520 · exibido=\(exibido.kcal) · registrado=\(registrado?.kcal ?? -1) "
                + "· por100=\(pratoDaIA.kcalPer100)")

        // H2c · a porção também tem de aparecer no NOME do item, senão o
        // diário mostra "Prato de teste" sem dizer de quanto.
        checa("H2c", "o registro carrega a porção no nome",
              registrado?.name.contains("250 g") == true,
              registrado?.name ?? "NADA")

        // H2d · o elo com a fonte única. Se alguém reescrever a conta em
        // qualquer uma das duas pontas, ela deixa de bater com esta.
        checa("H2d", "exibido e registrado saem da mesma função de escala",
              AppModel.escalarPor100(208, gramas: 250) == exibido.kcal
                && AppModel.escalarPor100(208, gramas: 100) == 208,
              "escala(208,250)=\(AppModel.escalarPor100(208, gramas: 250)) "
                + "escala(208,100)=\(AppModel.escalarPor100(208, gramas: 100))")

        UserDefaults().removePersistentDomain(forName: "auditoria.alma.comida")

        // ── E · a porção deixa de ser um decreto (2026-08-06) ────────────────
        //
        // O bloco H fez a tela e o diário contarem o MESMO número. Não fez esse
        // número poder estar CERTO: `porcaoG` vinha da IA, era `let`, e não
        // havia controle nenhum na tela — ou a pessoa aceitava a estimativa ou
        // não registrava. A queixa que abriu este trabalho foi exatamente essa:
        // "as proporções estão exatas mas a quantidade não era a que tinha no
        // prato".
        //
        // Deixar a porção editável REABRE a porta que o H fechou, se uma ponta
        // ler a estimativa e a outra ler o ajuste. É isso que E1 mede.
        //
        // O QUE ESTE BLOCO NÃO COBRE, dito antes de alguém supor que cobre: que
        // o Slider da tela escreve em `porcaoAjustada`, e que os tiles desenham
        // o que calcularam. Isso é wiring dentro de uma View e nenhuma asserção
        // de runtime pega sem XCUITest — fica com o lint E-W1..E-W4, estático.
        let modelEdicao = AppModel(store: UserDefaults(suiteName: "auditoria.alma.edicao")!)
        modelEdicao.meals = []

        let pratoParaEditar = FoodScanResult(
            name: "Prato de teste", brand: nil,
            description: "Porção estimada na foto: 250 g",
            kcalPer100: 208, proteinPer100: 27, carbsPer100: 4, fatPer100: 9,
            porcaoG: 250
        )

        // A pessoa olhou o prato e sabe que era mais do que a IA leu: 250 → 450.
        let porcaoCorrigida = 450
        let exibidoAposEdicao = pratoParaEditar.macros(para: porcaoCorrigida)
        let rotuloDoBotao = FoodScanView.rotuloDeConfirmacao(gramas: porcaoCorrigida,
                                                            refeicao: .almoco)
        modelEdicao.addFood(pratoParaEditar.comoFoodItem,
                            quantidade: porcaoCorrigida, to: .almoco)
        let gravadoAposEdicao = modelEdicao.meals.last

        /// O comparador que E0 e E1 compartilham. Estando os dois na mesma
        /// função, um comparador cego reprovaria E0 antes de aprovar E1 de
        /// mentira.
        let confereComExibido: (Meal?) -> Bool = { m in
            guard let m else { return false }
            return m.kcal == exibidoAposEdicao.kcal
                && m.protein == exibidoAposEdicao.proteina
                && m.carbs == exibidoAposEdicao.carbo
                && m.fat == exibidoAposEdicao.gordura
        }

        // E0 · CANÁRIO, primeiro de todos (Regra 2 do CLAUDE.md).
        //
        // Monta o registro que sairia do BUG que E1 existe para pegar — o botão
        // gravando a estimativa da IA em vez do ajuste da pessoa — e exige que o
        // comparador o REPROVE. Se E0 ficar verde, o comparador está cego e o
        // resultado de E1 não vale nada.
        let comoSeUsasseAEstimativa = Meal(
            type: .almoco, name: "canário",
            kcal: pratoParaEditar.macrosDaPorcao.kcal,
            protein: pratoParaEditar.macrosDaPorcao.proteina,
            carbs: pratoParaEditar.macrosDaPorcao.carbo,
            fat: pratoParaEditar.macrosDaPorcao.gordura,
            done: true)
        checa("E0", "o comparador acusa um registro feito com a estimativa, não com o ajuste",
              confereComExibido(comoSeUsasseAEstimativa) == false,
              "estimativa=\(pratoParaEditar.macrosDaPorcao.kcal)kcal vs "
                + "ajuste=\(exibidoAposEdicao.kcal)kcal · "
                + (confereComExibido(comoSeUsasseAEstimativa)
                   ? "✗✗ COMPARADOR CEGO" : "✓ comparador vivo"))

        // E1 · O INVARIANTE, agora com a porção CORRIGIDA pela pessoa.
        //
        // Mutação alvo, dita com precisão para não prometer o que não entrego:
        // fazer `macros(para:)` e `addFood` escalarem por quantidades
        // diferentes. E1 NÃO toca na View — chama `addFood` direto — então ela
        // não pega o botão passando `r.porcaoG` no lugar de `gramas`. Esse caso
        // é do lint E-W1/E-W1b, estático. Aqui provo a aritmética das duas
        // pontas; lá provo que a tela liga as duas pontas na mesma variável.
        checa("E1", "com a porção ajustada, o que a tela mostra é o que entra na dieta",
              confereComExibido(gravadoAposEdicao),
              "exibido=\(exibidoAposEdicao.kcal)kcal/\(exibidoAposEdicao.proteina)P/"
                + "\(exibidoAposEdicao.carbo)C/\(exibidoAposEdicao.gordura)G · registrado="
                + (gravadoAposEdicao.map {
                    "\($0.kcal)kcal/\($0.protein)P/\($0.carbs)C/\($0.fat)G" } ?? "NADA"))

        // E1b · GUARDA ANTI-CEGUEIRA do E1. Se o ajuste fosse ignorado, E1
        // passaria comparando a estimativa com ela mesma. Aqui exijo que o
        // número da porção ajustada seja OUTRO: 450 g de 208 kcal/100 g são
        // 936 kcal, não os 520 da estimativa de 250 g.
        checa("E1b", "o ajuste realmente muda o número — não é a estimativa disfarçada",
              exibidoAposEdicao.kcal == 936
                && exibidoAposEdicao.kcal != pratoParaEditar.macrosDaPorcao.kcal,
              "ajustado=\(exibidoAposEdicao.kcal) (esperado 936) · "
                + "estimado=\(pratoParaEditar.macrosDaPorcao.kcal)")

        // E2 · O QUE O BOTÃO PROMETE É O QUE O DIÁRIO REGISTRA.
        //
        // Terceira ponta do requisito: exibido, CONFIRMADO e gravado. O rótulo
        // do botão é a promessa que a pessoa lê antes de tocar; se ele disser
        // 450 g e o diário guardar outra coisa, é o bug de 05/08 de novo, só
        // que na frase em vez do número.
        //
        // [revisão 06/08] A primeira versão fazia `.contains("450 g")` nas duas
        // frases. Isso é quase tautologia: eu passei 450 para as duas e conferi
        // que 450 voltou. Agora EXTRAIO o número de cada frase e comparo os
        // números — as duas frases são produzidas por funções diferentes
        // (`rotuloDeConfirmacao` e `addFood`), então a comparação tem do que
        // discordar. Mutação alvo: mudar o número dentro de qualquer uma delas.
        let extrairGramas: (String) -> Int? = { frase in
            guard let marca = frase.range(of: " g") else { return nil }
            var digitos = ""
            for caractere in frase[frase.startIndex..<marca.lowerBound].reversed() {
                if caractere.isNumber { digitos.insert(caractere, at: digitos.startIndex) }
                else { break }
            }
            return Int(digitos)
        }
        let gramasNoBotao = extrairGramas(rotuloDoBotao)
        let gramasNoDiario = gravadoAposEdicao.flatMap { extrairGramas($0.name) }
        checa("E2", "o rótulo do botão carrega a mesma porção que foi registrada",
              gramasNoBotao != nil
                && gramasNoBotao == gramasNoDiario
                && gramasNoBotao == porcaoCorrigida,
              "botão=\(gramasNoBotao.map(String.init) ?? "nada") · "
                + "diário=\(gramasNoDiario.map(String.init) ?? "nada") · "
                + "esperado=\(porcaoCorrigida) · frases: \"\(rotuloDoBotao)\" / "
                + "\"\(gravadoAposEdicao?.name ?? "NADA")\"")

        // E2b · GUARDA ANTI-CEGUEIRA do E2: o extrator precisa saber devolver
        // números DIFERENTES para frases diferentes. Se ele devolvesse sempre a
        // mesma coisa (ou sempre nil comparado com nil), E2 passaria comparando
        // nada com nada.
        checa("E2b", "o extrator do E2 distingue frases com números diferentes",
              extrairGramas(FoodScanView.rotuloDeConfirmacao(gramas: 250, refeicao: .almoco)) == 250
                && extrairGramas("sem número aqui") == nil,
              "250→\(extrairGramas(FoodScanView.rotuloDeConfirmacao(gramas: 250, refeicao: .almoco)).map(String.init) ?? "nil") · "
                + "sem número→\(extrairGramas("sem número aqui").map(String.init) ?? "nil")")

        // E3 · a estimativa continua sendo lida DA estimativa.
        //
        // [revisão 06/08] A primeira versão assertava `porcaoG == 250` — o
        // mesmo 250 que a linha acima acabara de passar ao construtor. Isso não
        // é asserção, é eco: `porcaoG` é `let` numa struct e nada aqui o muta,
        // então nem trocar `let` por `var` deixaria a linha vermelha, ao
        // contrário do que o comentário antigo prometia.
        //
        // O que VALE a pena travar é o elo que a refatoração de hoje criou:
        // `macrosDaPorcao` (que H2/H2b/H2d usam para provar o conserto de
        // 05/08) tem de continuar sendo `macros(para: porcaoG)`. Se alguém
        // apontar `macrosDaPorcao` para outra quantidade — 100, ou a ajustada —
        // as asserções H passam a falar de outra coisa sem avisar.
        // Mutação alvo: trocar o corpo de `macrosDaPorcao` para `macros(para: 100)`.
        let porEstimativa = pratoParaEditar.macrosDaPorcao
        let porParametro = pratoParaEditar.macros(para: pratoParaEditar.porcaoG)
        checa("E3", "macrosDaPorcao continua sendo a escala da porção estimada",
              porEstimativa == porParametro && porEstimativa.kcal == 520
                && porEstimativa.kcal != exibidoAposEdicao.kcal,
              "estimativa=\(porEstimativa.kcal)kcal · parametrizada=\(porParametro.kcal)kcal "
                + "· ajustada=\(exibidoAposEdicao.kcal)kcal")

        // ── E4 · o CustomFoodForm para de trocar a unidade em silêncio ───────
        //
        // O formulário pergunta "Macros (por porção)" e o `StoredFood` guarda
        // por 100 g. Até 06/08 os mesmos números iam para os dois lugares: uma
        // marmita de 600 kcal virava 600 kcal POR 100 G, e a leitura seguinte
        // do código de barras a 350 g devolvia 2 100 kcal. Mesmo gênero do bug
        // do scan — número mudando de unidade sem nada denunciar.
        let convertido = CustomFoodForm.converterPara100g(600, gramasDaPorcao: 350)
        checa("E4", "macros por porção são convertidos para 100 g antes de virar catálogo",
              convertido == 171,
              "600 kcal em 350 g → \(convertido) kcal/100 g (esperado 171)")

        // E4b · CANÁRIO DA CONVERSÃO, nas duas pontas que importam:
        //   · em 100 g tem de ser a IDENTIDADE, senão a correção quebra quem
        //     ignorou o campo novo (o valor pré-preenchido é 100);
        //   · fora de 100 g NÃO pode ser cópia — a cópia era exatamente o bug.
        let identidade = CustomFoodForm.converterPara100g(600, gramasDaPorcao: 100)
        checa("E4b", "a conversão é identidade em 100 g e deixa de ser cópia fora dele",
              identidade == 600 && convertido != 600,
              "em100g=\(identidade) (esperado 600) · em350g=\(convertido) (não pode ser 600)")

        UserDefaults().removePersistentDomain(forName: "auditoria.alma.edicao")

        UserDefaults().removePersistentDomain(forName: suiteHK)
        UserDefaults().removePersistentDomain(forName: suiteAp)
        UserDefaults().removePersistentDomain(forName: suite)

        log("═════ RESULTADO ═════")
        log("aprovados: \(aprovados)")
        if reprovados.isEmpty {
            log("reprovados: NENHUM")
        } else {
            log("REPROVADOS (\(reprovados.count)):")
            reprovados.forEach { log("   ✗ \($0)") }
        }
    }
}
#endif
