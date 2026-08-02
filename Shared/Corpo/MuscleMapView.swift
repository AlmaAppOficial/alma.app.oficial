//
//  MuscleMapView.swift
//  CorpoEAlma
//
//  Mapa muscular anatômico (frente/costas) — Biblioteca 2.0, iteração 2.
//  Arte própria: cada músculo é um blob orgânico (spline Catmull-Rom fechada)
//  definido por pontos-âncora normalizados. ~24 regiões visuais mapeadas nos
//  16 MuscleGroup de dados (ex.: abdutores→glúteos, tibial→panturrilha).
//

import SwiftUI

// MARK: - Spline fechada suave (Catmull-Rom → Bézier)

private func smoothBlob(_ pts: [CGPoint], in size: CGSize, tension: CGFloat = 0.55) -> Path {
    var p = Path()
    guard pts.count > 2 else { return p }
    let s = pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    let n = s.count
    p.move(to: s[0])
    for i in 0..<n {
        let p0 = s[(i - 1 + n) % n], p1 = s[i], p2 = s[(i + 1) % n], p3 = s[(i + 2) % n]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6 * tension, y: p1.y + (p2.y - p0.y) / 6 * tension)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6 * tension, y: p2.y - (p3.y - p1.y) / 6 * tension)
        p.addCurve(to: p2, control1: c1, control2: c2)
    }
    p.closeSubpath()
    return p
}

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func mirror(_ pts: [CGPoint]) -> [CGPoint] { pts.map { P(1 - $0.x, $0.y) } }

// MARK: - Músculo visual

private struct VisualMuscle: Identifiable {
    let id: String
    let group: MuscleGroup
    let anchors: [CGPoint]          // lado esquerdo (ou centro)
    var symmetric: Bool = true      // espelha no lado direito
    var detail: [[CGPoint]] = []    // linhas internas (vincos anatômicos)

    func paths(in size: CGSize) -> [Path] {
        var out = [smoothBlob(anchors, in: size)]
        if symmetric { out.append(smoothBlob(mirror(anchors), in: size)) }
        return out
    }

    func detailPaths(in size: CGSize) -> [Path] {
        var lines = detail
        if symmetric { lines += detail.map(mirror) }
        return lines.map { pts in
            var p = Path()
            let s = pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
            guard s.count > 1 else { return p }
            p.move(to: s[0])
            if s.count == 2 { p.addLine(to: s[1]) }
            else {
                for i in 1..<(s.count - 1) {
                    let mid = CGPoint(x: (s[i].x + s[i+1].x)/2, y: (s[i].y + s[i+1].y)/2)
                    p.addQuadCurve(to: mid, control: s[i])
                }
                p.addLine(to: s[s.count - 1])
            }
            return p
        }
    }
}

// MARK: - Anatomia FRENTE

private let frontMuscles: [VisualMuscle] = [
    VisualMuscle(id: "pescoco-f", group: .pescoco,
        anchors: [P(0.462, 0.112), P(0.474, 0.122), P(0.478, 0.152), P(0.458, 0.168), P(0.444, 0.158), P(0.452, 0.128)]),
    VisualMuscle(id: "trapezio-f", group: .trapezio,
        anchors: [P(0.44, 0.158), P(0.478, 0.168), P(0.442, 0.182), P(0.382, 0.192), P(0.368, 0.182)]),
    VisualMuscle(id: "deltoide-f", group: .ombros,
        anchors: [P(0.358, 0.186), P(0.316, 0.20), P(0.292, 0.24), P(0.30, 0.288), P(0.33, 0.292), P(0.356, 0.252), P(0.364, 0.21)]),
    VisualMuscle(id: "peitoral", group: .peito,
        anchors: [P(0.375, 0.205), P(0.44, 0.205), P(0.492, 0.212), P(0.492, 0.288), P(0.455, 0.315), P(0.395, 0.30), P(0.362, 0.258), P(0.36, 0.222)],
        detail: [[P(0.40, 0.302), P(0.452, 0.312), P(0.49, 0.30)]]),
    VisualMuscle(id: "biceps", group: .biceps,
        anchors: [P(0.302, 0.298), P(0.33, 0.31), P(0.342, 0.352), P(0.334, 0.396), P(0.308, 0.408), P(0.29, 0.365), P(0.29, 0.322)],
        detail: [[P(0.319, 0.312), P(0.327, 0.355), P(0.32, 0.40)]]),
    VisualMuscle(id: "antebraco-f", group: .antebraco,
        anchors: [P(0.295, 0.418), P(0.32, 0.428), P(0.312, 0.482), P(0.288, 0.545), P(0.266, 0.54), P(0.269, 0.482), P(0.281, 0.434)]),
    VisualMuscle(id: "abdomen", group: .abdomen,
        anchors: [P(0.444, 0.318), P(0.5, 0.312), P(0.556, 0.318), P(0.558, 0.40), P(0.535, 0.472), P(0.5, 0.492), P(0.465, 0.472), P(0.442, 0.40)],
        symmetric: false,
        detail: [[P(0.5, 0.315), P(0.5, 0.488)], [P(0.448, 0.362), P(0.552, 0.362)], [P(0.45, 0.408), P(0.55, 0.408)], [P(0.46, 0.452), P(0.54, 0.452)]]),
    VisualMuscle(id: "obliquos", group: .obliquos,
        anchors: [P(0.415, 0.325), P(0.437, 0.34), P(0.432, 0.42), P(0.452, 0.478), P(0.425, 0.492), P(0.398, 0.435), P(0.396, 0.36)],
        detail: [[P(0.412, 0.36), P(0.428, 0.375)], [P(0.408, 0.40), P(0.425, 0.415)]]),
    VisualMuscle(id: "quadriceps", group: .quadriceps,
        anchors: [P(0.408, 0.505), P(0.462, 0.518), P(0.478, 0.575), P(0.472, 0.652), P(0.452, 0.708), P(0.425, 0.718), P(0.402, 0.672), P(0.392, 0.578), P(0.396, 0.525)],
        detail: [[P(0.436, 0.53), P(0.44, 0.62), P(0.435, 0.70)], [P(0.412, 0.55), P(0.408, 0.64)]]),
    VisualMuscle(id: "adutores", group: .adutores,
        anchors: [P(0.472, 0.518), P(0.496, 0.528), P(0.494, 0.588), P(0.478, 0.625), P(0.468, 0.575)]),
    VisualMuscle(id: "abdutor-tfl", group: .gluteos,   // TFL/abdutor visual → grupo glúteos
        anchors: [P(0.385, 0.498), P(0.408, 0.502), P(0.40, 0.565), P(0.382, 0.558), P(0.375, 0.525)]),
    VisualMuscle(id: "tibial", group: .panturrilha,     // tibial anterior → panturrilha
        anchors: [P(0.418, 0.748), P(0.44, 0.758), P(0.437, 0.822), P(0.425, 0.878), P(0.409, 0.872), P(0.405, 0.80)]),
    VisualMuscle(id: "gastro-int-f", group: .panturrilha,
        anchors: [P(0.446, 0.752), P(0.463, 0.762), P(0.458, 0.826), P(0.444, 0.818), P(0.44, 0.78)]),
]

// MARK: - Anatomia COSTAS

private let backMuscles: [VisualMuscle] = [
    VisualMuscle(id: "trapezio-c", group: .trapezio,
        anchors: [P(0.5, 0.128), P(0.452, 0.148), P(0.372, 0.182), P(0.442, 0.215), P(0.478, 0.30), P(0.5, 0.352)],
        detail: [[P(0.5, 0.14), P(0.5, 0.345)]]),
    VisualMuscle(id: "deltoide-c", group: .ombros,
        anchors: [P(0.358, 0.186), P(0.316, 0.20), P(0.292, 0.24), P(0.30, 0.288), P(0.33, 0.292), P(0.356, 0.252), P(0.364, 0.21)]),
    VisualMuscle(id: "redondo", group: .costas,
        anchors: [P(0.358, 0.235), P(0.418, 0.242), P(0.43, 0.272), P(0.372, 0.278), P(0.352, 0.255)]),
    VisualMuscle(id: "dorsal", group: .costas,
        anchors: [P(0.372, 0.285), P(0.452, 0.30), P(0.475, 0.362), P(0.462, 0.428), P(0.432, 0.455), P(0.402, 0.412), P(0.378, 0.345)],
        detail: [[P(0.415, 0.31), P(0.44, 0.38), P(0.44, 0.44)]]),
    VisualMuscle(id: "lombar", group: .lombar,
        anchors: [P(0.468, 0.432), P(0.5, 0.425), P(0.532, 0.432), P(0.525, 0.492), P(0.5, 0.512), P(0.475, 0.492)],
        symmetric: false,
        detail: [[P(0.5, 0.428), P(0.5, 0.508)]]),
    VisualMuscle(id: "triceps", group: .triceps,
        anchors: [P(0.302, 0.298), P(0.33, 0.31), P(0.342, 0.352), P(0.334, 0.396), P(0.308, 0.408), P(0.29, 0.365), P(0.29, 0.322)],
        detail: [[P(0.314, 0.315), P(0.322, 0.358), P(0.314, 0.40)]]),
    VisualMuscle(id: "antebraco-c", group: .antebraco,
        anchors: [P(0.295, 0.418), P(0.32, 0.428), P(0.312, 0.482), P(0.288, 0.545), P(0.266, 0.54), P(0.269, 0.482), P(0.281, 0.434)]),
    VisualMuscle(id: "gluteo", group: .gluteos,
        anchors: [P(0.418, 0.502), P(0.478, 0.508), P(0.495, 0.552), P(0.482, 0.598), P(0.44, 0.608), P(0.408, 0.578), P(0.402, 0.532)]),
    VisualMuscle(id: "isquios", group: .posteriorCoxa,
        anchors: [P(0.415, 0.615), P(0.478, 0.618), P(0.475, 0.682), P(0.455, 0.728), P(0.428, 0.722), P(0.408, 0.668)],
        detail: [[P(0.443, 0.625), P(0.446, 0.68), P(0.44, 0.725)]]),
    VisualMuscle(id: "gastrocnemio", group: .panturrilha,
        anchors: [P(0.412, 0.752), P(0.462, 0.755), P(0.468, 0.798), P(0.452, 0.856), P(0.428, 0.862), P(0.408, 0.812)],
        detail: [[P(0.438, 0.758), P(0.44, 0.815), P(0.438, 0.858)]]),
]

// MARK: - Contorno do corpo (silhueta própria, frente e costas iguais)

private func bodyOutline(in size: CGSize) -> Path {
    var p = Path()
    // cabeça
    p.addEllipse(in: CGRect(x: 0.428 * size.width, y: 0.012 * size.height,
                            width: 0.144 * size.width, height: 0.096 * size.height))
    // tronco + pernas (metade esquerda espelhada dentro da spline)
    let torsoLegs: [CGPoint] = [
        P(0.458, 0.108), P(0.445, 0.15),                       // pescoço
        P(0.36, 0.172), P(0.302, 0.192),                       // ombro largo
        P(0.345, 0.262), P(0.358, 0.335),                      // axila/peito lateral
        P(0.378, 0.44), P(0.355, 0.505),                       // cintura → quadril
        P(0.362, 0.575), P(0.382, 0.66), P(0.398, 0.728),      // coxa externa → joelho
        P(0.392, 0.80), P(0.404, 0.888),                       // panturrilha externa → tornozelo
        P(0.394, 0.936), P(0.442, 0.942),                      // pé
        P(0.454, 0.898), P(0.45, 0.80),                        // tornozelo interno
        P(0.462, 0.728), P(0.455, 0.66),                       // joelho interno
        P(0.475, 0.578), P(0.499, 0.53),                       // coxa interna → virilha
        // espelho (lado direito), virilha → pé direito
        P(1 - 0.475, 0.578), P(1 - 0.455, 0.66), P(1 - 0.462, 0.728),
        P(1 - 0.45, 0.80), P(1 - 0.454, 0.898), P(1 - 0.442, 0.942), P(1 - 0.394, 0.936),
        P(1 - 0.404, 0.888), P(1 - 0.392, 0.80), P(1 - 0.398, 0.728), P(1 - 0.382, 0.66),
        P(1 - 0.362, 0.575), P(1 - 0.355, 0.505), P(1 - 0.378, 0.44),
        P(1 - 0.358, 0.335), P(1 - 0.345, 0.262), P(1 - 0.302, 0.192), P(1 - 0.36, 0.172),
        P(1 - 0.445, 0.15), P(1 - 0.458, 0.108),
    ]
    p.addPath(smoothBlob(torsoLegs, in: size, tension: 0.4))
    // braços (esquerdo + espelho) — mais curtos e encorpados
    let armL: [CGPoint] = [
        P(0.30, 0.205), P(0.278, 0.24), P(0.272, 0.315),       // deltoide ext
        P(0.28, 0.40), P(0.258, 0.475), P(0.245, 0.535),       // braço → antebraço ext
        P(0.24, 0.578), P(0.262, 0.598), P(0.284, 0.572),      // mão
        P(0.296, 0.53), P(0.318, 0.458), P(0.328, 0.398),      // antebraço int
        P(0.344, 0.315), P(0.35, 0.252),                       // braço int → axila
    ]
    p.addPath(smoothBlob(armL, in: size, tension: 0.4))
    p.addPath(smoothBlob(mirror(armL), in: size, tension: 0.4))
    return p
}

// MARK: - Canvas do corpo (API compatível com a iteração 1)

struct BodyMapCanvas: View {
    let isFront: Bool
    var highlightedPrimary: Set<MuscleGroup> = []
    var highlightedSecondary: Set<MuscleGroup> = []
    var selected: MuscleGroup? = nil
    var onTap: ((MuscleGroup) -> Void)? = nil

    private var muscles: [VisualMuscle] { isFront ? frontMuscles : backMuscles }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // silhueta (pele)
                bodyOutline(in: size)
                    .fill(Theme.inkSoft.opacity(0.13))
                bodyOutline(in: size)
                    .stroke(Theme.inkSoft.opacity(0.45), lineWidth: max(0.7, size.width * 0.006))

                // músculos
                ForEach(muscles) { m in
                    let color = fillColor(for: m.group)
                    ForEach(Array(m.paths(in: size).enumerated()), id: \.offset) { _, path in
                        path.fill(color)
                        path.stroke(Theme.background.opacity(0.9),
                                    lineWidth: max(0.6, size.width * 0.005))
                    }
                    // vincos anatômicos
                    ForEach(Array(m.detailPaths(in: size).enumerated()), id: \.offset) { _, line in
                        line.stroke(Theme.background.opacity(0.8),
                                    lineWidth: max(0.7, size.width * 0.007))
                    }
                }

                // camada de toque
                if let onTap {
                    ForEach(muscles) { m in
                        ForEach(Array(m.paths(in: size).enumerated()), id: \.offset) { _, path in
                            path.fill(Color.white.opacity(0.001))
                                .contentShape(path)
                                .onTapGesture { onTap(m.group) }
                        }
                    }
                }
            }
        }
        .aspectRatio(0.52, contentMode: .fit)
    }

    private func fillColor(for group: MuscleGroup) -> Color {
        if group == selected { return Theme.primary }
        if highlightedPrimary.contains(group) { return Color(red: 0.86, green: 0.28, blue: 0.25) }
        if highlightedSecondary.contains(group) { return Color(red: 0.95, green: 0.62, blue: 0.30) }
        // tom "músculo em repouso" — legível nos temas claro e escuro
        return Color(red: 0.78, green: 0.62, blue: 0.58).opacity(0.55)
    }
}

// MARK: - Corpo com highlight de um exercício (thumbnail programática)

/// Escolhe a vista (frente/costas) com mais músculos do exercício e pinta
/// primários/secundários — zero assets, dados que já existem no catálogo.
struct ExerciseMuscleThumb: View {
    let exercise: ExerciseV2

    var showsFront: Bool {
        let all = exercise.primaryMuscles + exercise.secondaryMuscles
        let front = all.filter(\.isFront).count
        return front >= all.count - front
    }

    var body: some View {
        BodyMapCanvas(isFront: showsFront,
                      highlightedPrimary: Set(exercise.primaryMuscles),
                      highlightedSecondary: Set(exercise.secondaryMuscles))
            .allowsHitTesting(false)
    }
}

// MARK: - Tela do mapa

struct MuscleMapView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingFront = true
    @State private var selectedGroup: MuscleGroup? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Toque em um músculo para ver os exercícios")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                ZStack(alignment: .bottomTrailing) {
                    BodyMapCanvas(isFront: showingFront,
                                  selected: selectedGroup) { group in
                        selectedGroup = group
                    }
                    .frame(maxWidth: 320)
                    .animation(.easeInOut(duration: 0.15), value: selectedGroup)

                    Button {
                        withAnimation(.spring(duration: 0.35)) { showingFront.toggle() }
                    } label: {
                        VStack(spacing: 4) {
                            BodyMapCanvas(isFront: !showingFront)
                                .frame(width: 56)
                                .allowsHitTesting(false)
                            Text(showingFront ? "Costas" : "Frente")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(8)
                        .background(Theme.inkSoft.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)

                let groups = MuscleGroup.allCases.filter { $0.isFront == showingFront }
                FlowChips(groups: groups, selected: $selectedGroup)
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Mapa muscular")
        .navigationBarTitleDisplayMode(.inline)
        // [Fusão] variante iOS 16 de navigationDestination(item:)
        .navigationDestination(isPresented: Binding(
            get: { selectedGroup != nil },
            set: { if !$0 { selectedGroup = nil } }
        )) {
            if let group = selectedGroup {
                ExerciseListV2View(group: group)
            }
        }
    }
}

private struct FlowChips: View {
    let groups: [MuscleGroup]
    @Binding var selected: MuscleGroup?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(groups) { g in
                Button { selected = g } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.primary.opacity(0.7)).frame(width: 7, height: 7)
                        Text(g.namePTBR)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(ExerciseCatalog.exercises(for: g).count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.inkSoft.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Card compacto para a aba Treino

struct MuscleMapCard: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 2) {
                BodyMapCanvas(isFront: true).frame(width: 34).allowsHitTesting(false)
                BodyMapCanvas(isFront: false).frame(width: 34).allowsHitTesting(false)
            }
            .frame(width: 80, height: 66)
            .background(Theme.primary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Mapa muscular")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("Toque no músculo e veja \(ExerciseCatalog.all.count) exercícios")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .cardStyle(padding: 14)
    }
}
