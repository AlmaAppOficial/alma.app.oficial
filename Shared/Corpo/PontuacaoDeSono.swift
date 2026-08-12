// PontuacaoDeSono.swift
// Alma — pontuação 0–100 do sono, a partir dos estágios do Apple Saúde
//
// [2026-08-04] Pedido do Assis: "uma noite de sono perfeita — com a quantidade
// certa de REM, sono profundo, sono leve e tempo total — seja 100%".
//
// POR QUE ESTA CONTA EXISTE (e não um dado pronto)
// Conferi os cabeçalhos do SDK do iOS: NÃO existe métrica de qualidade/score de
// sono no HealthKit. O que há é `HKCategoryValueSleepAnalysis` (asleepREM,
// asleepDeep, asleepCore, asleepUnspecified, awake, inBed), distúrbios
// respiratórios e apneia. `WorkoutEffortScore` existe — mas é de TREINO.
// Logo: a pontuação é do Alma, calculada aqui, e a UI diz isso com todas as
// letras. Nunca apresentar como número do Apple Saúde.
//
// REGRA DE HONESTIDADE (a mais importante deste arquivo)
// Sem estágios não há pontuação. Se a pessoa não usou relógio, devolvemos `nil`
// e a tela mostra só a duração. Inventar um score a partir de duração pura
// seria dar ares de precisão a um chute — exatamente o que este projeto não faz.
//
// Esta é uma função PURA: sem HealthKit, sem UI, sem relógio. Dá para exercitar
// a regra inteira com entradas fabricadas, do mesmo jeito que
// `FeminineHealthSecureStore.decidirHistórico`.

import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Uma noite, como o HealthKit a entrega (em horas).
struct NoiteDeSono {
    /// Soma de todos os estágios de sono (REM + profundo + core + não especificado).
    let totalDormido: Double
    /// `nil` quando o aparelho não registrou estágios (só duração).
    let rem: Double?
    let profundo: Double?
    /// Tempo acordado durante a noite.
    let acordado: Double?
    /// Quantas vezes acordou.
    let despertares: Int?

    var temEstagios: Bool { rem != nil && profundo != nil }
}

// MARK: - Da amostra do HealthKit para a noite [2026-08-04]
//
// A tradução das amostras vive AQUI, e não dentro de cada HealthManager, por um
// motivo simples: existem dois leitores de HealthKit neste app (o do Alma e o
// do Corpo). Se cada um montasse a noite do seu jeito, o card da tela e a linha
// que a IA recebe poderiam discordar sobre a mesma madrugada — e o usuário
// nunca saberia qual dos dois acreditar.
//
// A função é PURA: recebe estágio + início + fim e devolve a noite. Dá para
// exercitar a regra inteira com amostras fabricadas, sem HealthKit, sem
// simulador e sem tocar em dado de saúde de ninguém.

/// Uma amostra de sono já traduzida do vocabulário do HealthKit para o nosso.
struct AmostraDeSono {
    enum Estagio {
        case rem, profundo, leve, indeterminado, acordado, naCama
    }
    let estagio: Estagio
    let inicio: Date
    let fim: Date

    var horas: Double { max(0, fim.timeIntervalSince(inicio)) / 3600 }
}

// MARK: - Qual madrugada é "a noite passada" [2026-08-07]
//
// [DEFEITO relatado pelo Assis: "o sono indicou 11h30, mas no relógio foram 6h50"]
//
// O leitor do Corpo (`HealthManager.readSleepLastNight`) usava uma janela
// ROLANTE de 30 horas a partir de agora. Abrindo o app às 10:00, ela começava
// às 04:00 de ONTEM — e somava o rabo da noite retrasada com a noite passada.
// Duas madrugadas contadas como uma. A conta que ele viu: 6h50 da noite real
// + 4h30 do fim da noite anterior = 11h20. Ele viu 11h30.
//
// A regra vive AQUI, e não dentro de cada manager, pelo mesmo motivo que a
// tradução das amostras: existem DOIS leitores de HealthKit neste app. Se cada
// um recortasse a madrugada do seu jeito, o card da tela e a linha que a IA
// recebe falariam de noites diferentes — e o usuário nunca saberia qual é.
//
// Função pura: entra "agora", sai o intervalo. Exercitável com datas
// fabricadas, sem HealthKit e sem simulador.

// MARK: - União de intervalos sobrepostos [2026-08-07]
//
// [DEFEITO relatado pelo Assis: o card de pontuação dizia 9h21 e a outra tela
// dizia 11h30, para a MESMA noite, em que o relógio marcou 6h50.]
//
// Duas fontes gravam a mesma madrugada no Apple Saúde: o relógio estagia
// (REM/profundo/leve) e o iPhone grava um bloco "dormindo, sem estágio". Somar
// as durações conta o mesmo minuto duas vezes. Medido: 13,50 h onde o real
// eram 7,00 h.
//
// A regra certa é medir a UNIÃO dos intervalos: minuto coberto por duas fontes
// vale um minuto. É o que o Apple Saúde mostra e é o que o relógio da pessoa
// mostra — e agora é o que o Alma mostra.

/// Une intervalos sobrepostos ou encostados e devolve os blocos resultantes.
///
/// Ordena por início e vai fundindo enquanto houver interseção. Blocos de
/// duração zero ou negativa são descartados (amostra corrompida não vira tempo).
func unirIntervalos(_ amostras: [AmostraDeSono]) -> [(inicio: Date, fim: Date)] {
    let validos = amostras
        .filter { $0.fim > $0.inicio }
        .sorted { $0.inicio < $1.inicio }
    guard let primeiro = validos.first else { return [] }

    var blocos: [(inicio: Date, fim: Date)] = [(primeiro.inicio, primeiro.fim)]
    for amostra in validos.dropFirst() {
        let ultimo = blocos[blocos.count - 1]
        if amostra.inicio <= ultimo.fim {
            // Sobrepõe (ou encosta): estica o bloco atual, não abre outro.
            blocos[blocos.count - 1].fim = max(ultimo.fim, amostra.fim)
        } else {
            blocos.append((amostra.inicio, amostra.fim))
        }
    }
    return blocos
}

/// Horas totais de uma lista de blocos já unidos.
func horasDosBlocos(_ blocos: [(inicio: Date, fim: Date)]) -> Double {
    blocos.reduce(0) { $0 + $1.fim.timeIntervalSince($1.inicio) } / 3600
}

/// A janela da noite passada: de ontem às 18:00 até hoje ao meio-dia.
///
/// O fim é `min(meio-dia, agora)` para quem abre o app de madrugada — não faz
/// sentido pedir amostras do futuro.
///
/// Ancorada de propósito. Uma janela relativa a "agora" varre duas madrugadas
/// sempre que o app é aberto de manhã, que é justamente o horário em que
/// alguém olha o sono.
func janelaDaNoitePassada(
    agora: Date = Date(),
    calendario: Calendar = .current
) -> (inicio: Date, fim: Date) {
    let ontem = calendario.date(byAdding: .day, value: -1, to: agora) ?? agora
    let inicio = calendario.date(bySettingHour: 18, minute: 0, second: 0, of: ontem) ?? ontem
    let meioDia = calendario.date(bySettingHour: 12, minute: 0, second: 0, of: agora) ?? agora
    return (inicio, min(meioDia, agora))
}

#if canImport(HealthKit)
/// Do vocabulário do HealthKit para o nosso — uma única vez no app inteiro.
///
/// Amostra com código desconhecido vira `nil` e some. Adivinhar o estágio a
/// partir de um valor que não conhecemos seria exatamente o chute que esta
/// pontuação existe para não dar.
///
/// Função de nível de arquivo (`nonisolated` por natureza) porque roda dentro
/// dos closures `Sendable` do `HKSampleQuery`: uma `static` dentro de uma classe
/// `@MainActor` não pode ser lida ali (erro de isolamento no Swift 6).
///
/// [2026-08-07] Esta é a ÚNICA lista de estados de sono do app. `HealthKitManager`
/// tinha a sua própria (`sleepAsleepStates`) e somava por conta — foi o que fez
/// duas telas mostrarem durações diferentes para a mesma madrugada.
func traduzirAmostraDeSono(_ amostra: HKCategorySample) -> AmostraDeSono? {
    let estagio: AmostraDeSono.Estagio
    if #available(iOS 16.0, *) {
        switch amostra.value {
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:         estagio = .rem
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:        estagio = .profundo
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:        estagio = .leve
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: estagio = .indeterminado
        case HKCategoryValueSleepAnalysis.awake.rawValue:             estagio = .acordado
        case HKCategoryValueSleepAnalysis.inBed.rawValue:             estagio = .naCama
        default: return nil
        }
    } else {
        switch amostra.value {
        case HKCategoryValueSleepAnalysis.asleep.rawValue: estagio = .indeterminado
        case HKCategoryValueSleepAnalysis.inBed.rawValue:  estagio = .naCama
        default: return nil
        }
    }
    return AmostraDeSono(estagio: estagio, inicio: amostra.startDate, fim: amostra.endDate)
}
#endif

extension NoiteDeSono {

    /// Monta a noite a partir das amostras do aparelho.
    ///
    /// Duas decisões que valem a pena estar escritas:
    ///
    /// **1. `naCama` nunca vira sono pontuável.** Algumas fontes (Garmin é o
    /// caso conhecido aqui) só gravam "na cama". Isso serve para dizer *quanto
    /// tempo* — não serve para pontuar, porque não há estágio nenhum. Nesse
    /// caso a noite volta com `rem`/`profundo` em `nil` e a tela mostra só a
    /// duração, sem número. É a regra de honestidade do arquivo.
    ///
    /// **2. Ou o aparelho classifica a noite, ou não classifica.** Se houver
    /// qualquer amostra de REM/profundo/leve, tratamos a classificação como
    /// existente — e aí `acordado` e `despertares` valem, inclusive zerados
    /// (zero desperta é informação, não ausência de informação). Sem nenhuma
    /// amostra classificada, os quatro campos ficam `nil` juntos: não dá para
    /// afirmar "você não acordou" quando o aparelho simplesmente não olhou.
    ///
    /// **3. [2026-08-07] Sobreposição conta UMA vez.** Antes, amostras
    /// sobrepostas (iPhone + relógio na mesma madrugada) eram somadas, e havia
    /// um comentário aqui dizendo que mudar isso mexeria no número que a pessoa
    /// já via. Mexeu — e era esse o conserto: o número que ela via estava
    /// errado em DUAS telas ao mesmo tempo, com valores diferentes (9h21 no
    /// card, 11h30 na outra) para uma noite de 6h50. Um app que mostra duas
    /// durações para a mesma madrugada não tem credibilidade nenhuma.
    ///
    /// O TOTAL é a união de todos os estágios de sono juntos — **não** a soma
    /// dos quatro. Somar contaria duas vezes o minuto em que o iPhone diz
    /// "dormindo, sem estágio" e o relógio diz "REM".
    ///
    /// LIMITE CONHECIDO, escrito de propósito: se uma fonte grosseira cobrir com
    /// "dormindo" um trecho que outra marcou como "acordado", o trecho conta
    /// como sono. Não subtraímos `acordado` da união porque isso seria eleger
    /// uma fonte como mais confiável que a outra sem ter como saber. O efeito é
    /// de minutos, não de horas — a ordem de grandeza que motivou este conserto
    /// era 1,4× a 1,7×.
    static func montar(_ amostras: [AmostraDeSono]) -> NoiteDeSono? {
        guard !amostras.isEmpty else { return nil }

        func blocos(_ e: AmostraDeSono.Estagio) -> [(inicio: Date, fim: Date)] {
            unirIntervalos(amostras.filter { $0.estagio == e })
        }
        func horas(_ e: AmostraDeSono.Estagio) -> Double { horasDosBlocos(blocos(e)) }

        let rem = horas(.rem)
        let profundo = horas(.profundo)

        // A união dos QUATRO estágios de sono de uma vez só.
        let estagiosDeSono: Set<AmostraDeSono.Estagio> = [.rem, .profundo, .leve, .indeterminado]
        let dormido = horasDosBlocos(
            unirIntervalos(amostras.filter { estagiosDeSono.contains($0.estagio) })
        )

        let classificada = amostras.contains {
            $0.estagio == .rem || $0.estagio == .profundo || $0.estagio == .leve
        }

        if dormido <= 0 {
            // Só "na cama": dá para dizer o tempo, não dá para pontuar.
            let naCama = horas(.naCama)
            guard naCama > 0 else { return nil }
            return NoiteDeSono(totalDormido: naCama, rem: nil, profundo: nil,
                               acordado: nil, despertares: nil)
        }

        guard classificada else {
            return NoiteDeSono(totalDormido: dormido, rem: nil, profundo: nil,
                               acordado: nil, despertares: nil)
        }

        // `despertares` conta BLOCOS unidos, não amostras: o mesmo despertar
        // gravado pelo iPhone e pelo relógio é um despertar, não dois.
        let blocosAcordado = blocos(.acordado)

        return NoiteDeSono(
            totalDormido: dormido,
            rem: rem,
            profundo: profundo,
            acordado: horasDosBlocos(blocosAcordado),
            despertares: blocosAcordado.count
        )
    }
}

enum PontuacaoDeSono {

    // MARK: - Faixas de referência
    //
    // Faixas de adulto usadas como "noite de referência". NÃO vão para a tela
    // como número, e a UI não afirma que são fato científico — a regra 3.1 do
    // projeto proíbe. Aqui elas são o parâmetro do cálculo, e só.
    static let duracaoIdeal = 7.0 ... 9.0          // horas
    static let remIdeal = 0.20 ... 0.25            // fração do total
    static let profundoIdeal = 0.13 ... 0.23       // fração do total
    static let acordadoIdeal = 0.0 ... 0.05        // fração do total
    static let despertaresIdeal = 0 ... 2

    static let pesoDuracao = 40
    static let pesoREM = 20
    static let pesoProfundo = 20
    static let pesoContinuidade = 20

    /// Nota 0–1 de um fator.
    ///
    /// Dentro da faixa: 1,0. Fora: cai linearmente e chega a 0 quando a
    /// distância da borda alcança o DOBRO da largura da faixa. Escolhi o dobro
    /// (e não a largura simples) porque com a largura simples uma noite de 6h
    /// zerava o fator duração — punição desproporcional para quem dormiu quase
    /// o suficiente.
    static func nota(_ valor: Double, faixa: ClosedRange<Double>) -> Double {
        if faixa.contains(valor) { return 1 }
        let largura = max(faixa.upperBound - faixa.lowerBound, 0.0001)
        let distancia = valor < faixa.lowerBound
            ? faixa.lowerBound - valor
            : valor - faixa.upperBound
        return max(0, 1 - distancia / (largura * 2))
    }

    struct Resultado {
        /// `nil` quando não há estágios — e aí NÃO existe pontuação.
        let pontos: Int?
        /// Frase curta, descritiva, nunca diagnóstica.
        let descricao: String
        /// Detalhe por fator, para a tela poder explicar a conta.
        let fatores: [(nome: String, nota: Double, peso: Int)]
        let precisaDeEstagios: Bool
    }

    static func calcular(_ n: NoiteDeSono) -> Resultado {
        guard n.totalDormido > 0 else {
            return Resultado(pontos: nil,
                             descricao: "Sem registro de sono nesta noite.",
                             fatores: [],
                             precisaDeEstagios: false)
        }

        guard let rem = n.rem, let profundo = n.profundo else {
            // Honestidade: dá para dizer quanto dormiu, não dá para pontuar.
            return Resultado(pontos: nil,
                             descricao: "\(horas(n.totalDormido)) de sono. "
                                      + "A pontuação precisa dos estágios do sono.",
                             fatores: [],
                             precisaDeEstagios: true)
        }

        let notaDuracao = nota(n.totalDormido, faixa: duracaoIdeal)
        let notaREM = nota(rem / n.totalDormido, faixa: remIdeal)
        let notaProfundo = nota(profundo / n.totalDormido, faixa: profundoIdeal)

        // Continuidade = média entre "quanto tempo ficou acordado" e
        // "quantas vezes acordou". Quando um dos dois falta, vale o outro.
        var partes: [Double] = []
        if let acordado = n.acordado {
            partes.append(nota(acordado / n.totalDormido, faixa: acordadoIdeal))
        }
        if let d = n.despertares {
            partes.append(nota(Double(d),
                               faixa: Double(despertaresIdeal.lowerBound)...Double(despertaresIdeal.upperBound)))
        }
        let notaContinuidade = partes.isEmpty ? 1.0 : partes.reduce(0, +) / Double(partes.count)

        let bruto = notaDuracao * Double(pesoDuracao)
                  + notaREM * Double(pesoREM)
                  + notaProfundo * Double(pesoProfundo)
                  + notaContinuidade * Double(pesoContinuidade)
        let pontos = Int(bruto.rounded())

        return Resultado(
            pontos: pontos,
            descricao: descricaoDe(pontos: pontos, horas: n.totalDormido),
            fatores: [("Tempo total", notaDuracao, pesoDuracao),
                      ("REM", notaREM, pesoREM),
                      ("Sono profundo", notaProfundo, pesoProfundo),
                      ("Continuidade", notaContinuidade, pesoContinuidade)],
            precisaDeEstagios: false)
    }

    /// Linguagem descritiva e acolhedora. Nada de "seu sono é ruim".
    static func descricaoDe(pontos: Int, horas h: Double) -> String {
        switch pontos {
        case 85...:  return "Noite parecida com a de referência — \(horas(h))."
        case 70..<85: return "Noite perto da referência — \(horas(h))."
        case 50..<70: return "Noite com algumas diferenças da referência — \(horas(h))."
        default:      return "Noite bem diferente da referência — \(horas(h))."
        }
    }

    static func horas(_ h: Double) -> String {
        let total = Int((h * 60).rounded())
        return "\(total / 60)h\(String(format: "%02d", total % 60))"
    }

    /// Texto fixo da tela. Fica aqui para o checador de copy alcançar.
    static let explicacao =
        "Comparamos seu sono com uma noite de referência: tempo total, REM, "
      + "sono profundo e continuidade."
    /// [2026-08-07] O rodapé dizia: *"Estimativa do Alma a partir dos seus
    /// dados. Não vem do Apple Saúde e não é avaliação clínica."*
    ///
    /// O Assis apontou, e estava certo: **os dados VÊM do Apple Saúde.** Tempo
    /// total, REM, profundo e despertares só podem vir de lá — é o relógio que
    /// estagia o sono, e o app não tem como medir nada disso sozinho. Conferido
    /// na origem antes de reescrever: `HealthManager.readSleepLastNight` →
    /// `HKSampleQuery(.sleepAnalysis)` → `traduzirAmostraDeSono` → `montar`.
    /// Todos os campos de `NoiteDeSono` nascem de `HKCategorySample`.
    ///
    /// O que é do Alma é a PONTUAÇÃO: as faixas de referência deste arquivo, as
    /// notas por fator e o total de 0 a 100 (`calcular`). Nada disso existe no
    /// HealthKit — não há métrica de qualidade de sono na Apple.
    ///
    /// A frase antiga negava a origem do dado e, com isso, sugeria que o app
    /// tinha inventado os números. Trocar "não vem do Apple Saúde" por uma
    /// separação explícita entre DADO e PONTUAÇÃO corrige sem afrouxar nada: o
    /// "não é avaliação clínica" continua, porque é ele que segura a regra 3.1.
    ///
    /// Vale para as três ramificações do card (com pontuação, sem estágios e
    /// sem registro nenhum) — o rodapé é renderizado embaixo das três.
    static let rodape =
        "Tempo total, REM, sono profundo e despertares vêm do Apple Saúde. "
      + "A pontuação e a comparação com uma noite de referência são cálculo "
      + "do Alma — não é avaliação clínica."

    /// O que a tela diz quando existe duração mas faltam os estágios.
    static let semEstagios =
        "Sem os estágios do sono não dá para pontuar a noite. Quem grava "
      + "estágios é o relógio; o iPhone sozinho costuma registrar só a duração."

    // MARK: - Contexto da IA
    //
    // [2026-08-04] A linha que a Alma recebe DESCREVE a noite; ela nunca
    // recomenda nada. É a regra 3.2 do CLAUDE.md aplicada na origem: se o dado
    // chegasse embalado em conselho ("dormiu pouco, tente dormir mais"), a IA
    // repetiria o conselho como se fosse dela. O adjetivo "estimativa do Alma"
    // viaja junto de propósito — o modelo também não pode tratar o número como
    // medida clínica.

    /// `nil` quando não há pontuação: sem estágios, a IA recebe só a duração
    /// pela linha de sono que já existia. Nada é inventado para preencher.
    static func linhaParaIA(_ r: Resultado) -> String? {
        guard let pontos = r.pontos else { return nil }
        return "Pontuação de sono: \(pontos)/100 (estimativa do Alma pelos "
             + "estágios da noite, não é medida clínica)"
    }
}
