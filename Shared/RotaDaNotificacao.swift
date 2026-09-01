// RotaDaNotificacao.swift
// Alma — para onde cada notificação leva quando a pessoa toca nela
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE
//
// Até o build 93 o app agendava 11 lembretes locais e tratava o toque de UM
// deles. `AppDelegate.userNotificationCenter(_:didReceive:)` só olhava
// `userInfo["action"] == "openFeed"` — o push de feed vindo da Cloud Function.
// Os onze lembretes locais (água, três refeições, treino, suplemento, dois da
// Alma, cinco marcos de vício) não carregavam `userInfo` nenhum: tocar neles
// abria o app na tela padrão e a pessoa tinha que achar sozinha o lugar do que
// o app acabou de pedir.
//
// O pior modo de falha aqui não é "não leva a lugar nenhum". É "leva às vezes":
// quem tocou no push do feed e foi parar no feed aprende que notificação leva
// a algum lugar, e passa a interpretar o toque da refeição — que não leva — como
// app quebrado. Por isso o encaminhamento é de TODAS ou de nenhuma.
//
// ═══════════════════════════════════════════════════════════════════════════
// AS DUAS PORTAS DE ENTRADA DO iOS, E POR QUE A SEGUNDA É SEMPRE ESQUECIDA
//
// 1. APP VIVO (primeiro ou segundo plano). O delegate dispara com a árvore de
//    views montada. Publicar o destino basta: quem observa reage na hora.
//
// 2. APP FECHADO (partida fria). O delegate TAMBÉM dispara — o iOS entrega a
//    resposta logo depois de `didFinishLaunchingWithOptions`. Só que nesse
//    instante NÃO EXISTE view nenhuma: a `RootView` ainda está no splash,
//    talvez no login, talvez no onboarding. Um `@Published` emitido aí é
//    emitido para ninguém, e o destino evapora em silêncio.
//
//    É por isso que `pendente` NÃO é um evento: é um ESTADO que fica guardado
//    até alguém consumir. Cada tela chama `consumir(_:)` tanto no `onAppear`
//    (partida fria: a tela nasce e encontra o destino esperando) quanto no
//    `onChange` (app vivo: a tela já existe e o destino chega depois). Sem as
//    duas chamadas, metade dos caminhos fica quebrada — e é sempre a metade
//    fria, porque é a que ninguém testa.
//
// ═══════════════════════════════════════════════════════════════════════════
// O QUE ESTE ARQUIVO PROVA E O QUE NÃO PROVA
//
// PROVA (asserções R1–R7 em AuditoriaBloqueadores, em runtime):
//   • que todo identificador que o app agenda tem destino — e que a lista de
//     identificadores não está vazia (guarda anti-cegueira, lição do A26d);
//   • que o mapa identificador → destino é o esperado, um a um;
//   • que `pendente` sobrevive a ser escrito sem observador (o caso frio);
//   • que consumir devolve o destino UMA vez e limpa.
//
// NÃO PROVA, e não vou fingir que prova:
//   • que o iOS de fato chama o delegate ao tocar na notificação;
//   • que a aba muda na TELA depois de o destino ser consumido.
//   Ambas exigem XCUITest, que este projeto não tem (CLAUDE.md, "XCUITest
//   ausente"). O elo entre o destino consumido e o `selectedTab` da tela é
//   coberto pelo lint de wiring (R-W1..R-W8 em `_scripts/lint_wiring.py`), que
//   é verificação estática e fica vermelha se alguém apagar a linha — não é a
//   mesma coisa que ver a tela mudar, e está declarado como não sendo.

import Foundation
import SwiftUI

// MARK: - Abas, com nome

/// Abas do Alma. Os valores brutos são os mesmos `tag` do `MainTabView` —
/// se um dia divergirem, a asserção R6 fica vermelha.
enum AbaDaAlma: Int, CaseIterable {
    case inicio = 0, feed = 1, praticas = 2, insights = 3, perfil = 4
}

/// Abas do módulo Corpo, iguais aos `tag` do `RootTabView`.
enum AbaDoCorpo: Int, CaseIterable {
    case inicio = 0, saude = 1, dieta = 2, treino = 3, insights = 4
}

// MARK: - Destino

/// Para onde o toque leva. Fechado de propósito: acrescentar caso obriga a
/// tratar o caso em todas as telas que fazem `switch`.
enum DestinoDaNotificacao: Equatable {
    /// Uma aba do Alma.
    case almaAba(AbaDaAlma)
    /// Uma aba dentro do módulo Corpo (que é um `fullScreenCover` da Início).
    case corpoAba(AbaDoCorpo)
    /// A conversa com a Alma (`ChatView`, empilhada na Início).
    case conversarComAlma
    /// O contador "Livre de Vícios" (empilhado na Início).
    case livreDeVicios
}

// MARK: - Catálogo

/// O catálogo é a FONTE ÚNICA: quem agenda um lembrete carimba o destino a
/// partir daqui, e quem recebe o toque resolve o destino a partir daqui.
/// Um identificador novo que não passe por este arquivo é pego pela asserção
/// R1 (todo agendado tem destino) e pelo lint R-W5.
enum RotaDaNotificacao {

    /// Chave carimbada no `userInfo` de cada lembrete local, e que a Cloud
    /// Function pode mandar no `data` do push.
    static let chaveDestino = "almaDestino"

    /// Identificadores que o app agenda hoje, e o destino de cada um.
    ///
    /// Os identificadores vêm de:
    ///   • `NotificationManager.sync`  — water-*, meal-*, workout, supplement-daily
    ///   • `LembretesDaAlma.agendar`   — daily_morning, daily_evening
    ///   • `AddictionFreeView`         — addiction_*
    ///
    /// Os prefixos batem com `DonoDoLembrete.prefixos` (GradeDeLembretes) —
    /// a asserção R7 compara os dois conjuntos.
    static let catalogo: [(identificador: String, destino: DestinoDaNotificacao)] = [
        // Água: o copo se registra na Início do Corpo (`waterCard`).
        ("water-9",  .corpoAba(.inicio)),
        ("water-13", .corpoAba(.inicio)),
        ("water-17", .corpoAba(.inicio)),
        ("water-20", .corpoAba(.inicio)),

        // Refeições: a aba Dieta é onde se registra o que comeu. É o pedido
        // literal do Assis — "quando clico na notificação não me manda pra aba
        // de dieta diretamente".
        ("meal-breakfast", .corpoAba(.dieta)),
        ("meal-lunch",     .corpoAba(.dieta)),
        ("meal-dinner",    .corpoAba(.dieta)),

        // Treino do dia.
        ("workout", .corpoAba(.treino)),

        // Suplementos: NÃO têm tela própria alcançável. `SupplementsView.swift`
        // existe no disco e não é referenciada por ninguém (órfã); o que a
        // pessoa usa é a `SupplementsSection()` dentro da Dieta.
        ("supplement-daily", .corpoAba(.dieta)),

        // Lembretes da Alma: o texto é sobre respirar e desacelerar, e o que
        // cumpre isso são as práticas.
        ("daily_morning", .almaAba(.praticas)),
        ("daily_evening", .almaAba(.praticas)),

        // [2026-08-26] Jejum: os dois avisos levam à Dieta, que é onde o
        // módulo mora (card dentro da `DietaView`, tela empilhada a partir
        // dele). Não há aba nova nem destino novo — acrescentar caso em
        // `DestinoDaNotificacao` obrigaria a tratar o caso em todo `switch` do
        // app, e o jejum não precisa disso: ele é parte da Dieta.
        ("jejum_fim",    .corpoAba(.dieta)),
        ("jejum_janela", .corpoAba(.dieta)),

        // Marcos do contador de tempo sem vício.
        ("addiction_1",   .livreDeVicios),
        ("addiction_12",  .livreDeVicios),
        ("addiction_24",  .livreDeVicios),
        ("addiction_168", .livreDeVicios),
        ("addiction_720", .livreDeVicios),
    ]

    /// Índice por identificador exato.
    private static let porIdentificador: [String: DestinoDaNotificacao] =
        Dictionary(uniqueKeysWithValues: catalogo.map { ($0.identificador, $0.destino) })

    /// Prefixos, para os identificadores que variam (água por hora, marcos por
    /// hora). Ordem importa: o mais específico primeiro.
    private static let porPrefixo: [(String, DestinoDaNotificacao)] = [
        ("water-",      .corpoAba(.inicio)),
        ("meal-",       .corpoAba(.dieta)),
        ("supplement-", .corpoAba(.dieta)),
        ("jejum_",      .corpoAba(.dieta)),
        ("workout",     .corpoAba(.treino)),
        ("daily_",      .almaAba(.praticas)),
        ("addiction_",  .livreDeVicios),
    ]

    // MARK: Carimbo (na hora de agendar)

    /// `userInfo` que todo lembrete local deve carregar. Carimbar na origem faz
    /// o destino viajar com a notificação: um lembrete agendado por um build
    /// antigo e disparado depois continua roteando pelo prefixo, e um lembrete
    /// novo roteia pelo carimbo, que é explícito.
    static func carimbo(para identificador: String) -> [String: Any] {
        guard let destino = destinoPorIdentificador(identificador) else { return [:] }
        return [chaveDestino: codigo(de: destino)]
    }

    // MARK: Resolução (na hora do toque)

    /// A função pura que o toque atravessa. Três fontes, nesta ordem:
    ///   1. o carimbo explícito no `userInfo` (lembretes novos e push do servidor);
    ///   2. o `action: "openFeed"` legado (push da Cloud Function `notifyNewFeedPost`,
    ///      que continua no ar e não vou quebrar);
    ///   3. o identificador do request (lembretes já agendados em builds antigos —
    ///      um lembrete `repeats: true` agendado pelo 93 continua disparando
    ///      depois da atualização, com o `userInfo` vazio do 93).
    static func destino(identificador: String,
                        userInfo: [AnyHashable: Any]) -> DestinoDaNotificacao? {
        if let bruto = userInfo[chaveDestino] as? String,
           let d = destino(deCodigo: bruto) {
            return d
        }
        if let acao = userInfo["action"] as? String, acao == "openFeed" {
            return .almaAba(.feed)
        }
        // [Áudio do dia 2026-08-31] O push das 6h (`audioDoDiaNotificacao`,
        // codebase `audio`) carrega `action: "openAudioDoDia"`. A caixa com o
        // player mora na Início — o toque leva direto a ela.
        if let acao = userInfo["action"] as? String, acao == "openAudioDoDia" {
            return .almaAba(.inicio)
        }
        return destinoPorIdentificador(identificador)
    }

    static func destinoPorIdentificador(_ identificador: String) -> DestinoDaNotificacao? {
        if let exato = porIdentificador[identificador] { return exato }
        for (prefixo, destino) in porPrefixo where identificador.hasPrefix(prefixo) {
            return destino
        }
        return nil
    }

    // MARK: Código textual (o que viaja no userInfo e no push)

    static func codigo(de destino: DestinoDaNotificacao) -> String {
        switch destino {
        case .almaAba(let a):      return "alma:\(a.rawValue)"
        case .corpoAba(let a):     return "corpo:\(a.rawValue)"
        case .conversarComAlma:    return "chat"
        case .livreDeVicios:       return "vicios"
        }
    }

    static func destino(deCodigo codigo: String) -> DestinoDaNotificacao? {
        switch codigo {
        case "chat":   return .conversarComAlma
        case "vicios": return .livreDeVicios
        default:
            let partes = codigo.split(separator: ":")
            guard partes.count == 2, let n = Int(partes[1]) else { return nil }
            switch partes[0] {
            case "alma":  return AbaDaAlma(rawValue: n).map(DestinoDaNotificacao.almaAba)
            case "corpo": return AbaDoCorpo(rawValue: n).map(DestinoDaNotificacao.corpoAba)
            default:      return nil
            }
        }
    }
}

// MARK: - Roteador (o estado que sobrevive à partida fria)

/// Guarda o destino até uma tela conseguir consumi-lo.
///
/// Não é `PassthroughSubject` nem `NotificationCenter.post` de propósito: os
/// dois são EVENTOS, e evento emitido antes de existir observador some. Na
/// partida fria é exatamente isso que acontece — o delegate resolve o destino
/// segundos antes de a `MainTabView` existir.
///
/// Sem `@MainActor`, pelo mesmo motivo declarado em `AparenciaDoApp`: o projeto
/// compila em Swift 5.0 com checagem mínima, e uma View não é isolada ao
/// MainActor nesse modo — anotar a classe faria os métodos auxiliares das
/// Views deixarem de compilar. Quem escreve é o delegate, e ele já entra pela
/// fila principal (`DispatchQueue.main.async` em AlmaApp.swift).
final class RoteadorDeNotificacao: ObservableObject {
    static let shared = RoteadorDeNotificacao()

    /// Destino esperando por uma tela. `nil` = nada pendente.
    @Published private(set) var pendente: DestinoDaNotificacao?

    /// Aba pedida dentro do módulo Corpo. Fica separada porque o `RootTabView`
    /// só existe depois de a Início apresentar o `fullScreenCover` — quando o
    /// destino é consumido pela Início, a aba precisa continuar guardada até o
    /// `RootTabView` nascer.
    @Published var abaDoCorpoPendente: AbaDoCorpo?

    /// Quantos destinos já foram roteados. Só para a auditoria enxergar
    /// atividade — uma asserção que não consegue distinguir "funcionou" de
    /// "não rodou" é uma asserção cega.
    private(set) var roteados = 0

    init() {}

    /// Chamado pelo `AppDelegate` quando a pessoa toca na notificação.
    func rotear(_ destino: DestinoDaNotificacao) {
        pendente = destino
        roteados += 1
        if case .corpoAba(let aba) = destino { abaDoCorpoPendente = aba }
    }

    /// Consome o pendente SE ele casar com o predicado. Devolve `nil` quando
    /// não há nada ou quando o destino é de outra tela — assim cada tela pega
    /// só o que sabe cumprir, e o resto continua esperando.
    func consumir(onde condicao: (DestinoDaNotificacao) -> Bool) -> DestinoDaNotificacao? {
        guard let atual = pendente, condicao(atual) else { return nil }
        pendente = nil
        return atual
    }

    /// Consome a aba do Corpo (usado pelo `RootTabView` ao nascer e a cada
    /// mudança). Limpa para que reabrir o módulo à mão não pule para a aba
    /// de uma notificação velha.
    func consumirAbaDoCorpo() -> AbaDoCorpo? {
        defer { abaDoCorpoPendente = nil }
        return abaDoCorpoPendente
    }

    /// Só para a auditoria: devolve o estado a zero entre asserções.
    func zerarParaAuditoria() {
        pendente = nil
        abaDoCorpoPendente = nil
        roteados = 0
    }
}
