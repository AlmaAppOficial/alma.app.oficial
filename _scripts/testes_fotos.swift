// testes_fotos.swift
// Alma — as fotos dos exercícios exercitadas FORA do simulador.
//
// Compila o código de PRODUÇÃO (`Exercicio.swift`, `ExerciseLibraryV2.swift`)
// com `swiftc` e prova, em ordem de importância:
//
//   F1 · o `customWorkouts` gravado ANTES desta mudança continua legível.
//        É a família de defeito que já apagou dado neste projeto: campo novo
//        NÃO-OPCIONAL num tipo persistido faz o decodificador sintetizado
//        lançar `keyNotFound`, o `try?` de `AppModel.init` engole o erro, e a
//        pessoa abre o app com "Meus treinos" vazio — sem mensagem, sem volta.
//   F2 · `Exercise` continua com EXATAMENTE as 8 chaves de sempre, e `fotos`
//        não é uma delas. É a asserção que impede o defeito de F1 de nascer.
//   F3 · a ponte V2 → legado (`asLegacyExercise`), que é o que roda quando a
//        pessoa salva um treino, não carrega foto para o disco.
//   F4 · `fotos` é OPCIONAL de verdade: 581 dos 1.095 não têm o campo.
//   F5 · todo arquivo citado pelo catálogo existe na pasta do bundle.
//   F6 · nenhum dos 1.095 sumiu, mudou de id ou de nome — a fusão não virou
//        substituição.
//
// Cada bloco começa por um CANÁRIO que prova que a asserção enxerga. Um teste
// que lê arquivo passa verde quando não acha arquivo nenhum; aqui isso é
// reprovação explícita e barulhenta.
//
// Rodar:   _scripts/rodar_testes_fotos.sh
// Mutação: _scripts/mutacao_fotos.sh
// Saída:   0 = verde · 1 = vermelho
//
// ═══════════════════════════════════════════════════════════════════════════
// DUAS TENTATIVAS QUE FALHARAM EM 02/09 — para ninguém repetir
// ═══════════════════════════════════════════════════════════════════════════
//
// 1. **`xcodebuild` do simulador não coube no disco.** Chegou a 2,0 GB de
//    DerivedData e ainda estava compilando, com o Mac em 1,6 GB livres; foi
//    abortado e a DerivedData apagada. Orçar >2,5 GB antes de tentar de novo.
//    Consequência: as telas do iOS não têm captura, e o `project.pbxproj`
//    (a referência de pasta que leva `ExerciciosFotos` para o bundle) está
//    verificado só por `plutil -lint`, não por build.
//
// 2. **`swiftc -typecheck` do módulo NÃO é substituto — e mente.** Excluindo
//    os arquivos que importam FirebaseAuth/HealthKit/StoreKit, o compilador
//    devolveu "zero erros" nos arquivos desta mudança. Parecia prova. Um erro
//    de tipo PLANTADO de propósito (`let x: Int = "texto"`) em
//    `FotoDoExercicio.swift` **não foi acusado**: com erro de resolução de
//    nome no módulo, o `swiftc` não chega a verificar o corpo das declarações.
//    O "zero erros" media o compilador ter desistido antes.
//
//    Fechar a lacuna com stubs não fecha: o fecho transitivo de dependências
//    de `Shared/Corpo` engole 54 dos 61 arquivos, incluindo os 9 desta
//    mudança. Ou é build, ou não é verificação. O script que tentava isso foi
//    apagado em vez de ficar como papel pintado.
//
//    (O que ESTE arquivo compila é real: `swiftc` monta `Exercicio.swift` e
//    `ExerciseLibraryV2.swift` de verdade, sem stub nenhum, e as asserções
//    rodam contra o binário. É o modelo que está provado, não as Views.)

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

func canario(_ deveFalhar: Bool, _ nome: String, _ explicacao: String) {
    if deveFalhar {
        passou += 1
        print("  ✓ \(nome)")
    } else {
        falhou.append("\(nome) DETECTOR CEGO")
        print("  ✗✗ \(nome) DETECTOR CEGO — \(explicacao)")
    }
}

// ── Argumentos: catálogo novo, catálogo de HEAD, pasta das fotos ───────────
let args = CommandLine.arguments
guard args.count >= 4 else {
    print("uso: testes_fotos <catalogo_novo.json> <catalogo_head.json> <pasta_de_fotos>")
    exit(3)
}
let caminhoNovo = args[1], caminhoHead = args[2], pastaFotos = args[3]

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F0 · CONTROLE POSITIVO — os arquivos foram lidos mesmo ═══")

guard let dadosNovo = FileManager.default.contents(atPath: caminhoNovo) else {
    print("  ✗✗ F0 catálogo novo não abriu em \(caminhoNovo). NADA abaixo prova coisa alguma.")
    exit(1)
}
guard let dadosHead = FileManager.default.contents(atPath: caminhoHead) else {
    print("  ✗✗ F0 catálogo de HEAD não abriu em \(caminhoHead). NADA abaixo prova coisa alguma.")
    exit(1)
}
let catalogo = (try? JSONDecoder().decode([ExerciseV2].self, from: dadosNovo)) ?? []
let catalogoHead = (try? JSONDecoder().decode([ExerciseV2].self, from: dadosHead)) ?? []
confere(catalogo.count > 1000, "F0 catálogo novo tem os 1.095 (\(catalogo.count))", "\(catalogo.count)")
confere(catalogoHead.count > 1000, "F0 catálogo de HEAD tem os 1.095 (\(catalogoHead.count))", "\(catalogoHead.count)")
confere(catalogo.count == catalogoHead.count,
        "F0 os dois catálogos têm o MESMO tamanho — fusão, não substituição",
        "novo \(catalogo.count) vs head \(catalogoHead.count)")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F1 · O TREINO GRAVADO ANTES DESTA MUDANÇA CONTINUA LEGÍVEL ═══")
//
// O JSON abaixo é o formato que o build 103 grava em `customWorkouts`:
// `JSONEncoder` sintetizado sobre `CustomWorkout { id, name, exercises }` e
// `Exercise { id, name, sets, reps, equipment, muscle, symbol, instructions }`.
// Foi copiado da asserção L1 de `testes_series.swift` de propósito: o mesmo
// dado tem de sobreviver a TODA mudança, não só àquela.

let treinoAntigo = #"""
[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"Peito e costas","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino com halteres","sets":4,"reps":"10 reps","equipment":"Halteres","muscle":"Peito e tríceps","symbol":"figure.strengthtraining.traditional","instructions":["Deite no banco com um halter em cada mão, na linha do peito.","Empurre os halteres para cima até estender os cotovelos."]},{"id":"0A1C2E3F-1111-4222-8333-444455558888","name":"Flexão de braço","sets":3,"reps":"15 reps","equipment":"Peso corporal","muscle":"Peito","symbol":"figure.core.training","instructions":["Mãos na largura dos ombros, corpo reto."]}]}]
"""#

// CANÁRIO: o decodificador NÃO é cego. Um exercício sem `sets` (campo
// não-opcional) TEM de derrubar o decode. Se isto passar, F1 não prova nada —
// e a prova de que o campo novo é inofensivo teria medido o nada.
let semSets = #"[{"id":"0A1C2E3F-1111-4222-8333-444455556666","name":"X","exercises":[{"id":"0A1C2E3F-1111-4222-8333-444455557777","name":"Supino","reps":"10 reps","equipment":"Halteres","muscle":"Peito","symbol":"s","instructions":[]}]}]"#
canario((try? JSONDecoder().decode([CustomWorkout].self, from: Data(semSets.utf8))) == nil,
        "F1c canário vivo — campo não-opcional ausente derruba o decode",
        "o decode aceitou um exercício sem `sets`; F1 não significa nada.")

let treinos = try? JSONDecoder().decode([CustomWorkout].self, from: Data(treinoAntigo.utf8))
confere(treinos != nil, "F1 o customWorkouts do build 103 decodifica com o código de hoje")
confere(treinos?.first?.name == "Peito e costas", "F1 o nome do treino sobreviveu",
        "\(String(describing: treinos?.first?.name))")
confere(treinos?.first?.exercises.count == 2, "F1 os dois exercícios sobreviveram",
        "\(String(describing: treinos?.first?.exercises.count))")
let supino = treinos?.first?.exercises.first
confere(supino?.name == "Supino com halteres" && supino?.sets == 4 && supino?.reps == "10 reps"
        && supino?.equipment == .halteres && supino?.instructions.count == 2,
        "F1 nome, séries, reps, equipamento e instruções intactos", "\(String(describing: supino))")
confere(treinos?.first?.id.uuidString == "0A1C2E3F-1111-4222-8333-444455556666",
        "F1 o id do treino é o gravado, não um novo")

// F1b · e o exercício gravado é justamente um que GANHOU foto no catálogo.
// Se a foto tivesse vazado para o tipo persistido, seria aqui que apareceria.
confere(treinos?.first?.exercises.last?.name == "Flexão de braço",
        "F1b o treino antigo cita um exercício que hoje TEM foto no catálogo")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F2 · `Exercise` NÃO GANHOU CAMPO — as 8 chaves de sempre ═══")
//
// Esta é a asserção que a mutação M1 ataca. Se alguém acrescentar `fotos` (ou
// qualquer outro campo) ao `Exercise`, ela fica vermelha ANTES de o dado de
// alguém ser apagado em produção.

let chavesEsperadas: Set<String> = ["id", "name", "sets", "reps", "equipment",
                                    "muscle", "symbol", "instructions"]
let umExercicio = Exercise(name: "Flexão de braço", sets: 3, reps: "15 reps",
                           equipment: .corporal, muscle: "Peito",
                           symbol: "figure.core.training",
                           instructions: ["Mãos na largura dos ombros."])
let cru = try? JSONSerialization.jsonObject(
    with: JSONEncoder().encode(umExercicio)) as? [String: Any]
let chaves = Set((cru ?? [:]).keys)
confere(chaves == chavesEsperadas,
        "F2 `Exercise` grava exatamente as 8 chaves de sempre",
        "gravou \(chaves.sorted())")
confere(!chaves.contains("fotos"),
        "F2 `fotos` NÃO está no formato persistido", "chaves: \(chaves.sorted())")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F3 · A PONTE V2 → LEGADO NÃO LEVA FOTO PARA O DISCO ═══")
//
// `asLegacyExercise()` é o que roda quando a pessoa toca "salvar treino".
// Um V2 COM foto tem de virar um legado sem nenhum vestígio dela.

guard let comFoto = catalogo.first(where: { ($0.fotos?.isEmpty == false) }) else {
    print("  ✗✗ F3 nenhum exercício do catálogo tem foto. O bloco inteiro mediria o nada.")
    falhou.append("F3 SEM DADO")
    exit(1)
}
let legado = comFoto.asLegacyExercise()
let cruLegado = try? JSONSerialization.jsonObject(
    with: JSONEncoder().encode(legado)) as? [String: Any]
confere(Set((cruLegado ?? [:]).keys) == chavesEsperadas,
        "F3 V2 com foto → legado grava as mesmas 8 chaves",
        "gravou \(Set((cruLegado ?? [:]).keys).sorted())")
let textoLegado = String(data: (try? JSONEncoder().encode(legado)) ?? Data(), encoding: .utf8) ?? ""
confere(!textoLegado.contains(".webp") && !textoLegado.contains("fotos"),
        "F3 nem o nome do arquivo nem a chave aparecem no JSON gravado",
        textoLegado.prefix(240).description)
confere(!comFoto.displaySymbol.contains(".webp"),
        "F3 `displaySymbol` continua sendo símbolo, não caminho de imagem",
        comFoto.displaySymbol)

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F4 · `fotos` É OPCIONAL DE VERDADE ═══")
//
// 581 dos 1.095 não têm o campo. Se ele virasse obrigatório, o catálogo
// inteiro pararia de decodificar e a biblioteca cairia no fallback legado —
// silenciosamente, porque `load()` usa `try?`.

let semCampo = #"""
[{"id":"x","namePTBR":"Sem foto","type":"forca","primaryMuscles":["peito"],"secondaryMuscles":[],"equipment":"Peso corporal","difficulty":"iniciante","media":{"kind":"sfSymbol","value":"figure.core.training"},"instructions":["a"],"defaultSets":3,"defaultReps":"12 reps","sourceAttribution":"teste"}]
"""#
let semFoto = try? JSONDecoder().decode([ExerciseV2].self, from: Data(semCampo.utf8))
confere(semFoto?.count == 1, "F4 um ExerciseV2 SEM a chave `fotos` decodifica")
confere(semFoto?.first?.fotos == nil, "F4 e `fotos` fica nil, não vazio",
        "\(String(describing: semFoto?.first?.fotos))")

// CANÁRIO do F4: um campo que É obrigatório, ausente, TEM de derrubar. Sem
// isto, "decodificou sem `fotos`" poderia significar só que o decodificador
// aceita qualquer coisa.
let semNome = #"[{"id":"x","type":"forca","equipment":"Peso corporal"}]"#
canario((try? JSONDecoder().decode([ExerciseV2].self, from: Data(semNome.utf8))) == nil,
        "F4c canário vivo — sem `namePTBR` nem `name` o decode falha",
        "o decodificador aceitou um objeto sem nome nenhum.")

let comFotos = catalogo.filter { ($0.fotos?.isEmpty == false) }
confere(!comFotos.isEmpty && comFotos.count < catalogo.count,
        "F4 o catálogo tem os dois estados: \(comFotos.count) com foto, \(catalogo.count - comFotos.count) sem",
        "\(comFotos.count)/\(catalogo.count)")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F5 · TODO ARQUIVO CITADO EXISTE NA PASTA DO BUNDLE ═══")
//
// Um catálogo que aponta para arquivo inexistente não quebra nada visível: a
// tela desenha o corpo anatômico e ninguém descobre. Por isso a conferência é
// contra o disco, não contra a própria lista.

let citados = Set(catalogo.compactMap(\.fotos).flatMap { $0 })
let faltando = citados.filter { !FileManager.default.fileExists(atPath: pastaFotos + "/" + $0) }
confere(!citados.isEmpty, "F5 o catálogo cita arquivos (\(citados.count))", "\(citados.count)")
confere(faltando.isEmpty, "F5 os \(citados.count) arquivos citados existem em disco",
        "faltam \(faltando.count): \(faltando.sorted().prefix(5))")

// CANÁRIO do F5: um nome inventado TEM de ser acusado como ausente. Se não
// for, o teste está medindo a existência da pasta, não a dos arquivos.
canario(!FileManager.default.fileExists(atPath: pastaFotos + "/nao-existe-de-proposito.webp"),
        "F5c canário vivo — arquivo inventado é acusado como ausente",
        "o FileManager disse que um arquivo inventado existe.")

confere(citados.allSatisfy { $0.hasSuffix(".webp") },
        "F5 todo arquivo citado é .webp (o formato que o bundle carrega)")

// ═══════════════════════════════════════════════════════════════════════════
print("\n═══ F6 · OS 1.095 CONTINUAM OS MESMOS — fusão, não substituição ═══")

let idsHead = catalogoHead.map(\.id)
let idsNovo = catalogo.map(\.id)
confere(idsHead == idsNovo, "F6 a lista de ids é idêntica, na mesma ordem",
        "\(zip(idsHead, idsNovo).first(where: { $0 != $1 }).map { "\($0)" } ?? "?")")

let nomesHead = Dictionary(uniqueKeysWithValues: catalogoHead.map { ($0.id, $0.namePTBR) })
let nomesMudados = catalogo.filter { nomesHead[$0.id] != $0.namePTBR }
confere(nomesMudados.isEmpty,
        "F6 nenhum nome exibido mudou (o histórico de séries é indexado pelo slug do nome)",
        "mudaram \(nomesMudados.count): \(nomesMudados.prefix(3).map(\.id))")

let instrHead = Dictionary(uniqueKeysWithValues: catalogoHead.map { ($0.id, $0.instructions) })
let instrMudadas = catalogo.filter { instrHead[$0.id] != $0.instructions }
confere(instrMudadas.isEmpty, "F6 nenhum passo a passo foi reescrito",
        "mudaram \(instrMudadas.count)")

let midiaHead = Dictionary(uniqueKeysWithValues: catalogoHead.map { ($0.id, $0.media) })
let midiaMudada = catalogo.filter { midiaHead[$0.id] != $0.media }
confere(midiaMudada.isEmpty,
        "F6 `media` intocada — é ela que vira `symbol` dentro de customWorkouts",
        "mudaram \(midiaMudada.count)")

// Os órfãos continuam no catálogo, com o dado que sempre tiveram.
let semFotoAgora = catalogo.filter { ($0.fotos ?? []).isEmpty }
confere(semFotoAgora.count + comFotos.count == catalogo.count,
        "F6 quem não ganhou foto continua no catálogo (\(semFotoAgora.count) deles)")

// ═══════════════════════════════════════════════════════════════════════════
print("\n══════════════════════════════════════════════")
print("  \(passou) verdes · \(falhou.count) vermelhas")
if !falhou.isEmpty {
    print("  VERMELHAS:")
    falhou.forEach { print("    · \($0)") }
}
print("  O QUE ESTE HARNESS NÃO EXECUTA, declarado:")
print("    · nenhuma View — que a miniatura DESENHE a foto é prova de captura")
print("      de tela, não daqui;")
print("    · o carregamento pelo `Bundle.main` do app (aqui o bundle é o do")
print("      executável de teste) — o que se prova é que o ARQUIVO existe no")
print("      caminho que a referência de pasta do Xcode copia;")
print("    · a qualidade visual do recorte — isso é a folha de contato.")
print("══════════════════════════════════════════════")
exit(falhou.isEmpty ? 0 : 1)
