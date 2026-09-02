// testes_series.swift
// Alma — o registro de séries (reps × carga) exercitado FORA do simulador.
//
// Compila o código de produção (`Exercicio.swift`, `RegistroDeSeries.swift`)
// com `swiftc` e prova quatro coisas, cada uma com mutação em
// `mutacao_series.sh`:
//
//   R · as regras puras (reps ou segundos, peso corporal, parsing, texto);
//   G · GRAVOU O QUE A PESSOA DIGITOU — lido de volta por OUTRA instância do
//       store, como o app reaberto. É a família de asserção que já saiu verde
//       sem gravar nada (bug do treino personalizado no Android), por isso a
//       releitura é sempre por instância nova, nunca pelo cache;
//   T · um registro ilegível não derruba os outros;
//   L · o `customWorkouts` gravado ANTES desta mudança continua legível —
//       com um canário (L0) mostrando a armadilha que a asserção vigia.
//
// Rodar:  _scripts/rodar_testes_series.sh
// Saída:  0 = verde · 1 = vermelho

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

// Domínio isolado: não encosta nos dados de ninguém.
let suite = "teste.series.alma"
UserDefaults().removePersistentDomain(forName: suite)
guard let store = UserDefaults(suiteName: suite) else {
    print("✗✗ não consegui criar a suíte de teste")
    exit(1)
}

let cal = Calendar(identifier: .gregorian)
let sessaoA = UUID()
let sessaoB = UUID()
let t0 = Date(timeIntervalSince1970: 1_756_400_000)   // 2025-08-28 (UTC)

func serie(_ sessao: UUID, _ quando: Date, _ nome: String, numero: Int = 1,
           reps: Int? = nil, seg: Int? = nil, kg: Double? = nil) -> SerieRegistrada {
    SerieRegistrada(sessao: sessao, quando: quando, treino: "Treino de teste",
                    exercicioSlug: slugDeExercicio(nome), exercicio: nome,
                    numero: numero, repeticoes: reps, segundos: seg, cargaKg: kg)
}

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ R · REGRAS ═══")

// R1 · reps ou segundos, lido do que o catálogo prescreve
for (reps, esperado) in [
    ("12 reps", MedidaDaSerie.repeticoes), ("8-12", .repeticoes), ("10 cada", .repeticoes),
    ("max reps", .repeticoes), ("20", .repeticoes), ("5 ciclos", .repeticoes),
    ("20 m", .repeticoes), ("100 batidas", .repeticoes),
    ("7 meio inferior, 7 meio superior, 7 completos.", .repeticoes),
    ("30 s", .segundos), ("45 s cada", .segundos), ("60 seg", .segundos),
    ("20 min", .segundos), ("1 min", .segundos), ("20 s on / 10 s off", .segundos),
    ("25 min", .segundos), ("40 s", .segundos),
] {
    let obtido = RegrasDeSeries.medida(paraReps: reps)
    confere(obtido == esperado, "R1 \"\(reps)\" conta \(esperado == .segundos ? "segundos" : "repetições")", "\(obtido)")
}

// R2 · peso corporal recolhe o campo de carga
confere(RegrasDeSeries.ehPesoCorporal(.corporal), "R2 peso corporal é peso corporal")
confere(!RegrasDeSeries.ehPesoCorporal(.halteres), "R2 halteres não é peso corporal")
confere(!RegrasDeSeries.ehPesoCorporal(.barra), "R2 barra não é peso corporal")

// R3 · inteiro digitado
confere(RegrasDeSeries.inteiro(de: "12") == 12, "R3 \"12\" → 12", "\(String(describing: RegrasDeSeries.inteiro(de: "12")))")
confere(RegrasDeSeries.inteiro(de: " 12 ") == 12, "R3 espaços em volta são ignorados")
confere(RegrasDeSeries.inteiro(de: "12 reps") == 12, "R3 \"12 reps\" → 12")
confere(RegrasDeSeries.inteiro(de: "0") == 0, "R3 zero é um valor (não é ausência)")
confere(RegrasDeSeries.inteiro(de: "") == nil, "R3 em branco → nil")
confere(RegrasDeSeries.inteiro(de: "abc") == nil, "R3 letras → nil")
confere(RegrasDeSeries.inteiro(de: "-3") == nil, "R3 negativo → nil")
confere(RegrasDeSeries.inteiro(de: "1000") == nil, "R3 acima do teto de repetições (999) → nil")
confere(RegrasDeSeries.inteiro(de: "1000", teto: RegrasDeSeries.segundosMaximos) == 1000,
        "R3 1000 segundos cabem no teto de tempo")

// R4 · carga digitada
confere(RegrasDeSeries.carga(de: "60") == 60, "R4 \"60\" → 60")
confere(RegrasDeSeries.carga(de: "12,5") == 12.5, "R4 vírgula decimal (PT-BR) → 12,5", "\(String(describing: RegrasDeSeries.carga(de: "12,5")))")
confere(RegrasDeSeries.carga(de: "12.5") == 12.5, "R4 ponto decimal também → 12,5")
confere(RegrasDeSeries.carga(de: "1,25") == 1.25, "R4 meia anilha (1,25) sobrevive")
confere(RegrasDeSeries.carga(de: "12,555") == 12.56, "R4 arredonda a duas casas", "\(String(describing: RegrasDeSeries.carga(de: "12,555")))")
confere(RegrasDeSeries.carga(de: "0") == 0, "R4 zero é um valor")
confere(RegrasDeSeries.carga(de: "") == nil, "R4 em branco → nil")
confere(RegrasDeSeries.carga(de: "-5") == nil, "R4 negativo → nil")
confere(RegrasDeSeries.carga(de: "abc") == nil, "R4 letras → nil")
confere(RegrasDeSeries.carga(de: "1e3") == nil, "R4 notação científica → nil")
confere(RegrasDeSeries.carga(de: "inf") == nil, "R4 infinito → nil")
confere(RegrasDeSeries.carga(de: "1.2.3") == nil, "R4 dois pontos → nil")
confere(RegrasDeSeries.carga(de: "2000") == nil, "R4 acima do teto (1500 kg) → nil")

// R5 · montar: em branco NÃO existe registro
confere(RegrasDeSeries.montar(sessao: sessaoA, quando: t0, treino: "T", exercicio: "Supino com halteres",
                              numero: 1, repeticoes: nil, segundos: nil, cargaKg: nil) == nil,
        "R5 tudo em branco → nil (nada a gravar)")
let soReps = RegrasDeSeries.montar(sessao: sessaoA, quando: t0, treino: "T", exercicio: "Supino com halteres",
                                   numero: 2, repeticoes: 12, segundos: nil, cargaKg: nil)
confere(soReps?.repeticoes == 12 && soReps?.cargaKg == nil && soReps?.segundos == nil,
        "R5 só repetições → registro só com repetições", "\(String(describing: soReps))")
confere(soReps?.exercicioSlug == "supino-com-halteres" && soReps?.exercicio == "Supino com halteres",
        "R5 o slug é gravado NA ESCRITA, junto do nome", "\(String(describing: soReps?.exercicioSlug))")
confere(soReps?.numero == 2, "R5 o número da série é o informado")
let numeroZero = RegrasDeSeries.montar(sessao: sessaoA, quando: t0, treino: "T", exercicio: "X",
                                       numero: 0, repeticoes: nil, segundos: nil, cargaKg: 10)
confere(numeroZero?.numero == 1, "R5 série 0 vira 1 (não existe série zero)", "\(String(describing: numeroZero?.numero))")
let soCarga = RegrasDeSeries.montar(sessao: sessaoA, quando: t0, treino: "T", exercicio: "X",
                                    numero: 1, repeticoes: nil, segundos: nil, cargaKg: 40)
confere(soCarga?.cargaKg == 40 && soCarga?.repeticoes == nil, "R5 só carga → registro só com carga")

// R6 · texto da carga, vírgula decimal, sem zeros à direita
confere(RegrasDeSeries.textoDaCarga(60) == "60", "R6 60 → \"60\"", RegrasDeSeries.textoDaCarga(60))
confere(RegrasDeSeries.textoDaCarga(12.5) == "12,5", "R6 12,5 → \"12,5\"", RegrasDeSeries.textoDaCarga(12.5))
confere(RegrasDeSeries.textoDaCarga(1.25) == "1,25", "R6 1,25 → \"1,25\"", RegrasDeSeries.textoDaCarga(1.25))
confere(RegrasDeSeries.textoDaCarga(100) == "100", "R6 100 → \"100\"", RegrasDeSeries.textoDaCarga(100))
confere(RegrasDeSeries.textoDaCarga(0) == "0", "R6 0 → \"0\"", RegrasDeSeries.textoDaCarga(0))

// R7 · resumo só com o que foi informado
confere(RegrasDeSeries.resumo(serie(sessaoA, t0, "Supino", reps: 12, kg: 60)) == "12 reps × 60 kg",
        "R7 reps + carga → \"12 reps × 60 kg\"", RegrasDeSeries.resumo(serie(sessaoA, t0, "Supino", reps: 12, kg: 60)))
confere(RegrasDeSeries.resumo(serie(sessaoA, t0, "Prancha", seg: 30, kg: 10)) == "30 s × 10 kg",
        "R7 segundos + carga → \"30 s × 10 kg\"")
confere(RegrasDeSeries.resumo(serie(sessaoA, t0, "Flexão", reps: 12)) == "12 reps",
        "R7 só reps → \"12 reps\" (não inventa carga)")
confere(RegrasDeSeries.resumo(serie(sessaoA, t0, "Leg press", kg: 120.5)) == "120,5 kg",
        "R7 só carga → \"120,5 kg\"")

// R8 · a linha debaixo dos campos: registro, nunca sugestão
let mesmaSessao = serie(sessaoA, t0, "Supino", reps: 12, kg: 60)
let linhaMesma = RegrasDeSeries.linhaDeUltimaVez(mesmaSessao, sessaoAtual: sessaoA, calendario: cal)
confere(linhaMesma == "Série anterior: 12 reps × 60 kg",
        "R8 mesma sessão → \"Série anterior: …\"", linhaMesma)
var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
let outraSessao = serie(sessaoB, t0, "Supino", reps: 12, kg: 60)
let linhaOutra = RegrasDeSeries.linhaDeUltimaVez(outraSessao, sessaoAtual: sessaoA, calendario: utc)
confere(linhaOutra == "Última vez (28/08): 12 reps × 60 kg",
        "R8 outra sessão → \"Última vez (dd/MM): …\"", linhaOutra)
confere(!linhaOutra.lowercased().contains("tente") && !linhaMesma.lowercased().contains("tente"),
        "R8 nenhuma linha sugere nada (\"tente\" não aparece)")

// R9 · a última é pelo instante, não pela posição na lista
let lista9 = [
    serie(sessaoA, t0.addingTimeInterval(3600), "Supino", reps: 10, kg: 60),   // mais recente, mas primeira
    serie(sessaoA, t0, "Supino", reps: 12, kg: 55),
    serie(sessaoA, t0.addingTimeInterval(7200), "Remada", reps: 12, kg: 40),
]
let ultima9 = RegrasDeSeries.ultima(em: lista9, exercicioSlug: "supino")
confere(ultima9?.cargaKg == 60 && ultima9?.repeticoes == 10,
        "R9 última do supino é a de 60 kg (instante), não a última da lista", "\(String(describing: ultima9))")
confere(RegrasDeSeries.ultima(em: lista9, exercicioSlug: "agachamento") == nil,
        "R9 exercício nunca feito → nil")

// R10 · slug estável = o id do catálogo
confere(slugDeExercicio("Supino com halteres") == "supino-com-halteres", "R10 slug simples", slugDeExercicio("Supino com halteres"))
confere(slugDeExercicio("Flexão de braço") == "flexao-de-braco", "R10 acentos e cedilha caem", slugDeExercicio("Flexão de braço"))
confere(slugDeExercicio("Remada curvada (barra)") == "remada-curvada-barra", "R10 parênteses viram hífen e não sobram", slugDeExercicio("Remada curvada (barra)"))
confere(slugDeExercicio("Rosca 21") == "rosca-21", "R10 dígitos ficam", slugDeExercicio("Rosca 21"))

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ G · GRAVAÇÃO — o que a pessoa digitou é o que fica ═══")

// G1 · escreve por uma instância, lê por OUTRA (o app reaberto)
do {
    let escritor = RegistroDeSeries(store: store)
    escritor.registrar(serie(sessaoA, t0, "Supino com halteres", numero: 1, reps: 12, kg: 60.5))
}
let leitor = RegistroDeSeries(store: store)
let lidas = leitor.todas()
confere(lidas.count == 1, "G1 uma série gravada, uma série lida", "\(lidas.count)")
confere(lidas.first?.repeticoes == 12, "G1 as 12 repetições digitadas voltaram", "\(String(describing: lidas.first?.repeticoes))")
confere(lidas.first?.cargaKg == 60.5, "G1 os 60,5 kg digitados voltaram", "\(String(describing: lidas.first?.cargaKg))")
confere(lidas.first?.segundos == nil, "G1 segundos não informados continuam nil")
confere(lidas.first?.exercicioSlug == "supino-com-halteres", "G1 o slug sobreviveu")
confere(lidas.first?.exercicio == "Supino com halteres", "G1 o nome sobreviveu")
confere(lidas.first?.numero == 1 && lidas.first?.sessao == sessaoA && lidas.first?.treino == "Treino de teste",
        "G1 número, sessão e treino sobreviveram")
confere(abs((lidas.first?.quando.timeIntervalSince1970 ?? 0) - t0.timeIntervalSince1970) < 1,
        "G1 o instante sobreviveu (ao segundo)", "\(String(describing: lidas.first?.quando))")

// G2 · ordem de gravação preservada
do {
    let w = RegistroDeSeries(store: store)
    w.registrar(serie(sessaoA, t0.addingTimeInterval(120), "Supino com halteres", numero: 2, reps: 10, kg: 62.5))
    w.registrar(serie(sessaoA, t0.addingTimeInterval(240), "Supino com halteres", numero: 3, reps: 8, kg: 62.5))
}
let tres = RegistroDeSeries(store: store).todas()
confere(tres.count == 3 && tres.map(\.numero) == [1, 2, 3],
        "G2 três séries, na ordem em que foram gravadas", "\(tres.map(\.numero))")

// G3 · o teto: as mais antigas saem primeiro
do {
    let w = RegistroDeSeries(store: store)
    for i in 4...(RegistroDeSeries.maximo + 5) {
        w.registrar(serie(sessaoA, t0.addingTimeInterval(Double(i) * 60), "Enchimento", numero: i, reps: 1))
    }
}
let cheia = RegistroDeSeries(store: store).todas()
confere(cheia.count == RegistroDeSeries.maximo,
        "G3 nunca passa do teto (\(RegistroDeSeries.maximo))", "\(cheia.count)")
confere(cheia.first?.numero == 6 && cheia.last?.numero == RegistroDeSeries.maximo + 5,
        "G3 as mais antigas (1…5) saíram; a mais nova ficou", "primeira \(String(describing: cheia.first?.numero)), última \(String(describing: cheia.last?.numero))")

// G4 · "última vez" lida do disco, pelo instante
UserDefaults().removePersistentDomain(forName: suite)
do {
    let w = RegistroDeSeries(store: store)
    w.registrar(serie(sessaoB, t0.addingTimeInterval(-86400 * 3), "Agachamento livre", numero: 1, reps: 12, kg: 80))
    w.registrar(serie(sessaoB, t0.addingTimeInterval(-86400 * 3 + 300), "Agachamento livre", numero: 2, reps: 10, kg: 85))
    w.registrar(serie(sessaoB, t0.addingTimeInterval(-86400 * 3 + 600), "Remada curvada", numero: 1, reps: 12, kg: 40))
}
let ultimaAgachamento = RegistroDeSeries(store: store).ultima(exercicioSlug: "agachamento-livre")
confere(ultimaAgachamento?.cargaKg == 85 && ultimaAgachamento?.numero == 2,
        "G4 última do agachamento é a série 2 (85 kg)", "\(String(describing: ultimaAgachamento))")
confere(RegistroDeSeries(store: store).daSessao(sessaoB).count == 3, "G4 as três séries da sessão B")

// G5 · em branco: nada é escrito
let antes = store.data(forKey: RegistroDeSeries.chave)
let branco = RegrasDeSeries.montar(sessao: sessaoA, quando: t0, treino: "T", exercicio: "Supino",
                                   numero: 1, repeticoes: nil, segundos: nil, cargaKg: nil)
confere(branco == nil, "G5 em branco → nada a gravar")
confere(store.data(forKey: RegistroDeSeries.chave) == antes, "G5 o disco não mudou")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ T · TOLERÂNCIA — um registro ruim não derruba os outros ═══")

let bom1 = #"{"id":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A0001","sessao":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A00AA","quando":1756400000,"treino":"T","exercicioSlug":"supino","exercicio":"Supino","numero":1,"repeticoes":12,"segundos":null,"cargaKg":60}"#
let semQuando = #"{"id":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A0002","exercicioSlug":"supino","exercicio":"Supino","numero":2,"repeticoes":10}"#
let bom2 = #"{"id":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A0003","sessao":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A00AA","quando":1756400300,"treino":"T","exercicioSlug":"supino","exercicio":"Supino","numero":3,"repeticoes":8,"cargaKg":62.5}"#
let doFuturo = #"{"id":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A0004","sessao":"6B1B8F4E-2E2B-4C9F-9B3B-3E3F5C1A00AA","quando":1756400600,"treino":"T","exercicioSlug":"remada","exercicio":"Remada","numero":1,"repeticoes":12,"cargaKg":40,"campoQueAindaNaoExiste":"x","rpe":8}"#
let soNome = #"{"quando":1756400900,"exercicio":"Flexão de braço","repeticoes":15}"#

let misto = RegistroDeSeries.decodificar(Data("[\(bom1),\(semQuando),\(bom2)]".utf8))
confere(misto.count == 2 && misto.map(\.numero) == [1, 3],
        "T1 registro sem instante é descartado; os dois bons ficam", "\(misto.map(\.numero))")
let futuro = RegistroDeSeries.decodificar(Data("[\(doFuturo)]".utf8))
confere(futuro.count == 1 && futuro.first?.cargaKg == 40,
        "T2 campo desconhecido (build mais novo) é ignorado, o registro fica", "\(futuro.count)")
confere(RegistroDeSeries.decodificar(Data("isto não é json".utf8)).isEmpty,
        "T3 lixo → lista vazia, sem crash")
confere(RegistroDeSeries.decodificar(Data("{\"a\":1}".utf8)).isEmpty,
        "T3 objeto em vez de lista → vazio, sem crash")
let derivado = RegistroDeSeries.decodificar(Data("[\(soNome)]".utf8))
confere(derivado.first?.exercicioSlug == "flexao-de-braco" && derivado.first?.numero == 1,
        "T4 sem slug e sem número: slug derivado do nome, série 1", "\(String(describing: derivado.first))")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ L · O DADO ANTIGO CONTINUA LEGÍVEL ═══")
//
// O JSON abaixo é o formato que o build 102 grava em `customWorkouts`:
// `JSONEncoder` sintetizado sobre `CustomWorkout { id, name, exercises }` e
// `Exercise { id, name, sets, reps, equipment, muscle, symbol, instructions }`.
// Os structs de hoje são byte a byte os de ontem (só mudaram de arquivo) — e
// esta asserção é o que impede que um campo novo os mude sem ninguém ver.

let antigo = #"""
[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"Peito e costas","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino com halteres","sets":4,"reps":"10 reps","equipment":"Halteres","muscle":"Peito e tríceps","symbol":"figure.strengthtraining.traditional","instructions":["Deite no banco com um halter em cada mão, na linha do peito.","Empurre os halteres para cima até estender os cotovelos."]},{"id":"0A1C2E3F-1111-4222-8333-444455558888","name":"Prancha","sets":3,"reps":"45 s","equipment":"Peso corporal","muscle":"Core","symbol":"figure.core.training","instructions":["Apoie antebraços e pontas dos pés no chão."]}]}]
"""#

// L0 · CANÁRIO: o decodificador NÃO é cego. Um exercício sem `sets` (campo
// não-opcional) TEM de falhar. Se isto passar, o L1 abaixo não prova nada.
let semSets = #"[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"X","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino","reps":"10 reps","equipment":"Halteres","muscle":"Peito","symbol":"s","instructions":[]}]}]"#
let canario = try? JSONDecoder().decode([CustomWorkout].self, from: Data(semSets.utf8))
if canario == nil {
    passou += 1
    print("  ✓ L0 canário vivo — campo não-opcional ausente derruba o decode (é a armadilha)")
} else {
    falhou.append("L0 DETECTOR CEGO")
    print("  ✗✗ L0 DETECTOR CEGO — o decode aceitou um exercício sem `sets`. O L1 não significa nada.")
}

let treinos = try? JSONDecoder().decode([CustomWorkout].self, from: Data(antigo.utf8))
confere(treinos != nil, "L1 o customWorkouts gravado antes desta mudança decodifica")
confere(treinos?.count == 1 && treinos?.first?.name == "Peito e costas",
        "L1 o nome do treino sobreviveu", "\(String(describing: treinos?.first?.name))")
confere(treinos?.first?.exercises.count == 2, "L1 os dois exercícios sobreviveram", "\(String(describing: treinos?.first?.exercises.count))")
let supino = treinos?.first?.exercises.first
confere(supino?.name == "Supino com halteres" && supino?.sets == 4 && supino?.reps == "10 reps"
        && supino?.equipment == .halteres && supino?.instructions.count == 2,
        "L1 nome, séries, reps, equipamento e instruções intactos", "\(String(describing: supino))")
confere(treinos?.first?.exercises.last?.equipment == .corporal,
        "L1 \"Peso corporal\" continua sendo `.corporal`")
confere(treinos?.first?.id.uuidString == "0A1C2E3F-1111-4222-8333-444455556666",
        "L1 o id do treino é o gravado, não um novo")

// L2 · ida e volta: reescrever não perde nada
if let treinos, let reenc = try? JSONEncoder().encode(treinos),
   let relidos = try? JSONDecoder().decode([CustomWorkout].self, from: reenc) {
    confere(relidos == treinos, "L2 codificar e decodificar de novo dá o mesmo treino")
} else {
    confere(false, "L2 ida e volta", "não codificou/decodificou")
}

// ═══════════════════════════════════════════════════════════════════════════
print("\n══════════════════════════════════════════════")
print("  \(passou) verdes · \(falhou.count) vermelhas")
if !falhou.isEmpty {
    print("  VERMELHAS:")
    falhou.forEach { print("    · \($0)") }
}
print("  O QUE ESTE HARNESS NÃO EXECUTA, declarado:")
print("    · nenhuma View — se o botão \"Completar série\" chama `registrarSerie`")
print("      é a auditoria S1–S3 no simulador que prova, não isto;")
print("    · `AppModel.registrarSerie` (SwiftUI) — idem, S1–S3;")
print("    · a exclusão de conta (chave na lista do LocalDataCleanupService) — B9e.")
print("══════════════════════════════════════════════")
UserDefaults().removePersistentDomain(forName: suite)
exit(falhou.isEmpty ? 0 : 1)
