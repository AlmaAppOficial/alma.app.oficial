//
//  AlmaComplication.swift
//  AlmaComplication
//
//  Complication de marca do Alma para o mostrador do Apple Watch.
//  v1: atalho + frase. Famílias accessory (circular, inline, retangular, corner).
//

import WidgetKit
import SwiftUI

struct AlmaEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> AlmaEntry {
        AlmaEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (AlmaEntry) -> Void) {
        completion(AlmaEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlmaEntry>) -> Void) {
        // Estático (marca/atalho) — sem necessidade de refresh.
        completion(Timeline(entries: [AlmaEntry(date: Date())], policy: .never))
    }
}

struct AlmaComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
            }
        case .accessoryInline:
            Label("Cuida da tua alma", systemImage: "leaf.fill")
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Alma").font(.headline)
                    Text("Cuida da tua alma")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryCorner:
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
                .widgetLabel("Alma")
        default:
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
        }
    }
}

struct AlmaComplication: Widget {
    let kind: String = "AlmaComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AlmaComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Alma")
        .description("Um atalho para cuidar da sua mente.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .accessoryCorner,
        ])
    }
}
