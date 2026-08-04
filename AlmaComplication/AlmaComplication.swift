//
//  AlmaComplication.swift
//  AlmaComplication
//
//  Complicações do Alma com DADOS VIVOS — streak, água e treino do dia,
//  lidos do App Group que o app do relógio mantém (WatchGroupStore).
//
//  Era uma folhinha estática com policy .never; a HIG é explícita:
//  "uma complicação estática que não exibe dados significativos tem menos
//  chance de permanecer no mostrador". Agora cada família mostra dado real
//  e tem um deep link próprio (também pedido da HIG).
//
//  A retangular aparece automaticamente no Smart Stack (watchOS 10+).
//

import WidgetKit
import SwiftUI

// MARK: - Dados (App Group do relógio)

struct DadosDoDia {
    var streak = 0
    var aguaMl = 0
    var aguaMeta = 2500
    var treinouHoje = false
    var praticouHoje = false

    static func carregar() -> DadosDoDia {
        guard let d = UserDefaults(suiteName: "group.com.almaapp.shared") else { return DadosDoDia() }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let hoje = f.string(from: Date())
        var dados = DadosDoDia()
        dados.streak = d.integer(forKey: "watch_streak")
        let meta = d.integer(forKey: "watch_agua_meta")
        dados.aguaMeta = meta > 0 ? meta : 2500
        dados.aguaMl = d.string(forKey: "watch_agua_dia") == hoje ? d.integer(forKey: "watch_agua_ml") : 0
        dados.treinouHoje = d.string(forKey: "watch_treinou_dia") == hoje
        dados.praticouHoje = d.string(forKey: "watch_praticou_dia") == hoje
        return dados
    }
}

struct AlmaEntry: TimelineEntry {
    let date: Date
    let dados: DadosDoDia
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> AlmaEntry {
        AlmaEntry(date: Date(), dados: DadosDoDia(streak: 7, aguaMl: 1500, aguaMeta: 2500,
                                                  treinouHoje: true, praticouHoje: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (AlmaEntry) -> Void) {
        completion(AlmaEntry(date: Date(), dados: DadosDoDia.carregar()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlmaEntry>) -> Void) {
        let agora = Date()
        let entry = AlmaEntry(date: agora, dados: DadosDoDia.carregar())
        // Recarrega na virada do dia (zera água/treino "de hoje").
        // O app do relógio também força reload a cada atualização de estado.
        let meiaNoite = Calendar.current.startOfDay(for: agora).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry], policy: .after(meiaNoite)))
    }
}

// MARK: - Cores locais (a extensão não compila os arquivos do app)

private enum CorC {
    static let violeta = Color(red: 0.486, green: 0.227, blue: 0.929)      // #7c3aed
    static let violetaClaro = Color(red: 0.624, green: 0.478, blue: 0.918) // #9F7AEA
    static let laranja = Color(red: 0.965, green: 0.678, blue: 0.333)      // #F6AD55
    static let azure = Color(red: 0.361, green: 0.576, blue: 0.722)        // #5C93B8
    static let oliva = Color(red: 0.663, green: 0.737, blue: 0.420)        // #A9BC6B
}

// MARK: - Vistas por família

struct AlmaComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var d: DadosDoDia { entry.dados }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryCorner: corner
            case .accessoryInline: inline
            case .accessoryRectangular: retangular
            default: circular
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    /// Anel de progresso até o próximo marco + número do streak.
    private var circular: some View {
        let marcos = [3, 7, 14, 21, 30, 60, 100, 365]
        let anterior = marcos.last(where: { $0 <= d.streak }) ?? 0
        let alvo = marcos.first(where: { $0 > d.streak }) ?? (d.streak + 30)
        let progresso = alvo > anterior ? Double(d.streak - anterior) / Double(alvo - anterior) : 1
        return ZStack {
            AccessoryWidgetBackground()
            Gauge(value: progresso) {
                Image(systemName: "sparkles")
            } currentValueLabel: {
                Text("\(d.streak)")
                    .font(.system(.body, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(CorC.violeta)
        }
        .widgetURL(URL(string: "alma://watch/hoje"))
    }

    /// Streak no canto, com rótulo curvo.
    private var corner: some View {
        Text("\(d.streak)")
            .font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(CorC.laranja)
            .widgetCurvesContent()
            .widgetLabel {
                Text(d.streak == 1 ? "Alma · 1 dia" : "Alma · \(d.streak) dias")
            }
            .widgetURL(URL(string: "alma://watch/respirar"))
    }

    /// Uma linha de texto no mostrador.
    private var inline: some View {
        Label {
            Text(d.praticouHoje ? "\(d.streak) dias · feito hoje" : "\(d.streak) dias de prática")
        } icon: {
            Image(systemName: "sparkles")
        }
        .widgetURL(URL(string: "alma://watch/hoje"))
    }

    /// Smart Stack: o dia inteiro em três linhas.
    private var retangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .foregroundStyle(CorC.violetaClaro)
                Text("Alma")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                Spacer()
                Text("\(d.streak) \(d.streak == 1 ? "dia" : "dias")")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(CorC.laranja)
            }
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(CorC.azure)
                    .font(.system(size: 10))
                Text(agua)
                    .font(.system(.caption2, design: .rounded))
            }
            HStack(spacing: 4) {
                Image(systemName: d.treinouHoje ? "checkmark.circle.fill" : "dumbbell.fill")
                    .foregroundStyle(CorC.oliva)
                    .font(.system(size: 10))
                Text(d.treinouHoje ? "Treino feito" : "Sem treino hoje")
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .widgetURL(URL(string: "alma://watch/hoje"))
    }

    private var agua: String {
        let l = Double(d.aguaMl) / 1000
        let meta = Double(d.aguaMeta) / 1000
        let fmt = { (v: Double) in String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",") }
        return "\(fmt(l)) de \(fmt(meta)) L"
    }
}

// MARK: - Widget

struct AlmaComplication: Widget {
    let kind: String = "AlmaComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AlmaComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Alma")
        .description("Sua sequência, água e treino do dia.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}
