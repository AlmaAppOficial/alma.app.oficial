// testes_jejum.swift
// Alma — o domínio do jejum exercitado FORA do simulador.
//
// Compila o código de produção (`Jejum.swift`, `QuebraDeJejum.swift`,
// `JejumConteudo.swift`, mais `Refeicao.swift` e `UnidadeDeMedida.swift`, de
// que eles dependem) com `swiftc`, e exercita as decisões com datas fabricadas.
//
// Mesma ideia do `testes_refeicao.swift`: é por isto que aqueles três arquivos
// só importam Foundation. O que roda aqui roda em segundos, sem aparelho, sem
// tocar em dado de ninguém — e por isso pode ser reprovado por mutação.
//
// Rodar:  _scripts/rodar_testes_jejum.sh

import Foundation

var passou = 0
var falhou: [String] = []

func confere(_ ok: Bool, _ nome: String, _ observado: @autoclosure () -> String = "") {
    if ok {
        passou += 1
        print("  ✓ \(nome)")
    } else {
        falhou.append(nome)
        print("  ✗ \(nome) — OBSERVADO: \(observado())")
    }
}

// Catálogo mínimo, com os nomes exatos que `QuebraDeJejum` procura. Injetado em
// vez do `foodDatabase` real de propósito: `Models.swift` importa SwiftUI, e o
// dia em que o catálogo mudar não pode quebrar este teste por acidente.
let catalogo: [FoodItem] = [
    FoodItem(name: "Iogurte natural integral", kcalPer100: 61, proteinPer100: 4, carbsPer100: 5, fatPer100: 3, emoji: "🥛"),
    FoodItem(name: "Queijo cottage", kcalPer100: 98, proteinPer100: 11, carbsPer100: 4, fatPer100: 4, emoji: "🧀"),
    FoodItem(name: "Ovo cozido", kcalPer100: 155, proteinPer100: 13, carbsPer100: 1, fatPer100: 11, emoji: "🥚"),
    FoodItem(name: "Lentilha cozida", kcalPer100: 116, proteinPer100: 9, carbsPer100: 20, fatPer100: 0, emoji: "🫘"),
    FoodItem(name: "Mamão papaia", kcalPer100: 43, proteinPer100: 1, carbsPer100: 11, fatPer100: 0, emoji: "🍈"),
    FoodItem(name: "Banana", kcalPer100: 89, proteinPer100: 1, carbsPer100: 23, fatPer100: 0, emoji: "🍌"),
    FoodItem(name: "Peito de frango grelhado", kcalPer100: 165, proteinPer100: 31, carbsPer100: 0, fatPer100: 4, emoji: "🍗"),
    FoodItem(name: "Tilápia grelhada", kcalPer100: 128, proteinPer100: 26, carbsPer100: 0, fatPer100: 3, emoji: "🐟"),
    FoodItem(name: "Peito de peru", kcalPer100: 135, proteinPer100: 29, carbsPer100: 0, fatPer100: 2, emoji: "🦃"),
    FoodItem(name: "Feijão preto cozido", kcalPer100: 132, proteinPer100: 9, carbsPer100: 24, fatPer100: 1, emoji: "🫘"),
    FoodItem(name: "Arroz integral cozido", kcalPer100: 111, proteinPer100: 3, carbsPer100: 23, fatPer100: 1, emoji: "🍚"),
    FoodItem(name: "Batata-doce cozida", kcalPer100: 86, proteinPer100: 2, carbsPer100: 20, fatPer100: 0, emoji: "🍠"),
    FoodItem(name: "Brócolis cozido", kcalPer100: 35, proteinPer100: 2, carbsPer100: 7, fatPer100: 0, emoji: "🥦"),
    FoodItem(name: "Espinafre cozido", kcalPer100: 23, proteinPer100: 3, carbsPer100: 4, fatPer100: 0, emoji: "🥬"),
    FoodItem(name: "Azeite de oliva", kcalPer100: 884, proteinPer100: 0, carbsPer100: 0, fatPer100: 100, emoji: "🫒")
]

let cal = Calendar(identifier: .gregorian)
let t0 = Date(timeIntervalSince1970: 1_700_000_000)

print("\n═══ T1 · CRONÔMETRO ═══")

let jejum = JejumEmCurso(protocolo: .dezesseisPorOito, comecouEm: t0)

confere(jejum.decorrido(agora: t0.addingTimeInterval(3600)) == 3600,
        "uma hora de relógio é uma hora de jejum",
        "\(jejum.decorrido(agora: t0.addingTimeInterval(3600)))")

// A pausa: 2 h correndo, 1 h parado, 1 h correndo = 3 h.
let pausado = jejum.pausando(agora: t0.addingTimeInterval(2 * 3600))
confere(pausado.estaPausado, "pausar marca como pausado")
confere(pausado.decorrido(agora: t0.addingTimeInterval(10 * 3600)) == 2 * 3600,
        "pausado, o cronômetro para de andar",
        "\(pausado.decorrido(agora: t0.addingTimeInterval(10 * 3600)))")

let retomado = pausado.retomando(agora: t0.addingTimeInterval(3 * 3600))
confere(!retomado.estaPausado, "retomar tira da pausa")
confere(retomado.decorrido(agora: t0.addingTimeInterval(4 * 3600)) == 3 * 3600,
        "o acumulado sobrevive à pausa",
        "\(retomado.decorrido(agora: t0.addingTimeInterval(4 * 3600)))")

// O caso do reboot / relógio para trás.
confere(jejum.decorrido(agora: t0.addingTimeInterval(-7200)) == 0,
        "relógio para trás devolve zero, não negativo",
        "\(jejum.decorrido(agora: t0.addingTimeInterval(-7200)))")
confere(jejum.progresso(agora: t0.addingTimeInterval(-7200)) == 0,
        "progresso também não fica negativo")

// Previsão só existe com o cronômetro andando.
confere(jejum.previsaoDeTermino(agora: t0) != nil, "correndo, há previsão de término")
confere(pausado.previsaoDeTermino(agora: t0) == nil,
        "pausado, NÃO há previsão de término")

confere(jejum.metaAtingida(agora: t0.addingTimeInterval(16 * 3600)),
        "16 h de 16/8 atinge a meta")
confere(!jejum.metaAtingida(agora: t0.addingTimeInterval(15 * 3600 + 3599)),
        "um segundo antes, não atinge")
confere(jejum.progresso(agora: t0.addingTimeInterval(20 * 3600)) > 1,
        "o progresso passa de 1 quando a pessoa segue além da meta",
        "\(jejum.progresso(agora: t0.addingTimeInterval(20 * 3600)))")

print("\n═══ T2 · O TETO (anti-escalada) ═══")

let maior = ProtocoloDeJejum.allCases.map(\.horasDeJejum).max() ?? 0
confere(maior <= 24 && !ProtocoloDeJejum.allCases.isEmpty,
        "nenhum protocolo oferecido passa de 24 h", "maior = \(maior) h")

// A sequência conta DIAS. Um jejum de 30 h vale o mesmo que um de 16 h.
let hoje = cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
let ontem = cal.date(byAdding: .day, value: -1, to: hoje)!
let anteontem = cal.date(byAdding: .day, value: -2, to: hoje)!

let curto = JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: ontem,
                           terminouEm: ontem, duracao: 16 * 3600)
let longo = JejumConcluido(protocolo: .omad, comecouEm: hoje,
                           terminouEm: hoje, duracao: 30 * 3600)

confere(Sequencia.dias([curto], hoje: hoje, calendario: cal)
            == Sequencia.dias([longo], hoje: hoje, calendario: cal),
        "30 h vale o mesmo que 16 h na sequência",
        "curto=\(Sequencia.dias([curto], hoje: hoje, calendario: cal)) longo=\(Sequencia.dias([longo], hoje: hoje, calendario: cal))")

confere(Sequencia.dias([curto, longo], hoje: hoje, calendario: cal) == 2,
        "dois dias seguidos contam dois",
        "\(Sequencia.dias([curto, longo], hoje: hoje, calendario: cal))")

// Um dia abaixo da meta NÃO conta — mas também não zera o que veio antes dele
// se ele estiver fora da corrente.
let abaixo = JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: anteontem,
                            terminouEm: anteontem, duracao: 10 * 3600)
confere(Sequencia.dias([curto, longo, abaixo], hoje: hoje, calendario: cal) == 2,
        "dia abaixo da meta não entra na sequência",
        "\(Sequencia.dias([curto, longo, abaixo], hoje: hoje, calendario: cal))")

// A sequência sobrevive a "ainda não fechei a janela de hoje".
confere(Sequencia.dias([curto], hoje: hoje, calendario: cal) == 1,
        "sequência que terminou ONTEM continua viva")

let tresDiasAtras = cal.date(byAdding: .day, value: -3, to: hoje)!
let velho = JejumConcluido(protocolo: .dezesseisPorOito, comecouEm: tresDiasAtras,
                           terminouEm: tresDiasAtras, duracao: 16 * 3600)
confere(Sequencia.dias([velho], hoje: hoje, calendario: cal) == 0,
        "sequência de três dias atrás está morta",
        "\(Sequencia.dias([velho], hoje: hoje, calendario: cal))")

print("\n═══ T3 · QUEBRA — DURAÇÃO MUDA O PRATO ═══")

func montar(_ horas: Double, restricoes: String = "", meta: Int? = 2000,
            consumidas: Int = 0, objetivo: ObjetivoDaQuebra = .manter) -> SugestaoDeQuebra {
    QuebraDeJejum.montar(duracao: horas * 3600, horasDeJanela: 8,
                         kcalGoal: meta, kcalConsumidas: consumidas,
                         objetivo: objetivo,
                         restricoesTextoLivre: restricoes,
                         catalogo: catalogo)
}

let q12 = montar(12)
let q16 = montar(16)
let q20 = montar(20)

confere(q12.gentileza == .direta && !q12.temPrimeiroPrato,
        "12 h: prato único, sem porção leve",
        "\(q12.gentileza) · \(q12.primeiroPrato.count) itens")
confere(q16.gentileza == .moderada && q16.temPrimeiroPrato,
        "16 h: porção leve antes", "\(q16.gentileza)")
confere(q20.gentileza == .cuidadosa && q20.temPrimeiroPrato,
        "20 h: porção leve antes", "\(q20.gentileza)")

confere(q20.kcalDoPrimeiroPrato <= q16.kcalDoPrimeiroPrato,
        "jejum mais longo NÃO recebe porção leve maior",
        "16h=\(q16.kcalDoPrimeiroPrato) 20h=\(q20.kcalDoPrimeiroPrato)")
confere(q20.kcalDoPrimeiroPrato > 0 && q20.kcalDoPrimeiroPrato <= 250,
        "a porção leve é leve", "\(q20.kcalDoPrimeiroPrato) kcal")

// ── O CASO QUE A MUTAÇÃO M8 ENCONTROU EM 26/08 ────────────────────────────
//
// A asserção acima passava VERDE com o teto de `.cuidadosa` alterado de 200
// para 600 kcal. Motivo: com meta de 2.000 e janela de 8 h, o orçamento dá
// 1.000 kcal e os 20 % dele (200) já ficam abaixo do teto — o teto nunca era
// a restrição que mordia, então mexer nele não mudava nada.
//
// Duas travas guardam a mesma garantia (o teto por gentileza e a fatia de
// 20 %), e um cenário só exercita uma delas. Este cenário — orçamento grande,
// janela curta — é o que faz o TETO ser quem morde: 1.100 × 20 % = 220, acima
// dos 200 do `.cuidadosa`.
let orcamentoGrande = QuebraDeJejum.montar(
    duracao: 20 * 3600, horasDeJanela: 4, kcalGoal: 3000, kcalConsumidas: 0,
    catalogo: catalogo)
confere(orcamentoGrande.kcalDoPrimeiroPrato <= 210,
        "com orçamento grande, quem segura a porção leve é o TETO",
        "\(orcamentoGrande.kcalDoPrimeiroPrato) kcal de um orçamento de \(orcamentoGrande.orcamentoKcal)")

// E o teto declarado, contra LITERAIS — pela mesma razão do orçamento máximo
// em T5. Sem isto, a segunda rodada de M8 continuaria furando: com teto de 600
// o alvo cai para os 20 % do orçamento (220 kcal), que ainda passa por baixo de
// qualquer margem folgada que a asserção de comportamento use.
//
// Duas travas guardam a mesma garantia; esta prende a que o comportamento não
// consegue prender sozinho.
confere(GentilezaDaQuebra.cuidadosa.tetoDoPrimeiroPrato == 200
            && GentilezaDaQuebra.moderada.tetoDoPrimeiroPrato == 250
            && GentilezaDaQuebra.direta.tetoDoPrimeiroPrato == 0,
        "os tetos da porção leve são os que este teste conhece",
        "cuidadosa=\(GentilezaDaQuebra.cuidadosa.tetoDoPrimeiroPrato) "
            + "moderada=\(GentilezaDaQuebra.moderada.tetoDoPrimeiroPrato)")
confere(GentilezaDaQuebra.cuidadosa.tetoDoPrimeiroPrato
            <= GentilezaDaQuebra.moderada.tetoDoPrimeiroPrato,
        "o teto NUNCA sobe com a duração do jejum")
confere(q20.intervaloEmMinutos == 30 && q16.intervaloEmMinutos == 20 && q12.intervaloEmMinutos == 0,
        "o intervalo cresce com a duração",
        "12h=\(q12.intervaloEmMinutos) 16h=\(q16.intervaloEmMinutos) 20h=\(q20.intervaloEmMinutos)")

print("\n═══ T4 · QUEBRA — RESTRIÇÃO ALIMENTAR ═══")

func nomes(_ s: SugestaoDeQuebra) -> [String] {
    (s.primeiroPrato + s.pratoPrincipal).map { LeitorDeRestricoes.normalizar($0.nome) }
}

let semRestricao = montar(20)
confere(nomes(semRestricao).contains { $0.contains("iogurte") },
        "ANTI-CEGUEIRA: sem restrição, o iogurte aparece",
        nomes(semRestricao).joined(separator: ", "))

let semLactose = montar(20, restricoes: "sem lactose")
confere(!nomes(semLactose).contains { $0.contains("iogurte") || $0.contains("queijo") },
        "com 'sem lactose', iogurte e queijo somem",
        nomes(semLactose).joined(separator: ", "))
confere(!semLactose.pratoPrincipal.isEmpty,
        "…e ainda assim sobra um prato",
        "\(semLactose.pratoPrincipal.count) itens")

let vegano = montar(20, restricoes: "vegano")
let proibidosVeganos = ["frango", "peru", "tilapia", "iogurte", "queijo", "ovo"]
confere(!nomes(vegano).contains { n in proibidosVeganos.contains { n.contains($0) } },
        "'vegano' tira carne, peixe, laticínio e ovo de uma vez",
        nomes(vegano).joined(separator: ", "))
confere(!vegano.pratoPrincipal.isEmpty && vegano.kcalTotal > 0,
        "…e o prato vegano não sai vazio",
        "\(vegano.kcalTotal) kcal em \(nomes(vegano).joined(separator: ", "))")

let vegetariano = montar(20, restricoes: "vegetariana")
confere(nomes(vegetariano).contains { $0.contains("iogurte") || $0.contains("ovo") },
        "'vegetariana' NÃO tira ovo nem laticínio",
        nomes(vegetariano).joined(separator: ", "))

let desconhecida = montar(16, restricoes: "alergia a jaracatiá e a umbuzeiro")
confere(desconhecida.restricoesNaoLidas.contains { $0.contains("jaracatia") }
            && desconhecida.restricoesNaoLidas.contains { $0.contains("umbuzeiro") },
        "o que o leitor não entendeu é reportado, não engolido",
        "\(desconhecida.restricoesNaoLidas)")

let soRuido = montar(16, restricoes: "sem lactose")
confere(soRuido.restricoesNaoLidas.isEmpty,
        "o que ele entendeu NÃO vira falso alarme",
        "\(soRuido.restricoesNaoLidas)")

print("\n═══ T5 · QUEBRA — ORÇAMENTO ═══")

let cheio = montar(20, meta: 2400, consumidas: 0)
let quaseCheio = montar(20, meta: 2400, consumidas: 2200)
confere(cheio.orcamentoKcal > quaseCheio.orcamentoKcal,
        "quem já comeu quase tudo recebe sugestão menor",
        "0 kcal → \(cheio.orcamentoKcal) · 2200 kcal → \(quaseCheio.orcamentoKcal)")
// ── OS NÚMEROS ABAIXO SÃO LITERAIS DE PROPÓSITO ───────────────────────────
//
// A mutação M9 de 26/08 subiu `orcamentoMaximo` de 1.100 para 9.000 e este
// teste passou VERDE. Ele dizia `cheio.orcamentoKcal <= QuebraDeJejum.orcamentoMaximo`
// — comparando o resultado com a MESMA constante que o produziu. É uma
// tautologia: não existe valor de `orcamentoMaximo` que a faça falhar. É o
// mesmo defeito da asserção N2, removida em 04/08 por "testar aritmética, não
// o app".
//
// Com literal, mexer na constante fica vermelho. O preço é que mudar o teto de
// propósito exige mudar este número aqui — e isso é uma característica, não um
// defeito: o teto existe por causa do achado do Ramadã sobre refeição de quebra
// muito grande, e mudá-lo tem de ser uma decisão consciente.
confere(quaseCheio.orcamentoKcal >= 280,
        "…mas nunca abaixo do piso de 280", "\(quaseCheio.orcamentoKcal)")

let estouraria = montar(20, meta: 3000, consumidas: 0)
confere(estouraria.orcamentoKcal <= 1100,
        "…nem acima do teto de 1100, mesmo com meta alta",
        "meta 3000 → \(estouraria.orcamentoKcal)")
confere(QuebraDeJejum.orcamentoMaximo == 1100 && QuebraDeJejum.orcamentoMinimo == 280,
        "as constantes são as que este teste conhece",
        "min=\(QuebraDeJejum.orcamentoMinimo) max=\(QuebraDeJejum.orcamentoMaximo)")

let semMeta = montar(20, meta: nil)
confere(!semMeta.orcamentoVeioDaMeta && semMeta.orcamentoKcal == QuebraDeJejum.orcamentoSemMeta,
        "sem meta, o orçamento é padrão E DIZ que é padrão",
        "veioDaMeta=\(semMeta.orcamentoVeioDaMeta) kcal=\(semMeta.orcamentoKcal)")
confere(cheio.orcamentoVeioDaMeta,
        "ANTI-CEGUEIRA: com meta, o rótulo diz que veio da meta")

// O INVARIANTE: o número da tela é a soma dos componentes.
let soma = (cheio.primeiroPrato + cheio.pratoPrincipal).reduce(0) { $0 + $1.kcal }
confere(cheio.kcalTotal == soma && soma > 0,
        "o total é a soma dos componentes", "total=\(cheio.kcalTotal) soma=\(soma)")

// Objetivo mexe no carboidrato.
let perder = montar(20, objetivo: .perder)
let ganhar = montar(20, objetivo: .ganhar)
func carbo(_ s: SugestaoDeQuebra) -> Int { s.pratoPrincipal.reduce(0) { $0 + $1.carbo } }
confere(carbo(perder) < carbo(ganhar),
        "objetivo 'perder' traz menos carboidrato que 'ganhar'",
        "perder=\(carbo(perder))g ganhar=\(carbo(ganhar))g")

// Nenhuma quantidade absurda.
let todasAsQuantidades = (cheio.primeiroPrato + cheio.pratoPrincipal).map(\.quantidade)
confere(todasAsQuantidades.allSatisfy { $0 > 0 && $0 <= 400 },
        "nenhuma porção impossível de servir", "\(todasAsQuantidades)")

print("\n═══ T6 · CONTEÚDO ═══")

let textos = JejumConteudo.oQueALiteraturaObserva.flatMap { [$0.titulo, $0.corpo] }
    + JejumConteudo.dicas.flatMap { [$0.titulo, $0.corpo] }
    + JejumConteudo.contraindicacoes.values.flatMap { [$0.titulo, $0.corpo] }
    + [JejumConteudo.sobreAQuebra.corpo, JejumConteudo.disclaimer]
    + ProtocoloDeJejum.allCases.map(\.detalhe)

let proibidas = ["emagre", "cura ", "reverte", "garante", "queima gordura", "detox"]
let promessas = textos.flatMap { t -> [String] in
    let n = LeitorDeRestricoes.normalizar(t)
    return proibidas.filter { n.contains($0) }
}
confere(promessas.isEmpty && textos.count > 20,
        "nenhuma promessa de resultado",
        promessas.isEmpty ? "\(textos.count) textos" : "\(Set(promessas))")

let semFonte = (JejumConteudo.oQueALiteraturaObserva + [JejumConteudo.sobreAQuebra])
    .filter { $0.fonte.isEmpty || !$0.url.hasPrefix("http") }
confere(semFonte.isEmpty, "toda afirmação tem fonte e URL", "\(semFonte.map(\.titulo))")

confere(JejumConteudo.contraindicacoesEmOrdem.count == JejumConteudo.ChaveDeContraindicacao.allCases.count,
        "todas as contraindicações estão na ordem de exibição",
        "\(JejumConteudo.contraindicacoesEmOrdem.count) de \(JejumConteudo.ChaveDeContraindicacao.allCases.count)")
confere(JejumConteudo.contraindicacoesEmOrdem.allSatisfy { JejumConteudo.contraindicacoes[$0] != nil },
        "toda chave da ordem tem texto")

print("\n═══ T7 · FORMATAÇÃO ═══")
confere(textoDaDuracao(0) == "0 min", "zero", textoDaDuracao(0))
confere(textoDaDuracao(3600) == "1 h", "uma hora exata", textoDaDuracao(3600))
confere(textoDaDuracao(3600 + 1800) == "1 h 30 min", "hora e meia", textoDaDuracao(3600 + 1800))
confere(textoDaDuracao(-500) == "0 min", "negativo vira zero", textoDaDuracao(-500))
confere(textoDaDuracao(3661, comSegundos: true) == "01:01:01", "com segundos",
        textoDaDuracao(3661, comSegundos: true))

print("\n══════════════════════════════════════")
print("  \(passou) passaram · \(falhou.count) falharam")
if !falhou.isEmpty {
    falhou.forEach { print("    ✗ \($0)") }
    exit(1)
}
print("  ✓ tudo verde")
print("══════════════════════════════════════\n")
