// testes_padrao.swift
// Alma — o padrão do exercício (N séries × M reps × carga) fora do simulador.
//
// Compila o código de produção (`Exercicio.swift`, `RegistroDeSeries.swift`,
// `PadraoDoExercicio.swift`) com `swiftc` e prova:
//
//   P · as regras puras (parsing, aplicar sobre o catálogo, resumo, oferta);
//   G · GRAVOU O QUE A PESSOA DEFINIU — lido de volta por OUTRA instância do
//       store, como o app reaberto. Nunca pelo cache: é exatamente essa a
//       família de asserção que já saiu verde sem gravar nada neste projeto;
//   T · um padrão ilegível não derruba os outros;
//   L · O QUE ESTE TRABALHO NÃO PODIA QUEBRAR — o `customWorkouts` gravado
//       ANTES desta mudança continua legível, com canário (L0) provando que o
//       detector enxerga. `Exercise` não ganhou campo nenhum, e é isto que
//       impede que alguém acrescente um sem ver o estrago.
//
// Rodar:  _scripts/rodar_testes_padrao.sh
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

let suite = "teste.padrao.alma"
UserDefaults().removePersistentDomain(forName: suite)
guard let store = UserDefaults(suiteName: suite) else {
    print("✗✗ não consegui criar a suíte de teste")
    exit(1)
}

let t0 = Date(timeIntervalSince1970: 1_756_400_000)

/// O supino como o CATÁLOGO prescreve — 4×8. É dele que o padrão discorda.
let supinoDoCatalogo = Exercise(
    name: "Supino com halteres", sets: 4, reps: "8 reps", equipment: .halteres,
    muscle: "Peito e tríceps", symbol: "figure.strengthtraining.traditional",
    instructions: ["Deite no banco.", "Empurre para cima."])

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ P · REGRAS ═══")

// P1 · o campo "séries"
confere(RegrasDePadrao.series(de: "3") == 3, "P1 \"3\" → 3", "\(String(describing: RegrasDePadrao.series(de: "3")))")
confere(RegrasDePadrao.series(de: " 3 ") == 3, "P1 espaços em volta são ignorados")
confere(RegrasDePadrao.series(de: "") == nil, "P1 em branco → nil (não defini)")
confere(RegrasDePadrao.series(de: "0") == nil, "P1 zero série não é treino")
confere(RegrasDePadrao.series(de: "-2") == nil, "P1 negativo é recusado")
confere(RegrasDePadrao.series(de: "999") == nil, "P1 acima do teto é recusado",
        "\(String(describing: RegrasDePadrao.series(de: "999")))")
confere(RegrasDePadrao.series(de: "50") == 50, "P1 o teto exato passa")
confere(RegrasDePadrao.series(de: "abc") == nil, "P1 letra não é número")

// P2 · o campo "reps" — texto livre, como o catálogo
confere(RegrasDePadrao.reps(de: "8") == "8", "P2 \"8\" sobrevive inteiro")
confere(RegrasDePadrao.reps(de: "10-12") == "10-12", "P2 a FAIXA sobrevive — é o que o Assis digita")
confere(RegrasDePadrao.reps(de: " 30 s ") == "30 s", "P2 apara as pontas, preserva o miolo")
confere(RegrasDePadrao.reps(de: "") == nil, "P2 em branco → nil")
confere(RegrasDePadrao.reps(de: "   ") == nil, "P2 só espaço → nil")
confere(RegrasDePadrao.reps(de: String(repeating: "x", count: 25)) == nil,
        "P2 bilhete de 25 caracteres é recusado")

// P3 · a carga usa o MESMO parser do registro (uma regra, não duas)
confere(RegrasDePadrao.carga(de: "60") == 60, "P3 \"60\" → 60")
confere(RegrasDePadrao.carga(de: "12,5") == 12.5, "P3 vírgula decimal PT-BR")
confere(RegrasDePadrao.carga(de: "-10") == nil, "P3 negativo é recusado")
confere(RegrasDePadrao.carga(de: "") == nil, "P3 em branco → nil")

// P4 · montar: os três em branco NÃO viram padrão
confere(RegrasDePadrao.montar(exercicio: "Supino", series: nil, reps: nil, cargaKg: nil) == nil,
        "P4 tudo em branco não é padrão — é a volta ao catálogo")
confere(RegrasDePadrao.montar(exercicio: "Supino", series: 3, reps: nil, cargaKg: nil) != nil,
        "P4 só as séries já é um padrão")
confere(RegrasDePadrao.montar(exercicio: "Supino", series: nil, reps: nil, cargaKg: 60) != nil,
        "P4 só a carga já é um padrão")
let montado = RegrasDePadrao.montar(exercicio: "Supino com halteres", series: 3,
                                    reps: "8", cargaKg: 60, em: t0)
confere(montado?.exercicioSlug == "supino-com-halteres",
        "P4 o slug é calculado do nome, na escrita", "\(String(describing: montado?.exercicioSlug))")
confere(montado?.exercicio == "Supino com halteres", "P4 o nome exibido vai junto")

// P5 · aplicar: o padrão VENCE o catálogo, campo a campo
let comPadrao = RegrasDePadrao.aplicar(montado, em: supinoDoCatalogo)
confere(comPadrao.sets == 3 && comPadrao.reps == "8",
        "P5 3×8 da pessoa vence 4×8 reps do catálogo", "\(comPadrao.sets)×\(comPadrao.reps)")
confere(comPadrao.id == supinoDoCatalogo.id,
        "P5 o `id` NÃO muda — trocá-lo reanimaria a lista a cada render")
confere(comPadrao.equipment == .halteres && comPadrao.muscle == "Peito e tríceps"
        && comPadrao.symbol == supinoDoCatalogo.symbol
        && comPadrao.instructions == supinoDoCatalogo.instructions,
        "P5 equipamento, músculo, símbolo e instruções NUNCA vêm do padrão")
confere(RegrasDePadrao.aplicar(nil, em: supinoDoCatalogo) == supinoDoCatalogo,
        "P5 sem padrão, o exercício é o do catálogo, intacto")
let soCarga = RegrasDePadrao.montar(exercicio: "Supino com halteres", series: nil,
                                    reps: nil, cargaKg: 60, em: t0)
let aplicadoSoCarga = RegrasDePadrao.aplicar(soCarga, em: supinoDoCatalogo)
confere(aplicadoSoCarga.sets == 4 && aplicadoSoCarga.reps == "8 reps",
        "P5 padrão só de CARGA não mexe em séries nem reps",
        "\(aplicadoSoCarga.sets)×\(aplicadoSoCarga.reps)")

// P6 · resumo
confere(RegrasDePadrao.resumo(montado) == "3 séries · 8 · 60 kg",
        "P6 \"3 séries · 8 · 60 kg\"", "\(String(describing: RegrasDePadrao.resumo(montado)))")
confere(RegrasDePadrao.resumo(soCarga) == "60 kg",
        "P6 só o que foi definido — nunca a parte que falta",
        "\(String(describing: RegrasDePadrao.resumo(soCarga)))")
confere(RegrasDePadrao.resumo(nil) == nil, "P6 sem padrão, sem resumo")
let umaSerie = RegrasDePadrao.montar(exercicio: "Prancha", series: 1, reps: nil, cargaKg: nil, em: t0)
confere(RegrasDePadrao.resumo(umaSerie) == "1 série", "P6 singular em PT-BR: \"1 série\"",
        "\(String(describing: RegrasDePadrao.resumo(umaSerie)))")

// P7 · pré-preenchimento da sessão
confere(RegrasDePadrao.cargaPrePreenchida(montado) == "60", "P7 a carga-alvo vem no campo")
confere(RegrasDePadrao.cargaPrePreenchida(nil) == "", "P7 sem padrão, campo vazio")
confere(RegrasDePadrao.cargaPrePreenchida(umaSerie) == "", "P7 padrão sem carga, campo vazio")
confere(RegrasDePadrao.repsPrePreenchidas(montado) == "8", "P7 \"8\" é número limpo, vem no campo")
let faixa = RegrasDePadrao.montar(exercicio: "Flexão", series: 3, reps: "10-12", cargaKg: nil, em: t0)
confere(RegrasDePadrao.repsPrePreenchidas(faixa) == "",
        "P7 FAIXA \"10-12\" NÃO pré-preenche — o app não escolhe dentro da faixa por ela",
        "\"\(RegrasDePadrao.repsPrePreenchidas(faixa))\"")
let frase = RegrasDePadrao.montar(exercicio: "Burpee", series: 3, reps: "max reps", cargaKg: nil, em: t0)
confere(RegrasDePadrao.repsPrePreenchidas(frase) == "", "P7 \"max reps\" não pré-preenche")

// P8 · a OFERTA (e tudo que NÃO é oferta)
func serie(_ nome: String, _ quando: Date, kg: Double?, numero: Int = 1) -> SerieRegistrada {
    SerieRegistrada(sessao: UUID(), quando: quando, treino: "T",
                    exercicioSlug: slugDeExercicio(nome), exercicio: nome,
                    numero: numero, repeticoes: 8, segundos: nil, cargaKg: kg)
}
let slugSupino = slugDeExercicio("Supino com halteres")
let tres65 = (0..<3).map { serie("Supino com halteres", t0.addingTimeInterval(Double($0) * 300), kg: 65) }
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: tres65, exercicioSlug: slugSupino, padrao: montado) == 65,
        "P8 três séries seguidas a 65 kg com padrão de 60 → OFERECE 65")
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: Array(tres65.prefix(2)),
                                             exercicioSlug: slugSupino, padrao: montado) == nil,
        "P8 duas não bastam")
let padrao65 = RegrasDePadrao.montar(exercicio: "Supino com halteres", series: 3, reps: "8", cargaKg: 65, em: t0)
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: tres65, exercicioSlug: slugSupino, padrao: padrao65) == nil,
        "P8 se já bate com o padrão, não há o que oferecer")
let variadas = [serie("Supino com halteres", t0, kg: 60),
                serie("Supino com halteres", t0.addingTimeInterval(300), kg: 65),
                serie("Supino com halteres", t0.addingTimeInterval(600), kg: 70)]
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: variadas, exercicioSlug: slugSupino, padrao: montado) == nil,
        "P8 cargas diferentes não são um hábito — não oferece")
let comBranco = [serie("Supino com halteres", t0, kg: 65),
                 serie("Supino com halteres", t0.addingTimeInterval(300), kg: nil),
                 serie("Supino com halteres", t0.addingTimeInterval(600), kg: 65)]
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: comBranco, exercicioSlug: slugSupino, padrao: montado) == nil,
        "P8 série sem carga no meio quebra a sequência")
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: tres65, exercicioSlug: slugDeExercicio("Remada"),
                                             padrao: nil) == nil,
        "P8 as séries de OUTRO exercício não contam")
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: tres65, exercicioSlug: slugSupino, padrao: nil) == 65,
        "P8 sem padrão nenhum, três séries iguais também rendem oferta")
// A ordem no disco não pode mudar a resposta: são as três MAIS RECENTES.
let foraDeOrdem = [serie("Supino com halteres", t0.addingTimeInterval(600), kg: 65),
                   serie("Supino com halteres", t0, kg: 40),
                   serie("Supino com halteres", t0.addingTimeInterval(300), kg: 65),
                   serie("Supino com halteres", t0.addingTimeInterval(900), kg: 65)]
confere(RegrasDePadrao.sugestaoDeAtualizacao(registros: foraDeOrdem, exercicioSlug: slugSupino, padrao: montado) == 65,
        "P8 é pelo INSTANTE, não pela posição na lista")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ G · GRAVOU MESMO ═══")

let escrita = PadroesDeExercicio(store: store)
guard let padraoDoAssis = RegrasDePadrao.montar(exercicio: "Supino com halteres",
                                                series: 3, reps: "8", cargaKg: 60, em: t0) else {
    print("✗✗ não montou o padrão")
    exit(1)
}
escrita.definir(padraoDoAssis)

// A releitura é por INSTÂNCIA NOVA, como o app reaberto — nunca pelo cache.
let releitura = PadroesDeExercicio(store: store)
let lido = releitura.padrao(paraExercicio: "Supino com halteres")
confere(lido != nil, "G1 o padrão sobrevive a fechar e abrir o app")
confere(lido?.series == 3, "G1 3 séries", "\(String(describing: lido?.series))")
confere(lido?.reps == "8", "G1 8 reps", "\(String(describing: lido?.reps))")
confere(lido?.cargaKg == 60, "G1 60 kg", "\(String(describing: lido?.cargaKg))")
confere(lido?.exercicio == "Supino com halteres", "G1 o nome exibido sobrevive")

// G2 · e é ISSO que a tela mostra depois de reabrir
confere(RegrasDePadrao.aplicar(lido, em: supinoDoCatalogo).sets == 3,
        "G2 na próxima vez, o plano mostra 3 séries — não as 4 do catálogo")
confere(RegrasDePadrao.cargaPrePreenchida(lido) == "60",
        "G2 e a carga já vem preenchida na sessão seguinte")

// G3 · redefinir substitui, não duplica
escrita.definir(RegrasDePadrao.montar(exercicio: "Supino com halteres", series: 4,
                                      reps: "6", cargaKg: 70, em: t0.addingTimeInterval(86_400))!)
let depois = PadroesDeExercicio(store: store).padrao(paraExercicio: "Supino com halteres")
confere(depois?.series == 4 && depois?.reps == "6" && depois?.cargaKg == 70,
        "G3 redefinir substitui o padrão", "\(String(describing: depois))")
confere(PadroesDeExercicio(store: store).todos().count == 1,
        "G3 e não duplica a linha", "\(PadroesDeExercicio(store: store).todos().count)")

// G4 · exercícios diferentes, padrões independentes
escrita.definir(RegrasDePadrao.montar(exercicio: "Remada curvada", series: 3, reps: "12", cargaKg: 40, em: t0)!)
let dois = PadroesDeExercicio(store: store).todos()
confere(dois.count == 2, "G4 dois exercícios, dois padrões", "\(dois.count)")
confere(dois[slugDeExercicio("Remada curvada")]?.cargaKg == 40, "G4 a remada tem a carga da remada")
confere(dois[slugSupino]?.cargaKg == 70, "G4 e o supino continua com a dele")

// G5 · remover é voltar ao catálogo
escrita.remover(slug: slugDeExercicio("Remada curvada"))
let apos = PadroesDeExercicio(store: store)
confere(apos.padrao(paraExercicio: "Remada curvada") == nil, "G5 removido, o padrão some do disco")
confere(apos.padrao(paraExercicio: "Supino com halteres") != nil, "G5 e o do vizinho fica")

// G6 · o REGISTRO do dia NÃO mexe no padrão (é o ponto do desenho inteiro)
let registro = RegistroDeSeries(store: store)
registro.registrar(serie("Supino com halteres", t0.addingTimeInterval(3600), kg: 45))
let padraoDepoisDoTreino = PadroesDeExercicio(store: store).padrao(paraExercicio: "Supino com halteres")
confere(padraoDepoisDoTreino?.cargaKg == 70,
        "G6 registrar 45 kg num dia ruim NÃO estraga o padrão de 70",
        "\(String(describing: padraoDepoisDoTreino?.cargaKg))")
confere(registro.ultima(exercicioSlug: slugSupino)?.cargaKg == 45,
        "G6 e o registro do dia continua sendo o que aconteceu: 45")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ T · TOLERÂNCIA ═══")

// T1 · um padrão ilegível no meio não derruba os outros
let comLixo = #"""
[{"exercicioSlug":"supino","exercicio":"Supino","series":3,"reps":"8","cargaKg":60,"atualizadoEm":1756400000},
 {"exercicio":null,"exercicioSlug":null},
 {"exercicioSlug":"remada","exercicio":"Remada","series":4,"atualizadoEm":1756400000}]
"""#
let tolerado = PadroesDeExercicio.decodificar(Data(comLixo.utf8))
confere(tolerado.count == 2, "T1 a linha corrompida cai sozinha; as outras ficam", "\(tolerado.count)")
confere(tolerado["supino"]?.cargaKg == 60, "T1 o supino sobreviveu")
confere(tolerado["remada"]?.series == 4 && tolerado["remada"]?.cargaKg == nil,
        "T1 a remada sobreviveu — sem carga é `nil`, não zero")

// T2 · lista inteira ilegível → vazio, não estouro
confere(PadroesDeExercicio.decodificar(Data("não sou json".utf8)).isEmpty,
        "T2 lixo total devolve vazio, e a próxima escrita recomeça")

// T3 · campo desconhecido (build antigo lendo o disco de um build novo)
let comCampoNovo = #"[{"exercicioSlug":"supino","exercicio":"Supino","series":3,"cargaKg":60,"atualizadoEm":1756400000,"campoQueAindaNaoExiste":"x"}]"#
confere(PadroesDeExercicio.decodificar(Data(comCampoNovo.utf8))["supino"]?.series == 3,
        "T3 campo que este build não conhece é ignorado, não fatal")

// T4 · `atualizadoEm` ausente não derruba a linha
let semData = #"[{"exercicioSlug":"supino","exercicio":"Supino","series":3}]"#
confere(PadroesDeExercicio.decodificar(Data(semData.utf8))["supino"]?.series == 3,
        "T4 sem `atualizadoEm` a linha continua válida")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ L · O QUE ISTO NÃO PODIA QUEBRAR ═══")
//
// Esta é A asserção do trabalho. O pedido era "definir séries, reps e carga por
// exercício", e o caminho óbvio — campo novo em `Exercise` — apagaria em
// silêncio todo treino montado, porque `AppModel.init` decodifica
// `customWorkouts` com `try?`. `Exercise` NÃO ganhou campo nenhum; o padrão
// mora em coleção própria. O JSON abaixo é o formato gravado ANTES desta
// mudança, e tem de continuar abrindo com o código de DEPOIS.

let antigo = #"""
[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"Peito e costas","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino com halteres","sets":4,"reps":"10 reps","equipment":"Halteres","muscle":"Peito e tríceps","symbol":"figure.strengthtraining.traditional","instructions":["Deite no banco com um halter em cada mão, na linha do peito.","Empurre os halteres para cima até estender os cotovelos."]},{"id":"0A1C2E3F-1111-4222-8333-444455558888","name":"Prancha","sets":3,"reps":"45 s","equipment":"Peso corporal","muscle":"Core","symbol":"figure.core.training","instructions":["Apoie antebraços e pontas dos pés no chão."]}]}]
"""#

// L0 · CANÁRIO: o decodificador NÃO é cego. Se ISTO passar, o L1 não prova nada.
let semSets = #"[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"X","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino","reps":"10 reps","equipment":"Halteres","muscle":"Peito","symbol":"s","instructions":[]}]}]"#
if (try? JSONDecoder().decode([CustomWorkout].self, from: Data(semSets.utf8))) == nil {
    passou += 1
    print("  ✓ L0 canário vivo — campo não-opcional ausente derruba o decode (é a armadilha)")
} else {
    falhou.append("L0 DETECTOR CEGO")
    print("  ✗✗ L0 DETECTOR CEGO — o decode aceitou um exercício sem `sets`. O L1 não significa nada.")
}

let treinos = try? JSONDecoder().decode([CustomWorkout].self, from: Data(antigo.utf8))
confere(treinos != nil, "L1 o customWorkouts gravado ANTES do padrão continua decodificando")
confere(treinos?.first?.exercises.count == 2, "L1 os dois exercícios sobreviveram",
        "\(String(describing: treinos?.first?.exercises.count))")
let supinoAntigo = treinos?.first?.exercises.first
confere(supinoAntigo?.sets == 4 && supinoAntigo?.reps == "10 reps"
        && supinoAntigo?.equipment == .halteres && supinoAntigo?.instructions.count == 2,
        "L1 séries, reps, equipamento e instruções intactos", "\(String(describing: supinoAntigo))")
confere(treinos?.first?.id.uuidString == "0A1C2E3F-1111-4222-8333-444455556666",
        "L1 o id do treino é o gravado, não um novo")

// L2 · e o padrão se aplica POR CIMA desse treino antigo, sem tocar no disco dele
if let antigoSupino = supinoAntigo {
    let vestido = RegrasDePadrao.aplicar(
        RegrasDePadrao.montar(exercicio: antigoSupino.name, series: 3, reps: "8", cargaKg: 60, em: t0),
        em: antigoSupino)
    confere(vestido.sets == 3 && vestido.reps == "8",
            "L2 o padrão veste o treino ANTIGO sem migração de disco",
            "\(vestido.sets)×\(vestido.reps)")
    confere(antigoSupino.sets == 4 && antigoSupino.reps == "10 reps",
            "L2 e o exercício gravado continua exatamente como estava")
} else {
    confere(false, "L2 vestir o treino antigo", "não havia supino antigo")
}

// L3 · o `Exercise` de hoje ainda decodifica o JSON antigo campo a campo — a
// prova direta de que nenhum campo foi acrescentado a ele por este trabalho.
let exAntigo = #"{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino","sets":4,"reps":"8 reps","equipment":"Barra","muscle":"Peito","symbol":"s","instructions":[]}"#
confere((try? JSONDecoder().decode(Exercise.self, from: Data(exAntigo.utf8)))?.sets == 4,
        "L3 `Exercise` com os 8 campos de sempre — nenhum campo novo foi exigido")

// ═══════════════════════════════════════════════════════════════════════════
print("\n══════════════════════════════════════════════")
print("  \(passou) verdes · \(falhou.count) vermelhas")
if !falhou.isEmpty {
    print("  VERMELHAS:")
    falhou.forEach { print("    · \($0)") }
}
print("  O QUE ESTE HARNESS NÃO EXECUTA, declarado:")
print("    · nenhuma View — que o botão \"Salvar\" do editor chame `definirPadrao`")
print("      é a captura no simulador que prova, não isto;")
print("    · `AppModel.definirPadrao` (SwiftUI) — idem;")
print("    · a exclusão de conta (chave na lista do LocalDataCleanupService).")
print("══════════════════════════════════════════════")
UserDefaults().removePersistentDomain(forName: suite)
exit(falhou.isEmpty ? 0 : 1)
