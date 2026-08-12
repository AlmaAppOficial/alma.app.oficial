//
//  main.swift — asserções da fronteira "gordura ausente ≠ gordura zero".
//
//  Roda contra o código de produção (`Shared/Corpo/AIBodyScan.swift` compilado
//  junto) e contra o TEXTO de `Shared/Corpo/ScanResultView.swift`.
//
//  Uso:  ./gordura <raiz-do-repo>
//
//  Regras da casa que este arquivo obedece (CLAUDE.md):
//   · `falhas` é preenchido de verdade — não é o `var falhas` decorativo do
//     SmokeTestTelas que imprimia "nenhuma falha" desde sempre;
//   · nada de `allSatisfy` sobre lista que pode estar vazia (verdade vácua):
//     onde há coleção, o número de casos é contado e conferido;
//   · o total de asserções é conferido no fim — harness que roda menos do que
//     promete se denuncia;
//   · há CANÁRIO que TEM de acusar; se ele passar, o resultado inteiro cai.
//

import Foundation

// ── infraestrutura ───────────────────────────────────────────────────────
var falhas: [String] = []
var totalDeChecagens = 0

func checa(_ id: String, _ oQue: String, _ condicao: Bool, _ evidencia: String) {
    totalDeChecagens += 1
    if condicao {
        print("  ✓ \(id) \(oQue) — \(evidencia)")
    } else {
        print("  ✗ \(id) \(oQue) — \(evidencia)")
        falhas.append("\(id) \(oQue) — \(evidencia)")
    }
}

func d(_ v: Double?) -> String { v.map { String($0) } ?? "nil" }

print("═════ GORDURA AUSENTE ≠ GORDURA ZERO — asserções contra o código de produção ═════")

// ── 1. A REGRA PURA ──────────────────────────────────────────────────────
// Regra 4 do CLAUDE.md: a asserção testa a FUNÇÃO, nunca dado real de saúde.
checa("G1", "ausência declarada (nil) não vira número",
      BodyAnalysis.gorduraInformada(nil) == nil,
      "nil → \(d(BodyAnalysis.gorduraInformada(nil)))")

checa("G2", "o zero de carga é ausência, não medida",
      BodyAnalysis.gorduraInformada(0) == nil,
      "0 → \(d(BodyAnalysis.gorduraInformada(0)))")

checa("G3", "percentual informado atravessa intacto",
      BodyAnalysis.gorduraInformada(18.4) == 18.4,
      "18.4 → \(d(BodyAnalysis.gorduraInformada(18.4)))")

checa("G4", "negativo não é medida",
      BodyAnalysis.gorduraInformada(-3) == nil,
      "-3 → \(d(BodyAnalysis.gorduraInformada(-3)))")

checa("G5", "NaN e infinito não são medida",
      BodyAnalysis.gorduraInformada(.nan) == nil
        && BodyAnalysis.gorduraInformada(.infinity) == nil,
      "nan → \(d(BodyAnalysis.gorduraInformada(.nan))) · inf → \(d(BodyAnalysis.gorduraInformada(.infinity)))")

// O outro lado da fronteira, explícito: 5% é o mínimo que o slider de
// `EditAssessmentView` deixa a pessoa informar. Tem de sobreviver.
checa("G5b", "o mínimo que a pessoa consegue informar (5%) continua sendo medida",
      BodyAnalysis.gorduraInformada(5) == 5,
      "5 → \(d(BodyAnalysis.gorduraInformada(5)))")

// ── 2. CONSTRUÇÃO ────────────────────────────────────────────────────────
func analise(_ g: Double?) -> BodyAnalysis {
    BodyAnalysis(somatotype: .mesomorfo, estimatedBodyFat: g,
                 summary: "resumo", observations: ["obs"], focusAreas: ["foco"])
}

checa("G6", "construir com 0 já guarda ausência",
      analise(0).estimatedBodyFat == nil,
      "estimatedBodyFat = \(d(analise(0).estimatedBodyFat))")

checa("G7", "construir com 22 guarda 22",
      analise(22).estimatedBodyFat == 22,
      "estimatedBodyFat = \(d(analise(22).estimatedBodyFat))")

// ── 3. A ROTA DO DEFEITO: scan só com medidas, sem foto ──────────────────
func entrada(gordura: Double) -> ScanInput {
    ScanInput(weightKg: 78, heightCm: 176, ageYears: 34, bodyFat: gordura,
              goal: Goal.manter.rawValue, frontPhoto: nil, sidePhoto: nil)
}

let semGordura = try await MockAIPlanService().analyze(entrada(gordura: 0))
let comGordura = try await MockAIPlanService().analyze(entrada(gordura: 22))

checa("G8", "sem gordura informada, a linha não tem o que mostrar",
      semGordura.analysis.estimatedBodyFat == nil,
      "estimatedBodyFat = \(d(semGordura.analysis.estimatedBodyFat))")

checa("G9", "com gordura informada, a linha aparece",
      comGordura.analysis.estimatedBodyFat == 22,
      "estimatedBodyFat = \(d(comGordura.analysis.estimatedBodyFat))")

checa("G10", "é mesmo a rota sem foto (a que o Assis relatou)",
      semGordura.isAIGenerated == false,
      "isAIGenerated = \(String(describing: semGordura.isAIGenerated))")

// A lição do somatotipo: esconder um campo NÃO pode derrubar a análise.
checa("G11", "esconder a gordura não derruba o resto da análise",
      !semGordura.analysis.summary.isEmpty
        && semGordura.analysis.observations.count >= 1
        && semGordura.analysis.focusAreas.count >= 1
        && semGordura.plan.dailyKcal > 0,
      "resumo=\(semGordura.analysis.summary.count) chars · obs=\(semGordura.analysis.observations.count) · focos=\(semGordura.analysis.focusAreas.count) · kcal=\(semGordura.plan.dailyKcal)")

// ── 4. O QUE JÁ ESTÁ GRAVADO NO APARELHO ────────────────────────────────
// `AppModel.scanResult` é persistido em JSON e reaberto pelo "Ver meu plano
// atual" (SaudeView). Quem já tomou o 0% tem esse 0 no disco.
let jsonAntigoComZero = #"{"somatotype":"Mesomorfo","estimatedBodyFat":0,"summary":"resumo","observations":["obs"],"focusAreas":["foco"]}"#
let lidoDoDisco = try JSONDecoder().decode(BodyAnalysis.self,
                                           from: Data(jsonAntigoComZero.utf8))

checa("G12", "o 0 já gravado vira ausência na leitura",
      lidoDoDisco.estimatedBodyFat == nil,
      "estimatedBodyFat = \(d(lidoDoDisco.estimatedBodyFat))")

checa("G12b", "e o resultado salvo continua inteiro ao redor",
      lidoDoDisco.somatotype == .mesomorfo
        && lidoDoDisco.summary == "resumo"
        && lidoDoDisco.observations == ["obs"]
        && lidoDoDisco.focusAreas == ["foco"],
      "somatotipo=\(String(describing: lidoDoDisco.somatotype)) resumo=\(lidoDoDisco.summary) obs=\(lidoDoDisco.observations) focos=\(lidoDoDisco.focusAreas)")

let jsonAntigoComMedida = #"{"somatotype":"Endomorfo","estimatedBodyFat":31.5,"summary":"resumo","observations":["obs"],"focusAreas":["foco"]}"#
let salvoComMedida = try JSONDecoder().decode(BodyAnalysis.self,
                                              from: Data(jsonAntigoComMedida.utf8))
checa("G13", "resultado salvo com medida real continua mostrando",
      salvoComMedida.estimatedBodyFat == 31.5,
      "estimatedBodyFat = \(d(salvoComMedida.estimatedBodyFat))")

let jsonSemAChave = #"{"summary":"resumo","observations":[],"focusAreas":[]}"#
let semAChave = try JSONDecoder().decode(BodyAnalysis.self,
                                         from: Data(jsonSemAChave.utf8))
checa("G14", "resultado sem a chave decodifica como ausência, sem estourar",
      semAChave.estimatedBodyFat == nil && semAChave.somatotype == nil,
      "estimatedBodyFat = \(d(semAChave.estimatedBodyFat))")

let voltaComMedida = try JSONDecoder().decode(
    BodyAnalysis.self, from: JSONEncoder().encode(analise(18)))
checa("G15", "ida e volta pelo disco preserva a medida",
      voltaComMedida.estimatedBodyFat == 18,
      "estimatedBodyFat = \(d(voltaComMedida.estimatedBodyFat))")

let voltaSemMedida = try JSONDecoder().decode(
    BodyAnalysis.self, from: JSONEncoder().encode(analise(0)))
checa("G16", "ida e volta não ressuscita o zero",
      voltaSemMedida.estimatedBodyFat == nil,
      "estimatedBodyFat = \(d(voltaSemMedida.estimatedBodyFat))")

// ── 5. A TELA ────────────────────────────────────────────────────────────
// Sem simulador (gate do Assis: nada de build). O que dá para provar aqui é a
// DECISÃO DE RENDER escrita no arquivo. Se o arquivo não for lido, isto aborta
// alto — asserção sobre arquivo que não abriu é a verdade vácua da semana.
let raiz = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
let caminhoDaTela = raiz + "/Shared/Corpo/ScanResultView.swift"
guard let fonteDaTela = try? String(contentsOfFile: caminhoDaTela, encoding: .utf8),
      fonteDaTela.count > 500 else {
    print("✗✗ NÃO CONSEGUI LER \(caminhoDaTela) — as asserções de tela não valem nada. Abortando.")
    exit(2)
}

/// Os três jeitos de imprimir a gordura sem antes perguntar se ela existe.
/// Devolve os que encontrou — lista vazia é o estado bom.
func rendersCegos(_ fonte: String) -> [String] {
    var achados: [String] = []
    if fonte.contains(#"analysis.estimatedBodyFat)"#) { achados.append("render direto") }
    if fonte.contains("estimatedBodyFat ??") { achados.append("valor de reserva") }
    if fonte.contains("estimatedBodyFat!") { achados.append("desembrulho à força") }
    return achados
}

checa("G17", "controle positivo: a tela de fato fala de gordura estimada",
      fonteDaTela.contains("Gordura estimada"),
      "achou a copy na fonte")

let temLigacaoOpcional = fonteDaTela.contains("analysis.estimatedBodyFat.map {")
checa("G18", "a tela lê a gordura por ligação opcional",
      temLigacaoOpcional,
      temLigacaoOpcional ? "achou `analysis.estimatedBodyFat.map {`"
                         : "NÃO achou `analysis.estimatedBodyFat.map {` na fonte")

let cegosNaTela = rendersCegos(fonteDaTela)
checa("G19", "a tela não imprime a gordura sem checar se ela existe",
      cegosNaTela.isEmpty,
      cegosNaTela.isEmpty ? "nenhum render cego" : "ACHADOS: \(cegosNaTela.joined(separator: ", "))")

// CANÁRIO (Regra 2): uma tela ruim de propósito, com os três defeitos.
// O detector TEM de acusar os três. Se acusar menos, G19 não vale nada.
let telaRuimDePropósito = """
Text(String(format: "Gordura estimada: %.0f%%", analysis.estimatedBodyFat))
Text(String(format: "%.0f", analysis.estimatedBodyFat ?? 0))
Text(String(format: "%.0f", analysis.estimatedBodyFat!))
"""
let acusados = rendersCegos(telaRuimDePropósito)
checa("G20 CANÁRIO", "o detector enxerga os três renders cegos quando eles existem",
      acusados.count == 3,
      acusados.count == 3
        ? "✓ detector vivo — acusou: \(acusados.joined(separator: ", "))"
        : "✗✗ DETECTOR CEGO (acusou \(acusados.count) de 3) — DESCARTAR G19")

// ── 6. O harness rodou tudo que promete? ────────────────────────────────
// 22 e não 20: a primeira execução acusou "rodou 22, esperava 20" porque eu
// tinha acrescentado G5b e G12b depois de contar. O guarda pegou o autor do
// harness — que é para isso que ele existe.
let ESPERADO = 22
if totalDeChecagens != ESPERADO {
    let msg = "HARNESS INCOMPLETO: rodou \(totalDeChecagens) asserções, esperava \(ESPERADO)"
    print("✗✗ \(msg)")
    falhas.append(msg)
}

print("─────────────────────────────────────────────────────────────────")
if falhas.isEmpty {
    print("\(totalDeChecagens) asserções, 0 FALHA(S).")
} else {
    print("\(falhas.count) FALHA(S) de \(totalDeChecagens):")
    for f in falhas { print("  · \(f)") }
}
exit(falhas.isEmpty ? 0 : 1)
