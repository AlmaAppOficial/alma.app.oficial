// BreatheView.swift
// Alma Watch — respiração guiada com háptica, agora de verdade.
//
// O que mudou em relação à versão antiga (que morria quando a pessoa baixava
// o pulso): a sessão roda dentro de uma WKExtendedRuntimeSession do tipo
// mindfulness — o app continua em primeiro plano por até 1 hora mesmo com a
// tela apagada (Apple, "Using extended runtime sessions").
//
// Ao concluir:
//   • grava mindfulSession no Apple Saúde (cumprindo o texto de permissão)
//   • envia o evento ao iPhone, que conta a prática do dia (streak)
//
// Ritmo: inspira 4 s, expira 6 s — cadência comum de respiração lenta.
// Sem alegação de saúde: o app registra e acompanha, não promete efeito.

import SwiftUI
import WatchKit

struct BreatheView: View {
    @State private var rodando = false
    @State private var fase = "Prepare-se"
    @State private var escala: CGFloat = 0.55
    @State private var restam: Int = 0
    @State private var duracaoEscolhida = 180
    @State private var inicioSessao: Date?
    @State private var tarefa: Task<Void, Never>?
    @State private var runtime: WKExtendedRuntimeSession?
    @State private var runtimeDelegate = RuntimeDelegate()
    @State private var concluida = false

    private let inspira: Double = 4
    private let expira: Double = 6

    var body: some View {
        Group {
            if concluida {
                telaConcluida
            } else if rodando {
                telaSessao
            } else {
                telaEscolha
            }
        }
        .navigationTitle("Respirar")
        .onDisappear { parar(salvar: false) }
    }

    // MARK: - Escolha da duração

    private var telaEscolha: some View {
        VStack(spacing: 8) {
            petalas(escala: 0.8)
                .frame(height: 64)
            Text("Respire com calma")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(WatchTheme.almaSoft)
            HStack(spacing: 6) {
                ForEach([60, 180, 300], id: \.self) { seg in
                    Button {
                        duracaoEscolhida = seg
                        comecar()
                    } label: {
                        Text("\(seg / 60) min")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(WatchTheme.almaPrimary.opacity(0.35),
                                        in: Capsule())
                            .foregroundStyle(WatchTheme.almaBright)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sessão

    private var telaSessao: some View {
        VStack(spacing: 6) {
            Text(fase)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(WatchTheme.almaBright)
                .animation(.easeInOut, value: fase)
            petalas(escala: escala)
                .frame(height: 88)
            Text(tempoRestante)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(WatchTheme.almaSoft)
            Button("Encerrar") { parar(salvar: true) }
                .font(.system(size: 12, design: .rounded))
                .buttonStyle(.plain)
                .foregroundStyle(WatchTheme.textSecondary)
        }
    }

    private var telaConcluida: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(WatchTheme.corpoOlivaClaro)
            Text("Prática registrada")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("Salva no Apple Saúde")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
            Button("Nova sessão") { concluida = false }
                .font(.system(size: 12, design: .rounded))
                .buttonStyle(.plain)
                .foregroundStyle(WatchTheme.almaText)
        }
    }

    /// Flor de pétalas violeta — a assinatura visual da respiração do Alma.
    private func petalas(escala: CGFloat) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(WatchTheme.almaPrimary.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .offset(y: -14)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle()
                .fill(WatchTheme.almaText.opacity(0.5))
                .frame(width: 30, height: 30)
        }
        .scaleEffect(escala)
        .animation(.easeInOut(duration: fase == "Inspire" ? inspira : expira), value: escala)
    }

    private var tempoRestante: String {
        String(format: "%d:%02d", restam / 60, restam % 60)
    }

    // MARK: - Motor

    private func comecar() {
        rodando = true
        concluida = false
        restam = duracaoEscolhida
        inicioSessao = Date()

        // Sessão estendida: mantém a prática viva com o pulso abaixado.
        let sessao = WKExtendedRuntimeSession()
        sessao.delegate = runtimeDelegate
        sessao.start()
        runtime = sessao

        tarefa = Task { @MainActor in
            while restam > 0 && !Task.isCancelled {
                fase = "Inspire"
                escala = 1.0
                WKInterfaceDevice.current().play(.directionUp)
                try? await Task.sleep(nanoseconds: UInt64(inspira * 1_000_000_000))
                if Task.isCancelled || restam <= 0 { break }

                fase = "Expire"
                escala = 0.55
                WKInterfaceDevice.current().play(.directionDown)
                try? await Task.sleep(nanoseconds: UInt64(expira * 1_000_000_000))

                restam = max(0, restam - Int(inspira + expira))
            }
            if !Task.isCancelled { parar(salvar: true) }
        }
    }

    private func parar(salvar: Bool) {
        tarefa?.cancel()
        tarefa = nil
        runtime?.invalidate()
        runtime = nil
        guard rodando else { return }
        rodando = false

        if salvar, let inicio = inicioSessao {
            let fim = Date()
            let duracao = Int(fim.timeIntervalSince(inicio))
            // Menos de 30 s não vale registro — evita toque acidental.
            if duracao >= 30 {
                WKInterfaceDevice.current().play(.success)
                concluida = true
                Task {
                    await WatchHealth.shared.salvarAtencaoPlena(inicio: inicio, fim: fim)
                }
                WatchSync.shared.registrarRespiracao(duracaoSeg: duracao)
            }
        }
        fase = "Prepare-se"
        escala = 0.55
        inicioSessao = nil
    }
}

/// Delegate mínimo da sessão estendida — sem trabalho pesado (a Apple cancela
/// sessões que abusam de CPU: exceededResourceLimits).
final class RuntimeDelegate: NSObject, WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ s: WKExtendedRuntimeSession) {}
    func extendedRuntimeSessionWillExpire(_ s: WKExtendedRuntimeSession) {}
    func extendedRuntimeSession(_ s: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {}
}
