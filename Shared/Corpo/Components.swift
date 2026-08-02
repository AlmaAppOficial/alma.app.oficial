//
//  Components.swift
//  Corpo & Alma
//
//  Componentes visuais reutilizáveis: cabeçalho, anéis de progresso, cards.
//

import SwiftUI

// MARK: - Cabeçalho de tela

struct ScreenHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Título de seção

struct SectionTitle: View {
    let text: String
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(text)
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Spacer()
            if action != nil {
                Button("Ver tudo", action: { action?() })
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
    }
}

// MARK: - Anel de progresso

struct ProgressRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 9
    var icon: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: lineWidth * 1.6, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
    }
}

// MARK: - Card de métrica (anel + valor)

struct MetricCard: View {
    let metric: CorpoHealthMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressRing(progress: metric.progress, tint: metric.tint, lineWidth: 7, icon: metric.systemImage)
                    .frame(width: 44, height: 44)
                Spacer()
                Text("\(Int(metric.progress * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(metric.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.value)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(metric.unit)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Barra de macro

struct MacroBar: View {
    let label: String
    let value: Int
    let goal: Int
    let tint: Color

    private var fraction: Double { goal == 0 ? 0 : min(Double(value) / Double(goal), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(value)/\(goal) g")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.16))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Linha de pílula (chip)

struct Pill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}
