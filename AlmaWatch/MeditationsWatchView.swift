// MeditationsWatchView.swift
// Alma Watch — as 30 meditações do Alma, com handoff honesto para o iPhone.
//
// O catálogo vem do telefone (applicationContext) — nada de lista escrita à
// mão dessincronizada (a versão antiga tinha 5 títulos, 3 deles apontando
// para a meditação errada). Sem contexto ainda, mostramos "Dia N" neutro.
//
// O áudio mora no iPhone (230 MB — não cabe nos 75 MB de teto do watchOS).
// O relógio dispara e DIZ A VERDADE sobre o que aconteceu: tocando,
// precisa do plano, entrou na fila, ou falhou.

import SwiftUI
import WatchKit

struct MeditationsWatchView: View {
    @ObservedObject private var sync = WatchSync.shared
    @State private var statusPorDia: [Int: WatchSync.RespostaMeditacao] = [:]

    private var catalogo: [MeditacaoDoCatalogo] {
        if sync.estado.meditacoes.count >= 30 { return sync.estado.meditacoes }
        if !sync.estado.meditacoes.isEmpty { return sync.estado.meditacoes }
        // Fallback neutro até o primeiro sync — sem inventar título.
        return (1...30).map { MeditacaoDoCatalogo(dia: $0, titulo: "Dia \($0)", minutos: 0) }
    }

    var body: some View {
        List {
            Section {
                ForEach(catalogo) { med in
                    linha(med)
                }
            } footer: {
                Text("O áudio toca no iPhone.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
            }
        }
        .navigationTitle("Meditações")
    }

    private func bloqueada(_ med: MeditacaoDoCatalogo) -> Bool {
        med.dia > 3 && !sync.estado.premium
    }

    private func linha(_ med: MeditacaoDoCatalogo) -> some View {
        Button {
            tocar(med)
        } label: {
            HStack(spacing: 8) {
                Text("\(med.dia)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(bloqueada(med) ? WatchTheme.textSecondary : WatchTheme.almaText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(med.titulo)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(WatchTheme.textPrimary)
                        .lineLimit(1)
                    Text(legenda(med))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(corLegenda(med))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: icone(med))
                    .font(.system(size: 13))
                    .foregroundStyle(bloqueada(med) ? WatchTheme.textSecondary : WatchTheme.almaText)
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WatchTheme.card)
        )
    }

    private func legenda(_ med: MeditacaoDoCatalogo) -> String {
        if let status = statusPorDia[med.dia] {
            switch status {
            case .tocando: return "Tocando no iPhone"
            case .precisaPremium: return "Disponível no plano completo"
            case .enviadoParaFila: return "Toca quando o iPhone abrir"
            case .falhou: return "iPhone fora de alcance"
            }
        }
        if bloqueada(med) { return "Plano completo" }
        return med.minutos > 0 ? "\(med.minutos) min" : "meditação guiada"
    }

    private func corLegenda(_ med: MeditacaoDoCatalogo) -> Color {
        if let s = statusPorDia[med.dia] {
            switch s {
            case .tocando: return WatchTheme.corpoOlivaClaro
            case .precisaPremium, .enviadoParaFila: return WatchTheme.gold
            case .falhou: return WatchTheme.coral
            }
        }
        return WatchTheme.textSecondary
    }

    private func icone(_ med: MeditacaoDoCatalogo) -> String {
        if bloqueada(med) { return "lock.fill" }
        if case .tocando = statusPorDia[med.dia] { return "iphone.radiowaves.left.and.right" }
        return "play.circle"
    }

    private func tocar(_ med: MeditacaoDoCatalogo) {
        if bloqueada(med) {
            statusPorDia[med.dia] = .precisaPremium
            WKInterfaceDevice.current().play(.retry)
            return
        }
        WKInterfaceDevice.current().play(.click)
        sync.tocarMeditacao(dia: med.dia) { resposta in
            statusPorDia[med.dia] = resposta
            switch resposta {
            case .tocando: WKInterfaceDevice.current().play(.success)
            case .falhou, .precisaPremium: WKInterfaceDevice.current().play(.retry)
            case .enviadoParaFila: break
            }
        }
    }
}
