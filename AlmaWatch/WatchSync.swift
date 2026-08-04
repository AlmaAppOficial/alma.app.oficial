// WatchSync.swift
// Alma Watch — a ponte com o iPhone (WatchConnectivity), lado do relógio.
//
// Três regras (do diagnóstico de 04/08/2026):
//   1. O iPhone é a fonte da verdade. O relógio nunca decide sozinho.
//   2. Estado DESCE por applicationContext (sobrescreve). Evento SOBE por
//      transferUserInfo (fila, garante entrega).
//   3. Todo evento carrega um ID único — o iPhone descarta duplicata.

import Foundation
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchSync: NSObject, ObservableObject {

    static let shared = WatchSync()

    @Published var estado = WatchGroupStore.carregar()
    @Published var iphoneAlcancavel = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Estado

    private func aplicarContexto(_ dict: [String: Any]) {
        var e = estado
        if let v = dict["streak"] as? Int { e.streak = v }
        if let v = dict["recorde"] as? Int { e.recorde = v }
        if let v = dict["aguaMeta"] as? Int, v > 0 { e.aguaMeta = v }
        let hoje = EstadoDoDia.chaveDia()
        // Campos "de hoje" só valem se o iPhone os gerou hoje.
        let diaDoContexto = dict["dia"] as? String ?? hoje
        if diaDoContexto == hoje {
            if let v = dict["aguaMl"] as? Int { e.aguaMl = v }
            if let v = dict["treinouHoje"] as? Bool { e.treinouHoje = v }
            if let v = dict["praticouHoje"] as? Bool { e.praticouHoje = v }
            e.humorHoje = (dict["humorHoje"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        } else {
            e.aguaMl = 0
            e.treinouHoje = false
            e.praticouHoje = false
            e.humorHoje = nil
        }
        if let v = dict["premium"] as? Bool { e.premium = v }
        if let v = dict["nome"] as? String { e.nome = v }
        if let lista = dict["meditacoes"] as? [[String]] {
            e.meditacoes = lista.compactMap { item in
                guard item.count >= 3, let dia = Int(item[0]), let min = Int(item[2]) else { return nil }
                return MeditacaoDoCatalogo(dia: dia, titulo: item[1], minutos: min)
            }
        }
        e.atualizadoEm = Date()
        estado = e
        WatchGroupStore.salvar(e)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Atualização otimista local + evento na fila para o iPhone.
    private func registrarLocalmente(_ muta: (inout EstadoDoDia) -> Void, evento: [String: Any]) {
        var e = estado
        muta(&e)
        estado = e
        WatchGroupStore.salvar(e)
        WidgetCenter.shared.reloadAllTimelines()

        var payload = evento
        payload["id"] = UUID().uuidString
        payload["dia"] = EstadoDoDia.chaveDia()
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.transferUserInfo(payload)
    }

    // MARK: - Ações do pulso

    func registrarAgua(_ ml: Int) {
        registrarLocalmente({ $0.aguaMl = min($0.aguaMl + ml, $0.aguaMeta + 1000) },
                            evento: ["evt": "agua", "ml": ml])
    }

    func registrarHumor(_ humor: String) {
        registrarLocalmente({ $0.humorHoje = humor },
                            evento: ["evt": "humor", "valor": humor])
    }

    func registrarTreino(duracaoMin: Int, tipo: String) {
        registrarLocalmente({ $0.treinouHoje = true },
                            evento: ["evt": "treino", "duracaoMin": duracaoMin, "tipo": tipo])
    }

    func registrarRespiracao(duracaoSeg: Int) {
        registrarLocalmente({ $0.praticouHoje = true; $0.streak = max($0.streak, 1) },
                            evento: ["evt": "respiracao", "duracaoSeg": duracaoSeg])
    }

    // MARK: - Meditação (handoff para o iPhone)

    enum RespostaMeditacao {
        case tocando
        case precisaPremium
        case enviadoParaFila
        case falhou
    }

    /// Pede ao iPhone para tocar a meditação. Com resposta de verdade:
    /// se o iPhone estiver alcançável, esperamos o `replyHandler`; senão,
    /// o pedido entra na fila e dizemos isso honestamente.
    func tocarMeditacao(dia: Int, resposta: @escaping (RespostaMeditacao) -> Void) {
        let session = WCSession.default
        guard session.activationState == .activated else { resposta(.falhou); return }
        let msg: [String: Any] = ["action": "playMeditation", "day": dia]
        if session.isReachable {
            session.sendMessage(msg, replyHandler: { dict in
                Task { @MainActor in
                    switch dict["status"] as? String {
                    case "playing": resposta(.tocando)
                    case "needsPremium": resposta(.precisaPremium)
                    default: resposta(.falhou)
                    }
                }
            }, errorHandler: { _ in
                Task { @MainActor in
                    session.transferUserInfo(msg)
                    resposta(.enviadoParaFila)
                }
            })
        } else {
            session.transferUserInfo(msg)
            resposta(.enviadoParaFila)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSync: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        // Contexto pode já ter chegado enquanto o app dormia.
        let ctx = session.receivedApplicationContext
        Task { @MainActor in
            self.iphoneAlcancavel = session.isReachable
            if !ctx.isEmpty { self.aplicarContexto(ctx) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let alcancavel = session.isReachable
        Task { @MainActor in self.iphoneAlcancavel = alcancavel }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.aplicarContexto(applicationContext) }
    }

    /// O iPhone usa transferCurrentComplicationUserInfo para acordar o relógio
    /// quando o streak muda por lá — chega por aqui.
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo["ctx"] != nil || userInfo["streak"] != nil else { return }
        Task { @MainActor in self.aplicarContexto(userInfo) }
    }
}
