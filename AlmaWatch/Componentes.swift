// Componentes.swift
// Alma Watch — peças visuais reutilizadas pelas telas.

import SwiftUI

// MARK: - Anel de progresso genérico

struct AnelProgresso: View {
    var progresso: Double          // 0...1
    var cor: Color
    var espessura: CGFloat = 6
    var fundo: Color = .white.opacity(0.12)

    var body: some View {
        ZStack {
            Circle().stroke(fundo, lineWidth: espessura)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progresso, 0), 1)))
                .stroke(cor, style: StrokeStyle(lineWidth: espessura, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progresso)
        }
    }
}

// MARK: - Mini anéis de atividade (Mover / Exercício / Em Pé)
// Desenho próprio, nas cores do Corpo — sem imitar os anéis da Apple.

struct MiniAneisAtividade: View {
    var mover: Double, moverMeta: Double
    var exercicio: Double, exercicioMeta: Double
    var emPe: Double, emPeMeta: Double

    private func fracao(_ v: Double, _ meta: Double) -> Double {
        meta > 0 ? v / meta : 0
    }

    var body: some View {
        HStack(spacing: 10) {
            anel(fracao(mover, moverMeta), WatchTheme.coral,
                 valor: "\(Int(mover))", rotulo: "kcal")
            anel(fracao(exercicio, exercicioMeta), WatchTheme.corpoOlivaClaro,
                 valor: "\(Int(exercicio))", rotulo: "min")
            anel(fracao(emPe, emPeMeta), WatchTheme.azure,
                 valor: "\(Int(emPe))", rotulo: "h em pé")
        }
    }

    private func anel(_ p: Double, _ cor: Color, valor: String, rotulo: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                AnelProgresso(progresso: p, cor: cor, espessura: 4)
                    .frame(width: 30, height: 30)
                Text(valor)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .frame(width: 24)
            }
            Text(rotulo)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Linha de métrica com ícone

struct LinhaMetrica: View {
    let icone: String
    let cor: Color
    let valor: String
    let rotulo: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icone)
                .font(.system(size: 14))
                .foregroundStyle(cor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(valor)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
                Text(rotulo)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Botão largo de ação

struct BotaoLargo: View {
    let titulo: String
    var icone: String? = nil
    var cor: Color = WatchTheme.almaPrimary
    var acao: () -> Void

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 6) {
                if let icone { Image(systemName: icone) }
                Text(titulo)
                    .fontWeight(.semibold)
            }
            .font(.system(.body, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(cor.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Formatação PT-BR

enum FormatoWatch {
    /// 1500 → "1,5 L"
    static func litros(_ ml: Int) -> String {
        let l = Double(ml) / 1000
        return String(format: "%.1f L", l).replacingOccurrences(of: ".", with: ",")
    }

    static func saudacao(_ nome: String) -> String {
        let hora = Calendar.current.component(.hour, from: Date())
        let periodo: String
        switch hora {
        case 5..<12: periodo = "Bom dia"
        case 12..<18: periodo = "Boa tarde"
        default: periodo = "Boa noite"
        }
        let n = nome.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? periodo : "\(periodo), \(n.components(separatedBy: " ").first ?? n)"
    }
}
