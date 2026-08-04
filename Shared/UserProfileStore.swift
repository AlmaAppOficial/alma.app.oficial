// UserProfileStore.swift
// Alma — fonte única do perfil da pessoa
//
// [2026-08-02] Antes desta camada o app tinha três verdades sobre quem é o
// usuário e nenhuma delas era confiável:
//   • a Home dizia só "Bom dia", sem nome;
//   • o Perfil mostrava `Auth.currentUser?.displayName ?? "Usuário"`;
//   • o módulo Corpo chutava "Felipe" — o nome do dono do app, gravado como
//     valor padrão. Todo mundo que instalasse o app se chamava Felipe.
//
// Aqui existe UMA fonte. Ela nunca inventa: quando não sabe o nome, devolve
// `nil` e a interface se adapta ("Bom dia" em vez de "Bom dia, Fulano").
//
// Onde vive: App Group, para que Alma e Corpo leiam o mesmo valor.

import Foundation
import Combine

@MainActor
final class UserProfileStore: ObservableObject {

    static let shared = UserProfileStore()

    private let store = UserDefaults(suiteName: "group.com.almaapp.shared") ?? .standard

    private enum Key {
        static let nome = "perfil_nome"
        static let onboardingConcluido = "perfil_onboardingConcluido"
        static let dataNascimento = "perfil_dataNascimento"
    }

    /// Nome de tratamento. `nil` quando desconhecido — nunca um chute.
    @Published var nome: String? {
        didSet {
            let limpo = nome?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let limpo, !limpo.isEmpty {
                store.set(limpo, forKey: Key.nome)
            } else {
                store.removeObject(forKey: Key.nome)
            }
        }
    }

    /// Data de nascimento — base do ano pessoal e do cálculo de idade.
    /// `nil` até a pessoa informar.
    @Published var dataNascimento: Date? {
        didSet {
            if let dataNascimento {
                store.set(dataNascimento.timeIntervalSince1970, forKey: Key.dataNascimento)
            } else {
                store.removeObject(forKey: Key.dataNascimento)
            }
        }
    }

    @Published var onboardingConcluido: Bool {
        didSet { store.set(onboardingConcluido, forKey: Key.onboardingConcluido) }
    }

    /// [2026-08-04 — BUG DO CARD] Muda sempre que algo que o card "Complete seu
    /// perfil" avalia é gravado, inclusive por telas que têm o SEU PRÓPRIO
    /// `AppModel`. É `@Published`, então quem observa este store recalcula as
    /// pendências na hora — sem isto o card só sumia ao reabrir o app.
    @Published private(set) var carimboDeMudanca = 0

    /// Marcado quando a pessoa passa pela tela de consentimento, tendo ligado
    /// algo ou não. Distingue "ainda não viu" de "viu e não quis".
    ///
    /// [2026-08-04] Era uma propriedade calculada sobre o UserDefaults: gravar
    /// nela não avisava a interface. Se a ÚNICA pendência restante fosse esta,
    /// o card também não sumia. Agora é `@Published`, como as outras.
    @Published var decidiuSobreContexto: Bool {
        didSet { store.set(decidiuSobreContexto, forKey: "perfil_decidiuContexto") }
    }

    /// [2026-08-04 — D-2] Zera o que está EM MEMÓRIA.
    ///
    /// `clearAll()` apagava `perfil_nome` do disco, mas este singleton segurava
    /// o valor antigo e o app não reinicia — `RootView` só troca a View. A
    /// sequência real era: excluir conta → logar outra pessoa → a Home
    /// cumprimentava o novo usuário pelo nome do anterior, e o onboarding
    /// regravava esse nome no App Group. O dado apagado voltava sozinho.
    ///
    /// Chamado por `LocalDataCleanupService.clearAll()` e no logout.
    func resetarEmMemoria() {
        nome = nil
        dataNascimento = nil
        onboardingConcluido = false
        decidiuSobreContexto = false
        carimboDeMudanca &+= 1
    }

    /// Ponte para quem não está no MainActor (o serviço de limpeza).
    nonisolated static func resetar() {
        Task { @MainActor in UserProfileStore.shared.resetarEmMemoria() }
    }

    /// Avisa que o perfil mudou. `nonisolated` porque quem grava peso e altura é
    /// o `AppModel` do módulo Corpo, que não é `@MainActor`.
    nonisolated static func avisarMudanca() {
        Task { @MainActor in
            UserProfileStore.shared.carimboDeMudanca &+= 1
        }
    }

    // MARK: - Acesso sem isolamento de ator
    //
    // O AppModel do módulo Corpo não é @MainActor e precisa ler/escrever o
    // mesmo nome. UserDefaults é seguro entre threads, então estes dois
    // acessores atravessam a fronteira sem forçar uma refatoração do Corpo.

    nonisolated static var suite: UserDefaults {
        UserDefaults(suiteName: "group.com.almaapp.shared") ?? .standard
    }

    nonisolated static func nomeSalvo() -> String? {
        let valor = suite.string(forKey: Key.nome)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (valor?.isEmpty == false) ? valor : nil
    }

    nonisolated static func salvarNome(_ novo: String?) {
        let limpo = novo?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let limpo, !limpo.isEmpty {
            suite.set(limpo, forKey: Key.nome)
        } else {
            suite.removeObject(forKey: Key.nome)
        }
    }

    private init() {
        nome = store.string(forKey: Key.nome)
        onboardingConcluido = store.bool(forKey: Key.onboardingConcluido)
        decidiuSobreContexto = store.bool(forKey: "perfil_decidiuContexto")
        let ts = store.double(forKey: Key.dataNascimento)
        dataNascimento = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    // MARK: - Leitura

    /// Primeiro nome, para tratamento na interface. "Felipe Assis Lara" → "Felipe".
    var primeiroNome: String? {
        guard let nome, !nome.isEmpty else { return nil }
        return nome.split(separator: " ").first.map(String.init)
    }

    /// Idade em anos, quando houver data de nascimento.
    var idadeAnos: Int? {
        guard let dataNascimento else { return nil }
        return Calendar.current.dateComponents([.year], from: dataNascimento, to: Date()).year
    }

    /// Semeia o nome a partir da conta (Apple/Google), mas SÓ se ainda não
    /// houver um informado pela pessoa — o que ela digitou sempre vence.
    func semearSeVazio(comNomeDaConta nomeDaConta: String?) {
        guard nome == nil || nome?.isEmpty == true else { return }
        let limpo = nomeDaConta?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let limpo, !limpo.isEmpty, limpo.lowercased() != "usuário" else { return }
        nome = limpo
    }

    // MARK: - Completude

    /// O que ainda falta para o app parar de operar no escuro. A ordem importa:
    /// é a ordem em que o card "Complete seu perfil" cobra.
    ///
    /// [2026-08-02] As medidas eram verificadas só quando alguém passasse um
    /// AppModel — e a Home chamava sem parâmetro. Resultado: o card dizia
    /// "faltam 3" mesmo com peso e altura em branco, e a barra de progresso
    /// mentia. Agora, sem model, ele monta um a partir do que está persistido.
    ///
    /// [2026-08-04 — BUG DO CARD, reportado pelo Assis no simulador]
    /// A correção de 02/08 passou a receber um `AppModel` de fora, e a de 03/08
    /// (B4) fez a Home guardar esse model num `@StateObject` criado UMA vez.
    /// Só que a tela que preenche o perfil tem o SEU PRÓPRIO `@StateObject`:
    /// ela gravava peso e altura na instância dela, o disco era atualizado, e a
    /// instância da Home continuava com 0 — o card cobrava para sempre uma
    /// informação que a pessoa acabara de dar. Sumia só ao reabrir o app, que é
    /// exatamente o sintoma relatado.
    ///
    /// A lição: perguntar a uma INSTÂNCIA é perguntar a uma cópia. Agora a
    /// completude é lida do DISCO, que é onde a verdade mora, e o
    /// `carimboDeMudanca` avisa a interface para recalcular.
    func pendencias(medidas: Medidas = .persistidas()) -> [PendenciaPerfil] {
        // Faz a leitura depender do carimbo: sem isto o SwiftUI poderia não
        // reavaliar quando só o disco muda.
        _ = carimboDeMudanca

        var lista: [PendenciaPerfil] = []

        if primeiroNome == nil { lista.append(.nome) }

        // [A6b] Usuário antigo tem a data no UserMemoryManager e nunca populou
        // a chave nova do App Group. Sem olhar as duas fontes, o card cobraria
        // eternamente uma informação que o app já tem.
        if dataNascimento == nil && UserMemoryManager.shared.birthDate == nil {
            lista.append(.nascimento)
        }

        // [A6a] `hasBodyProfile` exige idade > 0, mas a data de nascimento é
        // opcional no onboarding — quem informava peso e altura sem a data
        // ficava com o card para sempre. Aqui a cobrança é só do que a própria
        // pendência promete: peso e altura.
        if !medidas.completas { lista.append(.medidas) }

        // [A6c] Não consentir é uma escolha legítima. Só cobramos de quem ainda
        // não decidiu — quem já viu a tela e disse não, não é cobrado de novo.
        if !HealthContextConsent.hasAnyConsent && !decidiuSobreContexto {
            lista.append(.contexto)
        }
        return lista
    }

    /// Peso e altura como estão NO DISCO — não como estão numa instância viva de
    /// `AppModel`, que pode ser uma cópia velha. Ver o comentário de
    /// `pendencias(medidas:)`.
    struct Medidas {
        var peso: Double
        var altura: Double

        var completas: Bool { peso > 0 && altura > 0 }

        /// O mesmo store e as mesmas chaves que o `AppModel` grava.
        static func persistidas(store: UserDefaults = .standard) -> Medidas {
            Medidas(peso: store.object(forKey: "weightKg") as? Double ?? 0,
                    altura: store.object(forKey: "heightCm") as? Double ?? 0)
        }
    }
}

/// Cada pendência sabe explicar POR QUE está sendo pedida. Pedir dado sem dizer
/// para quê é o que faz as pessoas abandonarem onboarding.
enum PendenciaPerfil: String, Identifiable, CaseIterable {
    case nome
    case nascimento
    case medidas
    case contexto

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .nome:       return "Como você quer ser chamado"
        case .nascimento: return "Sua data de nascimento"
        case .medidas:    return "Suas medidas"
        case .contexto:   return "O que a Alma pode ver"
        }
    }

    /// Nome curto para o card DIZER o que falta, em vez de "faltam 2
    /// informações" — genérico manda a pessoa caçar o campo sozinha.
    var rotuloCurto: String {
        switch self {
        case .nome:       return "como te chamar"
        case .nascimento: return "sua data de nascimento"
        case .medidas:    return "peso e altura"
        // [2026-08-04] Era "o que a Alma pode ver" e a frase saía com "Alma"
        // duas vezes: "Falta o que a Alma pode ver para a Alma te acompanhar".
        case .contexto:   return "escolher o que ela pode ver"
        }
    }

    var porque: String {
        switch self {
        case .nome:       return "Para a Alma falar com você, e não com um usuário genérico."
        case .nascimento: return "Para calcular seu ano pessoal e adaptar as práticas à sua fase."
        case .medidas:    return "Sem peso e altura, as metas de calorias e água seriam chute."
        case .contexto:   return "Você escolhe o que ela enxerga. Nada sai do aparelho sem sua permissão."
        }
    }

    /// Frase do card. Função pura, fora da View, para o harness poder assertar
    /// que o texto NOMEIA o que falta — foi o pedido do Assis ao reportar o bug.
    static func textoDoQueFalta(_ pendencias: [PendenciaPerfil]) -> String {
        let nomes = pendencias.map(\.rotuloCurto)
        switch nomes.count {
        case 0:  return ""
        case 1:  return "Falta \(nomes[0]) para a Alma te acompanhar de verdade"
        default:
            let ultimo = nomes[nomes.count - 1]
            let anteriores = nomes.dropLast().joined(separator: ", ")
            return "Faltam \(anteriores) e \(ultimo) para a Alma te acompanhar de verdade"
        }
    }

    var icone: String {
        switch self {
        case .nome:       return "person.text.rectangle"
        case .nascimento: return "calendar"
        case .medidas:    return "figure.stand"
        case .contexto:   return "lock.shield"
        }
    }
}
