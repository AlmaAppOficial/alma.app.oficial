// JejumAtributosAoVivo.swift
// Alma — Corpo · o contrato entre o app e a extensão que desenha a tela bloqueada.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO É PEQUENO, E POR QUE ISSO É DE PROPÓSITO
//
// Este é o ÚNICO arquivo compilado nos dois lados: no app (que decide) e na
// extensão `AlmaJejumWidget` (que desenha). Tudo que entra aqui vira peso morto
// no `.appex`, e — pior — vira acoplamento: mudar `Jejum.swift` passaria a
// obrigar a recompilar e a re-testar o widget.
//
// Por isso ele NÃO importa `Jejum.swift`. Nada de `ProtocoloDeJejum`, nada de
// `JejumEmCurso`. O que atravessa a fronteira são strings já prontas e datas.
// A extensão não sabe o que é um protocolo de jejum; ela sabe desenhar um
// cronômetro. Quem traduz um no outro é `JejumAoVivo.swift`, do lado do app.
//
// ═══════════════════════════════════════════════════════════════════════════
// A DECISÃO CENTRAL: `baseDoCronometro` NÃO É `inicio`
//
// Mesma escolha do Android (`JejumAvisos.kt`), e pelo mesmo motivo:
//
//     baseDoCronometro = agora − decorrido
//
// `JejumEmCurso.inicio` é reescrito a cada retomada. Um cronômetro ancorado
// nele mostraria só o trecho depois da última pausa — quem pausou dez minutos
// depois de doze horas de jejum veria "10 min" na tela bloqueada e "12 h 10" na
// tela do app. Duas verdades para o mesmo número é o defeito que este módulo
// passou agosto fechando.
//
// Subtrair o decorrido de agora já embute o `acumuladoAntesDaPausa`, e o
// sistema desenha o resto sozinho: `Text(timerInterval:)` conta a partir dessa
// âncora sem o app precisar estar vivo. É por isso que o cronômetro continua
// correndo com o telefone no bolso — não há timer nosso rodando, há uma data.
//
// ═══════════════════════════════════════════════════════════════════════════
// O QUE APARECE NA TELA BLOQUEADA É DADO DE SAÚDE — E FICA NO APARELHO
//
// Nada aqui viaja: `ActivityKit` local não usa servidor, e o app não pede
// `pushType`. O estado do jejum sai do `JejumStore` (UserDefaults, aparelho) e
// vai direto para o `.appex`, no mesmo aparelho. Se algum dia alguém quiser
// atualizar a atividade por push, isso passa a mandar o estado do jejum de
// alguém para um servidor da Apple — decisão de privacidade, não de arquitetura,
// e que precisa passar pela corregedoria antes.

import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// O que a atividade ao vivo do jejum mostra na tela bloqueada e na Ilha
/// Dinâmica.
///
/// `@available(iOS 16.2)` e não 16.1: a partir do 16.2 existem `ActivityContent`
/// e `Activity.end(_:dismissalPolicy:)`, que são o jeito não-depreciado de
/// atualizar e de encerrar. O alvo do app continua sendo iOS 16.0 — quem estiver
/// abaixo de 16.2 simplesmente não ganha a atividade e segue com os dois avisos
/// de sempre. Ver `JejumAoVivo.swift`.
@available(iOS 16.2, *)
public struct AtributosDoJejumAoVivo: ActivityAttributes {

    /// A parte que muda enquanto o jejum corre.
    ///
    /// Repare no que NÃO está aqui: nenhum texto que dependa da hora atual.
    /// "Faltam 3 h 12 min" viraria mentira em treze minutos, porque a extensão
    /// só é redesenhada quando o app manda um estado novo — e o app está
    /// fechado, que é justamente o cenário. O que muda com o tempo é desenhado
    /// pelo sistema a partir das DATAS (`baseDoCronometro`, `metaEm`); o que é
    /// texto é fixo e continua verdadeiro sem atualização nenhuma.
    public struct ContentState: Codable, Hashable {
        /// Âncora do cronômetro: `agora − decorrido`. Ver o cabeçalho.
        public var baseDoCronometro: Date
        /// Quando a meta do protocolo será atingida, contando de `baseDoCronometro`.
        public var metaEm: Date
        /// Congela o cronômetro na tela. É o `pauseTime` do `Text(timerInterval:)`.
        public var pausadoEm: Date?
        /// Já passou da meta no instante em que este estado foi montado.
        public var atingiuAMeta: Bool

        public init(baseDoCronometro: Date,
                    metaEm: Date,
                    pausadoEm: Date? = nil,
                    atingiuAMeta: Bool = false) {
            self.baseDoCronometro = baseDoCronometro
            self.metaEm = metaEm
            self.pausadoEm = pausadoEm
            self.atingiuAMeta = atingiuAMeta
        }

        public var estaPausado: Bool { pausadoEm != nil }
    }

    /// "16/8", "OMAD". Já formatado — a extensão não conhece `ProtocoloDeJejum`.
    public var protocoloRotulo: String
    /// "16 h". Idem: já passou por `textoDaDuracao` do lado do app.
    public var metaFormatada: String

    public init(protocoloRotulo: String, metaFormatada: String) {
        self.protocoloRotulo = protocoloRotulo
        self.metaFormatada = metaFormatada
    }
}

#endif
