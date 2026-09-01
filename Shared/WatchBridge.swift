// WatchBridge.swift
// iPhone — a ponte com o Apple Watch (lado do telefone).
//
// O iPhone é a fonte da verdade:
//   • ESTADO desce por WCSession.updateApplicationContext (sobrescreve)
//   • EVENTOS sobem por transferUserInfo (fila) e são deduplicados por ID
//   • quando o streak muda por aqui, transferCurrentComplicationUserInfo
//     acorda o relógio para atualizar a complicação
//
// Este arquivo é novo (04/08/2026) e compila só no target iOS.

import Foundation
import WatchConnectivity

#if os(iOS)
import UIKit

@MainActor
final class WatchBridge: ObservableObject {

    static let shared = WatchBridge()

    /// Instância viva do AppModel do Corpo, quando o módulo está aberto
    /// (CorpoModuleView chama attach). Sem ela, eventos são aplicados numa
    /// instância temporária — a persistência é a mesma (UserDefaults).
    private weak var corpoModel: AppModel?

    private let processadosKey = "alma_watch_eventos_processados"
    private let maxProcessados = 300

    private var observadores: [NSObjectProtocol] = []
    private var debounceTask: Task<Void, Never>?

    private init() {}

    // MARK: - Ciclo de vida

    /// Chamado uma vez pelo AppDelegate, depois de ativar a WCSession.
    func iniciar() {
        let nc = NotificationCenter.default
        observadores.append(nc.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.publicarContexto() }
            })
        // O streak muda quando uma meditação/prática conclui.
        observadores.append(nc.addObserver(
            forName: NSNotification.Name("StreakManagerUpdated"),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.publicarContexto()
                    self?.acordarComplicacao()
                }
            })
        publicarContexto()
    }

    func attachCorpoModel(_ model: AppModel) {
        corpoModel = model
        publicarContexto()
    }

    private var modeloCorpo: AppModel {
        corpoModel ?? AppModel()
    }

    // MARK: - Estado (iPhone → Watch)

    func publicarContexto() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated else { return }

        let contexto = montarContexto()
        try? session.updateApplicationContext(contexto)
    }

    private func montarContexto() -> [String: Any] {
        let modelo = modeloCorpo
        let grupo = UserDefaults(suiteName: "group.com.almaapp.shared")

        // Premium: a fonte publicada pelo AccessManager na ponte do App Group.
        let premium = grupo?.bool(forKey: "alma_isPremium") ?? false
        let nome = grupo?.string(forKey: "shared_user_name")
            ?? UserDefaults.standard.string(forKey: "userName") ?? ""

        // Streak direto das chaves persistidas (StreakManager as mantém).
        let streak = UserDefaults.standard.integer(forKey: "alma_current_streak")
        let recorde = UserDefaults.standard.integer(forKey: "alma_longest_streak")
        let praticouHoje = Self.dataEHoje(UserDefaults.standard.object(forKey: "alma_last_meditation_date") as? Date)

        // Catálogo das 30 meditações — títulos canônicos do iPhone.
        let meditacoes: [[String]] = MeditationDay.all30Days.map {
            [String($0.day), $0.title, String($0.durationMinutes)]
        }

        var ctx: [String: Any] = [
            "v": 1,
            "dia": Self.chaveDia(),
            "streak": streak,
            "recorde": recorde,
            "aguaMl": modelo.waterMl,
            "aguaMeta": modelo.waterGoalMl,
            "treinouHoje": modelo.workoutDays.contains(Self.chaveDia()),
            "praticouHoje": praticouHoje,
            "premium": premium,
            "nome": nome,
            "meditacoes": meditacoes,
            "geradoEm": Date().timeIntervalSince1970,
        ]
        if let humor = humorDeHoje() { ctx["humorHoje"] = humor }

        // Jejum no pulso: o MESMO contrato da tela bloqueada — base = agora −
        // decorrido (nunca `inicio`, que é reescrito a cada retomada), meta =
        // base + duração, pausadoEm congela. Ver `JejumAoVivo.swift`; quem
        // desenha do outro lado é `AlmaWatch/JejumNoPulso.swift`.
        // Ausência das chaves = sem jejum: o applicationContext sobrescreve
        // inteiro, então encerrar aqui apaga a página e a complicação de lá.
        if let jejum = JejumStore.shared.emCurso {
            let vivo = estadoAoVivo(de: jejum)
            ctx["jejumBase"] = vivo.baseDoCronometro.timeIntervalSince1970
            ctx["jejumMeta"] = vivo.metaEm.timeIntervalSince1970
            ctx["jejumRotulo"] = jejum.protocolo.rotulo
            if let p = vivo.pausadoEm {
                ctx["jejumPausadoEm"] = p.timeIntervalSince1970
            }
        }
        return ctx
    }

    /// Streak mudou: acorda o relógio para a complicação refletir.
    /// (Orçamento limitado pelo sistema — usar só para o que muda o mostrador.)
    private func acordarComplicacao() {
        let session = WCSession.default
        guard WCSession.isSupported(),
              session.activationState == .activated,
              session.isComplicationEnabled else { return }
        var mini = montarContexto()
        mini["ctx"] = true
        mini.removeValue(forKey: "meditacoes")
        session.transferCurrentComplicationUserInfo(mini)
    }

    // MARK: - Eventos (Watch → iPhone)

    /// Roteia qualquer payload vindo do relógio (mensagem ou fila).
    /// Devolve true se reconheceu o payload.
    @discardableResult
    func processarPayload(_ payload: [String: Any]) -> Bool {
        if payload["action"] as? String == "playMeditation",
           let dia = payload["day"] as? Int {
            _ = tocarMeditacao(dia: dia)
            return true
        }
        guard let evt = payload["evt"] as? String else { return false }

        // Deduplicação: a fila do WatchConnectivity pode reentregar.
        if let id = payload["id"] as? String {
            var vistos = UserDefaults.standard.stringArray(forKey: processadosKey) ?? []
            guard !vistos.contains(id) else { return true }
            vistos.append(id)
            if vistos.count > maxProcessados { vistos.removeFirst(vistos.count - maxProcessados) }
            UserDefaults.standard.set(vistos, forKey: processadosKey)
        }

        switch evt {
        case "agua":
            if let ml = payload["ml"] as? Int, ml > 0, ml <= 2000 {
                modeloCorpo.addWater(ml)
            }
        case "humor":
            if let valor = payload["valor"] as? String,
               Mood(rawValue: valor) != nil {
                UserMemoryManager.shared.recordMood(valor)
                Self.registrarHumorParaOWatch(valor)
            }
        case "treino":
            modeloCorpo.registrarTreinoConcluido()
        case "respiracao":
            let seg = payload["duracaoSeg"] as? Int ?? 0
            Task {
                _ = await StreakManager.shared.recordMeditationCompletion(
                    duration: max(1, seg / 60), mood: "")
                await MainActor.run { self.publicarContexto() }
            }
        default:
            return false
        }
        publicarContexto()
        return true
    }

    // MARK: - Meditação (handoff)

    /// Toca a meditação pedida pelo relógio DIRETO no engine — funciona com o
    /// iPhone no bolso (o app tem background mode audio). A UI, se aberta,
    /// acompanha pela notificação .playMeditationFromWatch.
    /// Devolve o status para o replyHandler do relógio.
    func tocarMeditacao(dia: Int) -> String {
        guard let med = MeditationDay.all30Days.first(where: { $0.day == dia }) else {
            return "unknownDay"
        }
        let grupo = UserDefaults(suiteName: "group.com.almaapp.shared")
        let premium = grupo?.bool(forKey: "alma_isPremium") ?? false
        if med.day > 3 && !premium {
            return "needsPremium"
        }
        AudioManager.shared.stop()
        GuidedMeditationEngine.shared.play(day: med)
        NotificationCenter.default.post(name: .playMeditationFromWatch,
                                        object: nil, userInfo: ["day": dia])
        return "playing"
    }

    // MARK: - Datas

    static func chaveDia(_ data: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: data)
    }

    private static func dataEHoje(_ data: Date?) -> Bool {
        guard let data else { return false }
        return Calendar.current.isDateInToday(data)
    }

    /// Humor de hoje, se a pessoa registrou (a mesma trava de 1/dia do
    /// UserMemoryManager impede divergência).
    private func humorDeHoje() -> String? {
        // O UserMemoryManager guarda criptografado por uid; para o relógio
        // basta saber o rótulo registrado hoje — mantido em espelho simples.
        let d = UserDefaults.standard
        guard let dia = d.string(forKey: "alma_watch_humor_dia"), dia == Self.chaveDia() else { return nil }
        return d.string(forKey: "alma_watch_humor_valor")
    }

    /// Espelho do humor do dia para o contexto do relógio (chamado pela tela
    /// de Insights e pelo processamento de evento de humor).
    static func registrarHumorParaOWatch(_ valor: String) {
        let d = UserDefaults.standard
        d.set(valor, forKey: "alma_watch_humor_valor")
        d.set(chaveDia(), forKey: "alma_watch_humor_dia")
    }
}
#endif
