// TestePersistencia.swift
// Alma — Corpo · prova de que o dado sobrevive ao fechamento do app
//
// [2026-08-03] A revisão independente marcou como NÃO VERIFICADO a persistência
// com o app reaberto, e observou algo mais grave: o teste, do jeito que estava,
// teria sido enganoso. As séries (peso, calorias, treinos) só existiam porque o
// seed de DEBUG as criava — nenhum caminho de produção escrevia nelas (B3).
//
// Agora que os produtores existem, este harness exercita o ciclo completo:
//
//   1. cria um AppModel novo num domínio isolado;
//   2. mexe SÓ no que a interface mexe (peso, refeição, água, treino) —
//      nunca escreve direto nas coleções derivadas;
//   3. DESTRÓI o model, simulando o app sendo fechado;
//   4. cria outro do zero e confere se o dado voltou.
//
// Se um produtor for desligado, ou se alguém repetir o erro de gravar sem ler,
// este teste falha em voz alta. Roda com `-testePersistencia 1`, só em DEBUG.

#if DEBUG
import Foundation

enum TestePersistencia {

    private static let suite = "teste.persistencia.alma"

    static var ligado: Bool {
        UserDefaults.standard.bool(forKey: "testePersistencia")
    }

    @MainActor
    static func executar() {
        guard ligado else { return }

        func log(_ t: String) { NSLog("%@", "[PERSIST] " + t) }

        // Domínio isolado: não encosta nos dados de quem estiver usando o app.
        UserDefaults().removePersistentDomain(forName: suite)
        guard let store = UserDefaults(suiteName: suite) else {
            log("não consegui criar a suite de teste")
            return
        }

        var falhas = 0
        func confere(_ ok: Bool, _ nome: String, _ detalhe: String = "") {
            if ok { log("ok    \(nome)") }
            else { falhas += 1; log("FALHA \(nome) \(detalhe)") }
        }

        log("───── ciclo 1: gravando pelos caminhos de produção ─────")

        // Escopo fechado: ao sair, o model é liberado — o app "fechou".
        do {
            let m = AppModel(store: store)

            // Peso: só mexe na propriedade que a tela de medidas mexe.
            m.weightKg = 80.0
            m.heightCm = 178
            m.ageYears = 38

            // Refeição: acrescenta e marca como feita, exatamente como o fluxo
            // "Adicionar alimento" + toque no check da Dieta.
            m.meals.append(Meal(type: .cafe, name: "Teste", kcal: 500,
                                protein: 30, carbs: 40, fat: 15, done: true))

            // Água: pelo mesmo método que o botão "250 ml" chama.
            m.addWater(250)
            m.addWater(500)

            // Treino: pelo mesmo caminho que a conclusão da sessão usa.
            m.workoutDays.insert(CorpoInsightsEngine.chaveDia(Date()))

            // Restrições: o campo novo da tela de avaliação.
            m.dietaryRestrictions = "alergia a amendoim"

            log("gravado: peso 80, 1 refeição de 500 kcal, 750 ml, 1 treino, 1 restrição")
        }

        log("───── ciclo 2: app reaberto, model novo do zero ─────")

        let m2 = AppModel(store: store)

        confere(m2.weightKg == 80.0, "peso sobreviveu", "veio \(m2.weightKg)")
        confere(m2.kcalConsumed == 500, "refeição sobreviveu", "veio \(m2.kcalConsumed) kcal")
        confere(m2.waterMl == 750, "água sobreviveu", "veio \(m2.waterMl) ml")
        confere(m2.workoutDays.contains(CorpoInsightsEngine.chaveDia(Date())),
                "treino sobreviveu", "dias: \(m2.workoutDays)")
        confere(m2.dietaryRestrictions == "alergia a amendoim",
                "restrição alimentar sobreviveu", "veio '\(m2.dietaryRestrictions)'")

        // As séries derivadas — o coração do bug B3. Elas não foram escritas
        // diretamente em momento nenhum: têm de existir porque os PRODUTORES as
        // alimentaram quando peso e refeição mudaram.
        confere(!m2.weightLog.isEmpty,
                "série de peso foi PRODUZIDA (não escrita à mão)",
                "\(m2.weightLog.count) ponto(s)")
        confere(m2.kcalByDay[CorpoInsightsEngine.chaveDia(Date())] == 500,
                "calorias do dia foram PRODUZIDAS ao marcar a refeição",
                "mapa: \(m2.kcalByDay)")

        log("───── o que a IA recebe depois de reabrir ─────")
        let snap = CorpoContextSnapshot.atual(model: m2)
        for (nome, linha) in [("alimentação", snap.linhaAlimentacao),
                              ("água", snap.linhaAgua),
                              ("treino", snap.linhaTreino),
                              ("peso", snap.linhaPeso),
                              ("perfil", snap.linhaPerfil)] {
            log("\(nome): \(linha ?? "— sem registro")")
        }
        confere(snap.linhaTreino != nil, "linha de treino chega à IA (era inatingível)")
        confere(snap.linhaPerfil?.contains("amendoim") == true, "alergia chega à IA")

        log("───── água: o reset do dia novo (bug B4) ─────")
        // Carimba ontem e força o ramo de "novo dia".
        store.set(Calendar.current.date(byAdding: .day, value: -1, to: Date()), forKey: "lastWaterDate")
        let m3 = AppModel(store: store)
        confere(m3.waterMl == 0, "água zerou no dia novo", "veio \(m3.waterMl) ml")
        // A instância seguinte NO MESMO DIA não pode ressuscitar o valor.
        let m4 = AppModel(store: store)
        confere(m4.waterMl == 0,
                "água NÃO ressuscita numa segunda instância do mesmo dia",
                "veio \(m4.waterMl) ml")

        UserDefaults().removePersistentDomain(forName: suite)
        log(falhas == 0 ? "───── TUDO PASSOU ─────" : "───── \(falhas) FALHA(S) ─────")
    }
}
#endif
