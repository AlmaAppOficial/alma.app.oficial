// BotaoVoltarParaAlma.swift
// Alma — Corpo · caminho de volta simétrico
//
// [2026-08-02] Dentro do Alma, o botão do Corpo fica no topo DIREITO, com a
// logo do Corpo. Dentro do Corpo, o botão da Alma fica no MESMO lugar, com a
// logo da Alma. Sem seta — a simetria é o que ensina a navegação.
//
// Vive em cada aba (e não num NavigationStack externo) porque o wrapper
// aninhado fazia o SwiftUI engolir as toolbars internas — foi assim que o
// botão de editar medidas sumiu da aba Saúde.

import SwiftUI

/// Ação de voltar, propagada pelo ambiente para todas as abas do módulo.
private struct VoltarParaAlmaKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var voltarParaAlma: () -> Void {
        get { self[VoltarParaAlmaKey.self] }
        set { self[VoltarParaAlmaKey.self] = newValue }
    }
}

struct BotaoVoltarParaAlma: View {
    var acao: () -> Void

    var body: some View {
        Button(action: acao) {
            VStack(spacing: 2) {
                AlmaLogo(size: 28)
                Text("Alma")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.inkSoft)
            }
            .frame(width: 40, height: 44)
        }
        .accessibilityLabel("Voltar para a Alma")
    }
}

extension View {
    /// Põe o botão da Alma no topo direito desta tela.
    func almaBackButton() -> some View {
        modifier(AlmaBackButtonModifier())
    }
}

private struct AlmaBackButtonModifier: ViewModifier {
    @Environment(\.voltarParaAlma) private var voltar

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BotaoVoltarParaAlma(acao: voltar)
            }
        }
    }
}
