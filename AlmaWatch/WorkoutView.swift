// WorkoutView.swift
// Alma Watch — treino no pulso: escolher, treinar, encerrar.
// FC ao vivo, calorias e tempo vêm do HKLiveWorkoutBuilder (WorkoutManager).

import SwiftUI
import WatchKit

struct WorkoutView: View {
    @ObservedObject private var treino = TreinoCompartilhado.manager

    var body: some View {
        Group {
            switch treino.fase {
            case .parado, .contagem:
                escolha
            case .ativo, .pausado:
                sessao
            case .resumo:
                resumo
            }
        }
        .navigationTitle("Treino")
    }

    // MARK: - Escolha do tipo

    private var escolha: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(WorkoutManager.tipos) { tipo in
                    Button {
                        WKInterfaceDevice.current().play(.start)
                        Task { await treino.iniciar(tipo) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tipo.icone)
                                .font(.system(size: 15))
                                .foregroundStyle(WatchTheme.corpoOlivaClaro)
                                .frame(width: 22)
                            Text(tipo.nome)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(WatchTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(WatchTheme.textSecondary)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 10)
                        .background(WatchTheme.card,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if let erro = treino.erro {
                    Text(erro)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(WatchTheme.coral)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Sessão ao vivo

    private var sessao: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: treino.tipoAtual?.icone ?? "dumbbell.fill")
                    .font(.system(size: 11))
                Text(treino.tipoAtual?.nome ?? "Treino")
                    .font(.system(size: 12, design: .rounded))
            }
            .foregroundStyle(WatchTheme.corpoOlivaClaro)

            Text(treino.tempoFormatado)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
                .monospacedDigit()

            HStack(spacing: 14) {
                metrica(icone: "heart.fill", cor: .red,
                        valor: treino.freqCardiaca > 0 ? "\(treino.freqCardiaca)" : "—",
                        rotulo: "bpm")
                metrica(icone: "flame.fill", cor: WatchTheme.coral,
                        valor: "\(treino.kcalAtivas)", rotulo: "kcal")
            }

            HStack(spacing: 6) {
                Button {
                    if treino.fase == .pausado {
                        treino.retomar()
                        WKInterfaceDevice.current().play(.start)
                    } else {
                        treino.pausar()
                        WKInterfaceDevice.current().play(.stop)
                    }
                } label: {
                    Image(systemName: treino.fase == .pausado ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(WatchTheme.cardStrong, in: Capsule())
                        .foregroundStyle(WatchTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    WKInterfaceDevice.current().play(.success)
                    Task { await treino.encerrar() }
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(WatchTheme.corpoOliva.opacity(0.6), in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Resumo

    private var resumo: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(WatchTheme.corpoOlivaClaro)
            Text("Treino registrado")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(WatchTheme.textPrimary)
            HStack(spacing: 12) {
                metrica(icone: "clock.fill", cor: WatchTheme.azure,
                        valor: treino.tempoFormatado, rotulo: "tempo")
                metrica(icone: "flame.fill", cor: WatchTheme.coral,
                        valor: "\(treino.kcalAtivas)", rotulo: "kcal")
            }
            if let erro = treino.erro {
                Text(erro)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.coral)
                    .multilineTextAlignment(.center)
            }
            Button("Concluir") { treino.limpar() }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .buttonStyle(.plain)
                .foregroundStyle(WatchTheme.almaText)
        }
        .padding(.horizontal, 4)
    }

    private func metrica(icone: String, cor: Color, valor: String, rotulo: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: icone)
                    .font(.system(size: 10))
                    .foregroundStyle(cor)
                Text(valor)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .monospacedDigit()
            }
            Text(rotulo)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
        }
    }
}

/// O manager vive fora da View para a sessão sobreviver à navegação.
enum TreinoCompartilhado {
    @MainActor static let manager = WorkoutManager()
}
