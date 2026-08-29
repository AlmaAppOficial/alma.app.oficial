// JejumAoVivoWidget.swift
// Alma — como o jejum aparece na tela bloqueada e na Ilha Dinâmica.
//
// ═══════════════════════════════════════════════════════════════════════════
// A REGRA QUE GOVERNA ESTE ARQUIVO INTEIRO: NADA AQUI PODE ENVELHECER
//
// Esta extensão só é redesenhada quando o app manda um estado novo — e o app
// está FECHADO, que é justamente o cenário em que a tela bloqueada importa. Um
// texto como "faltam 3 h 12 min" viraria mentira em treze minutos e ficaria
// mentindo até a pessoa abrir o app.
//
// Por isso a divisão é rígida:
//
//   • O que muda com o tempo é desenhado pelo SISTEMA, a partir de DATAS:
//     `Text(timerInterval:)` para o contador e `ProgressView(timerInterval:)`
//     para a barra. Os dois andam sozinhos, sem app, sem timer, sem push.
//   • O que é TEXTO é fixo e continua verdadeiro sem atualização nenhuma:
//     "Meta de 16 h" é verdade às 3 h e às 15 h de jejum.
//
// A única coisa que envelhece é `atingiuAMeta` — e ela só TROCA um texto
// verdadeiro por outro mais específico. Se a atualização não chegar, a tela diz
// "Meta de 16 h · termina às 20:14", que continua correto. Não há estado em que
// esta tela afirme algo falso.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE NÃO HÁ BOTÕES, E POR QUE NÃO HÁ DEEP LINK
//
// Botões (pausar/encerrar pela tela bloqueada) exigem `AppIntents` e um alvo
// compartilhado com o app — é uma segunda funcionalidade, não um detalhe desta.
// O Android também não tem: lá a notificação não tem `addAction` nenhum. Manter
// os dois iguais é escolha, não omissão.
//
// `widgetURL` também não. O app NÃO tem `onOpenURL` — o esquema `alma://` está
// registrado no Info.plist e não é tratado por ninguém. Apontar para
// `alma://jejum` criaria exatamente o defeito que este projeto já documentou
// (deep link morto que cai no fallback). Tocar na atividade abre o app; navegar
// até o jejum é trabalho de outro dia, junto com o roteador de URL.
//
// ═══════════════════════════════════════════════════════════════════════════
// AS CORES SÃO REPETIDAS AQUI, E ISSO É PROPOSITAL
//
// `CorpoTheme` mora no alvo do app. Trazê-lo para cá arrastaria SwiftUI de tela,
// UIKit e o resto do módulo para dentro do `.appex`. São dois hex; a duplicação
// custa menos que o acoplamento. Se a marca mudar, muda nos dois lugares — e
// está escrito aqui para quem mudar saber que existe o segundo lugar.
//   Theme.violet  = 8B7BD8  (jejum correndo)
//   Theme.primary = 6F7D3F  (meta atingida)

import ActivityKit
import WidgetKit
import SwiftUI

struct JejumAoVivoWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AtributosDoJejumAoVivo.self) { contexto in
            TelaBloqueadaDoJejum(atributos: contexto.attributes, estado: contexto.state)
                .activityBackgroundTint(CoresDoJejumAoVivo.fundo)
                .activitySystemActionForegroundColor(CoresDoJejumAoVivo.violeta)

        } dynamicIsland: { contexto in
            let cor = CoresDoJejumAoVivo.acento(atingiuAMeta: contexto.state.atingiuAMeta,
                                                pausado: contexto.state.estaPausado)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Jejum")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(contexto.attributes.protocoloRotulo)
                            .font(.headline)
                            .foregroundStyle(cor)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CronometroDoJejum(estado: contexto.state, fonte: .title2)
                        .foregroundStyle(cor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        BarraDoJejum(estado: contexto.state, cor: cor)
                        LinhaDeEstadoDoJejum(atributos: contexto.attributes, estado: contexto.state)
                    }
                }

            } compactLeading: {
                Image(systemName: contexto.state.estaPausado ? "pause.circle" : "timer")
                    .foregroundStyle(cor)
                    .accessibilityLabel(contexto.state.estaPausado ? "Jejum pausado" : "Jejum em curso")

            } compactTrailing: {
                CronometroDoJejum(estado: contexto.state, fonte: .caption2)
                    .foregroundStyle(cor)
                    // Sem largura fixa a Ilha Dinâmica corta o contador quando
                    // ele passa de 9 h e ganha um dígito na hora.
                    .frame(maxWidth: 54)

            } minimal: {
                Image(systemName: contexto.state.estaPausado ? "pause.circle" : "timer")
                    .foregroundStyle(cor)
                    .accessibilityLabel("Jejum")
            }
        }
    }
}

// MARK: - Tela bloqueada

private struct TelaBloqueadaDoJejum: View {
    let atributos: AtributosDoJejumAoVivo
    let estado: AtributosDoJejumAoVivo.ContentState

    private var cor: Color {
        CoresDoJejumAoVivo.acento(atingiuAMeta: estado.atingiuAMeta, pausado: estado.estaPausado)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: estado.estaPausado ? "pause.circle.fill" : "timer")
                    .font(.footnote)
                    .foregroundStyle(cor)
                // Mesmo título do Android (`JejumAvisos.kt`), letra por letra.
                Text("\(estado.estaPausado ? "Jejum pausado" : "Jejum em curso") · \(atributos.protocoloRotulo)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                CronometroDoJejum(estado: estado, fonte: .system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                // O horário de término é hora de relógio: não envelhece, e some
                // quando o jejum está pausado — a mesma decisão de
                // `JejumEmCurso.previsaoDeTermino`, que devolve `nil` pausado
                // porque "um horário previsto para um cronômetro parado é um
                // número que a tela não tem direito de mostrar".
                if !estado.estaPausado && !estado.atingiuAMeta {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("termina às")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(estado.metaEm, style: .time)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }

            BarraDoJejum(estado: estado, cor: cor)
            LinhaDeEstadoDoJejum(atributos: atributos, estado: estado)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Peças

/// O contador. É o coração da funcionalidade e o único elemento que precisa
/// andar sem o app estar vivo.
///
/// `countsDown: false` — conta PARA CIMA, o tempo já jejuado, igual ao Android e
/// igual ao número grande dentro do app. Regressivo até a meta seria outro
/// número, e dois números para a mesma coisa é o defeito que este módulo passou
/// agosto fechando.
///
/// `pauseTime` é o que congela o cronômetro na pausa, sem o app precisar mandar
/// atualização nenhuma depois.
///
/// O limite superior da faixa é longe (72 h) só porque `Text(timerInterval:)`
/// exige uma faixa fechada e para de contar no fim dela. Não é um teto de
/// produto: o sistema encerra a atividade em 8 h de qualquer jeito
/// (ver `JejumAoVivo.swift`), muito antes disso.
private struct CronometroDoJejum: View {
    let estado: AtributosDoJejumAoVivo.ContentState
    let fonte: Font

    var body: some View {
        Text(timerInterval: estado.baseDoCronometro...estado.baseDoCronometro.addingTimeInterval(72 * 3600),
             pauseTime: estado.pausadoEm,
             countsDown: false)
            .font(fonte.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// A barra de progresso até a meta.
///
/// Correndo: `ProgressView(timerInterval:)`, que o sistema preenche sozinho
/// entre as duas datas.
/// Pausado: barra ESTÁTICA, com a fração congelada — uma barra que continua
/// enchendo com o jejum parado mostraria progresso que não está acontecendo.
private struct BarraDoJejum: View {
    let estado: AtributosDoJejumAoVivo.ContentState
    let cor: Color

    var body: some View {
        Group {
            if let pausadoEm = estado.pausadoEm {
                ProgressView(value: fracaoCongelada(pausadoEm), total: 1)
            } else {
                ProgressView(timerInterval: estado.baseDoCronometro...max(estado.metaEm, estado.baseDoCronometro.addingTimeInterval(1)),
                             countsDown: false)
                    .labelsHidden()
            }
        }
        .progressViewStyle(.linear)
        .tint(cor)
    }

    /// Derivada das datas que já estão no estado, em vez de mais um campo:
    /// decorrido = `pausadoEm − base`, meta = `metaEm − base`.
    private func fracaoCongelada(_ pausadoEm: Date) -> Double {
        let meta = estado.metaEm.timeIntervalSince(estado.baseDoCronometro)
        guard meta > 0 else { return 0 }
        let decorrido = pausadoEm.timeIntervalSince(estado.baseDoCronometro)
        return min(1, max(0, decorrido / meta))
    }
}

/// A linha de baixo. Três textos, todos verdadeiros em qualquer instante.
///
/// O texto de meta atingida é o mesmo da tela do app (`JejumView.swift:259`).
/// Repare no que ele NÃO diz: não parabeniza pela duração e não convida a
/// seguir jejuando. Diz que chegou. Ver o cabeçalho de `Sequencia`.
private struct LinhaDeEstadoDoJejum: View {
    let atributos: AtributosDoJejumAoVivo
    let estado: AtributosDoJejumAoVivo.ContentState

    var body: some View {
        Text(texto)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var texto: String {
        if estado.estaPausado {
            // Sem repetir a duração: o número grande logo acima já é ela.
            return "Pausado. Retome quando quiser."
        }
        if estado.atingiuAMeta {
            return "Você chegou à meta de \(atributos.metaFormatada)."
        }
        return "Meta de \(atributos.metaFormatada)."
    }
}

// MARK: - Cores

private enum CoresDoJejumAoVivo {
    static let violeta = Color(red: 0x8B / 255, green: 0x7B / 255, blue: 0xD8 / 255)
    static let oliva   = Color(red: 0x6F / 255, green: 0x7D / 255, blue: 0x3F / 255)
    static let fundo   = Color(red: 0x1D / 255, green: 0x21 / 255, blue: 0x1A / 255).opacity(0.9)

    static func acento(atingiuAMeta: Bool, pausado: Bool) -> Color {
        if pausado { return .white.opacity(0.6) }
        return atingiuAMeta ? oliva : violeta
    }
}
