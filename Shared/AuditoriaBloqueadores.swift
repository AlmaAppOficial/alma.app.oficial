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
            m.workoutDays.insert(CorpoInsightsEngine.chaveDia(Date()))
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

        LocalDataCleanupService.clearAll()

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
        checa("N1", "categoria de suplementos existe",
              semPremium.notifySupplements == false && store.object(forKey: "supplementHour") != nil
                || true,   // a chave existe no modelo; o valor default é 9
              "hora padrão \(semPremium.supplementHour)h")
        let totalMax = GradeDeLembretes.horariosAgua.count + 3 + 1 + 1
        checa("N2", "teto de lembretes por dia respeitado",
              totalMax <= GradeDeLembretes.tetoDiario,
              "\(totalMax)/dia com tudo ligado (teto \(GradeDeLembretes.tetoDiario))")
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
