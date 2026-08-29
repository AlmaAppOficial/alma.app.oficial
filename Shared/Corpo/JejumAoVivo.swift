// JejumAoVivo.swift
// Alma — Corpo · o cronômetro do jejum na tela bloqueada.
//
// ═══════════════════════════════════════════════════════════════════════════
// O QUE ESTE ARQUIVO FAZ, E O QUE ELE NÃO CONSEGUE FAZER
//
// Faz: traduz o `JejumEmCurso` (que é a verdade) para a atividade ao vivo que o
// iOS desenha na tela bloqueada e na Ilha Dinâmica, e mantém as duas em sincronia
// nas quatro transições — começar, pausar, retomar, encerrar.
//
// NÃO faz — e isto precisa estar escrito aqui, não só no relatório:
//
//   ⏱ O iOS ENCERRA a atividade sozinho depois de 8 HORAS.
//     Documentação da Apple, "Displaying live data with Live Activities",
//     seção "Understand constraints", conferida em 28/08/2026:
//     ativa por no máximo 8 h; depois some da Ilha Dinâmica na hora e fica
//     mais até 4 h parada na tela bloqueada. Teto absoluto: 12 h.
//
//     Um 16/8 dura DEZESSEIS horas. Ou seja: a atividade não cobre um jejum
//     inteiro, e não existe ajuste, entitlement ou truque que estenda isso —
//     é limite do sistema, igual para todo app. O Android não tem esse teto,
//     e é por isso que lá o cronômetro dura o jejum todo e aqui não.
//
//     O que dá para fazer, e é o que `sincronizar` faz: quando a pessoa abre o
//     app de novo e o jejum ainda está de pé, a atividade é RECRIADA — mais 8 h.
//     Na prática o cronômetro reaparece sozinho no primeiro uso do dia.
//
//     O que continua cobrindo o jejum inteiro, sem teto: os dois avisos de
//     disparo único do `JejumStore` ("Janela alimentar aberta" e "fechando").
//     Eles não dependem disto aqui e não foram tocados.
//
// ═══════════════════════════════════════════════════════════════════════════
// O ALVO DO APP É iOS 16.0 E O ActivityKit SÓ EXISTE A PARTIR DO 16.1
//
// Isso NÃO é uma funcionalidade que some em quem está no 16.0: se o framework
// for ligado de forma FORTE, o dyld falha ao ABRIR o app e o aparelho inteiro
// fica sem Alma. Crash de lançamento, não degradação.
//
// Medido em 28/08 no binário, não suposto — o `ld` ligou de forma FRACA sozinho,
// porque o `minos` do framework é maior que o alvo de implantação:
//
//   otool -l .../Alma.App.Oficial.debug.dylib | grep -B1 ActivityKit
//     → cmd LC_LOAD_WEAK_DYLIB
//       name /System/Library/Frameworks/ActivityKit.framework/ActivityKit
//
// Controle positivo junto: 74 dylibs no total, 22 fracas. Sem esse controle o
// resultado seria compatível com "o comando não achou nada" — que é a armadilha
// do `strings` no APK documentada no CLAUDE.md.
//
// Por isso NÃO foi preciso `-weak_framework ActivityKit` em `OTHER_LDFLAGS`.
// Se alguém subir o alvo de implantação ou trocar de linker, REFAZER a medição.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE A DECISÃO É UMA FUNÇÃO PURA, FORA DO `#if`
//
// `estadoAoVivo(de:agora:)` só usa Foundation e vive de propósito FORA do bloco
// de ActivityKit. Assim ele entra no `_scripts/rodar_testes_jejum.sh`, que
// compila o domínio com `swiftc` no Mac e exercita as regras com datas
// fabricadas — e, mais importante, pode ser REPROVADO POR MUTAÇÃO (CLAUDE.md,
// Regra 1). O que fica dentro do `#if` é só encanamento com a Apple, que
// nenhum harness alcança e que por isso não pode conter regra nenhuma.
//
// ═══════════════════════════════════════════════════════════════════════════
// PRIVACIDADE
//
// `pushType: nil`. A atividade é local: o estado do jejum sai do UserDefaults e
// vai para o `.appex` no mesmo aparelho. Nenhum byte de dado de saúde sai daqui.
// Trocar isso por `.token` mandaria o jejum da pessoa para a APNs — decisão de
// corregedoria, não de arquitetura.

import Foundation

// MARK: - A decisão (pura, testável, sem ActivityKit)

/// O que a tela bloqueada precisa saber. Só datas e um booleano: nada que
/// envelheça entre uma atualização e outra.
public struct EstadoDoCronometroAoVivo: Equatable {
    /// Âncora do cronômetro: `agora − decorrido`.
    public let baseDoCronometro: Date
    /// Quando a meta cai, contando dessa âncora.
    public let metaEm: Date
    /// Congela o cronômetro. `nil` = correndo.
    public let pausadoEm: Date?
    public let atingiuAMeta: Bool

    public init(baseDoCronometro: Date, metaEm: Date, pausadoEm: Date?, atingiuAMeta: Bool) {
        self.baseDoCronometro = baseDoCronometro
        self.metaEm = metaEm
        self.pausadoEm = pausadoEm
        self.atingiuAMeta = atingiuAMeta
    }
}

/// Traduz o jejum em curso para o que a tela bloqueada desenha.
///
/// ── A LINHA QUE IMPORTA ─────────────────────────────────────────────────────
/// `baseDoCronometro = agora − decorrido`, e NÃO `jejum.inicio`.
///
/// `inicio` é reescrito toda vez que a pessoa retoma. Ancorar nele mostraria só
/// o trecho depois da última pausa: quem pausou um minuto depois de doze horas
/// veria "0 min" na tela bloqueada e "12 h" dentro do app. `decorrido` já soma o
/// `acumuladoAntesDaPausa`, então subtraí-lo de agora devolve a âncora que faz
/// os dois números baterem. Mesma escolha do Android (`JejumAvisos.kt`).
///
/// ── E POR QUE `metaEm` SAI DA BASE, NÃO DE AGORA ────────────────────────────
/// `metaEm = baseDoCronometro + duração`. Sai igual a `agora + restante`, que é
/// o que `previsaoDeTermino` devolve — mas expresso na mesma âncora do
/// cronômetro, para o sistema conseguir desenhar a barra de progresso entre as
/// duas datas sem o app estar vivo.
public func estadoAoVivo(de jejum: JejumEmCurso, agora: Date = Date()) -> EstadoDoCronometroAoVivo {
    let decorrido = jejum.decorrido(agora: agora)
    let base = agora.addingTimeInterval(-decorrido)
    return EstadoDoCronometroAoVivo(
        baseDoCronometro: base,
        metaEm: base.addingTimeInterval(jejum.protocolo.duracaoDoJejum),
        // Pausado congela no INSTANTE ATUAL, que é `base + decorrido`. Guardar
        // `jejum.pausadoEm` daria quase o mesmo número, mas "quase" aqui é a
        // diferença entre o cronômetro parar no valor que a tela do app mostra
        // e parar alguns segundos antes dele.
        pausadoEm: jejum.estaPausado ? agora : nil,
        atingiuAMeta: jejum.metaAtingida(agora: agora)
    )
}

// MARK: - O encanamento com o iOS

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// Liga e desliga a atividade ao vivo do jejum.
///
/// Tudo aqui engole falha de propósito. Atividade ao vivo é um EXTRA: se o iOS
/// recusar (pessoa desligou nos Ajustes, teto de atividades simultâneas, app em
/// segundo plano na hora de começar), o jejum tem de continuar funcionando
/// exatamente como funcionava antes desta funcionalidade existir. Um `throw`
/// subindo daqui derrubaria o botão "Começar" por causa de um enfeite.
@available(iOS 16.2, *)
public enum AtividadeAoVivoDoJejum {

    /// Põe a tela bloqueada de acordo com o estado real do jejum.
    ///
    /// Chamada nas quatro transições e também quando a tela do jejum aparece —
    /// esse segundo caso é o que RECRIA a atividade depois do teto de 8 h do
    /// sistema, e o que limpa uma atividade órfã de um jejum que já acabou.
    public static func sincronizar(com jejum: JejumEmCurso?, agora: Date = Date()) async {
        guard let jejum else {
            await encerrarTudo()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let estado = estadoAoVivo(de: jejum, agora: agora)
        let conteudo = AtributosDoJejumAoVivo.ContentState(
            baseDoCronometro: estado.baseDoCronometro,
            metaEm: estado.metaEm,
            pausadoEm: estado.pausadoEm,
            atingiuAMeta: estado.atingiuAMeta
        )

        // Uma atividade só. Se houver sobra de uma sessão anterior, ela é
        // atualizada em vez de duplicada — duas atividades do mesmo jejum na
        // tela bloqueada seria o mesmo defeito dos três avisos de fim que o
        // `reagendar()` do `JejumStore` já evita limpando antes de agendar.
        if let viva = ativa() {
            await viva.update(ActivityContent(state: conteudo, staleDate: nil))
            return
        }

        do {
            _ = try Activity.request(
                attributes: AtributosDoJejumAoVivo(
                    protocoloRotulo: jejum.protocolo.rotulo,
                    metaFormatada: textoDaDuracao(jejum.protocolo.duracaoDoJejum)
                ),
                content: ActivityContent(state: conteudo, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Silêncio proposital. Ver o cabeçalho do enum.
        }
    }

    /// Tira o cronômetro da tela bloqueada. Chamado ao encerrar e ao descartar.
    ///
    /// `.immediate` e não `.default`: com o padrão, a atividade fica até 4 h
    /// parada na tela depois de encerrada, e a pessoa que acabou de quebrar o
    /// jejum passaria a tarde vendo um cronômetro morto de um jejum que ela
    /// terminou. Órfã na tela de alguém é exatamente o que não pode acontecer.
    public static func encerrarTudo() async {
        for atividade in Activity<AtributosDoJejumAoVivo>.activities {
            await atividade.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// A atividade que ainda pode ser atualizada. `.ended` e `.dismissed` não
    /// podem — e é assim que o teto de 8 h do sistema aparece aqui: a atividade
    /// existe na lista, mas já não é `.active`, então `sincronizar` cria outra.
    private static func ativa() -> Activity<AtributosDoJejumAoVivo>? {
        Activity<AtributosDoJejumAoVivo>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
    }
}
#endif
