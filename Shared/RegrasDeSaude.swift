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
}
