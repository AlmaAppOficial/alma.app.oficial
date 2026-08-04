// MoodView.swift
// Alma Watch — check-in de humor em um toque.
// Os SEIS estados são os mesmos do iPhone (enum Mood em CorpoContextFormat):
// Ótimo, Bem, Normal, Cansado, Ansioso, Triste — com os mesmos ícones.

import SwiftUI
import WatchKit

struct MoodView: View {
    @ObservedObject private var sync = WatchSync.shared

    /// Espelho literal do enum Mood do iPhone (rawValue + icone).
    /// Se o iPhone ganhar um humor novo, acrescentar aqui também.
    private static let humores: [(nome: String, icone: String, cor: Color)] = [
        ("Ótimo", "sun.max.fill", WatchTheme.gold),
        ("Bem", "leaf.fill", WatchTheme.corpoOlivaClaro),
        ("Normal", "cloud.fill", WatchTheme.azure),
        ("Cansado", "moon.zzz.fill", WatchTheme.violet),
        ("Ansioso", "bolt.heart.fill", WatchTheme.coral),
        ("Triste", "drop.fill", WatchTheme.azure),
    ]

    var body: some View {
        Group {
            if let humor = sync.estado.humorHoje {
                registrado(humor)
            } else {
                grade
            }
        }
        .navigationTitle("Humor")
    }

    private var grade: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Como você está agora?")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(WatchTheme.almaSoft)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Self.humores, id: \.nome) { h in
                        Button {
                            sync.registrarHumor(h.nome)
                            WKInterfaceDevice.current().play(.success)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: h.icone)
                                    .font(.system(size: 18))
                                    .foregroundStyle(h.cor)
                                Text(h.nome)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(WatchTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(WatchTheme.card,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func registrado(_ humor: String) -> some View {
        let item = Self.humores.first(where: { $0.nome == humor })
        return VStack(spacing: 8) {
            Image(systemName: item?.icone ?? "checkmark.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(item?.cor ?? WatchTheme.corpoOlivaClaro)
            Text(humor)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("Registrado hoje")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
        }
    }
}
