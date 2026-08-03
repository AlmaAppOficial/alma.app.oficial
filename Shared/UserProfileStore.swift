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
    func pendencias(corpo: AppModel? = nil) -> [PendenciaPerfil] {
        let dadosDoCorpo = corpo ?? AppModel()

        var lista: [PendenciaPerfil] = []
        if primeiroNome == nil { lista.append(.nome) }
        if dataNascimento == nil { lista.append(.nascimento) }
        if !dadosDoCorpo.hasBodyProfile { lista.append(.medidas) }
        if !HealthContextConsent.hasAnyConsent { lista.append(.contexto) }
        return lista
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

    var porque: String {
        switch self {
        case .nome:       return "Para a Alma falar com você, e não com um usuário genérico."
        case .nascimento: return "Para calcular seu ano pessoal e adaptar as práticas à sua fase."
        case .medidas:    return "Sem peso e altura, as metas de calorias e água seriam chute."
        case .contexto:   return "Você escolhe o que ela enxerga. Nada sai do aparelho sem sua permissão."
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
