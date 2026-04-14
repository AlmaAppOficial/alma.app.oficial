import SwiftUI
import FirebaseAuth

struct ChatView: View {

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var showLimitAlert = false
    @State private var authError: String? = nil
    @State private var showAuthError = false
    @Environment(\.dismiss) private var dismiss

    // 5-min session timer
    private let sessionDuration: Double = 300  // 5 minutes
    @State private var sessionStarted = false
    @State private var timeRemaining: Double = 300
    @State private var sessionTimer: Timer? = nil
    @State private var timerExpired = false

    // Daily limit (kept for backend logic)
    private let dailyLimit = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider().opacity(0.3)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if messages.isEmpty {
                            welcomeView
                        }
                        ForEach(messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
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
        }
        .background(CalmTheme.background)
        .navigationBarHidden(true)
        .alert("Limite diário atingido", isPresented: $showLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(timerExpired
                 ? "A tua sessão de 5 minutos terminou. Volta amanhã para continuar com a Alma."
                 : "Podes enviar \(dailyLimit) mensagens por sessão. Volta amanhã para continuar.")
        }
        .alert("Autenticação necessária", isPresented: $showAuthError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authError ?? "Por favor faz login para conversar com a Alma.")
        }
        .onDisappear {
            sessionTimer?.invalidate()
            sessionTimer = nil
        }
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

            // Session countdown timer
            sessionTimerBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CalmTheme.surface)
    }

    // MARK: - Timer Badge
    private var sessionTimerBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: timerExpired ? "clock.badge.xmark" : (sessionStarted ? "clock.fill" : "clock"))
                .font(.caption)
                .foregroundColor(timerColor)
            Text(timerExpired ? "Sessão encerrada" : formatTimer(timeRemaining))
                .font(.caption.bold())
                .foregroundColor(timerColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(timerColor.opacity(0.1))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.3), value: timerExpired)
    }

    private var timerColor: Color {
        if timerExpired { return .red }
        if timeRemaining <= 60 { return .orange }
        return CalmTheme.primary
    }

    private func formatTimer(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func startSessionTimer() {
        guard !sessionStarted else { return }
        sessionStarted = true
        timeRemaining = sessionDuration
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                sessionTimer?.invalidate()
                sessionTimer = nil
                timerExpired = true
            }
        }
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

    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Fale com a Alma...", text: $inputText)
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CalmTheme.surface)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(CalmTheme.primary.opacity(0.2), lineWidth: 1)
                )

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? CalmTheme.textSecondary.opacity(0.3)
                            : CalmTheme.primary
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(CalmTheme.background)
    }

    // MARK: - Send
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if timerExpired {
            showLimitAlert = true
            return
        }

        if todayMessageCount() >= dailyLimit {
            showLimitAlert = true
            return
        }

        // Start the 5-min session timer on first message
        startSessionTimer()

        let userMsg = ChatMessage(trimmed, isUser: true)
        messages.append(userMsg)
        inputText = ""
        incrementTodayCount()

        isTyping = true
        Task {
            // Se não há utilizador autenticado, fazer login anônimo automaticamente
            if Auth.auth().currentUser == nil {
                do {
                    try await Auth.auth().signInAnonymously()
                } catch {
                    await MainActor.run {
                        isTyping = false
                        let errMsg = ChatMessage("Não foi possível conectar. Verifique sua internet e tente novamente.", isUser: false)
                        messages.append(errMsg)
                    }
                    return
                }
            }

            do {
                let reply = try await OpenAIService.shared.sendMessage(trimmed)
                let almaMsg = ChatMessage(reply, isUser: false)
                await MainActor.run {
                    isTyping = false
                    messages.append(almaMsg)
                }
            } catch AlmaError.serverError(let code) where code == 401 {
                // Token expirado — força refresh e tenta de novo
                await MainActor.run { isTyping = true }
                do {
                    if let user = Auth.auth().currentUser {
                        _ = try await user.getIDToken()
                    }
                    let retry = try await OpenAIService.shared.sendMessage(trimmed)
                    await MainActor.run {
                        isTyping = false
                        messages.append(ChatMessage(retry, isUser: false))
                    }
                } catch {
                    await MainActor.run {
                        isTyping = false
                        messages.append(ChatMessage("Sessão expirada. Feche e abra o chat novamente para continuar.", isUser: false))
                    }
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    let errMsg = ChatMessage("Não foi possível obter resposta agora. Verifique sua internet e tente novamente.", isUser: false)
                    messages.append(errMsg)
                }
            }
        }
    }

    // MARK: - Daily Limit Helpers
    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "alma_msg_count_\(f.string(from: Date()))"
    }

    private func todayMessageCount() -> Int {
        UserDefaults.standard.integer(forKey: todayKey())
    }

    private func incrementTodayCount() {
        let key = todayKey()
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }
}
