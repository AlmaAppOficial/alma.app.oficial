// AparenciaDoApp.swift
// Alma App — fonte ÚNICA de verdade da aparência (claro / escuro / sistema)
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE — o bug do build 91 [2026-08-04]
//
// O Assis tocou na lua da Início do Corpo e NADA aconteceu no aparelho dele,
// enquanto 10 capturas do simulador mostravam claro e escuro funcionando.
// As duas coisas eram verdade ao mesmo tempo, porque mediam coisas diferentes.
//
// O app tinha DOIS armazenamentos de aparência e eles não se falavam:
//
//   ESCRITORES                                        CHAVE GRAVADA
//   ProfileView.darkModeRow (toggle)                  isDarkMode      (Bool)
//   CorpoHomeView (botão da LUA)                      appearanceMode  (String)
//   Corpo/SettingsView (picker "Aparência")           appearanceMode  (String)
//
//   LEITORES QUE DE FATO APLICAM .preferredColorScheme
//   AlmaApp / MainTabView / CorpoModuleView           isDarkMode      (Bool)
//
// Ou seja: a lua e o picker do Corpo gravavam `appearanceMode`, que NINGUÉM
// aplicava. `AppModel.colorScheme` era lido em exatamente dois lugares — as
// linhas 56 e 58 do CorpoHomeView — e as duas só decidiam qual ÍCONE desenhar.
// Por isso o botão parecia responder: o desenho virava de lua para sol, o
// estado mudava, e a aparência do app continuava exatamente onde estava.
//
// A correção de 04/08 registrada no CorpoModuleView consertou o LEITOR (passou
// a aplicar `isDarkMode` dentro do fullScreenCover, que de fato não herdava) e
// deixou o ESCRITOR apontando para a chave errada. Meio bug consertado.
//
// POR QUE O SIMULADOR NÃO PEGOU: `SmokeTestTelas.conferenciaDeAparencia` impõe
// `.environment(\.colorScheme, esquema)` direto na view e a renderiza numa
// UIWindow. Isso pula o botão, pula o @AppStorage e pula o
// .preferredColorScheme — prova que os CARDS sabem escurecer, nunca que o
// INTERRUPTOR está ligado a alguma coisa. As 10 capturas estavam certas sobre
// o que mediam; só não mediam o que quebrou.
//
// REGRA DAQUI PARA A FRENTE: uma chave só. Todo escritor passa por
// `AparenciaDoApp.shared`; todo leitor aplica `aparencia.colorScheme`.
// Se alguém criar um segundo armazenamento, a asserção A24d reprova.
// ═══════════════════════════════════════════════════════════════════════════
//
// ═══════════════════════════════════════════════════════════════════════════
// DÍVIDA CONHECIDA — A FRONTEIRA DO fullScreenCover [2026-08-05, build 93]
//
// O conserto acima ficou provado NO MODELO e continuou quebrado NA TELA,
// dentro do módulo Corpo. Sintoma do Assis, no aparelho, com o build 92:
// "entro no corpo e mudo de escuro pra claro não acontece nada, e de claro
// pra escuro também". Nas Configurações do Alma funcionava.
//
// O QUE FOI PROVADO POR LEITURA (build 92, commit a2cf65d):
//   · o Corpo é apresentado por `.fullScreenCover` — HomeView.swift:150-151 e
//     CorpoAlmaBannerView.swift:59-60. É uma CENA DE APRESENTAÇÃO separada.
//   · o leitor JÁ existe lá dentro: CorpoModuleView.swift:54 observa o
//     singleton e :70 aplica `.preferredColorScheme`.
//   · os escritores estavam certos, e os seis pontos do app usavam a MESMA
//     instância (`static let shared`), arquivo único, um alvo só no pbxproj.
//   · nenhuma hipótese secundária sobrevive: a migração só roda no `init`;
//     `appearanceMode` está aposentado; o tema do Corpo é dinâmico de verdade
//     (Corpo/CorpoTheme.swift:43-47).
//   · a teoria de "o Assis está num build velho" está MORTA: a2cf65d é um
//     commit só com o conserto da aparência E o scan de comida por IA.
//
// O QUE FALTA PROVAR — duas candidatas, ambas de runtime, que a leitura de
// código não separa:
//   (a) um `fullScreenCover` JÁ APRESENTADO não re-aplica
//       `preferredColorScheme` quando o valor muda com ele em tela (a
//       preferência valeria só no instante da apresentação);
//   (b) o override de nível de janela vindo de AlmaApp.swift:217
//       (raiz do WindowGroup → UIWindow.overrideUserInterfaceStyle) tem
//       precedência sobre o do cover.
//
// EXPERIMENTO QUE SEPARA AS DUAS: com o Corpo aberto, alternar a aparência e
// registrar (1) `AparenciaDoApp.shared.modo` e (2) o
// `userInterfaceStyle` do host do cover. Se o modo vira e o trait não vira,
// é a fronteira; e (a) vs (b) se decide olhando se o Alma ATRÁS do cover
// mudou junto — mudou = (a), não mudou = (b).
//
// DECISÃO DO BUILD 93: não consertar às pressas. Os controles de aparência
// SAÍRAM do módulo Corpo (ver Corpo/CorpoHomeView.swift e Corpo/SettingsView.swift)
// e a aparência passou a ter um lugar só: Alma › Perfil › Modo escuro. Isso
// faz o sintoma desaparecer de verdade, porque `CorpoModuleView` é construído
// a cada apresentação e lê o modo corrente ao abrir — a falha só existia para
// mudanças feitas COM o cover em tela.
//
// O QUE ISSO NÃO RESOLVE: qualquer controle futuro dentro do cover que precise
// mudar estado global e ver a tela reagir na hora vai bater na mesma parede.
// Quando for resolver, o conserto candidato é dirigir
// `overrideUserInterfaceStyle` na janela a partir do `didSet` do `modo`, que
// cobre (a) e (b) de uma vez — e aí as asserções A26a/A26b podem ser
// afrouxadas para permitir os controles de volta.
// ═══════════════════════════════════════════════════════════════════════════

import SwiftUI

// MARK: - Modo

/// Os três estados possíveis. `sistema` acompanha o aparelho.
enum ModoDeAparencia: String, CaseIterable, Sendable {
    case sistema
    case claro
    case escuro

    /// O que vai para `.preferredColorScheme`. `nil` = deixa o iOS decidir.
    var colorScheme: ColorScheme? {
        switch self {
        case .sistema: return nil
        case .claro:   return .light
        case .escuro:  return .dark
        }
    }

    /// Rótulo do picker. PT-BR.
    var rotulo: String {
        switch self {
        case .sistema: return "Sistema"
        case .claro:   return "Claro"
        case .escuro:  return "Escuro"
        }
    }
}

// MARK: - Fonte única

/// Sem `@MainActor` de propósito: acompanha o padrão dos outros singletons
/// observáveis do app (`AudioManager.shared`, `TabVisibilityState.shared`),
/// que são construídos como valor padrão de propriedade de View. O projeto
/// está em Swift 5 (`SWIFT_VERSION = 5.0`), e só a UI toca nesta classe.
final class AparenciaDoApp: ObservableObject {

    static let shared = AparenciaDoApp()

    /// A chave. Uma só, no app inteiro.
    static let chave = "aparenciaModo"

    /// Chaves antigas — lidas UMA vez na migração e nunca mais.
    static let chaveLegadaAlma  = "isDarkMode"      // Bool,   toggle do Perfil
    static let chaveLegadaCorpo = "appearanceMode"  // String, lua e picker do Corpo

    private let defaults: UserDefaults

    @Published var modo: ModoDeAparencia {
        didSet {
            guard modo != oldValue else { return }
            defaults.set(modo.rawValue, forKey: Self.chave)
            // Espelha na chave antiga para não quebrar quem ainda a leia
            // (LocalDataCleanupService a preserva, e um downgrade de build
            // encontra um valor coerente em vez de lixo).
            defaults.set(modo == .escuro, forKey: Self.chaveLegadaAlma)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.modo = Self.modoInicial(defaults)
        // Grava o resultado da migração para que a próxima abertura leia
        // direto da chave nova.
        defaults.set(self.modo.rawValue, forKey: Self.chave)
    }

    /// O que o app aplica.
    var colorScheme: ColorScheme? { modo.colorScheme }

    // MARK: Ação da lua

    /// A ação EXATA que o botão da lua executa. O botão não pode fazer nada
    /// além de chamar isto — é o que a asserção A24b exercita.
    ///
    /// - Parameter sistemaEstaEscuro: aparência atual do aparelho, usada só
    ///   quando o modo é `.sistema` (aí alternar significa "sair do sistema
    ///   para o oposto do que estou vendo").
    func alternar(sistemaEstaEscuro: Bool) {
        modo = Self.proximoModo(de: modo, sistemaEstaEscuro: sistemaEstaEscuro)
    }

    /// Função PURA da alternância — testável sem UI, sem UserDefaults.
    static func proximoModo(de atual: ModoDeAparencia, sistemaEstaEscuro: Bool) -> ModoDeAparencia {
        switch atual {
        case .escuro:  return .claro
        case .claro:   return .escuro
        case .sistema: return sistemaEstaEscuro ? .claro : .escuro
        }
    }

    // MARK: Migração

    /// Decide o modo inicial a partir do que existir no disco.
    ///
    /// Ordem e por quê:
    ///  1. `aparenciaModo` — a chave nova, se já existir, manda.
    ///  2. `isDarkMode == true` — a pessoa estava VENDO escuro. Preservar.
    ///  3. `appearanceMode == "dark"` — a pessoa PEDIU escuro pela lua e nunca
    ///     recebeu. Agora recebe. É o conserto chegando a quem sofreu o bug.
    ///  4. `appearanceMode == "light"` — pediu claro, já estava claro.
    ///  5. Qualquer outra coisa (inclusive `appearanceMode == "system"`) → `.claro`.
    ///
    /// O passo 5 merece explicação: "system" é o VALOR PADRÃO do `appearanceMode`,
    /// então não dá para distinguir "escolheu Sistema" de "nunca tocou nisso".
    /// Migrar todo mundo para `.sistema` mudaria a aparência de quem tem o
    /// aparelho no escuro sem essa pessoa ter pedido nada — o app abriria
    /// diferente do que abria ontem. `.claro` preserva exatamente o
    /// comportamento observável de hoje. Quem quiser Sistema escolhe no picker.
    static func modoMigrado(
        aparenciaModo: String?,
        isDarkMode: Bool,
        appearanceMode: String?
    ) -> ModoDeAparencia {
        if let novo = aparenciaModo, let m = ModoDeAparencia(rawValue: novo) {
            return m
        }
        if isDarkMode { return .escuro }
        switch appearanceMode {
        case "dark":  return .escuro
        case "light": return .claro
        default:      return .claro
        }
    }

    private static func modoInicial(_ d: UserDefaults) -> ModoDeAparencia {
        modoMigrado(
            aparenciaModo: d.string(forKey: chave),
            isDarkMode: d.bool(forKey: chaveLegadaAlma),
            appearanceMode: d.string(forKey: chaveLegadaCorpo)
        )
    }
}
