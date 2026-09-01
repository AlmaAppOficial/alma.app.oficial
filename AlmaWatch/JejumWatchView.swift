// JejumWatchView.swift
// Alma Watch — a página do jejum: o cronômetro que o pulso não mata.
//
// Por que esta página existe: o iPhone ganhou o cronômetro na tela bloqueada
// (Live Activity), mas o iOS encerra a atividade em 8 horas — e um 16/8 dura
// dezesseis. No pulso não há esse teto. É aqui que o recurso funciona inteiro.
//
// O que esta página NÃO tem, de propósito: botão de começar, pausar ou
// encerrar. Essas transições mexem em histórico, notificação e tela bloqueada,
// que moram no iPhone — e o iPhone é a fonte da verdade (regra 1 do
// `WatchSync.swift`). O pulso mostra; quem decide é o telefone. Se um dia o
// pulso ganhar controles, eles sobem como evento (`transferUserInfo`), igual
// à água e ao humor.
//
// Nada aqui envelhece: o número grande é `Text(timerInterval:)` — o sistema
// conta sozinho, com o app aberto ou não — e a troca de texto na meta é um
// `TimelineView(.everyMinute)`. Mesma divisão da tela bloqueada
// (`AlmaJejumWidget/JejumAoVivoWidget.swift`).

import SwiftUI

struct JejumWatchView: View {
    @ObservedObject private var sync = WatchSync.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let jejum = sync.estado.jejum {
                    JejumEmCursoWatch(jejum: jejum)
                } else {
                    semJejum
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Jejum")
    }

    /// Janela alimentar (ou pessoa que nunca usou o jejum).
    private var semJejum: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 28))
                .foregroundStyle(WatchTheme.violet)
                .padding(.top, 8)
            Text("Nenhum jejum em curso")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(WatchTheme.textPrimary)
            Text("Comece pelo iPhone, no módulo Corpo. O cronômetro aparece aqui e na complicação.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
                .multilineTextAlignment(.center)
            // = JejumConteudo.disclaimerCurto, letra por letra
            // (o alvo do relógio não compila Shared/).
            Text("Cronômetro e registro. Não é orientação médica.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Jejum em curso

private struct JejumEmCursoWatch: View {
    let jejum: JejumNoPulso.Estado

    var body: some View {
        // .everyMinute só troca TEXTO (meta atingida, "termina às"); o número
        // grande anda por conta do sistema, segundo a segundo.
        TimelineView(.everyMinute) { contexto in
            let agora = contexto.date
            let atingiu = jejum.atingiuAMeta(agora: agora)
            let cor: Color = jejum.estaPausado
                ? WatchTheme.textSecondary
                : (atingiu ? WatchTheme.corpoOlivaClaro : WatchTheme.violet)

            VStack(spacing: 8) {
                cartaoDoCronometro(cor: cor, atingiu: atingiu)
                if !jejum.estaPausado && !atingiu {
                    linhaTermino
                }
                Text("Pausar e encerrar ficam no iPhone.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary)
                // = JejumConteudo.disclaimerCurto, letra por letra.
                Text("Cronômetro e registro. Não é orientação médica.")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(WatchTheme.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func cartaoDoCronometro(cor: Color, atingiu: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: jejum.estaPausado ? "pause.circle.fill" : "timer")
                    .font(.system(size: 12))
                    .foregroundStyle(cor)
                // Mesmo título da tela bloqueada e do Android, letra por letra.
                Text("\(jejum.estaPausado ? "Jejum pausado" : "Jejum em curso")\(jejum.rotulo.isEmpty ? "" : " · \(jejum.rotulo)")")
                    .font(.system(size: 12, design: .rounded).weight(.semibold))
                    .foregroundStyle(WatchTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }

            // O número grande. Correndo, o sistema conta sozinho (o limite de
            // 72 h existe só porque a API exige faixa fechada — não é teto de
            // produto). Pausado, texto ESTÁTICO derivado do estado: o
            // `pauseTime:` da API não congela direito com pausa no passado —
            // ver o cabeçalho de `JejumNoPulso.cronometro`.
            Group {
                if jejum.estaPausado {
                    Text(JejumNoPulso.cronometro(jejum.decorrido()))
                } else {
                    Text(timerInterval: jejum.base...jejum.base.addingTimeInterval(72 * 3600),
                         countsDown: false)
                }
            }
            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(jejum.estaPausado ? WatchTheme.textSecondary : WatchTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)

            // A barra até a meta: correndo, o sistema preenche sozinho;
            // pausado, fração ESTÁTICA — barra que enche com o jejum parado
            // mostraria progresso que não está acontecendo.
            Group {
                if let pausadoEm = jejum.pausadoEm {
                    ProgressView(value: JejumNoPulso.fracaoCongelada(base: jejum.base,
                                                                    meta: jejum.meta,
                                                                    pausadoEm: pausadoEm),
                                 total: 1)
                } else {
                    ProgressView(timerInterval: jejum.base...max(jejum.meta, jejum.base.addingTimeInterval(1)),
                                 countsDown: false)
                        .labelsHidden()
                }
            }
            .progressViewStyle(.linear)
            .tint(cor)

            // A linha de estado — os mesmos três textos da tela bloqueada.
            Text(linhaDeEstado(atingiu: atingiu))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(WatchTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func linhaDeEstado(atingiu: Bool) -> String {
        if jejum.estaPausado {
            return "Pausado. Retome quando quiser."
        }
        if atingiu {
            return "Você chegou à meta de \(JejumNoPulso.textoDeDuracao(jejum.duracaoDaMeta))."
        }
        return "Meta de \(JejumNoPulso.textoDeDuracao(jejum.duracaoDaMeta))."
    }

    /// Hora de relógio: não envelhece. Some pausado — horário previsto para um
    /// cronômetro parado é número que a tela não tem direito de mostrar
    /// (`JejumEmCurso.previsaoDeTermino`).
    private var linhaTermino: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 10))
                .foregroundStyle(WatchTheme.textSecondary)
            Text("termina às \(Self.horaCurta(jejum.meta))")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(WatchTheme.textSecondary)
        }
    }

    /// "20:14" — mesmo formato fixo da tela do iPhone (`JejumView.horaCurta`):
    /// HH:mm com locale pt_BR, para o pulso e o telefone dizerem a mesma hora
    /// do mesmo jeito.
    private static func horaCurta(_ data: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f.string(from: data)
    }
}
