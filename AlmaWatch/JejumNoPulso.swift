// JejumNoPulso.swift
// Alma Watch — o contrato do jejum no pulso, sem uma linha de SwiftUI.
//
// ═══════════════════════════════════════════════════════════════════════════
// UM ARQUIVO, DOIS ALVOS — E POR QUE ISSO É DECISÃO, NÃO ACIDENTE
//
// Este arquivo é compilado no app do relógio E na extensão da complicação
// (mesmo truque do `JejumAtributosAoVivo.swift`, que o app do iPhone divide
// com o widget da tela bloqueada). A complicação de streak/água duplica as
// leituras do App Group de propósito ("a extensão não compila os arquivos do
// app") — mas lá o que se duplica é leitura de inteiro, sem regra. Aqui há
// REGRA: o que é um par (base, meta) válido, como congelar a fração na pausa,
// quando a meta foi atingida. Regra duplicada diverge; regra num arquivo só,
// não. E regra num arquivo que só importa Foundation pode ser reprovada por
// mutação num binário de linha de comando (`_scripts/rodar_testes_jejum_watch.sh`),
// que é a Regra 1 do CLAUDE.md.
//
// ═══════════════════════════════════════════════════════════════════════════
// O CONTRATO É O MESMO DA TELA BLOQUEADA DO IPHONE
//
// `base = agora − decorrido` (nunca `inicio`, que é reescrito a cada retomada),
// `meta = base + duração do protocolo`, `pausadoEm` congela, e o rótulo chega
// pronto ("16/8") porque o pulso não conhece `ProtocoloDeJejum`. É, campo por
// campo, o `EstadoDoCronometroAoVivo` de `Shared/Corpo/JejumAoVivo.swift` —
// atravessando WCSession em vez de ActivityKit. Quem monta os valores é o
// iPhone (`WatchBridge.montarContexto`); o relógio nunca decide, só desenha.
//
// Por que o relógio importa mais que a tela bloqueada aqui: o iOS MATA a
// atividade ao vivo em 8 horas, e um 16/8 dura dezesseis. No pulso não há esse
// teto — é onde o cronômetro dura o jejum inteiro.
//
// ═══════════════════════════════════════════════════════════════════════════
// PRIVACIDADE
//
// Jejum é dado de saúde. Ele viaja do iPhone para o relógio por WCSession
// (canal local do sistema, aparelho ↔ aparelho pareado) e fica no App Group
// DO RELÓGIO para a complicação ler. Nada disto encosta em Firestore,
// Analytics ou rede — a mesma regra do módulo Corpo inteiro.

import Foundation

enum JejumNoPulso {

    // MARK: - Chaves do App Group (relógio ↔ complicação)
    //
    // Moram aqui, e não em `WatchGroupKeys`, porque a complicação compila este
    // arquivo e não o `WatchState.swift`. Uma chave digitada duas vezes é a
    // primeira coisa que diverge.

    static let suite = "group.com.almaapp.shared"
    static let chaveBase      = "watch_jejum_base"
    static let chaveMeta      = "watch_jejum_meta"
    static let chavePausadoEm = "watch_jejum_pausado_em"
    static let chaveRotulo    = "watch_jejum_rotulo"

    // MARK: - Regras puras

    /// Um par (base, meta) em segundos de época só é um jejum se a base existir
    /// e a meta vier DEPOIS dela. `meta == base` é inválido: viraria divisão por
    /// zero na fração e um anel que nasce cheio.
    static func valido(base: Double, meta: Double) -> Bool {
        base > 0 && meta > base
    }

    /// Fração 0…1 da barra/anel congelada na pausa. Derivada das datas que já
    /// estão no estado — mesma conta do `BarraDoJejum` da tela bloqueada
    /// (`AlmaJejumWidget/JejumAoVivoWidget.swift`): decorrido = pausadoEm − base,
    /// alvo = meta − base.
    static func fracaoCongelada(base: Date, meta: Date, pausadoEm: Date) -> Double {
        let alvo = meta.timeIntervalSince(base)
        guard alvo > 0 else { return 0 }
        return min(1, max(0, pausadoEm.timeIntervalSince(base) / alvo))
    }

    /// "16 h", "1 h 5 min", "45 min" — cópia fiel de `textoDaDuracao`
    /// (`Shared/Corpo/Jejum.swift`), que o alvo do relógio não compila.
    /// Mudou lá, muda aqui.
    static func textoDeDuracao(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// "12h" / "35m" — para o centro da complicação circular, onde não cabe
    /// mais que três ou quatro caracteres.
    static func textoCompacto(_ segundos: TimeInterval) -> String {
        let total = Int(max(0, segundos))
        let h = total / 3600
        return h > 0 ? "\(h)h" : "\(total / 60)m"
    }

    /// "5:12:00" — o cronômetro CONGELADO da pausa, no mesmo desenho do
    /// `Text(timerInterval:)` que corre (hora sem zero à esquerda).
    ///
    /// Pausado usa texto estático em vez de `Text(timerInterval:pauseTime:)`
    /// por ser derivado do estado: o que congela é a MESMA conta que a barra e
    /// a complicação usam, então os três números não têm como divergir.
    ///
    /// Registro de método (29/08): a primeira medição parecia acusar o
    /// `pauseTime:` de não congelar no valor certo (5:13:36 em vez de 5:12:00).
    /// A causa real era o harness de captura: `defaults write -float` grava
    /// float de 32 bits, e em magnitude de época (~1,79e9 s) o passo de
    /// quantização é de ~128 s — os 96 s de desvio eram do arredondamento das
    /// seeds, não da API. Semear com `-int` zerou o desvio. Fica escrito para
    /// ninguém reabrir o processo contra a API com a prova viciada.
    static func cronometro(_ segundos: TimeInterval) -> String {
        let t = Int(max(0, segundos))
        return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    // MARK: - Estado

    /// O jejum como o pulso o conhece. Quatro campos, nenhuma decisão do lado
    /// de cá além de ler datas.
    struct Estado: Codable, Equatable {
        /// Âncora do cronômetro: `agora − decorrido`, montada pelo iPhone.
        var base: Date
        /// Quando a meta do protocolo cai, contando da âncora.
        var meta: Date
        /// Congela o cronômetro. `nil` = correndo.
        var pausadoEm: Date?
        /// "16/8", "OMAD" — já formatado pelo iPhone.
        var rotulo: String

        var estaPausado: Bool { pausadoEm != nil }

        /// Segundos de jejum já corridos. Pausado, congela em `pausadoEm − base`
        /// (conta que não deriva: os dois lados derivam juntos a cada republicação
        /// do contexto). Correndo, `agora − base` — nunca negativo, pelo mesmo
        /// motivo do `JejumEmCurso.decorrido`: relógio acertado para trás não
        /// pode virar "-2:31:00" na tela.
        func decorrido(agora: Date = Date()) -> TimeInterval {
            if let pausadoEm { return max(0, pausadoEm.timeIntervalSince(base)) }
            return max(0, agora.timeIntervalSince(base))
        }

        func atingiuAMeta(agora: Date = Date()) -> Bool {
            decorrido(agora: agora) >= meta.timeIntervalSince(base)
        }

        /// Duração da meta do protocolo ("16 h" vem daqui).
        var duracaoDaMeta: TimeInterval { meta.timeIntervalSince(base) }
    }

    // MARK: - App Group (o mesmo ler/gravar para o app e para a complicação)

    /// Lê o jejum do App Group. `nil` = sem jejum em curso.
    static func carregar(de defaults: UserDefaults?) -> Estado? {
        guard let d = defaults else { return nil }
        let base = d.double(forKey: chaveBase)
        let meta = d.double(forKey: chaveMeta)
        guard valido(base: base, meta: meta) else { return nil }
        let p = d.double(forKey: chavePausadoEm)
        return Estado(base: Date(timeIntervalSince1970: base),
                      meta: Date(timeIntervalSince1970: meta),
                      pausadoEm: p > 0 ? Date(timeIntervalSince1970: p) : nil,
                      rotulo: d.string(forKey: chaveRotulo) ?? "")
    }

    /// Grava (`nil` limpa — encerrar no iPhone tem de apagar a complicação).
    static func salvar(_ estado: Estado?, em defaults: UserDefaults?) {
        guard let d = defaults else { return }
        guard let e = estado else {
            d.removeObject(forKey: chaveBase)
            d.removeObject(forKey: chaveMeta)
            d.removeObject(forKey: chavePausadoEm)
            d.removeObject(forKey: chaveRotulo)
            return
        }
        d.set(e.base.timeIntervalSince1970, forKey: chaveBase)
        d.set(e.meta.timeIntervalSince1970, forKey: chaveMeta)
        if let p = e.pausadoEm {
            d.set(p.timeIntervalSince1970, forKey: chavePausadoEm)
        } else {
            d.removeObject(forKey: chavePausadoEm)
        }
        d.set(e.rotulo, forKey: chaveRotulo)
    }
}
