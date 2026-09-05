// JejumStore.swift
// Alma — Corpo · onde o jejum é gravado e como ele avisa.
//
// ═══════════════════════════════════════════════════════════════════════════
// A DIVISÃO DE TRABALHO
//
// `Jejum.swift` decide (funções puras sobre datas). Este arquivo LEMBRA
// (UserDefaults) e AVISA (UNUserNotificationCenter). Separados porque a decisão
// tem de ser exercitável sem simulador e a persistência não tem como ser.
//
// [28/08] Um terceiro verbo entrou: este arquivo também MOSTRA — mantém o
// cronômetro da tela bloqueada em sincronia com o jejum, por
// `sincronizarCronometroDaTelaBloqueada()`. A decisão de o que mostrar continua
// fora daqui, em `estadoAoVivo(de:agora:)` (`JejumAoVivo.swift`), que é pura e
// entra no harness de mutação. Aqui só ficou o gatilho.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE SINGLETON, SE O `AppModel` NÃO É
//
// O `AppModel` é `@StateObject` de `CorpoModuleView`: nasce quando o módulo
// abre e morre quando ele fecha. Para o diário do dia isso funciona, porque o
// diário é relido do disco a cada abertura.
//
// Um jejum EM CURSO é diferente: ele existe enquanto o app está fechado, e o
// card da Dieta, a tela do jejum e o agendador de notificação precisam ver o
// mesmo objeto no mesmo instante — senão a tela mostra "em curso" e o card
// mostra "parado". Instância única resolve isso sem passar o objeto por seis
// níveis de View.
//
// `store` continua injetável pelo mesmo motivo do `AppModel`: teste que grava
// em `.standard` contamina o aparelho de quem está usando o app.
//
// ═══════════════════════════════════════════════════════════════════════════
// AS NOTIFICAÇÕES SÃO DE DISPARO ÚNICO, E ISSO IMPORTA PARA A AUDITORIA
//
// `GradeDeLembretes.totalDiario()` conta só gatilhos com `repeats == true`. Um
// jejum não é diário — começa quando a pessoa aperta o botão — então o gatilho
// é `UNTimeIntervalNotificationTrigger(repeats: false)`, e o teto de 9 avisos
// por dia continua sendo o que era. Não é acidente: é a razão de não haver
// `UNCalendarNotificationTrigger` aqui.
//
// O dono `.jejum` na `GradeDeLembretes` existe para o cancelamento. Sem dono
// próprio, `NotificationManager.sync` (que limpa o dono `.corpo` inteiro a cada
// toque no interruptor de água) apagaria em silêncio o aviso de fim de jejum —
// que é, letra por letra, o "bug da fusão" documentado naquele arquivo.

import Foundation
import Combine
import UserNotifications

@MainActor
final class JejumStore: ObservableObject {

    static let shared = JejumStore()

    private let store: UserDefaults

    // MARK: Chaves
    //
    // ⚠️ Estão no disco de quem usa o app. Ver o aviso do `MealType`.
    private enum Chave {
        static let emCurso        = "jejumEmCurso"
        static let historico      = "jejumHistorico"
        static let protocolo      = "jejumProtocoloPreferido"
        static let avisoVisto     = "jejumAvisoDeSaudeVisto"
        static let notificacoes   = "jejumNotificacoes"
    }

    // MARK: Estado

    /// O jejum acontecendo agora. `nil` = janela alimentar.
    @Published private(set) var emCurso: JejumEmCurso? {
        didSet { persistirEmCurso() }
    }

    /// Mais recente primeiro. Limitado a 120 registros — ver `podar`.
    @Published private(set) var historico: [JejumConcluido] {
        didSet { persistirHistorico() }
    }

    /// O último protocolo escolhido, para o botão já vir preenchido.
    @Published var protocoloPreferido: ProtocoloDeJejum {
        didSet { store.set(protocoloPreferido.rawValue, forKey: Chave.protocolo) }
    }

    /// O aviso de saúde (contraindicações) já foi mostrado uma vez?
    ///
    /// "Informe de forma clara e sem drama, uma vez, e siga." Depois de visto,
    /// o conteúdo continua alcançável na aba "Saber mais" — informar uma vez é
    /// diferente de esconder.
    @Published private(set) var avisoDeSaudeVisto: Bool {
        didSet { store.set(avisoDeSaudeVisto, forKey: Chave.avisoVisto) }
    }

    @Published var notificacoesLigadas: Bool {
        didSet {
            store.set(notificacoesLigadas, forKey: Chave.notificacoes)
            Task { await reagendar() }
        }
    }

    // MARK: Init

    init(store: UserDefaults = .standard) {
        self.store = store

        if let d = store.data(forKey: Chave.emCurso),
           let v = try? JSONDecoder().decode(JejumEmCurso.self, from: d) {
            emCurso = v
        } else {
            emCurso = nil
        }

        if let d = store.data(forKey: Chave.historico),
           let v = try? JSONDecoder().decode([JejumConcluido].self, from: d) {
            historico = v
        } else {
            historico = []
        }

        protocoloPreferido = ProtocoloDeJejum(rawValue: store.string(forKey: Chave.protocolo) ?? "")
            ?? .dezesseisPorOito
        avisoDeSaudeVisto = store.bool(forKey: Chave.avisoVisto)
        // Ligado por padrão SÓ na aparência: a notificação só existe depois de o
        // iOS autorizar, e a autorização é pedida quando o primeiro jejum
        // começa — nunca ao abrir a tela. Pedir permissão antes de a pessoa
        // querer a coisa é o jeito mais rápido de receber "não".
        notificacoesLigadas = store.object(forKey: Chave.notificacoes) as? Bool ?? true
    }

    // MARK: - Ciclo de vida do jejum

    func iniciar(_ protocolo: ProtocoloDeJejum, agora: Date = Date()) {
        protocoloPreferido = protocolo
        emCurso = JejumEmCurso(protocolo: protocolo, comecouEm: agora)
        Task {
            await pedirAutorizacaoSePreciso()
            await reagendar()
            await sincronizarCronometroDaTelaBloqueada()
        }
    }

    func pausar(agora: Date = Date()) {
        guard let atual = emCurso else { return }
        emCurso = atual.pausando(agora: agora)
        Task {
            await reagendar()
            await sincronizarCronometroDaTelaBloqueada()
        }
    }

    func retomar(agora: Date = Date()) {
        guard let atual = emCurso else { return }
        emCurso = atual.retomando(agora: agora)
        Task {
            await reagendar()
            await sincronizarCronometroDaTelaBloqueada()
        }
    }

    /// Encerra e arquiva. Devolve o registro para quem quiser mostrar o resumo.
    ///
    /// Encerrar ANTES da meta é um encerramento como qualquer outro: entra no
    /// histórico com a duração que teve, sem rótulo de fracasso e sem tela de
    /// confirmação perguntando "tem certeza?". Um app que dificulta parar de
    /// jejuar é um app que empurra para continuar jejuando.
    @discardableResult
    func encerrar(agora: Date = Date()) -> JejumConcluido? {
        guard let atual = emCurso else { return nil }
        let registro = JejumConcluido(
            protocolo: atual.protocolo,
            comecouEm: atual.comecouEm,
            terminouEm: agora,
            duracao: atual.decorrido(agora: agora)
        )
        historico.insert(registro, at: 0)
        podar()
        emCurso = nil
        Task {
            await reagendar()
            await sincronizarCronometroDaTelaBloqueada()
        }
        return registro
    }

    /// Descarta sem arquivar — para quem começou por engano.
    func descartar() {
        emCurso = nil
        Task {
            await GradeDeLembretes.limpar(.jejum)
            await sincronizarCronometroDaTelaBloqueada()
        }
    }

    func marcarAvisoDeSaudeComoVisto() { avisoDeSaudeVisto = true }

    /// Apaga o histórico. Usado pela limpeza de conta e pela própria tela.
    func apagarHistorico() {
        historico = []
    }

    // MARK: - Derivados

    var sequenciaEmDias: Int { Sequencia.dias(historico) }
    var estatisticas: EstatisticasDoJejum { EstatisticasDoJejum.calcular(historico) }

    /// Nomes dos alimentos já registrados hoje, para a sugestão de quebra não
    /// repetir o que a pessoa acabou de comer.
    static func nomesRegistrados(em refeicoes: [Meal]) -> [String] {
        refeicoes.flatMap { refeicao -> [String] in
            if let c = refeicao.componentes, !c.isEmpty { return c.map(\.nome) }
            return [refeicao.name]
        }
    }

    /// Mantém o histórico num tamanho que não faz o `UserDefaults` inchar nem a
    /// lista da tela travar. 120 registros são meses de uso.
    private func podar() {
        if historico.count > 120 { historico = Array(historico.prefix(120)) }
    }

    #if DEBUG
    /// Semeia estado para a conferência visual. **DEBUG e nada mais.**
    ///
    /// Existe porque `emCurso` e `historico` são `private(set)` — e continuam
    /// sendo, porque o único jeito legítimo de eles mudarem em produção é pelos
    /// métodos de ciclo de vida acima. Uma porta de escrita pública faria a
    /// próxima tela gravar direto e furar o agendamento de notificação.
    func semearParaCapturas(emCurso: JejumEmCurso?, historico: [JejumConcluido]) {
        self.emCurso = emCurso
        self.historico = historico
    }
    #endif

    // MARK: - Persistência

    private func persistirEmCurso() {
        guard let v = emCurso, let d = try? JSONEncoder().encode(v) else {
            store.removeObject(forKey: Chave.emCurso)
            return
        }
        store.set(d, forKey: Chave.emCurso)
    }

    private func persistirHistorico() {
        guard let d = try? JSONEncoder().encode(historico) else { return }
        store.set(d, forKey: Chave.historico)
    }

    // MARK: - Notificações

    private func pedirAutorizacaoSePreciso() async {
        guard notificacoesLigadas else { return }
        let centro = UNUserNotificationCenter.current()
        let estado = await centro.notificationSettings().authorizationStatus
        guard estado == .notDetermined else { return }
        _ = await NotificationManager.shared.requestAuthorization()
    }

    /// Reagenda os dois avisos do jejum a partir do estado atual.
    ///
    /// Sempre limpa antes. Um jejum pausado e retomado três vezes agendaria três
    /// avisos de fim em horários diferentes — e a pessoa receberia os três.
    func reagendar() async {
        await GradeDeLembretes.limpar(.jejum)
        guard notificacoesLigadas, let atual = emCurso, !atual.estaPausado else { return }

        let restante = atual.restante()

        // 1. Fim do jejum = ABERTURA da janela alimentar.
        if restante > 0 {
            agendar(id: JejumStore.idFimDoJejum,
                    titulo: "Janela alimentar aberta",
                    corpo: "Você fechou \(textoDaDuracao(atual.protocolo.duracaoDoJejum)) de jejum. Toque para montar a refeição de quebra.",
                    daquiA: restante)
        }

        // 2. Fim da janela = começo do próximo jejum. Só existe para protocolo
        //    com janela diária; o 5:2 não tem, e inventar um horário para ele
        //    seria a tela mentindo sobre o que a pessoa escolheu.
        if let janela = atual.protocolo.horasDeJanela {
            let ateOFimDaJanela = restante + janela * 3600
            agendar(id: JejumStore.idFimDaJanela,
                    titulo: "Janela alimentar fechando",
                    corpo: "Suas \(Int(janela)) h de janela terminam agora. Comece o próximo jejum quando quiser.",
                    daquiA: ateOFimDaJanela)
        }
    }

    static let idFimDoJejum  = "jejum_fim"
    static let idFimDaJanela = "jejum_janela"

    // MARK: - Cronômetro na tela bloqueada (Live Activity)

    /// Põe a atividade ao vivo de acordo com o estado atual do jejum.
    ///
    /// Chamada nas quatro transições (começar, pausar, retomar, encerrar) e
    /// também de `CorpoModuleView` — ao abrir o módulo e a cada volta do
    /// segundo plano. Esse segundo caso cobre dois cenários que nenhuma
    /// transição cobre: recriar a atividade depois do teto de 8 horas do iOS,
    /// e limpar uma atividade órfã que sobrou de um jejum já encerrado.
    ///
    /// ⚠️ NÃO passa por `notificacoesLigadas`, e isso é decisão, não descuido.
    /// Aquele interruptor governa os dois avisos de disparo único; a atividade
    /// ao vivo tem autorização PRÓPRIA no iOS (Ajustes › Alma › Atividades ao
    /// Vivo), então filtrá-la aqui esconderia o cronômetro de quem só desligou
    /// os avisos de janela. Mesma divisão do Android, onde a notificação
    /// persistente é publicada independentemente de `avisosLigados`.
    func sincronizarCronometroDaTelaBloqueada() async {
        // [29/08] Segundo consumidor do mesmo gatilho: o Apple Watch. As quatro
        // transições e a volta ao primeiro plano já passam por aqui — publicar o
        // contexto neste ponto dá ao relógio a mesma lista de gatilhos da tela
        // bloqueada, sem estado novo. ANTES do #available de propósito: o
        // relógio não depende do ActivityKit, e um iPhone no iOS 16.0 sem
        // atividade ao vivo continua tendo de atualizar o pulso.
        #if os(iOS)
        WatchBridge.shared.publicarContexto()
        #endif
        guard #available(iOS 16.2, *) else { return }
        await AtividadeAoVivoDoJejum.sincronizar(com: emCurso)
    }

    /// Disparo único. Ver o cabeçalho: `repeats: true` aqui furaria o teto
    /// diário de lembretes que a auditoria confere.
    private func agendar(id: String, titulo: String, corpo: String, daquiA: TimeInterval) {
        guard daquiA > 0 else { return }
        let conteudo = UNMutableNotificationContent()
        conteudo.title = titulo
        conteudo.body = corpo
        conteudo.sound = .default
        conteudo.categoryIdentifier = "ALMA_LEMBRETE"
        conteudo.userInfo = RotaDaNotificacao.carimbo(para: id)

        let gatilho = UNTimeIntervalNotificationTrigger(timeInterval: daquiA, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: conteudo, trigger: gatilho)
        )
    }
}
