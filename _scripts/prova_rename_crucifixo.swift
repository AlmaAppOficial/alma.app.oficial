// prova_rename_crucifixo.swift — 2026-09-03
//
// Pergunta ÚNICA: o que acontece com um dado JÁ GRAVADO que aponta para
// "Crucifixo" depois de renomear o exercício?
//
// Não deduz do código: carrega bytes no formato antigo e mede o que sai.
//
// Compila com:
//   swiftc -O Shared/Corpo/Exercicio.swift Shared/Corpo/RegistroDeSeries.swift \
//          _scripts/prova_rename_crucifixo.swift -o /tmp/prova && /tmp/prova
//
// Os dois arquivos de produção são Foundation-only de propósito (ver o
// cabeçalho de RegistroDeSeries.swift) — é o que torna esta prova possível
// fora do simulador.

import Foundation

var falhas = 0
var checagens = 0
func checa(_ id: String, _ o_que: String, _ ok: Bool) {
    checagens += 1
    print("  \(ok ? "✓" : "✗✗") \(id) — \(o_que)")
    if !ok { falhas += 1 }
}

print("═══ PROVA 1 — customWorkouts gravado ANTES do rename ═══")
print("Um treino que a pessoa montou, com o exercício chamado \"Crucifixo\".")
print("Bytes exatamente como o app gravaria em 02/09 (7 campos, sem id de catálogo).\n")

// Blob no formato persistido de HOJE. Repare: NÃO existe campo de id de
// catálogo. É o ponto — o `Exercise` guarda o NOME, e mais nada que ligue à
// ficha dos 1.095.
let treinoAntigo = """
[{"id":"3D2B0E1A-0000-4000-8000-000000000001","name":"Meu treino",
  "exercises":[
    {"id":"3D2B0E1A-0000-4000-8000-000000000002","name":"Crucifixo","sets":3,
     "reps":"12 reps","equipment":"Peso corporal","muscle":"Ombros",
     "symbol":"figure.strengthtraining.traditional",
     "instructions":["Segure os pesos parados para os lados."]}]}]
""".data(using: .utf8)!

let treinos = try? JSONDecoder().decode([CustomWorkout].self, from: treinoAntigo)
checa("W1", "o treino antigo continua decodificando (não some)", treinos?.count == 1)
checa("W2", "o nome gravado é o NOME, não um id de catálogo",
      treinos?.first?.exercises.first?.name == "Crucifixo")
// A busca de qualquer coisa sobre esse exercício parte daqui:
let slugDoTreinoAntigo = slugDeExercicio(treinos?.first?.exercises.first?.name ?? "")
checa("W3", "o vínculo com o catálogo é calculado do nome: \"\(slugDoTreinoAntigo)\"",
      slugDoTreinoAntigo == "crucifixo")

print("\n═══ PROVA 2 — histórico de séries gravado ANTES do rename ═══")
print("Uma série feita em 01/09, com exercicioSlug \"crucifixo\".\n")

let seriesAntigas = """
[{"id":"3D2B0E1A-0000-4000-8000-000000000010",
  "sessao":"3D2B0E1A-0000-4000-8000-000000000011",
  "quando":1788220800,"treino":"Meu treino",
  "exercicioSlug":"crucifixo","exercicio":"Crucifixo",
  "numero":1,"repeticoes":12,"cargaKg":8}]
""".data(using: .utf8)!

let lidas = RegistroDeSeries.decodificar(seriesAntigas)
checa("S1", "a série antiga decodifica", lidas.count == 1)
checa("S2", "o slug gravado no disco é \"crucifixo\"", lidas.first?.exercicioSlug == "crucifixo")

// ── O TESTE QUE IMPORTA ────────────────────────────────────────────────────
// Depois do rename, a tela procura o histórico assim (WorkoutSessionView:153):
//     model.series.ultima(exercicioSlug: slugDeExercicio(ex.name))
// e `ex.name` agora vem do catálogo como "Isometria em cruz".
let slugDepoisDoRename = slugDeExercicio("Isometria em cruz")
let achouComNomeNovo = RegrasDeSeries.ultima(em: lidas, exercicioSlug: slugDepoisDoRename)

print("\n  chave gravada no disco ....: \"crucifixo\"")
print("  chave procurada pós-rename : \"\(slugDepoisDoRename)\"")
// ESTA é a asserção que decidiu não renomear. Ela afirma o DEFEITO: depois de
// um rename, a série de 01/09 fica órfã. Verde aqui = "sim, quebraria".
checa("S3", "renomear ÓRFA a série de 01/09 (é por isto que não renomeamos)",
      achouComNomeNovo == nil)

// Controle positivo: com o nome ANTIGO ela é encontrada. Sem este, S3 poderia
// estar verde só porque a busca não acha NADA nunca — e não teria medido nada.
let achouComNomeAntigo = RegrasDeSeries.ultima(em: lidas, exercicioSlug: slugDeExercicio("Crucifixo"))
checa("S4", "CONTROLE POSITIVO — com o nome atual ela É encontrada (senão S3 é cega)",
      achouComNomeAntigo != nil)

print("\n═══ PROVA 3 — por que o mapa de alias não salva ═══")
// O alias mapeia VELHO→NOVO. O disco guarda o VELHO. Aplicá-lo na ida leva a
// busca para longe do que está gravado, não para perto.
let comAlias = RegrasDeSeries.ultima(em: lidas,
                                     exercicioSlug: SlugsRenomeados.atual(slugDepoisDoRename))
checa("A1", "aplicar o alias na IDA não resgata (mapeia velho→novo; o disco tem o velho)",
      comAlias == nil)
checa("A2", "SlugsRenomeados está VAZIO — nenhum rename em vigor",
      SlugsRenomeados.de.isEmpty)
checa("A3", "e por isso atual(_:) é a identidade",
      SlugsRenomeados.atual("crucifixo") == "crucifixo")

print("\n───────────────────────────────────────────")
print(falhas == 0 ? "TODAS AS \(checagens) PASSARAM" : "\(falhas) de \(checagens) FALHARAM")
exit(falhas == 0 ? 0 : 1)
