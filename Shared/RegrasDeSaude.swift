// RegrasDeSaude.swift
// Alma App — as decisões sobre dado de saúde, sem HealthKit e sem SwiftUI.
//
// [2026-08-13] Este arquivo existe por um motivo de método, não de arquitetura.
//
// As três correções que ele carrega vinham de regras escritas DENTRO do
// `HealthKitManager`, que importa HealthKit e SwiftUI e só existe rodando num
// aparelho com o app Saúde. Uma regra que só dá para exercitar assim não é
// exercitada — foi o que aconteceu com as três. Isoladas aqui, viram funções
// puras: entram números, sai uma decisão, e a decisão pode ficar VERMELHA num
// harness (Regra 1 do CLAUDE.md).
//
// É a mesma jogada de `CycleCalculator` (extraído do `FeminineHealthView` no
// Build 84) e de `FeminineHealthSecureStore.decidirHistórico` — com o bônus,
// nos dois casos de saúde feminina, de a asserção nunca encostar no Keychain
// de ninguém.
//
// Nenhum import além do Foundation. Se um dia alguém precisar de SwiftUI aqui,
// é sinal de que a coisa a acrescentar é apresentação, e ela vive em outro
// lugar (ver `extension StressLevel` em HealthKitManager.swift).

import Foundation

// MARK: - Sexo biológico (usado apenas na fórmula, 100% local)
//
// [2026-08-14] Veio de `NutritionEngine.swift`. Sem SwiftUI em volta, o tipo
// que a regra devolve pode ser construído num teste de linha de comando.

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case masculino = "Masculino"
    case feminino  = "Feminino"

    var id: String { rawValue }
}

// MARK: - Nível de atividade

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentario = "Sedentário"
    case leve       = "Leve (1–3x/semana)"
    case moderado   = "Moderado (3–5x/semana)"
    case intenso    = "Intenso (6–7x/semana)"

    var id: String { rawValue }

    /// Fator multiplicador do gasto basal (valores clássicos de Harris/Mifflin).
    var factor: Double {
        switch self {
        case .sedentario: return 1.2
        case .leve:       return 1.375
        case .moderado:   return 1.55
        case .intenso:    return 1.725
        }
    }
}

// MARK: - Nível de stress

/// Nível de stress derivado da variabilidade da frequência cardíaca.
///
/// Só os casos moram aqui. `label`, `color` e `icon` continuam em
/// `HealthKitManager.swift`, que é quem pode importar SwiftUI — sem isso este
/// arquivo não compilaria fora do app e a regra voltaria a ser inverificável.
enum StressLevel {
    case low, moderate, high
}

enum RegrasDeSaude {

    // MARK: Stress

    /// Nível de stress, ou `nil` quando não há HRV para sustentar afirmação
    /// nenhuma.
    ///
    /// [2026-08-13] O badge "Relaxado" aparecia na Início para quem usa
    /// pulseira que grava frequência cardíaca e **não** grava HRV. O defeito
    /// era a distância entre duas linhas:
    ///
    ///   • o portão da tela aceitava `averageHRV > 0 || hrv > 0 ||
    ///     averageHeartRate > 0 || heartRate > 0` — FC bastava para o badge
    ///     aparecer;
    ///   • a conta usava **só HRV**, e sem HRV caía no `else { stressLevel =
    ///     .low }`, cujo rótulo é "Relaxado", com folha verde.
    ///
    /// Ou seja: o valor padrão de uma variável era apresentado à pessoa como
    /// leitura do corpo dela. Não era medição de nada — era o estado inicial
    /// de um `@Published`.
    ///
    /// Devolver `Optional` fecha a porta por construção: não existe mais um
    /// "nível" separado da pergunta "dá para saber?". Quem exibe é obrigado a
    /// desembrulhar, e o portão da tela não tem como divergir da conta porque
    /// passou a ser a mesma coisa.
    ///
    /// - Parameters:
    ///   - hrvMedio: média do dia (mais robusta; tem prioridade).
    ///   - hrvUltimo: última amostra, usada quando não há média.
    static func nivelDeStress(hrvMedio: Double, hrvUltimo: Double) -> StressLevel? {
        let hrv = hrvMedio > 0 ? hrvMedio : hrvUltimo
        guard hrv.isFinite, hrv > 0 else { return nil }
        if hrv > 50 { return .low }
        if hrv > 30 { return .moderate }
        return .high
    }

    // MARK: Passos

    /// Passos de HOJE. `nil` = não há dado de hoje.
    ///
    /// [2026-08-13] **Não existe fallback para ontem, e a ausência dele é a
    /// correção.** `fetchTodaySteps()` fazia assim: se a soma de hoje viesse 0,
    /// buscava a soma de ONTEM e devolvia aquele número — que a Início exibia
    /// no card "Passos", sob o título **"Saúde hoje"**. O comentário original
    /// justificava com "evita exibir 0 cedo de manhã antes do relógio
    /// sincronizar"; só que a tela já aprendeu a dizer "—" quando não há dado,
    /// então o remédio virou a doença: em vez de não afirmar nada, o app
    /// afirmava o número errado.
    ///
    /// O agravante era interno. `stepsToday()`, a fonte que alimenta o
    /// `healthContext` do chat, **não** tinha o fallback e devolvia `nil`. No
    /// mesmo instante, o mesmo app exibia "7.412 passos" na Início e conversava
    /// como se não soubesse nada sobre os passos da pessoa. Duas verdades no
    /// mesmo app, e a que estava na tela era a falsa.
    ///
    /// Uma fonte, uma verdade: os dois caminhos passam por aqui.
    ///
    /// - Parameter somaDeHoje: soma do `stepCount` de hoje vinda do HealthKit
    ///   (`0` tanto para "não andou" quanto para "sem autorização/sem dado" —
    ///   a API não distingue, e nenhum dos dois autoriza exibir número).
    static func passosDeHoje(somaDeHoje: Double) -> Int? {
        guard somaDeHoje.isFinite, somaDeHoje > 0 else { return nil }
        return Int(somaDeHoje)
    }

    // MARK: - Sexo biológico
    //
    // [2026-08-14] Decisão do Assis: *"não deveria ser como se identifica, e sim
    // sua fisiologia, homem ou mulher"*. O onboarding perguntava IDENTIDADE
    // ("Como você se identifica?", 4 opções) e o app usava a resposta como se
    // fosse FISIOLOGIA — o pior dos dois mundos, porque errava nas duas pontas.
    //
    // Estas funções são o irmão iOS de `SexoDaMeta.kt` (Android, 13/08). Vivem
    // aqui, e não dentro de `AppState` ou de `UserMemoryManager`, pelo motivo
    // que dá nome a este arquivo: regra que só roda com `UserDefaults` e
    // Keychain montados é regra que ninguém exercita. Aqui elas recebem
    // `String?`/`BiologicalSex?` e devolvem decisão — e a asserção **nunca
    // encosta na chave real de ninguém** (Regra 4 do CLAUDE.md).

    /// Traduz o gênero LEGADO (identidade, 4 valores) para sexo biológico.
    ///
    /// **O mapeamento é parcial de propósito.** "Não binário" e "Prefiro não
    /// dizer" não carregam fisiologia: devolvem `nil`, que significa *não
    /// informado*. Mapear qualquer um dos dois para um lado seria transformar
    /// uma recusa explícita em resposta — e quem escolheu "Prefiro não dizer"
    /// foi justamente a única pessoa que disse alguma coisa a respeito.
    ///
    /// **Ausência não é palpite.**
    ///
    /// O `default` é a decisão segura, não o descuido: se um build futuro
    /// gravar um quinto valor, ele cai em "não informado" em vez de virar
    /// homem por omissão — que é exatamente o defeito que isto conserta.
    ///
    /// - Parameter genero: valor cru de `UserMemoryManager.gender`
    ///   (chave `alma_user_gender`), `nil` ou `""` quando nunca respondido.
    static func sexoDoGeneroLegado(_ genero: String?) -> BiologicalSex? {
        switch genero {
        case "Feminino":  return .feminino
        case "Masculino": return .masculino
        default:          return nil
        }
    }

    /// O sexo que o cálculo usa, na ordem de confiança.
    ///
    /// **Esta ordem é o que faz a correção alcançar quem já usa o app.** Ela
    /// roda na LEITURA do estado, não na escrita: ninguém refaz o onboarding,
    /// nada é reescrito no disco, e quem já tem gênero gravado passa a ter a
    /// meta certa na próxima abertura. Mesma lição do `SexoDaMeta.efetivo` —
    /// normalizar na decodificação em vez de esperar que todo escritor futuro
    /// lembre da regra.
    ///
    /// - Parameters:
    ///   - escolhidoNaDieta: o que a pessoa marcou no seletor de Dieta → Meta
    ///     (chave `sexBiological`). Ganha de tudo: é resposta direta à pergunta
    ///     que a fórmula faz, e é a tela que existe para corrigir as outras.
    ///   - informadoNoOnboarding: a resposta à pergunta de fisiologia
    ///     (chave `alma_user_biological_sex`), a partir de 14/08.
    ///   - generoLegado: o gênero de identidade coletado até 14/08 — a ponte
    ///     para quem já tinha o app instalado.
    /// - Returns: o sexo, ou `nil` quando não dá para saber. **Nunca um chute.**
    static func sexoEfetivo(escolhidoNaDieta: BiologicalSex?,
                            informadoNoOnboarding: BiologicalSex?,
                            generoLegado: String?) -> BiologicalSex? {
        escolhidoNaDieta ?? informadoNoOnboarding ?? sexoDoGeneroLegado(generoLegado)
    }

    /// O portão da saúde feminina (ciclo menstrual e gravidez).
    ///
    /// [2026-08-14] Antes isto era `access.isPremium && UserMemoryManager.shared.isFemale`
    /// escrito direto no `if` da `HomeView` (:98), com `isFemale` sendo
    /// `gender == "Feminino"`. Duas coisas melhoram ao virar função:
    ///
    /// 1. **Dá para provar sem Keychain.** Ciclo e gravidez moram no
    ///    `FeminineHealthSecureStore`; um teste que precisasse abrir a tela para
    ///    exercitar o portão encostaria nesses dados. Aqui entram dois valores
    ///    e sai um `Bool`.
    /// 2. **A troca de fonte fica visível.** O portão passa a ler o sexo
    ///    efetivo — e, como `sexoEfetivo` cai no gênero legado quando não há
    ///    resposta nova, **ninguém que via a saúde feminina deixa de ver**.
    ///    Quem marcou "Feminino" continua satisfazendo o portão pela terceira
    ///    posição da cadeia, sem migração.
    ///
    /// A recíproca também vale, e é o que garante que ninguém GANHE acesso
    /// indevido: "Não binário" e "Prefiro não dizer" já não passavam por
    /// `gender == "Feminino"`, e continuam não passando por `== .feminino`.
    static func mostrarSaudeFeminina(ehPremium: Bool, sexoEfetivo: BiologicalSex?) -> Bool {
        ehPremium && sexoEfetivo == .feminino
    }

    // MARK: - Mifflin-St Jeor (núcleo puro)
    //
    // [2026-08-14] Estas declarações vieram de `Shared/Corpo/NutritionEngine.swift`.
    // Lá elas eram inalcançáveis por qualquer asserção: aquele arquivo termina
    // numa `View` e importa SwiftUI, então só compila dentro do app. Aqui,
    // com Foundation e mais nada, o termo que decide `−161` para uma mulher e
    // `+5` para um homem roda num binário de linha de comando — e pode ficar
    // VERMELHO numa mutação, que é a única prova que este projeto aceita.
    //
    // `suggestedKcal` NÃO veio junto, de propósito: ela depende de `Goal`, que
    // mora no `Models.swift` (SwiftUI). Ela passou a chamar a `bmr` e a
    // `fatorDeAtividade` daqui, então a parte arriscada — a escolha do termo —
    // é a que ficou exercitável.
    /// O termo de sexo da Mifflin-St Jeor — e o que fazer sem ele.
    ///
    /// [2026-08-14] Porte literal do `termoDeSexo` do Android
    /// (`NutritionEngine.kt`, 13/08). As duas plataformas têm de devolver o
    /// mesmo número para a mesma pessoa; divergir aqui é ter duas verdades
    /// sobre o mesmo corpo.
    ///
    /// **O caso `nil` é o interessante.** Qualquer número embute uma suposição;
    /// a questão é qual erro se aceita e o que se diz à pessoa. O ponto médio
    /// (`−78`) é o único que não escolhe um lado: limita o erro a **83 kcal**
    /// em vez de 166 contra metade dos usuários. Não é variante documentada de
    /// Mifflin, e por isso **nunca aparece sozinho** — `metaEhEstimada` existe
    /// para que a interface diga que aquilo é estimativa, e não cálculo pessoal.
    ///
    /// A alternativa (assumir masculino, como até hoje) não é "neutra": é a
    /// mesma suposição de sempre, só que sem aviso e penalizando sempre o mesmo
    /// grupo.
    static func termoDeSexo(_ sex: BiologicalSex?) -> Double {
        switch sex {
        case .masculino: return 5
        case .feminino:  return -161
        case nil:        return -78   // ponto médio; SEMPRE com o rótulo
        }
    }

    /// Fator de atividade assumido quando ninguém informou.
    ///
    /// **Aqui o número NÃO muda, e o rótulo sim** — e o motivo é diferente do
    /// caso do sexo. `+5` penalizava sistematicamente um grupo (toda mulher
    /// pagava 166 kcal), então valeu mexer no número. `leve` não penaliza grupo
    /// demográfico nenhum: erra por pessoa, para os dois lados. E `1.375` é
    /// fator **documentado** de Mifflin-St Jeor, enquanto o ponto médio da
    /// faixa (1.4625) não é fator de variante nenhuma — seria o "número que não
    /// é certo para ninguém".
    ///
    /// Somando: mexer no fator moveria a meta de todo mundo que nunca tocou no
    /// seletor, calada e retroativamente. Manter o número e **declarar a
    /// suposição** é o conserto honesto.
    static let fatorQuandoNaoInformado: Double = 1.375   // = ActivityLevel.leve.factor

    static func fatorDeAtividade(_ activity: ActivityLevel?) -> Double {
        activity?.factor ?? fatorQuandoNaoInformado
    }

    /// `true` quando a meta foi calculada sem saber o sexo **ou** sem saber a
    /// atividade — a interface tem de dizer isso. Uma meta que se apresenta
    /// como cálculo pessoal sem sê-lo é o que a Regra 3.1 do `CLAUDE.md`
    /// proíbe: o app **registra e exibe**, não promete.
    static func metaEhEstimada(sex: BiologicalSex?, activity: ActivityLevel?) -> Bool {
        sex == nil || activity == nil
    }

    /// **Nomeia** o que falta, em vez de dizer só que falta alguma coisa.
    /// Ordem = impacto na conta: atividade (806 kcal) antes do sexo (228).
    static func oQueFaltaNaMeta(sex: BiologicalSex?, activity: ActivityLevel?) -> [String] {
        var faltando: [String] = []
        if activity == nil { faltando.append("seu nível de atividade") }
        if sex == nil      { faltando.append("seu sexo biológico") }
        return faltando
    }

    /// Taxa metabólica basal — Mifflin-St Jeor.
    static func bmr(weightKg: Double, heightCm: Double, ageYears: Int, sex: BiologicalSex?) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears)
        return base + termoDeSexo(sex)
    }

}
