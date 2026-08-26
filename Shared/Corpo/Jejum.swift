// Jejum.swift
// Alma — Corpo · o domínio do jejum intermitente, sem uma linha de SwiftUI.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO SÓ IMPORTA FOUNDATION
//
// Mesmo motivo do `Refeicao.swift` e do `RegrasDeSaude.swift`: uma regra que só
// roda com a árvore de views montada é uma regra que ninguém exercita. Tudo que
// decide alguma coisa aqui — quanto tempo passou, se a meta foi atingida, se a
// sequência continua — é função pura sobre datas, e por isso pode ser reprovada
// por mutação num binário de linha de comando (`_scripts/testes_jejum.swift`).
//
// O que mora aqui: os protocolos, o estado do jejum em curso, o histórico e a
// sequência. O que NÃO mora aqui: UserDefaults (é do `JejumStore`),
// notificações (idem) e tela (`JejumView`).
//
// ═══════════════════════════════════════════════════════════════════════════
// A DECISÃO MAIS IMPORTANTE DESTE ARQUIVO: RELÓGIO DE PAREDE
//
// O pedido do Assis é explícito — "estado que sobreviva a fechar o app e a
// reiniciar o telefone". Existem duas formas de cronometrar no iOS, e uma delas
// falha exatamente nesse caso:
//
//   • `ProcessInfo.systemUptime` / `DispatchTime` são MONOTÔNICOS. Não andam
//     para trás, não são afetados por mudança de fuso, e **zeram quando o
//     aparelho reinicia**. Um jejum de 16 h iniciado às 20 h de ontem viraria
//     "0 h" depois de um reboot às 3 h da manhã.
//   • `Date` é relógio de PAREDE. Sobrevive a fechar o app, a reiniciar, e
//     inclusive à reinstalação enquanto o UserDefaults existir.
//
// Este arquivo usa `Date`. É a escolha certa para a pergunta "que horas eu
// comecei", que é a pergunta que o usuário faz. O preço é que mexer no relógio
// do aparelho mexe no cronômetro — e `decorrido` trata isso devolvendo zero em
// vez de um número negativo, em vez de fingir que não acontece.
//
// ═══════════════════════════════════════════════════════════════════════════
// A PAUSA, E POR QUE ELA NÃO É "PARAR E RECOMEÇAR"
//
// Pausar guarda quanto já tinha corrido (`acumuladoAntesDaPausa`) e apaga o
// ponto de partida. Retomar cria um ponto de partida novo, e o decorrido passa
// a ser "acumulado + o que correu desde a retomada". Sem o acumulado, pausar
// por um minuto jogaria 15 horas fora — e o usuário aprenderia a nunca pausar,
// que é o oposto do que um botão de pausa existe para permitir.
//
// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ OS `rawValue` DE `ProtocoloDeJejum` VÃO PARA O DISCO.
//
// `JejumEmCurso` e `JejumConcluido` são `Codable` e vivem em UserDefaults.
// Trocar o texto de um caso quebra o histórico de quem já usa — a mesma
// armadilha documentada no topo do `MealType`, em `Refeicao.swift`. Para mudar
// o que a TELA mostra, use `rotulo`, nunca o `rawValue`.

import Foundation

// MARK: - Protocolo

/// Os formatos de jejum que o app oferece.
///
/// ── POR QUE A LISTA PARA NA OMAD ────────────────────────────────────────────
/// Não há caso de 36 h, 48 h ou 72 h, e a ausência é deliberada.
///
/// Isto NÃO é um filtro sobre o usuário: o cronômetro continua contando depois
/// da meta, ninguém é interrompido, e quem quiser jejuar mais tempo jejua — a
/// escolha é dele e o app não opina. O que o app não faz é OFERECER duração
/// longa como produto, porque oferecer é sugerir, e sugerir jejum prolongado
/// num app de bem-estar com registro de humor e de ciclo é empurrar na direção
/// errada. Jejum acima de 24 h tem indicação clínica e acompanhamento; não é
/// item de menu.
///
/// A mesma régua governa a celebração: ver `Sequencia`, que conta DIAS, não
/// horas — de propósito.
public enum ProtocoloDeJejum: String, CaseIterable, Identifiable, Codable, Equatable {
    case dezesseisPorOito = "16/8"
    case dezoitoPorSeis   = "18/6"
    case vintePorQuatro   = "20/4"
    case cincoTrintaSeis  = "5:2"
    case omad             = "OMAD"

    public var id: String { rawValue }

    /// O que a tela mostra. Separado do `rawValue` porque o `rawValue` está no
    /// disco de quem já usa o app.
    public var rotulo: String {
        switch self {
        case .dezesseisPorOito: return "16/8"
        case .dezoitoPorSeis:   return "18/6"
        case .vintePorQuatro:   return "20/4"
        case .cincoTrintaSeis:  return "5:2"
        case .omad:             return "OMAD"
        }
    }

    /// Horas de jejum que o protocolo propõe.
    ///
    /// O 5:2 é o caso diferente da lista: ele não é uma janela diária, é um
    /// padrão semanal (cinco dias de alimentação normal, dois dias de ingestão
    /// bem reduzida). O cronômetro trata o dia reduzido como um jejum de 24 h
    /// entre refeições — é a leitura mais próxima do que a pessoa faz, e a tela
    /// diz isso com todas as letras em `detalhe`, para o número não mentir.
    public var horasDeJejum: Double {
        switch self {
        case .dezesseisPorOito: return 16
        case .dezoitoPorSeis:   return 18
        case .vintePorQuatro:   return 20
        case .cincoTrintaSeis:  return 24
        case .omad:             return 23
        }
    }

    /// Horas de janela alimentar. `nil` no 5:2, que não tem janela diária.
    public var horasDeJanela: Double? {
        switch self {
        case .cincoTrintaSeis: return nil
        default: return 24 - horasDeJejum
        }
    }

    public var duracaoDoJejum: TimeInterval { horasDeJejum * 3600 }

    /// Uma linha honesta sobre o que o protocolo é. Sem promessa de resultado.
    public var detalhe: String {
        switch self {
        case .dezesseisPorOito:
            return "16 horas sem comer e 8 horas para comer. É o formato mais estudado."
        case .dezoitoPorSeis:
            return "18 horas sem comer e 6 horas para comer."
        case .vintePorQuatro:
            return "20 horas sem comer e 4 horas para comer."
        case .cincoTrintaSeis:
            return "Cinco dias comendo normal e dois dias comendo bem pouco. Não é janela de horas: o cronômetro conta o intervalo do dia de comer pouco."
        case .omad:
            return "Uma refeição por dia. A janela dura cerca de 1 hora."
        }
    }

    public var simbolo: String {
        switch self {
        case .dezesseisPorOito: return "clock"
        case .dezoitoPorSeis:   return "clock.badge"
        case .vintePorQuatro:   return "clock.badge.exclamationmark"
        case .cincoTrintaSeis:  return "calendar"
        case .omad:             return "fork.knife"
        }
    }
}

// MARK: - Jejum em curso

/// O jejum que está acontecendo agora. `nil` no `JejumStore` = janela alimentar.
///
/// Os três campos juntos representam quatro situações, e nenhuma outra:
///   · `inicio != nil, pausadoEm == nil`  → correndo
///   · `inicio == nil, pausadoEm != nil`  → pausado
///   · os dois nil                        → estado impossível; `decorrido`
///                                          devolve o acumulado e segue
///   · os dois preenchidos                → idem, tratado como pausado
public struct JejumEmCurso: Codable, Equatable {
    public var protocolo: ProtocoloDeJejum
    /// Quando o trecho ATUAL começou a correr. `nil` quando pausado.
    public var inicio: Date?
    /// Quando pausou. `nil` quando correndo.
    public var pausadoEm: Date?
    /// Quanto já tinha corrido antes da pausa vigente.
    public var acumuladoAntesDaPausa: TimeInterval
    /// Quando a pessoa apertou "começar" pela primeira vez. Só para o histórico
    /// e para a tela dizer "desde as 20:14" — nunca entra no cálculo do
    /// decorrido, que precisa ignorar o tempo pausado.
    public var comecouEm: Date

    public init(protocolo: ProtocoloDeJejum,
                inicio: Date? = nil,
                pausadoEm: Date? = nil,
                acumuladoAntesDaPausa: TimeInterval = 0,
                comecouEm: Date = Date()) {
        self.protocolo = protocolo
        self.inicio = inicio ?? comecouEm
        self.pausadoEm = pausadoEm
        self.acumuladoAntesDaPausa = max(0, acumuladoAntesDaPausa)
        self.comecouEm = comecouEm
    }

    public var estaPausado: Bool { inicio == nil || pausadoEm != nil }

    /// Quanto tempo de jejum já correu, em segundos.
    ///
    /// NUNCA negativo. O caso que produz negativo é real e não é hipótese: a
    /// pessoa viaja, o fuso muda, ou ela mesma acerta o relógio para trás. Um
    /// `TimeInterval` negativo viraria "-2:31:00" em fonte grande na tela e um
    /// progresso negativo no anel. `max(0, …)` é a diferença entre um número
    /// esquisito e uma tela quebrada.
    public func decorrido(agora: Date = Date()) -> TimeInterval {
        guard let inicio, pausadoEm == nil else { return acumuladoAntesDaPausa }
        return acumuladoAntesDaPausa + max(0, agora.timeIntervalSince(inicio))
    }

    /// 0…1 até a meta; passa de 1 quando a pessoa segue além dela.
    ///
    /// NÃO é limitado a 1 aqui de propósito: quem desenha é que decide o teto do
    /// anel. A tela precisa saber a diferença entre "chegou" e "está muito além"
    /// para escolher o texto — e essa informação some se a função truncar.
    public func progresso(agora: Date = Date()) -> Double {
        let alvo = protocolo.duracaoDoJejum
        guard alvo > 0 else { return 0 }
        return decorrido(agora: agora) / alvo
    }

    public func metaAtingida(agora: Date = Date()) -> Bool {
        decorrido(agora: agora) >= protocolo.duracaoDoJejum
    }

    /// Quando a meta será atingida, se o jejum seguir sem pausa a partir de
    /// agora. `nil` quando pausado — porque um horário previsto para um
    /// cronômetro parado é um número que a tela não tem direito de mostrar.
    public func previsaoDeTermino(agora: Date = Date()) -> Date? {
        guard !estaPausado else { return nil }
        let falta = protocolo.duracaoDoJejum - decorrido(agora: agora)
        return agora.addingTimeInterval(max(0, falta))
    }

    /// Quanto falta. Zero quando a meta já foi atingida.
    public func restante(agora: Date = Date()) -> TimeInterval {
        max(0, protocolo.duracaoDoJejum - decorrido(agora: agora))
    }

    // MARK: Transições

    public func pausando(agora: Date = Date()) -> JejumEmCurso {
        guard !estaPausado else { return self }
        var c = self
        c.acumuladoAntesDaPausa = decorrido(agora: agora)
        c.inicio = nil
        c.pausadoEm = agora
        return c
    }

    public func retomando(agora: Date = Date()) -> JejumEmCurso {
        guard estaPausado else { return self }
        var c = self
        c.inicio = agora
        c.pausadoEm = nil
        return c
    }
}

// MARK: - Jejum concluído

/// Uma linha do histórico.
///
/// Guarda a duração JÁ CALCULADA em vez de duas datas. É a mesma regra do
/// invariante da `Meal`: dois números para a mesma coisa é a definição do bug
/// que este app passou agosto fechando. Aqui a duração é o único número, e o
/// tempo pausado — que a diferença entre duas datas não conhece — já está
/// descontado dela.
public struct JejumConcluido: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var protocolo: ProtocoloDeJejum
    public var comecouEm: Date
    public var terminouEm: Date
    /// Segundos EFETIVAMENTE em jejum, já sem o tempo pausado.
    public var duracao: TimeInterval

    public init(id: UUID = UUID(), protocolo: ProtocoloDeJejum,
                comecouEm: Date, terminouEm: Date, duracao: TimeInterval) {
        self.id = id
        self.protocolo = protocolo
        self.comecouEm = comecouEm
        self.terminouEm = terminouEm
        self.duracao = max(0, duracao)
    }

    /// Chegou na meta do protocolo escolhido?
    public var cumpriuAMeta: Bool { duracao >= protocolo.duracaoDoJejum }

    private enum CodingKeys: String, CodingKey {
        case id, protocolo, comecouEm, terminouEm, duracao
    }

    /// À mão pelo mesmo motivo do `ComponenteDaRefeicao`: `id` opcional na
    /// decodificação para o dado gravado por uma versão futura sem `id` não
    /// derrubar o histórico inteiro num `try?` engolido.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        protocolo  = try c.decode(ProtocoloDeJejum.self, forKey: .protocolo)
        comecouEm  = try c.decode(Date.self, forKey: .comecouEm)
        terminouEm = try c.decode(Date.self, forKey: .terminouEm)
        duracao    = max(0, try c.decode(TimeInterval.self, forKey: .duracao))
    }
}

// MARK: - Sequência

/// O que o app celebra: DIAS seguidos com uma janela cumprida.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// POR QUE A MÉTRICA É DIA E NÃO HORA
///
/// O pedido do Assis, literal: "não gamifique jejum mais longo sem teto.
/// Sequência e recorde são ok; 'seu novo recorde: 36 horas' como celebração,
/// não."
///
/// Um placar que sobe com a DURAÇÃO pede, por construção, jejum cada vez mais
/// longo — e num app que fala com gente em momento frágil, isso é um cronômetro
/// de restrição com pontuação. Um placar que sobe com CONSTÂNCIA pede a mesma
/// coisa amanhã, e o teto é um por dia.
///
/// Consequência de desenho, e é de propósito: um 16/8 cumprido vale exatamente
/// o mesmo que um OMAD cumprido. Não há mais pontos por jejuar mais tempo,
/// porque não há mais pontos por jejuar mais tempo.
///
/// O jejum mais longo do histórico CONTINUA visível — está em
/// `EstatisticasDoJejum.maisLongo`, na aba de histórico, como número seco. Ver
/// é diferente de comemorar; o que este arquivo não faz é transformar o número
/// em conquista.
/// ═══════════════════════════════════════════════════════════════════════════
public enum Sequencia {

    /// Dias consecutivos, terminando em hoje ou ontem, com pelo menos um jejum
    /// que cumpriu a meta do próprio protocolo.
    ///
    /// Aceitar que a sequência termine ONTEM é decisão: quem jejua 16/8 e ainda
    /// não fechou a janela de hoje às 11 h da manhã não perdeu a sequência — ela
    /// está viva e pendente. Exigir "hoje" faria o número piscar para zero toda
    /// madrugada e voltar à tarde.
    public static func dias(_ historico: [JejumConcluido],
                            hoje: Date = Date(),
                            calendario: Calendar = .current) -> Int {
        let diasComMeta = Set(historico
            .filter(\.cumpriuAMeta)
            .map { calendario.startOfDay(for: $0.terminouEm) })
        guard !diasComMeta.isEmpty else { return 0 }

        let inicioDeHoje = calendario.startOfDay(for: hoje)
        // Âncora: hoje se houve hoje; senão ontem; senão a sequência acabou.
        var cursor: Date
        if diasComMeta.contains(inicioDeHoje) {
            cursor = inicioDeHoje
        } else if let ontem = calendario.date(byAdding: .day, value: -1, to: inicioDeHoje),
                  diasComMeta.contains(ontem) {
            cursor = ontem
        } else {
            return 0
        }

        var total = 0
        while diasComMeta.contains(cursor) {
            total += 1
            guard let anterior = calendario.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = anterior
        }
        return total
    }
}

// MARK: - Estatísticas do histórico

/// Os números da aba de histórico. Descritivos, sem adjetivo.
public struct EstatisticasDoJejum: Equatable {
    public let total: Int
    public let cumpriramAMeta: Int
    public let maisLongo: TimeInterval
    public let mediaDosUltimos7: TimeInterval?

    public init(total: Int, cumpriramAMeta: Int, maisLongo: TimeInterval,
                mediaDosUltimos7: TimeInterval?) {
        self.total = total
        self.cumpriramAMeta = cumpriramAMeta
        self.maisLongo = maisLongo
        self.mediaDosUltimos7 = mediaDosUltimos7
    }

    public static func calcular(_ historico: [JejumConcluido],
                                hoje: Date = Date(),
                                calendario: Calendar = .current) -> EstatisticasDoJejum {
        let recentes = historico.filter {
            guard let limite = calendario.date(byAdding: .day, value: -7, to: hoje) else { return false }
            return $0.terminouEm >= limite
        }
        let media: TimeInterval? = recentes.isEmpty
            ? nil
            : recentes.reduce(0) { $0 + $1.duracao } / Double(recentes.count)

        return EstatisticasDoJejum(
            total: historico.count,
            cumpriramAMeta: historico.filter(\.cumpriuAMeta).count,
            maisLongo: historico.map(\.duracao).max() ?? 0,
            mediaDosUltimos7: media
        )
    }
}

// MARK: - Formatação

/// "14 h 32 min" — o texto do cronômetro.
///
/// Aqui e não numa View porque o mesmo texto aparece em três lugares (o card da
/// Dieta, a tela do jejum e o histórico) e três cópias divergem. `CorpoContextFormat`
/// não serve: ele formata número, não duração.
public func textoDaDuracao(_ segundos: TimeInterval, comSegundos: Bool = false) -> String {
    let total = Int(max(0, segundos))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if comSegundos {
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h) h" : "\(h) h \(m) min"
}
