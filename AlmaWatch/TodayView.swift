// TodayView.swift
// Alma Watch — a tela "Hoje": o dia inteiro numa olhada.
// Streak grande (o dado mais motivador), anéis de atividade, água, treino e FC.

import SwiftUI

struct TodayView: View {
    @ObservedObject private var sync = WatchSync.shared
    @ObservedObject private var saude = WatchHealth.shared

    /// Marcos do streak — os mesmos do iPhone (StreakManager.milestones).
    private static let marcos = [3, 7, 14, 21, 30, 60, 100, 365]

    private var proximoMarco: Int {
        Self.marcos.first(where: { $0 > sync.estado.streak }) ?? (sync.estado.streak + 30)
    }

    private var progressoMarco: Double {
        let anterior = Self.marcos.last(where: { $0 <= sync.estado.streak }) ?? 0
        let alvo = proximoMarco
        guard alvo > anterior else { return 1 }
        return Double(sync.estado.streak - anterior) / Double(alvo - anterior)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                saudacao
                cartaoStreak
                cartaoAneis
                cartaoAgua
                cartaoTreino
                rodapeFC
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Hoje")
        .task { await saude.atualizarTudo() }
    }

    private var saudacao: some View {
        Text(FormatoWatch.saudacao(sync.estado.nome))
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(WatchTheme.almaSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var cartaoStreak: some View {
        HStack(spacing: 10) {
            ZStack {
                AnelProgresso(progresso: progressoMarco, cor: WatchTheme.almaPrimary, espessura: 5)
                    .frame(width: 52, height: 52)
                VStack(spacing: -2) {
                    Text("\(sync.estado.streak)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.accent)
                    Text(sync.estado.streak == 1 ? "dia" : "dias")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(WatchTheme.almaSoft)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Sequência")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(WatchTheme.almaBright)
                Text(sync.estado.praticouHoje
                     ? "Prática de hoje feita"
                     : "Próximo marco: \(proximoMarco)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(WatchTheme.almaSoft)
                if sync.estado.recorde > 0 {
                    Text("Recorde: \(sync.estado.recorde)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchTheme.heroAlma, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cartaoAneis: some View {
        MiniAneisAtividade(mover: saude.moverKcal, moverMeta: saude.moverMetaKcal,
                           exercicio: saude.exercicioMin, exercicioMeta: saude.exercicioMetaMin,
                           emPe: saude.emPeHoras, emPeMeta: saude.emPeMetaHoras)
            .cartaoWatch()
    }

    private var cartaoAgua: some View {
        HStack(spacing: 8) {
            LinhaMetrica(icone: "drop.fill", cor: WatchTheme.azure,
                         valor: "\(FormatoWatch.litros(sync.estado.aguaMl)) de \(FormatoWatch.litros(sync.estado.aguaMeta))",
                         rotulo: "água hoje")
            AnelProgresso(progresso: Double(sync.estado.aguaMl) / Double(max(sync.estado.aguaMeta, 1)),
                          cor: WatchTheme.azure, espessura: 4)
                .frame(width: 24, height: 24)
        }
        .cartaoWatch()
    }

    private var cartaoTreino: some View {
        LinhaMetrica(icone: sync.estado.treinouHoje ? "checkmark.circle.fill" : "dumbbell.fill",
                     cor: WatchTheme.corpoOlivaClaro,
                     valor: sync.estado.treinouHoje ? "Treino feito" : "Sem treino ainda",
                     rotulo: sync.estado.treinouHoje ? "registrado hoje" : "gire a coroa para iniciar")
            .cartaoWatch()
    }

    private var rodapeFC: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
            Text(saude.freqCardiaca > 0 ? "\(saude.freqCardiaca) bpm" : "— bpm")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
            Text("·")
                .foregroundStyle(WatchTheme.textSecondary)
            Image(systemName: "figure.walk")
                .font(.system(size: 10))
                .foregroundStyle(WatchTheme.textSecondary)
            Text("\(saude.passosHoje)")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
        }
        .padding(.top, 2)
    }
}
