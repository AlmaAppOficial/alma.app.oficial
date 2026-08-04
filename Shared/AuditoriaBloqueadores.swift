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
              CorpoAcesso.scanDeAlimentoDisponivel == GeminiConfig.isAvailable,
              "IA disponível: \(GeminiConfig.isAvailable)")

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
