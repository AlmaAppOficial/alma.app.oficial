// teste_fisiologia.swift — 2026-08-14
//
// Executa as REGRAS DE PRODUÇÃO de `Shared/RegrasDeSaude.swift`. Não há cópia
// da regra aqui: este arquivo é compilado JUNTO com o de produção
// (`swiftc Shared/RegrasDeSaude.swift _scripts/teste_fisiologia.swift`), então
// se alguém mudar a regra, estas asserções mudam de cor.
//
// POR QUE UM BINÁRIO DE LINHA DE COMANDO, E NÃO O HARNESS DE DENTRO DO APP:
//
//   1. Roda em segundos, o que torna a MUTAÇÃO barata — e mutação é a única
//      coisa que prova que uma asserção enxerga (Regra 1 do CLAUDE.md).
//   2. **Não encosta em dado sensível de ninguém.** Ciclo e gravidez moram no
//      Keychain (`FeminineHealthSecureStore`); o portão que decide se essa tela
//      aparece é testado aqui como função pura, com dois argumentos e um Bool
//      de volta (Regra 4).
//   3. O `AuditoriaBloqueadores` precisa do app montado; o XCUITest não existe
//      neste projeto (ver "Pendências técnicas conhecidas" no CLAUDE.md).
//
// SAÍDA: exit 0 = tudo verde. exit 1 = alguma asserção vermelha.
// exit 2 = DETECTOR CEGO (o canário passou quando devia reprovar).

import Foundation

var falhas = 0
var total  = 0

func checar(_ nome: String, _ condicao: Bool) {
    total += 1
    if condicao {
        print("  ✓ \(nome)")
    } else {
        falhas += 1
        print("  ✗✗ VERMELHO — \(nome)")
    }
}

func secao(_ t: String) { print("\n── \(t) ──") }

// ═══════════════════════════════════════════════════════════════════════════
// 1. OS CINCO GRUPOS DE USUÁRIOS EXISTENTES
//
// A pergunta que cada caso responde: o que acontece com quem JÁ TEM o app
// instalado, na próxima abertura, sem responder nada de novo?
// ═══════════════════════════════════════════════════════════════════════════
secao("1. Migração dos 5 grupos (só gênero legado gravado)")

checar("G1 'Feminino'          → .feminino",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Feminino") == .feminino)
checar("G2 'Masculino'         → .masculino",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Masculino") == .masculino)
checar("G3 'Não binário'       → nil (ausência não é palpite)",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Não binário") == nil)
checar("G4 'Prefiro não dizer' → nil (recusa não vira resposta)",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Prefiro não dizer") == nil)
checar("G5 nunca gravou nada   → nil",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: nil) == nil)
checar("G5b string vazia       → nil (o getter do iOS devolve \"\", não nil)",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "") == nil)
checar("valor futuro desconhecido → nil, NUNCA masculino por omissão",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Agênero") == nil)

// ═══════════════════════════════════════════════════════════════════════════
// 2. A ORDEM DE PRECEDÊNCIA DA CADEIA
// ═══════════════════════════════════════════════════════════════════════════
secao("2. Precedência: Dieta > onboarding > gênero legado")

checar("escolha na Dieta ganha do onboarding",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: .masculino, informadoNoOnboarding: .feminino, generoLegado: nil) == .masculino)
checar("escolha na Dieta ganha do gênero legado",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: .masculino, informadoNoOnboarding: nil, generoLegado: "Feminino") == .masculino)
checar("onboarding ganha do gênero legado",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: .feminino, generoLegado: "Masculino") == .feminino)
checar("sem nenhuma das três → nil",
       RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: nil) == nil)

// ═══════════════════════════════════════════════════════════════════════════
// 3. O PORTÃO DA SAÚDE FEMININA — NINGUÉM PERDE, NINGUÉM GANHA INDEVIDAMENTE
//
// Este é o bloco que responde "verifique que o gate continua funcionando".
// A comparação é contra o comportamento ANTIGO, `gender == "Feminino"`.
// ═══════════════════════════════════════════════════════════════════════════
secao("3. Portão da saúde feminina (antes × depois)")

/// A regra ANTIGA, escrita aqui só para comparar. Era `isFemale` em
/// `UserMemoryManager` + o `&&` de `HomeView:98`.
func portaoAntigo(ehPremium: Bool, generoLegado: String?) -> Bool {
    ehPremium && generoLegado == "Feminino"
}

let generos: [String?] = ["Feminino", "Masculino", "Não binário", "Prefiro não dizer", nil, ""]
var divergencias = 0
for g in generos {
    for premium in [true, false] {
        let antes = portaoAntigo(ehPremium: premium, generoLegado: g)
        let depois = RegrasDeSaude.mostrarSaudeFeminina(
            ehPremium: premium,
            sexoEfetivo: RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: g))
        if antes != depois { divergencias += 1 }
    }
}
checar("PARIDADE TOTAL: 12 combinações (6 gêneros × 2 premium) sem divergência — ninguém perde nem ganha acesso",
       divergencias == 0)

checar("premium + fisiologia feminina → mostra",
       RegrasDeSaude.mostrarSaudeFeminina(ehPremium: true, sexoEfetivo: .feminino))
checar("SEM premium + feminina → NÃO mostra (o portão de pagamento continua)",
       !RegrasDeSaude.mostrarSaudeFeminina(ehPremium: false, sexoEfetivo: .feminino))
checar("premium + masculino → não mostra",
       !RegrasDeSaude.mostrarSaudeFeminina(ehPremium: true, sexoEfetivo: .masculino))
checar("premium + NÃO INFORMADO → não mostra (ausência não abre porta)",
       !RegrasDeSaude.mostrarSaudeFeminina(ehPremium: true, sexoEfetivo: nil))
checar("quem respondeu 'Prefiro não informar' no onboarding não vê a saúde feminina",
       !RegrasDeSaude.mostrarSaudeFeminina(
            ehPremium: true,
            sexoEfetivo: RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: nil)))

// ═══════════════════════════════════════════════════════════════════════════
// 4. O TERMO DA MIFFLIN — O CASO QUE REPRESENTA O DEFEITO INTEIRO
//
// "prove que essa pessoa passa a receber o termo −161" (Assis, 14/08).
// ═══════════════════════════════════════════════════════════════════════════
secao("4. Mifflin-St Jeor: o termo de sexo")

checar("termo masculino = +5",   RegrasDeSaude.termoDeSexo(.masculino) == 5)
checar("termo feminino  = −161", RegrasDeSaude.termoDeSexo(.feminino) == -161)
checar("termo sem informação = −78 (ponto médio, nunca um dos lados)",
       RegrasDeSaude.termoDeSexo(nil) == -78)
checar("não informado NÃO é tratado como masculino (era o defeito)",
       RegrasDeSaude.termoDeSexo(nil) != RegrasDeSaude.termoDeSexo(.masculino))
checar("diferença masculino−feminino = 166 kcal no BMR",
       RegrasDeSaude.termoDeSexo(.masculino) - RegrasDeSaude.termoDeSexo(.feminino) == 166)

secao("4b. O CAMINHO COMPLETO da mulher que marcou 'Feminino' antes de 14/08")

// Mulher, 65 kg, 165 cm, 35 anos — o exemplo do relatório de 14/08.
let sexoDela = RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Feminino")
let bmrDela  = RegrasDeSaude.bmr(weightKg: 65, heightCm: 165, ageYears: 35, sex: sexoDela)
let bmrAntes = RegrasDeSaude.bmr(weightKg: 65, heightCm: 165, ageYears: 35, sex: .masculino)

checar("o gênero legado dela chega na fórmula como .feminino", sexoDela == .feminino)
checar("e portanto o BMR usa −161 (1345,25 kcal)", bmrDela == 1345.25)
checar("o comportamento ANTIGO lhe dava 1511,25 — 166 kcal a mais", bmrAntes == 1511.25)
checar("ela deixa de receber a diferença de 166 kcal no BMR", bmrAntes - bmrDela == 166)

// Com o fator de atividade "leve" (o padrão calado antigo), no prato:
let noPratoAntes = bmrAntes * ActivityLevel.leve.factor
let noPratoAgora = bmrDela  * ActivityLevel.leve.factor
checar("no prato, com fator leve, a diferença passa de 228 kcal/dia",
       (noPratoAntes - noPratoAgora) > 228 && (noPratoAntes - noPratoAgora) < 229)

// ═══════════════════════════════════════════════════════════════════════════
// 5. O SEGUNDO LADO DA FRONTEIRA — QUEM NÃO INFORMOU NÃO RECEBE
//    NÚMERO QUE FINJA SER CÁLCULO PESSOAL
// ═══════════════════════════════════════════════════════════════════════════
secao("5. Rótulo de estimativa (o outro lado da fronteira)")

checar("sexo E atividade informados → NÃO é estimativa",
       !RegrasDeSaude.metaEhEstimada(sex: .feminino, activity: .moderado))
checar("sem sexo → é estimativa",
       RegrasDeSaude.metaEhEstimada(sex: nil, activity: .moderado))
checar("sem atividade → é estimativa",
       RegrasDeSaude.metaEhEstimada(sex: .feminino, activity: nil))
checar("sem nenhum dos dois → é estimativa",
       RegrasDeSaude.metaEhEstimada(sex: nil, activity: nil))
checar("quem recusou informar cai em estimativa",
       RegrasDeSaude.metaEhEstimada(
           sex: RegrasDeSaude.sexoEfetivo(escolhidoNaDieta: nil, informadoNoOnboarding: nil, generoLegado: "Prefiro não dizer"),
           activity: .leve))

checar("o que falta é NOMEADO, atividade primeiro (impacto maior)",
       RegrasDeSaude.oQueFaltaNaMeta(sex: nil, activity: nil) == ["seu nível de atividade", "seu sexo biológico"])
checar("nada falta quando os dois estão informados",
       RegrasDeSaude.oQueFaltaNaMeta(sex: .masculino, activity: .intenso).isEmpty)

secao("5b. Atividade: o número não muda, o rótulo sim")

checar("fator sem informação = 1.375 (= leve, fator documentado)",
       RegrasDeSaude.fatorDeAtividade(nil) == 1.375)
checar("fator sem informação == fator de .leve",
       RegrasDeSaude.fatorDeAtividade(nil) == ActivityLevel.leve.factor)
checar("mas SEM informar, a meta se declara estimativa — era isso que faltava",
       RegrasDeSaude.metaEhEstimada(sex: .feminino, activity: nil))
checar("faixa de atividade vale 806 kcal para um BMR de ~1535",
       Int((1535 * (ActivityLevel.intenso.factor - ActivityLevel.sedentario.factor)).rounded()) == 806)

// ═══════════════════════════════════════════════════════════════════════════
// 6. CANÁRIO — o detector está vivo?
//
// Regra 2 do CLAUDE.md: todo harness que varre muitos casos precisa de um caso
// que TEM de reprovar, verificado na própria execução. Se o canário passar, o
// harness está cego e o resultado inteiro é descartado.
// ═══════════════════════════════════════════════════════════════════════════
secao("6. Canário (tem de ser ACUSADO)")

let canarios: [(String, Bool)] = [
    ("afirmação falsa trivial", 1 == 2),
    ("feminino NÃO é masculino", RegrasDeSaude.termoDeSexo(.feminino) == RegrasDeSaude.termoDeSexo(.masculino)),
    ("nil NÃO abre a saúde feminina", RegrasDeSaude.mostrarSaudeFeminina(ehPremium: true, sexoEfetivo: nil)),
]
var canariosAcusados = 0
for (nome, condicaoQueDeveSerFalsa) in canarios {
    if condicaoQueDeveSerFalsa {
        print("  ✗✗ DETECTOR CEGO — o canário '\(nome)' passou e não devia")
    } else {
        canariosAcusados += 1
        print("  ✓ detector vivo: '\(nome)' foi acusado")
    }
}

// ═══════════════════════════════════════════════════════════════════════════
print("\n════════════════════════════════════════════════════")
print("asserções: \(total)   ·   vermelhas: \(falhas)")
print("canários acusados: \(canariosAcusados)/\(canarios.count)")

if canariosAcusados != canarios.count {
    print("RESULTADO: DETECTOR CEGO — resultado inteiro descartado.")
    exit(2)
}
if falhas > 0 {
    print("RESULTADO: VERMELHO (\(falhas))")
    exit(1)
}
print("RESULTADO: VERDE — \(total) asserções, detector provado vivo.")
exit(0)
