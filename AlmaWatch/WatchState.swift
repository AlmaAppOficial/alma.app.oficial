// WatchState.swift
// Alma Watch — o estado do dia, como o relógio o conhece.
//
// Fonte da verdade: o IPHONE. O relógio recebe o último estado por
// WCSession.applicationContext, guarda no App Group (para a complicação ler)
// e faz atualização OTIMISTA local quando a pessoa registra algo no pulso —
// o evento sobe para o iPhone pela fila (transferUserInfo) e o iPhone
// reconcilia e devolve o estado oficial.

import Foundation

/// Chaves do App Group compartilhadas entre o app do relógio e a complicação.
/// O grupo `group.com.almaapp.shared` aqui é o container DO RELÓGIO —
/// não se comunica com o do iPhone (App Group é por aparelho).
enum WatchGroupKeys {
    static let suite = "group.com.almaapp.shared"

    static let streak = "watch_streak"
    static let recorde = "watch_recorde"
    static let aguaMl = "watch_agua_ml"
    static let aguaMeta = "watch_agua_meta"
    static let aguaDia = "watch_agua_dia"
    static let treinouDia = "watch_treinou_dia"
    static let humorHoje = "watch_humor"
    static let humorDia = "watch_humor_dia"
    static let premium = "watch_premium"
    static let nome = "watch_nome"
    static let meditacoes = "watch_meditacoes_json"
    static let atualizadoEm = "watch_atualizado_em"
    static let praticouDia = "watch_praticou_dia"
}

struct MeditacaoDoCatalogo: Codable, Identifiable, Hashable {
    let dia: Int
    let titulo: String
    let minutos: Int
    var id: Int { dia }
}

/// Estado exibível do dia. Tudo `Codable` e simples de propósito.
struct EstadoDoDia: Codable, Equatable {
    var streak: Int = 0
    var recorde: Int = 0
    var aguaMl: Int = 0
    var aguaMeta: Int = 2500
    var treinouHoje: Bool = false
    var humorHoje: String? = nil
    var praticouHoje: Bool = false
    var premium: Bool = false
    var nome: String = ""
    var meditacoes: [MeditacaoDoCatalogo] = []
    var atualizadoEm: Date? = nil

    static func chaveDia(_ data: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: data)
    }
}

enum WatchGroupStore {

    static var defaults: UserDefaults? { UserDefaults(suiteName: WatchGroupKeys.suite) }

    /// Grava o estado no App Group. Campos "de hoje" carregam a chave do dia,
    /// para a leitura descartar sozinha o que ficou de ontem.
    static func salvar(_ e: EstadoDoDia) {
        guard let d = defaults else { return }
        let hoje = EstadoDoDia.chaveDia()
        d.set(e.streak, forKey: WatchGroupKeys.streak)
        d.set(e.recorde, forKey: WatchGroupKeys.recorde)
        d.set(e.aguaMl, forKey: WatchGroupKeys.aguaMl)
        d.set(e.aguaMeta, forKey: WatchGroupKeys.aguaMeta)
        d.set(hoje, forKey: WatchGroupKeys.aguaDia)
        d.set(e.treinouHoje ? hoje : "", forKey: WatchGroupKeys.treinouDia)
        d.set(e.humorHoje ?? "", forKey: WatchGroupKeys.humorHoje)
        d.set(e.humorHoje == nil ? "" : hoje, forKey: WatchGroupKeys.humorDia)
        d.set(e.praticouHoje ? hoje : "", forKey: WatchGroupKeys.praticouDia)
        d.set(e.premium, forKey: WatchGroupKeys.premium)
        d.set(e.nome, forKey: WatchGroupKeys.nome)
        d.set(Date(), forKey: WatchGroupKeys.atualizadoEm)
        if let data = try? JSONEncoder().encode(e.meditacoes) {
            d.set(data, forKey: WatchGroupKeys.meditacoes)
        }
    }

    /// Lê o estado, zerando o que não é de hoje.
    static func carregar() -> EstadoDoDia {
        guard let d = defaults else { return EstadoDoDia() }
        let hoje = EstadoDoDia.chaveDia()
        var e = EstadoDoDia()
        e.streak = d.integer(forKey: WatchGroupKeys.streak)
        e.recorde = d.integer(forKey: WatchGroupKeys.recorde)
        e.aguaMeta = max(d.integer(forKey: WatchGroupKeys.aguaMeta), 1)
        if e.aguaMeta == 1 { e.aguaMeta = 2500 }
        e.aguaMl = d.string(forKey: WatchGroupKeys.aguaDia) == hoje
            ? d.integer(forKey: WatchGroupKeys.aguaMl) : 0
        e.treinouHoje = d.string(forKey: WatchGroupKeys.treinouDia) == hoje
        e.praticouHoje = d.string(forKey: WatchGroupKeys.praticouDia) == hoje
        let humor = d.string(forKey: WatchGroupKeys.humorHoje) ?? ""
        e.humorHoje = (d.string(forKey: WatchGroupKeys.humorDia) == hoje && !humor.isEmpty) ? humor : nil
        e.premium = d.bool(forKey: WatchGroupKeys.premium)
        e.nome = d.string(forKey: WatchGroupKeys.nome) ?? ""
        e.atualizadoEm = d.object(forKey: WatchGroupKeys.atualizadoEm) as? Date
        if let data = d.data(forKey: WatchGroupKeys.meditacoes),
           let lista = try? JSONDecoder().decode([MeditacaoDoCatalogo].self, from: data) {
            e.meditacoes = lista
        }
        return e
    }
}
