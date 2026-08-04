// WaterView.swift
// Alma Watch — registrar água em dois toques.
// Mesmos botões do iPhone (+250 / +500), meta vinda do telefone.

import SwiftUI
import WatchKit

struct WaterView: View {
    @ObservedObject private var sync = WatchSync.shared
    @State private var pulso = false

    private var progresso: Double {
        Double(sync.estado.aguaMl) / Double(max(sync.estado.aguaMeta, 1))
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                AnelProgresso(progresso: progresso, cor: WatchTheme.azure, espessura: 7)
                    .frame(width: 84, height: 84)
                VStack(spacing: 0) {
                    Text(FormatoWatch.litros(sync.estado.aguaMl))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.textPrimary)
                    Text("de \(FormatoWatch.litros(sync.estado.aguaMeta))")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(WatchTheme.textSecondary)
                }
            }
            .scaleEffect(pulso ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: pulso)

            HStack(spacing: 6) {
                botaoAgua(250)
                botaoAgua(500)
            }
        }
        .navigationTitle("Água")
    }

    private func botaoAgua(_ ml: Int) -> some View {
        Button {
            sync.registrarAgua(ml)
            WKInterfaceDevice.current().play(.success)
            pulso = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { pulso = false }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14))
                Text("+\(ml) ml")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(WatchTheme.azure.opacity(0.28),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(WatchTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
