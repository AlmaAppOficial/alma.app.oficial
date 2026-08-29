import SwiftUI
import FirebaseAuth
import Speech
import AVFoundation

// MARK: - VoiceInputController [Build 84 — 2026-07-29]
// Ditado por voz no chat: STT nativo da Apple (SFSpeechRecognizer) em pt-BR,
// on-device quando o aparelho suportar (privacidade). O texto reconhecido
// PREENCHE o campo de entrada — o envio continua manual, e não há resposta
// falada neste build (TTS de resposta fica para o próximo).
@MainActor
final class VoiceInputController: ObservableObject {

    @Published var isRecording = false
    @Published var transcript = ""
    @Published var permissionDenied = false
    @Published var errorText: String? = nil

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Junta os enunciados do ditado. Ver `AcumuladorDeDitado` para a história
    /// das duas explicações erradas que dei antes de achar a causa real.
    private var acumulador = AcumuladorDeDitado()

    func toggle() {
        if isRecording {
            stop()
        } else {
            Task { await start() }
        }
    }

    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }

        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
    }

    func start() async {
        errorText = nil

        guard await requestPermissions() else {
            permissionDenied = true
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorText = "O reconhecimento de voz não está disponível agora. Tente novamente em instantes."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            // Privacidade: processa no aparelho quando o iOS oferecer pt-BR local
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            // [Build 84] Sem entrada de áudio válida (ex.: simulador sem
            // microfone, fone desconectado no meio) installTap lança exceção
            // Objective-C que derruba o app — falha com mensagem em vez disso.
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorText = "Não encontrei um microfone disponível neste aparelho."
                teardown()
                return
            }
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()

            // Preserva o que já estava escrito no campo.
            acumulador.semear(textoExistente: transcript)
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        // A junção acontece AQUI, na fronteira de enunciado —
                        // não no start(), que só roda quando se toca no botão.
                        self.transcript = self.acumulador.receber(
                            result.bestTranscription.formattedString)
                        if result.isFinal {
                            self.transcript = self.acumulador.encerrar()
                            self.teardown()
                        }
                    }
                    if error != nil {
                        self.teardown()
                    }
                }
            }
        } catch {
            errorText = "Não consegui acessar o microfone. Tente novamente."
            teardown()
        }
    }

    /// Encerra a captura; o resultado final ainda chega pelo recognitionTask.
    func stop() {
        request?.endAudio()
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        devolverSessaoParaReproducao()
    }

    private func teardown() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request = nil
        task = nil
        isRecording = false
        devolverSessaoParaReproducao()
    }

    /// [2026-08-04 — ÁUDIO MORTO NO BUILD 89] Devolve a sessão à reprodução.
    ///
    /// Antes aqui só havia `setActive(false)`. A categoria continuava `.record`,
    /// e a AVAudioSession é uma só para o processo inteiro: dali em diante
    /// nenhuma meditação, som ou música saía pelo alto-falante — `play()`
    /// devolvia `true`, `isPlaying` ficava `true`, o tempo andava, e silêncio.
    /// Só voltava ao normal matando e reabrindo o app.
    ///
    /// Quem sabe configurar a sessão de reprodução é o AudioManager; chamamos
    /// ele para não existirem duas verdades sobre categoria e modo.
    private func devolverSessaoParaReproducao() {
        AudioManager.shared.restaurarSessaoDeReproducao()
    }
}

struct ChatView: View {

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var authError: String? = nil
    @State private var showAuthError = false
    // [Build 84] Persistência do histórico (ChatHistoryStore)
    @State private var historyLoaded = false
    // [Build 84] Alerta amigável para mensagens acima do limite do servidor
    @State private var showLengthAlert = false
    // [Build 84] Ditado por voz (STT pt-BR — só entrada; sem resposta falada)
    @StateObject private var voice = VoiceInputController()
    // [Build 85 / 2.0] Leitura do HealthKit para o contexto de saúde da IA
    @StateObject private var healthManager = HealthKitManager()
    @Environment(\.dismiss) private var dismiss

    // [Build 82 — 2026-07-15] Chat exige Premium. Gate primário está em HomeView/heroButton;
    // este guard é segurança adicional para outros pontos de entrada.
    @EnvironmentObject var access: AccessManager
    @EnvironmentObject var store: StoreKitManager

    // [Build 84 — 2026-07-28] Removido o cronômetro de sessão de 5 minutos.
    // Era um resquício de controle de custo da primeira versão do chat (anterior
    // ao gate premium do Build 82). Comportamento atual: assinante = sem limite
    // de tempo; não-assinante = PremiumWallView (gate acima). O rate-limit de
    // mensagens continua no servidor (Cloud Function, 20 msg/hora).

    // [Build 84 — 2026-07-29] FREEMIUM: o bloqueio total do chat (Build 82)
    // deu lugar a uso limitado grátis — FreemiumLimits.chatMessagesPerDay
    // mensagens/dia. Ao esgotar, CTA → paywall (sheet). Assinante: sem limite.
    @State private var showPaywall = false

    // [2026-08-28] O servidor já recusou esta conta por assinatura neste
    // episódio. Existe para o paywall abrir UMA vez, e não a cada envio:
    // modal repetido troca um incômodo por outro. Enquanto true, o envio é
    // travado no botão e o convite fica visível na faixa do topo — a pessoa
    // continua vendo o motivo, sem levar um modal na cara toda vez.
    // Zera sozinho quando o premium entra (ver `.onChange` do `isPremium`).
    @State private var premiumBloqueado = false

    /// [2026-08-28] Copy escolhida pelo Assis. Mora no CLIENTE de propósito: o
    /// texto que o servidor manda no 403 é DESCARTADO por este caminho (vira
    /// `.premiumRequired`). Trocar a frase aqui não exige deploy de servidor.
    static let conviteAssinatura = "Assine para conversar com a sua Alma"
    /// Apoio em crise: aberto só por toque no rodapé, nunca automaticamente.
    @State private var showApoio = false
    @State private var freeUsedToday = FreemiumLimits.chatMessagesUsedToday()

    private var freeRemaining: Int {
        max(0, FreemiumLimits.chatMessagesPerDay - freeUsedToday)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider().opacity(0.3)

            // Pill de cota grátis (só não-assinante)
            if !access.isPremium {
                freemiumPill
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if messages.isEmpty {
                            // Grátis sem cota → convite ao Premium; assinante → boas-vindas
                            if !access.isPremium && freeRemaining <= 0 {
                                premiumInviteCard
                            } else {
                                welcomeView
                            }
                        }
                        // [Build 84] Mensagens agrupadas por dia (histórico persistido)
                        ForEach(messageGroups, id: \.dayKey) { group in
                            daySeparator(group.label)
                            ForEach(group.items) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                        }
                        if isTyping {
                            typingIndicator
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            // Input bar
            inputBar

            // [2026-08-22] Apoio em crise, sempre à mão. Não depende de
            // detecção nenhuma, e é por isso que está aqui: é a única camada
            // que funciona mesmo se o modelo errar. Ver `ApoioEmCrise.swift`.
            LinkDeApoio { showApoio = true }
        }
        .sheet(isPresented: $showApoio) {
            ApoioEmCriseView()
        }
        .background(CalmTheme.background)
        .navigationBarHidden(true)
        .alert("Autenticação necessária", isPresented: $showAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authError ?? "Por favor faz login para conversar com a Alma.")
        }
        .alert("Mensagem muito longa", isPresented: $showLengthAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sua mensagem tem \(inputText.trimmingCharacters(in: .whitespaces).count.formatted()) caracteres — o máximo é \(ChatLimits.maxMessageLength.formatted()). Divida o texto em partes menores e envie uma de cada vez. 💜")
        }
        .sheet(isPresented: $showPaywall) {
            // [2026-08-28] Título contextual quando o paywall veio da recusa do
            // servidor. Nos outros gatilhos (cota, botão) o título padrão fica.
            PremiumWallView(titulo: premiumBloqueado ? Self.conviteAssinatura : nil)
                .environmentObject(access)
                .environmentObject(store)
        }
        // [2026-08-28] Comprou (ou o entitlement finalmente resolveu): destrava
        // o envio e some com o convite, sem precisar reabrir a tela.
        .onChange(of: access.isPremium) { agoraEhPremium in
            if agoraEhPremium { premiumBloqueado = false }
        }
        .onAppear {
            TabVisibilityState.shared.hideMiniPlayer = true
            loadHistoryIfNeeded()
        }
        .onDisappear {
            TabVisibilityState.shared.hideMiniPlayer = false
            if voice.isRecording { voice.stop() }
        }
        // [Build 84] Texto ditado alimenta o campo em tempo real
        .onChange(of: voice.transcript) { newValue in
            if !newValue.isEmpty { inputText = newValue }
        }
        .alert("Permissão necessária", isPresented: $voice.permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Para falar com a Alma, permita o acesso ao microfone e ao reconhecimento de fala em Ajustes › Alma.")
        }
        // [Build 84] Falhas do ditado (mic indisponível, motor de fala offline)
        // precisam ser visíveis — antes ficavam só na propriedade, em silêncio.
        .alert("Não consegui ouvir", isPresented: Binding(
            get: { voice.errorText != nil },
            set: { if !$0 { voice.errorText = nil } }
        )) {
            Button("OK", role: .cancel) { voice.errorText = nil }
        } message: {
            Text(voice.errorText ?? "")
        }
    }

    // MARK: - Convite ao Premium [Build 84; revisto 2026-07-31]
    // Com cota 0 (decisão do Assis), o não-assinante vê um convite caloroso —
    // nunca um erro. Se um dia a cota voltar a ser > 0, a mesma faixa mostra o
    // saldo do dia automaticamente.
    private var freemiumPill: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 8) {
                Image(systemName: freeRemaining > 0 ? "message.badge.circle.fill" : "sparkles")
                    .font(.caption)
                Text(freemiumPillText)
                    .font(.caption.bold())
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(freeRemaining > 0 ? "Assinar" : "Conhecer")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CalmTheme.primary.opacity(0.18))
                    .cornerRadius(8)
            }
            .foregroundColor(freeRemaining > 0 ? CalmTheme.textSecondary : CalmTheme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CalmTheme.primary.opacity(0.06))
        }
        .buttonStyle(.plain)
    }

    private var freemiumPillText: String {
        // [2026-08-28] Recusa por assinatura vinda do SERVIDOR. Fica aqui, na
        // faixa fixa do topo, em vez de virar balão: é persistente, não some ao
        // rolar, e não se repete a cada mensagem.
        if premiumBloqueado {
            return Self.conviteAssinatura
        }
        if !FreemiumLimits.chatHasFreeQuota {
            return "Conversar com a Alma faz parte do Premium"
        }
        if freeRemaining <= 0 {
            return "Suas mensagens grátis de hoje acabaram"
        }
        if freeRemaining == 1 {
            return "1 mensagem grátis restante hoje"
        }
        return "\(freeRemaining) mensagens grátis hoje"
    }

    // Convite mostrado no corpo do chat quando o usuário grátis abre a tela e
    // ainda não há histórico — explica o valor em vez de mostrar um muro.
    private var premiumInviteCard: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 24)
            AlmaLogo(size: 64)

            Text("A Alma escuta você no Premium")
                .font(.title3.bold())
                .foregroundColor(CalmTheme.textPrimary)
                .multilineTextAlignment(.center)

            // [2026-08-04 — B-3] Verdadeiro somente APÓS o deploy da função
            // que remove o limite para assinante. Não submeter antes.
            // [2026-08-04] Era "Conversas ilimitadas com a sua mentora..." —
            // mesma promessa falsa do paywall principal. Ver SubscriptionView.
            Text("Converse com a sua mentora de bem-estar, com memória da sua jornada e acolhimento sempre que precisar.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button(action: { showPaywall = true }) {
                Text("Conhecer o Premium")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(CalmTheme.heroGradient)
                    .cornerRadius(24)
            }

            Text("As meditações iniciais, os sons e o check-in de humor continuam livres para você.")
                .font(.caption2)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(CalmTheme.primary)
            }

            // Alma avatar
            AlmaLogo(size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Alma")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Online")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CalmTheme.surface)
    }

    // MARK: - Histórico persistido [Build 84]

    /// Carrega o histórico local; se vazio, hidrata do Firestore
    /// (users/{uid}/messages — já era gravado pela Cloud Function).
    private func loadHistoryIfNeeded() {
        guard !historyLoaded else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        historyLoaded = true

        let local = ChatHistoryStore.shared.loadLocal(uid: uid)
        if !local.isEmpty {
            messages = local + messages.filter { $0.isTransient }
            return
        }

        Task {
            let remote = await ChatHistoryStore.shared.fetchRemoteHistory(uid: uid)
            guard !remote.isEmpty else { return }
            await MainActor.run {
                // Mantém mensagens enviadas enquanto a hidratação estava em curso
                let pending = messages
                messages = remote + pending
                ChatHistoryStore.shared.replaceAll(messages, uid: uid)
            }
        }
    }

    private func persist(_ message: ChatMessage) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        ChatHistoryStore.shared.append(message, uid: uid)
    }

    // MARK: - Agrupamento por dia [Build 84]

    private struct MessageGroup {
        let dayKey: String
        let label: String
        let items: [ChatMessage]
    }

    private var messageGroups: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDay: Date? = nil
        var currentItems: [ChatMessage] = []

        func flush() {
            guard let day = currentDay, !currentItems.isEmpty else { return }
            groups.append(MessageGroup(
                dayKey: dayKeyString(day),
                label: dayLabel(day, calendar: calendar),
                items: currentItems
            ))
        }

        for msg in messages {
            let day = calendar.startOfDay(for: msg.timestamp)
            if currentDay != day {
                flush()
                currentDay = day
                currentItems = [msg]
            } else {
                currentItems.append(msg)
            }
        }
        flush()
        return groups
    }

    private func dayKeyString(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: day)
    }

    private func dayLabel(_ day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInYesterday(day) { return "Ontem" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: Date())
        f.dateFormat = sameYear ? "d 'de' MMMM" : "d 'de' MMMM 'de' yyyy"
        return f.string(from: day)
    }

    private func daySeparator(_ label: String) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundColor(CalmTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(CalmTheme.primary.opacity(0.06))
            .cornerRadius(10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Welcome
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            AlmaLogo(size: 72)

            Text("Olá! Eu sou a Alma")
                .font(.title3.bold())
                .foregroundColor(CalmTheme.textPrimary)

            Text("Sua mentora de bem-estar emocional.\nComo posso te ajudar hoje?")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Typing Indicator
    private var typingIndicator: some View {
        HStack(spacing: 4) {
            AlmaLogo(size: 28)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(CalmTheme.primary.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isTyping ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: isTyping
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(CalmTheme.primary.opacity(0.08))
            .cornerRadius(18)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Faixa de transcrição ao vivo [Build 85 — REMOVIDA em 2026-08-04]
    //
    // Existia para o texto ditado ficar sempre visível em falas longas. O efeito
    // colateral foi pior que o problema: duplicava o texto do campo de entrada,
    // ocupava até 96 pt acima dele e cortava a última mensagem da Alma.
    // Decisão do Assis, com os prints do build 90 na mão: um campo só.
    //
    // Mantida abaixo, sem uso, por uma versão — se a legibilidade em falas
    // longas voltar a incomodar, a saída é o próprio campo rolar para o fim,
    // não uma segunda caixa.
    private var liveTranscriptStripRemovida: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                Text(inputText.isEmpty ? "Pode falar…" : inputText)
                    .font(.subheadline)
                    .foregroundColor(inputText.isEmpty ? CalmTheme.textSecondary : CalmTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .id("transcriptTail")
            }
            .frame(maxHeight: 96)
            .background(CalmTheme.primary.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 5) {
                    Circle().fill(Color.red).frame(width: 7, height: 7)
                    Text("ouvindo")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .onChange(of: inputText) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("transcriptTail", anchor: .bottom)
                }
            }
            .padding(.horizontal, 4)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 4) {
            // [2026-08-04 — decisão do Assis: "não deve haver duplicação"]
            // A faixa de transcrição ao vivo saiu daqui. Ela repetia, acima do
            // campo, exatamente o mesmo texto que já aparecia dentro dele —
            // dois campos empilhados mostrando a mesma frase, comendo quase
            // metade da tela e cortando o último balão da Alma.
            //
            // Agora o texto ditado vai DIRETO para o campo de entrada normal, e
            // o indicador de "ouvindo" mora nele. Um campo só, um placeholder
            // só. A `liveTranscriptStrip` foi removida junto.

            // [Build 84] Contador discreto quando o texto se aproxima do limite
            if inputText.count > ChatLimits.counterVisibleFrom {
                HStack {
                    Spacer()
                    Text("\(inputText.count.formatted()) / \(ChatLimits.maxMessageLength.formatted())")
                        .font(.caption2)
                        .foregroundColor(
                            inputText.count > ChatLimits.maxMessageLength
                                ? .red
                                : CalmTheme.textSecondary
                        )
                        .padding(.trailing, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                // [Build 85 — 2026-07-31] Dois bugs reportados pelo Assis no iPhone:
                //  1) o texto saía PRETO fixo — ilegível no tema escuro. Agora usa
                //     CalmTheme.textPrimary, que já se adapta ao colorScheme.
                //  2) durante o ditado só dava para ver o fim da frase: o campo era
                //     de uma linha. Agora cresce até 5 linhas (axis: .vertical) e a
                //     ScrollView interna acompanha o texto sendo transcrito.
                TextField(
                    voice.isRecording ? "Ouvindo…" : "Fale com a Alma...",
                    text: $inputText,
                    axis: .vertical
                )
                    .lineLimit(1...5)
                    .foregroundColor(CalmTheme.textPrimary)
                    .tint(CalmTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(CalmTheme.surface)
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                voice.isRecording
                                    ? Color.red.opacity(0.55)
                                    : CalmTheme.primary.opacity(0.2),
                                lineWidth: voice.isRecording ? 1.5 : 1
                            )
                    )
                    .animation(.easeOut(duration: 0.15), value: inputText)

                // [Build 84] Botão de ditado por voz (pt-BR)
                Button(action: { voice.toggle() }) {
                    Image(systemName: voice.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(voice.isRecording ? .red : CalmTheme.primary)
                }
                .disabled(isTyping)
                .accessibilityLabel(voice.isRecording ? "Parar ditado" : "Falar com a Alma")

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? CalmTheme.textSecondary.opacity(0.3)
                                : CalmTheme.primary
                        )
                }
                // [2026-08-28] `premiumBloqueado` trava o envio depois da recusa
                // do servidor. Sem isto, cada toque dispararia outro 403 — e a
                // escolha seria entre reabrir o modal (laço) ou não fazer nada
                // (silêncio). Botão desabilitado + convite na faixa do topo diz
                // o que houve sem nenhum dos dois.
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isTyping || voice.isRecording || premiumBloqueado)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CalmTheme.background)
        .animation(.easeInOut(duration: 0.2), value: voice.isRecording)
    }

    // MARK: - Send
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // [2026-08-28] Cinto de segurança do `premiumBloqueado`. O botão já está
        // desabilitado neste estado; isto cobre o ditado por voz e qualquer
        // outro caminho que chame `sendMessage()` sem passar pelo botão. Não
        // vai à rede e NÃO reabre o paywall — quem reabre é o toque na faixa.
        if premiumBloqueado && !access.isPremium { return }

        // [Build 84] FREEMIUM: não-assinante tem N mensagens/dia; ao esgotar,
        // paywall em vez de envio.
        if !access.isPremium && freeRemaining <= 0 {
            showPaywall = true
            return
        }

        // [Build 84] Validação amigável de tamanho ANTES de ir à rede.
        // Espelha o limite da Cloud Function — nunca mais "erro 400" cru.
        if trimmed.count > ChatLimits.maxMessageLength {
            showLengthAlert = true
            return
        }

        // Consome cota grátis no despacho (não-assinante)
        if !access.isPremium {
            FreemiumLimits.recordChatMessageSent()
            freeUsedToday = FreemiumLimits.chatMessagesUsedToday()
        }

        let userMsg = ChatMessage(trimmed, isUser: true)
        messages.append(userMsg)
        inputText = ""

        isTyping = true
        Task {
            // Se não há utilizador autenticado, fazer login anônimo automaticamente
            if Auth.auth().currentUser == nil {
                do {
                    try await Auth.auth().signInAnonymously()
                } catch {
                    await MainActor.run {
                        isTyping = false
                        let errMsg = ChatMessage("Não foi possível conectar. Verifique sua internet e tente novamente.", isUser: false, isTransient: true)
                        messages.append(errMsg)
                    }
                    return
                }
            }

            // [Build 84] Persiste a mensagem do usuário (uid garantido após auth acima)
            persist(userMsg)

            // [Build 85 / 2.0] Contexto de saúde do dia, montado NO APARELHO.
            // `nil` quando não há consentimento ou dado real — nesse caso nada
            // de saúde sai do iPhone e a Alma responde como antes.
            let healthContext = await HealthContextBuilder(health: healthManager).build()

            do {
                let reply = try await OpenAIService.shared.sendMessage(trimmed, healthContext: healthContext)
                let almaMsg = ChatMessage(reply, isUser: false)
                await MainActor.run {
                    isTyping = false
                    messages.append(almaMsg)
                }
                persist(almaMsg)
            } catch AlmaError.serverError(let code) where code == 401 {
                // Token expirado — forca refresh e tenta de novo (1 retry)
                await MainActor.run { isTyping = true }
                do {
                    if let user = Auth.auth().currentUser {
                        _ = try await user.getIDToken()
                    }
                    let retry = try await OpenAIService.shared.sendMessage(trimmed, healthContext: healthContext)
                    let retryMsg = ChatMessage(retry, isUser: false)
                    await MainActor.run {
                        isTyping = false
                        messages.append(retryMsg)
                    }
                    persist(retryMsg)
                } catch let retryError {
                    // [Build 77 — 12/05/2026] Mensagens especificas no segundo erro,
                    // em vez do generico "Sessao expirada" que enganava o usuario.
                    await MainActor.run {
                        isTyping = false
                        if case AlmaError.premiumRequired = retryError {
                            bloquearPorAssinatura()
                            return
                        }
                        messages.append(ChatMessage(errorMessage(for: retryError), isUser: false, isTransient: true))
                    }
                }
            } catch let firstError {
                // [Build 77 — 12/05/2026] Mensagens especificas por tipo de erro.
                await MainActor.run {
                    isTyping = false
                    // [2026-08-28] Recusa por assinatura NÃO vira mensagem da
                    // Alma: abre o paywall, uma vez. Todo o resto (rede, cota,
                    // 400, 500) continua caindo no `append` de baixo e continua
                    // APARECENDO para a pessoa — ver o teste de não-regressão
                    // no laudo. Engolir esses erros seria pior que o defeito.
                    if case AlmaError.premiumRequired = firstError {
                        bloquearPorAssinatura()
                        return
                    }
                    messages.append(ChatMessage(errorMessage(for: firstError), isUser: false, isTransient: true))
                }
            }
        }
    }

    /// [2026-08-28] Abre o paywall UMA vez e trava o envio.
    ///
    /// O `guard` é o coração da coisa: a segunda recusa (e a terceira) não
    /// reabrem o modal. Antes desta função, cada mensagem enviada gerava um
    /// balão idêntico; a correção ingênua — abrir o paywall a cada 403 — só
    /// trocaria o balão repetido por um modal repetido.
    private func bloquearPorAssinatura() {
        guard !premiumBloqueado else { return }
        premiumBloqueado = true
        showPaywall = true
    }

    // [Build 77 — 12/05/2026] Helper de mensagens especificas por tipo de erro.
    // Substitui o catch-all "Sessao expirada" que aparecia pra qualquer falha no retry,
    // confundindo o usuario sobre a causa real (rede, rate-limit, servidor, etc).
    private func errorMessage(for error: Error) -> String {
        if let almaError = error as? AlmaError {
            switch almaError {
            case .noUser:
                return "Faca login para conversar com a Alma."
            case .tokenFailed:
                return "Nao consegui validar sua sessao. Feche e abra o app novamente."
            // [Build 84] O servidor mandou uma explicação em PT-BR (ex.: mensagem
            // muito longa) — mostra ela em vez de "erro 400" cru.
            case .serverRejected(_, let serverText):
                return serverText
            // [2026-08-28] Não deve chegar aqui: `premiumRequired` é
            // interceptado no `catch` e abre o paywall. Existe para o `switch`
            // ser exaustivo e para o caso de alguém chamar `errorMessage` por
            // outro caminho no futuro.
            case .premiumRequired(let serverText):
                return serverText
            case .serverError(let code):
                switch code {
                case 400:
                    return "Nao consegui processar essa mensagem. Tente reescrever ou dividir em partes menores."
                // [2026-08-28] 401 e 403 eram um caso só, com a copy do 401.
                // Separados porque o 403 nunca foi sessão expirada — e agora
                // que o 403 de ASSINATURA saiu daqui (vira `.premiumRequired`),
                // sobrou só o 403 sem corpo JSON, que merece texto próprio.
                case 401:
                    return "Sua sessao expirou. Feche e abra o app novamente."
                case 403:
                    return "Este recurso nao esta disponivel na sua conta."
                case 429:
                    return "Voce atingiu o limite de mensagens. Tente novamente em alguns minutos."
                case 500...599:
                    return "A Alma esta temporariamente indisponivel. Tente em alguns instantes."
                default:
                    return "Algo deu errado (erro \(code)). Verifique sua conexao."
                }
            case .rateLimited:
                return "Voce atingiu o limite de mensagens. Tente novamente em alguns minutos."
            case .parseFailed:
                return "Nao consegui processar a resposta. Tente novamente."
            case .networkError:
                return "Sem conexao. Verifique sua internet."
            }
        }
        return "Algo deu errado. Tente novamente em alguns instantes."
    }

}
