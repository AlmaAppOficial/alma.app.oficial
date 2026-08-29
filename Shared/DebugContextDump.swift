// DebugContextDump.swift
// Alma — harness de verificação do contexto que a IA recebe
//
// [2026-08-02] Existe por causa de uma regra do projeto: nada é dado como
// pronto sem evidência. Este arquivo permite LER, no console, exatamente o
// texto que sai do aparelho rumo à IA — sem depender de automação de toque.
//
// Uso (simulador):
//   xcrun simctl launch <device> <bundle> -dumpContexto 1
//   xcrun simctl spawn <device> log stream --predicate 'eventMessage CONTAINS "[CONTEXTO]"'
//
// Compilado apenas em DEBUG: some do build de release.

#if DEBUG
import Foundation

/// [2026-08-04] Valores de saúde para a validação do contexto da IA.
///
/// POR QUE ISTO EXISTE: das 12 fontes que a Alma enxerga, 5 nascem no HealthKit
/// (passos, exercício, sono, minutos de atenção plena) ou dependem de histórico
/// de prática (sequência). O simulador não tem esses dados e o `simctl privacy`
/// **não** cobre a categoria `health` — não existe forma headless de conceder a
/// permissão do HealthKit nem de injetar amostras. Resultado: essas 5 linhas
/// nunca apareciam no dump, e a tabela dos 12 dados ficava com 5 buracos.
///
/// O QUE ISTO PROVA E O QUE NÃO PROVA:
///   ✅ prova a entrega — que o valor atravessa builder → prioridade → teto →
///      prompt, e que a linha sai formatada em PT-BR do jeito certo;
///   ❌ NÃO prova a LEITURA do HealthKit (a query `HKSampleQuery` em si), que só
///      pode ser exercitada em aparelho ou com a permissão concedida à mão.
///
/// Por isso o dump marca cada fonte semeada com `[semeado]`: quem ler o arquivo
/// de evidência seis meses depois não pode confundir uma coisa com a outra.
/// Só compila em DEBUG e só age com `-semearSaude 1`.
enum SementeDeSaude {

    static var ligada: Bool {
        UserDefaults.standard.bool(forKey: "semearSaude")
    }

    static let passos = 7432
    static let exercicioMinutos = 26
    static let sonoHoras = 6.5
    static let mindfulMinutos = 12
    static let sequenciaDias = 4
    static let totalDiasMeditados = 18

    /// Sete dias de check-in com maioria difícil — o cenário do bug B2, que
    /// devolvia "semana estável" para quem estava em sofrimento.
    static let humores = ["Triste", "Triste", "Cansado", "Ansioso", "Normal", "Bem", "Triste"]
}

enum DebugContextDump {

    static var ligado: Bool {
        UserDefaults.standard.bool(forKey: "dumpContexto")
    }

    /// [2026-08-03] Suprime os diálogos do sistema (HealthKit e notificações)
    /// durante a captura de telas de validação. Sem isto, todo screenshot sai
    /// com um alerta cinza do iOS por cima do conteúdo que se quer conferir —
    /// e a revisão independente cobrou justamente a validação visual das abas.
    /// Só em DEBUG e só com `-semPermissoes 1`.
    static var suprimirPermissoes: Bool {
        UserDefaults.standard.bool(forKey: "semPermissoes")
    }

    /// Semeia perfil e registros do Corpo para validar as telas sem depender de
    /// automação de toque (o teclado do simulador engole texto digitado por
    /// script). Roda só com `-semearPerfil 1`.
    @MainActor
    static func semearPerfil() {
        guard UserDefaults.standard.bool(forKey: "semearPerfil") else { return }

        let perfil = UserProfileStore.shared
        perfil.nome = "Assis"
        perfil.dataNascimento = Calendar.current.date(byAdding: .year, value: -38, to: Date())

        let corpo = AppModel()
        corpo.userName = "Assis"
        corpo.weightKg = 79.5
        corpo.heightCm = 178
        corpo.ageYears = 38
        corpo.waterMl = 1500
        corpo.dietaryRestrictions = "alergia a amendoim"
        corpo.healthConditions = "hérnia de disco"
        corpo.workoutDays.insert(CorpoInsightsEngine.chaveDia(Date()))
        if let primeira = corpo.meals.firstIndex(where: { !$0.done }) {
            corpo.meals[primeira].done = true
        }
        NSLog("[SEMEADO] perfil e registros de teste gravados")
    }

    /// [2026-08-28] Semeia um jejum EM CURSO e acende o cronômetro da tela
    /// bloqueada, para a conferência visual da atividade ao vivo.
    ///
    /// Existe pelo mesmo motivo do `semearPerfil`: a alternativa seria automação
    /// de toque atravessando Início → Dieta → card do jejum → escolher protocolo
    /// → "Começar", e depois ESPERAR horas para o contador mostrar um número que
    /// não fosse "00:00:03". Aqui o jejum nasce com o tempo que se pede.
    ///
    /// Uso:  `-semearJejum <horas>`  · `-semearJejumPausado 1` para pausá-lo.
    /// Exemplos:  `-semearJejum 3`  ·  `-semearJejum 17` (já passou da meta).
    ///
    /// **Não chega à App Store**: `semearParaCapturas` do `JejumStore` só existe
    /// em `#if DEBUG`, e este arquivo inteiro é de validação.
    @MainActor
    static func semearJejum() async {
        let horas = UserDefaults.standard.double(forKey: "semearJejum")
        guard horas > 0 else { return }

        #if DEBUG
        let agora = Date()
        let comecou = agora.addingTimeInterval(-horas * 3600)
        var jejum = JejumEmCurso(protocolo: .dezesseisPorOito, comecouEm: comecou)
        if UserDefaults.standard.bool(forKey: "semearJejumPausado") {
            jejum = jejum.pausando(agora: agora)
        }
        JejumStore.shared.semearParaCapturas(emCurso: jejum, historico: [])
        await JejumStore.shared.sincronizarCronometroDaTelaBloqueada()
        NSLog("[SEMEADO] jejum de \(horas) h em curso · pausado=\(jejum.estaPausado)")
        #endif
    }

    /// [2026-08-28] Encerra o jejum semeado e tira o cronômetro da tela
    /// bloqueada. É a metade que PROVA que a atividade não fica órfã — sem ela,
    /// a captura só mostraria que o cronômetro sabe aparecer.
    /// Uso: `-encerrarJejumSemeado 1`.
    @MainActor
    static func encerrarJejumSemeado() async {
        guard UserDefaults.standard.bool(forKey: "encerrarJejumSemeado") else { return }
        #if DEBUG
        JejumStore.shared.encerrar()
        await JejumStore.shared.sincronizarCronometroDaTelaBloqueada()
        NSLog("[SEMEADO] jejum encerrado e atividade ao vivo removida")
        #endif
    }

    /// [2026-08-04] Semeia as fontes que o simulador não consegue produzir
    /// sozinho: HealthKit (via `SementeDeSaude`, lida dentro do
    /// `HealthKitManager`), sequência de meditação, humor e suplementos.
    ///
    /// Existe para fechar a tabela dos 12 dados com dump real em vez de
    /// "verificado por leitura de código". Roda só com `-semearSaude 1`.
    @MainActor
    static func semearSaude() {
        guard SementeDeSaude.ligada else { return }

        // ── Meditação e sequência ────────────────────────────────────────────
        let streak = StreakManager.shared
        streak.currentStreak = SementeDeSaude.sequenciaDias
        streak.totalMeditationDays = SementeDeSaude.totalDiasMeditados

        // ── Humor: 7 check-ins, um por dia, dentro da janela de 7 dias ───────
        let memoria = UserMemoryManager.shared
        let cal = Calendar.current
        memoria.moodHistory = SementeDeSaude.humores.enumerated().compactMap { (i, rotulo) in
            guard let data = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            return MoodEntry(emoji: rotulo, date: data)
        }
        memoria.lastMoodDate = Date()
        memoria.save()

        // ── Suplementos: um tomado hoje, para a linha existir ────────────────
        let corpo = AppModel()
        if corpo.supplements.isEmpty {
            var whey = Supplement(name: "Whey protein",
                                  brand: "Growth",
                                  dose: "30 g",
                                  timeLabel: "Manhã",
                                  notes: nil,
                                  kcalPerDose: 120,
                                  proteinPerDose: 24)
            whey.takenDates = [CorpoInsightsEngine.chaveDia(Date())]
            corpo.supplements = [whey]
        }

        NSLog("[SEMEADO] saúde, sequência, humor e suplementos gravados")
    }

    /// Concede todas as categorias disponíveis e imprime o contexto montado.
    /// Só mexe no consentimento quando a flag está ligada — em uso normal este
    /// caminho nunca roda.
    static func executar(health: HealthKitManager) async {
        guard ligado else { return }

        for categoria in HealthConsentCategory.allCases where categoria.isAvailableNow {
            HealthContextConsent.set(true, for: categoria)
        }

        let contexto = await HealthContextBuilder(health: health).build()

        // NSLog trata o primeiro argumento como format string: passar o texto
        // direto fazia o "%" de "60% da meta" ser comido e virar "60 0a meta".
        // Com "%@" o conteúdo vai como argumento e sai literal.
        func log(_ texto: String) { NSLog("%@", "[CONTEXTO] " + texto) }

        log("───────── início ─────────")
        if let contexto {
            contexto.split(separator: "\n").forEach { log(String($0)) }
            log("(\(contexto.count) de \(HealthContextBuilder.maxCharacters) caracteres)")
        } else {
            log("nil — nenhum dado real disponível")
        }

        // ── Detalhe por fonte ────────────────────────────────────────────────
        // [2026-08-04] Antes eram 7 fontes (só as do Corpo + humor). As 5 que
        // vêm do HealthKit e da prática ficavam invisíveis aqui e só apareciam
        // — quando apareciam — dentro do bloco montado. A revisão pediu a
        // tabela dos 12; então o dump agora enumera os 12, na ordem da tabela,
        // e diz qual está mudo. Passos e exercício viram UMA linha ("Movimento")
        // no contexto final, e meditação e sequência também se fundem: por isso
        // o bloco montado tem menos linhas que 12. É de propósito.
        let corpo = await MainActor.run { CorpoContextSnapshot.atual() }
        let semeada = SementeDeSaude.ligada ? "  [semeado]" : ""

        let passos = await health.stepsToday()
        let exercicio = await health.exerciseMinutesToday()
        let sono = await health.lastNightSleepHours()
        let mindful = await health.mindfulMinutesToday()
        let sequencia = await MainActor.run { StreakManager.shared.currentStreak }

        let fontes: [(Int, String, String?, String)] = [
            (1,  "passos",        passos.map { "\(CorpoContextFormat.inteiro($0)) passos" }, semeada),
            (2,  "exercício",     exercicio.map { "\($0) min" }, semeada),
            (3,  "sono",          sono.map { HealthContextBuilder.formatHours($0) + " na noite passada" }, semeada),
            (4,  "meditação",     mindful.map { "\($0) min hoje" }, semeada),
            (5,  "sequência",     sequencia > 0 ? "\(sequencia) dia(s)" : nil, semeada),
            (6,  "alimentação",   corpo.linhaAlimentacao, ""),
            (7,  "água",          corpo.linhaAgua, ""),
            (8,  "treino",        corpo.linhaTreino, ""),
            (9,  "peso",          corpo.linhaPeso, ""),
            (10, "suplementos",   corpo.linhaSuplementos, ""),
            (11, "perfil",        corpo.linhaPerfil, ""),
            (12, "humor",         await MainActor.run { MoodSignal.sinalDaSemana() }, "")
        ]

        log("───────── por fonte (os 12) ─────────")
        var chegam = 0
        for (n, nome, valor, marca) in fontes {
            if valor != nil { chegam += 1 }
            let status = valor == nil ? "MUDA" : "chega"
            log(String(format: "%2d. %-13@ %@  %@%@", n, nome, status,
                       valor ?? "— sem registro", marca))
        }
        log("───────── placar: \(chegam) de 12 chegam à IA ─────────")
        log("───────── fim ─────────")
    }
}
#endif
