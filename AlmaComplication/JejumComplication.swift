//
//  JejumComplication.swift
//  AlmaComplication
//
//  A complicação do jejum — o cronômetro no mostrador, do começo ao fim.
//
//  Por que ela é uma complicação PRÓPRIA e não mais um caso da AlmaComplication:
//  a de streak/água/treino continua existindo, e a pessoa pode querer as DUAS
//  no mesmo mostrador. Uma complicação por assunto é também o que a HIG pede —
//  cada uma com um dado e um deep link.
//
//  A regra da tela bloqueada do iPhone vale inteira aqui, e mais forte: a
//  extensão só é redesenhada quando o app do relógio recarrega as timelines ou
//  quando uma entrada agendada vence. NADA pode envelhecer:
//    • o número é `Text(timerInterval:)` — o sistema conta sozinho;
//    • o anel correndo é `ProgressView(timerInterval:)` — idem;
//    • pausado, tudo é ESTÁTICO — e congelado não envelhece por definição;
//    • a única troca de texto (meta atingida) tem entrada agendada no instante
//      exato da meta.
//
//  Dados: App Group do relógio, via `JejumNoPulso` — o MESMO arquivo que o app
//  do relógio compila. As cores são repetidas aqui de propósito, como as da
//  `AlmaComplication`: dois hex custam menos que arrastar o tema inteiro para
//  dentro do .appex. Violeta 8B7BD8 (correndo) e oliva claro A9BC6B (meta) —
//  os mesmos da tela bloqueada e do WatchTheme. Mudou lá, muda aqui.
//

import WidgetKit
import SwiftUI

// MARK: - Provider

struct JejumEntry: TimelineEntry {
    let date: Date
    let jejum: JejumNoPulso.Estado?
}

struct JejumProvider: TimelineProvider {

    private static func atual() -> JejumNoPulso.Estado? {
        JejumNoPulso.carregar(de: UserDefaults(suiteName: JejumNoPulso.suite))
    }

    /// A galeria de complicações mostra o placeholder — com número de verdade
    /// (12 h de um 16/8), porque "uma complicação estática que não exibe dados
    /// significativos tem menos chance de permanecer no mostrador".
    func placeholder(in context: Context) -> JejumEntry {
        let agora = Date()
        return JejumEntry(date: agora,
                          jejum: JejumNoPulso.Estado(base: agora.addingTimeInterval(-12 * 3600),
                                                     meta: agora.addingTimeInterval(4 * 3600),
                                                     pausadoEm: nil,
                                                     rotulo: "16/8"))
    }

    func getSnapshot(in context: Context, completion: @escaping (JejumEntry) -> Void) {
        completion(JejumEntry(date: Date(), jejum: Self.atual()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JejumEntry>) -> Void) {
        let agora = Date()
        let jejum = Self.atual()
        var entradas = [JejumEntry(date: agora, jejum: jejum)]
        // Correndo e antes da meta: uma entrada no instante exato em que ela
        // cai, para "Meta de 16 h" virar "Meta atingida" sem depender do app.
        if let jejum, !jejum.estaPausado, jejum.meta > agora {
            entradas.append(JejumEntry(date: jejum.meta, jejum: jejum))
        }
        // O app do relógio recarrega as timelines a cada estado novo do iPhone;
        // o .after é só rede de segurança (e vira o dia por causa do stale).
        completion(Timeline(entries: entradas, policy: .after(agora.addingTimeInterval(6 * 3600))))
    }
}

// MARK: - Cores locais (ver o cabeçalho)

private enum CorJ {
    static let violeta = Color(red: 0x8B / 255, green: 0x7B / 255, blue: 0xD8 / 255) // 8B7BD8
    static let oliva   = Color(red: 0xA9 / 255, green: 0xBC / 255, blue: 0x6B / 255) // A9BC6B
    static let pausado = Color.white.opacity(0.6)
}

// MARK: - Vistas por família

struct JejumComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: JejumEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: retangular
            default: circular
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "alma://watch/jejum"))
    }

    private func cor(atingiu: Bool, pausado: Bool) -> Color {
        if pausado { return CorJ.pausado }
        return atingiu ? CorJ.oliva : CorJ.violeta
    }

    // MARK: Circular

    /// Anel de progresso até a meta + o tempo já jejuado no centro, contado
    /// pelo sistema. Pausado: anel e número congelados, estáticos.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let jejum = entry.jejum {
                if let pausadoEm = jejum.pausadoEm {
                    ProgressView(value: JejumNoPulso.fracaoCongelada(base: jejum.base,
                                                                    meta: jejum.meta,
                                                                    pausadoEm: pausadoEm),
                                 total: 1) {
                        Image(systemName: "pause.fill")
                    } currentValueLabel: {
                        Text(JejumNoPulso.textoCompacto(jejum.decorrido(agora: entry.date)))
                            .font(.system(.body, design: .rounded).weight(.bold))
                    }
                    .progressViewStyle(.circular)
                    .tint(CorJ.pausado)
                } else {
                    ProgressView(timerInterval: jejum.base...max(jejum.meta, jejum.base.addingTimeInterval(1)),
                                 countsDown: false) {
                        Image(systemName: "timer")
                    } currentValueLabel: {
                        // O número que prova que há dado vivo aqui: conta
                        // sozinho, segundo a segundo, sem o app.
                        // lineLimit(1) é obrigatório: sem ele, "13:20:39" quebra
                        // em duas linhas dentro do círculo (medido em 29/08).
                        Text(timerInterval: jejum.base...jejum.base.addingTimeInterval(72 * 3600),
                             countsDown: false)
                            .font(.system(.caption2, design: .rounded).weight(.semibold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.35)
                    }
                    .progressViewStyle(.circular)
                    .tint(cor(atingiu: jejum.atingiuAMeta(agora: entry.date), pausado: false))
                }
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "timer")
                        .font(.system(size: 15))
                    Text("Jejum")
                        .font(.system(size: 9, design: .rounded))
                }
            }
        }
    }

    // MARK: Retangular (Smart Stack)

    private var retangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let jejum = entry.jejum {
                let atingiu = jejum.atingiuAMeta(agora: entry.date)
                let corAtual = cor(atingiu: atingiu, pausado: jejum.estaPausado)

                HStack(spacing: 4) {
                    Image(systemName: jejum.estaPausado ? "pause.circle.fill" : "timer")
                        .foregroundStyle(corAtual)
                        .font(.system(size: 11))
                    // Mesmo título da tela bloqueada e do Android, letra por letra.
                    Text("\(jejum.estaPausado ? "Jejum pausado" : "Jejum em curso")\(jejum.rotulo.isEmpty ? "" : " · \(jejum.rotulo)")")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                // Pausado, texto estático — o `pauseTime:` da API não congela
                // direito com pausa no passado (ver `JejumNoPulso.cronometro`).
                Group {
                    if jejum.estaPausado {
                        Text(JejumNoPulso.cronometro(jejum.decorrido(agora: entry.date)))
                    } else {
                        Text(timerInterval: jejum.base...jejum.base.addingTimeInterval(72 * 3600),
                             countsDown: false)
                    }
                }
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                if jejum.estaPausado {
                    // = JejumView "Pausado" + tela bloqueada, encurtado ao espaço.
                    Text("Pausado")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                } else if atingiu {
                    // = JejumView:106, letra por letra.
                    Text("Meta atingida")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(CorJ.oliva)
                } else {
                    ProgressView(timerInterval: jejum.base...max(jejum.meta, jejum.base.addingTimeInterval(1)),
                                 countsDown: false)
                        .labelsHidden()
                        .progressViewStyle(.linear)
                        .tint(CorJ.violeta)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .foregroundStyle(CorJ.violeta)
                        .font(.system(size: 11))
                    Text("Jejum")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                }
                Text("Nenhum jejum em curso")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Comece pelo iPhone")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget

struct AlmaJejumComplication: Widget {
    let kind: String = "AlmaJejumComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JejumProvider()) { entry in
            JejumComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Jejum")
        .description("Seu cronômetro de jejum.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}
