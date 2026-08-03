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

enum DebugContextDump {

    static var ligado: Bool {
        UserDefaults.standard.bool(forKey: "dumpContexto")
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

        // Detalhe por fonte, para saber QUAL fonte está muda quando falta linha.
        let corpo = await MainActor.run { CorpoContextSnapshot.atual() }
        let fontes: [(String, String?)] = [
            ("alimentação", corpo.linhaAlimentacao),
            ("água", corpo.linhaAgua),
            ("treino", corpo.linhaTreino),
            ("peso", corpo.linhaPeso),
            ("suplementos", corpo.linhaSuplementos),
            ("perfil", corpo.linhaPerfil),
            ("humor", await MainActor.run { MoodSignal.sinalDaSemana() })
        ]
        log("───────── por fonte ─────────")
        for (nome, valor) in fontes {
            log("\(nome): \(valor ?? "— sem registro")")
        }
        log("───────── fim ─────────")
    }
}
#endif
