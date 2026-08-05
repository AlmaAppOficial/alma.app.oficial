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
        checa("N3", "cada dono limpa só o que é seu",
              DonoDoLembrete.allCases.count == 3
                && !DonoDoLembrete.alma.prefixos.contains(where: { DonoDoLembrete.corpo.prefixos.contains($0) }),
              "donos: \(DonoDoLembrete.allCases.map(\.rawValue).joined(separator: ", "))")

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
            "Acompanhe sono, passos, peso e alimentação",              // SubscriptionView:76
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

        checa("A18f", "o rodapé nega que o número venha do Apple Saúde",
              PontuacaoDeSono.rodape.contains("Não vem do Apple Saúde")
                && PontuacaoDeSono.rodape.contains("não é avaliação clínica"),
              PontuacaoDeSono.rodape)

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
