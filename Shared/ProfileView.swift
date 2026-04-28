import SwiftUI
import FirebaseAuth
import UserNotifications

// MARK: - ProfileView
struct ProfileView: View {

    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountSheet = false
    @State private var showAboutSheet = false
    @State private var showPrivacySheet = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var showNotifDeniedAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // ── Alma brand header ────────────────
                almaHeader

                // ── User info ────────────────────────
                userSection

                // ── Stats ────────────────────────────
                HStack(spacing: 16) {
                    ProfileStat(value: "\(totalMessages)", label: "Mensagens", icon: "bubble.left.fill", color: CalmTheme.primary)
                    ProfileStat(value: "\(daysActive)", label: "Dias ativos", icon: "flame.fill", color: .orange)
                }
                .padding(.horizontal, 20)

                // ── Preferências ─────────────────────
                settingsSection(title: "Preferências") {
                    notificationsRow
                    Divider().padding(.leading, 52)
                    darkModeRow
                }

                // ── Informação ───────────────────────
                settingsSection(title: "Informação") {
                    settingsRow(icon: "info.circle.fill", color: .blue, title: "Sobre a Alma", showChevron: true) {
                        showAboutSheet = true
                    }
                    Divider().padding(.leading, 52)
                    settingsRow(icon: "lock.shield.fill", color: .green, title: "Privacidade", showChevron: true) {
                        showPrivacySheet = true
                    }
                    Divider().padding(.leading, 52)
                    settingsRow(icon: "star.fill", color: CalmTheme.accent, title: "Avaliar o app", showChevron: true) {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/id") {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                // ── Conta ────────────────────────────
                settingsSection(title: "Conta") {
                    settingsRow(icon: "rectangle.portrait.and.arrow.right", color: .red, title: "Sair da conta", showChevron: false) {
                        showLogoutAlert = true
                    }
                    Divider().padding(.leading, 52)
                    settingsRow(icon: "trash.fill", color: .red, title: "Excluir minha conta", showChevron: true) {
                        showDeleteAccountSheet = true
                    }
                }

                Text("Alma v1.0.0 · Feito com ♡ no Brasil")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.bottom, 32)
            }
            .adaptiveContentWidth()
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await checkNotificationStatus() }
        .alert("Sair da conta?", isPresented: $showLogoutAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                    let uid = Auth.auth().currentUser?.uid
                    LocalDataCleanupService.clearUserData(uid: uid)
                    try? Auth.auth().signOut()
                }
        }
        .alert("Notificações bloqueadas", isPresented: $showNotifDeniedAlert) {
            Button("Abrir Configurações") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Para ativar notificações, abra as Configurações do iPhone e permita notificações para a Alma.")
        }
        .sheet(isPresented: $showDeleteAccountSheet) { DeleteAccountView() }
        .sheet(isPresented: $showAboutSheet) { AboutView() }
        .sheet(isPresented: $showPrivacySheet) { PrivacyView() }
    }

    // MARK: - Alma Brand Header
    private var almaHeader: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                AlmaLogo(size: 56)
                Text("Alma")
                    .font(.title.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("Mentora de Bem-estar")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 24)
    }

    // MARK: - User Section
    private var userSection: some View {
        VStack(spacing: 6) {
            Text(displayName)
                .font(.headline.bold())
                .foregroundColor(CalmTheme.textPrimary)
            if let email = Auth.auth().currentUser?.email, !email.isEmpty {
                Text(email)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            } else {
                Text("Conta anônima")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
    }

    // MARK: - Settings Section Container
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(CalmTheme.textSecondary)
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                content()
            }
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Notifications Row
    private var notificationsRow: some View {
        Button(action: handleNotificationsTap) {
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundColor(.red)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notificações")
                        .font(.body)
                        .foregroundColor(CalmTheme.textPrimary)
                    Text(notifStatusLabel)
                        .font(.caption)
                        .foregroundColor(notifStatusColor)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var notifStatusLabel: String {
        switch notifStatus {
        case .authorized: return "Ativadas"
        case .denied: return "Bloqueadas — toca para configurar"
        default: return "Toca para ativar"
        }
    }

    private var notifStatusColor: Color {
        switch notifStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return CalmTheme.textSecondary
        }
    }

    private func handleNotificationsTap() {
        switch notifStatus {
        case .authorized:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        case .denied:
            showNotifDeniedAlert = true
        default:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                Task { @MainActor in
                    notifStatus = granted ? .authorized : .denied
                }
            }
        }
    }

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifStatus = settings.authorizationStatus
    }

    // MARK: - Dark Mode Row
    private var darkModeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.fill")
                .font(.body)
                .foregroundColor(.indigo)
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.12))
                .cornerRadius(8)
            Text("Modo escuro")
                .font(.body)
                .foregroundColor(CalmTheme.textPrimary)
            Spacer()
            Toggle("", isOn: $isDarkMode)
                .labelsHidden()
                .tint(CalmTheme.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Generic Settings Row
    private func settingsRow(icon: String, color: Color, title: String, showChevron: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)
                Text(title)
                    .font(.body)
                    .foregroundColor(title == "Sair da conta" ? .red : CalmTheme.textPrimary)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Computed Properties
    private var displayName: String {
        Auth.auth().currentUser?.displayName ?? "Usuário"
    }

    private var totalMessages: Int {
        let d = UserDefaults.standard
        return d.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("alma_msg_count_") }
            .reduce(0) { $0 + d.integer(forKey: $1) }
    }

    private var daysActive: Int {
        UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("alma_msg_count_") }.count
    }
}

// MARK: - ProfileStat
struct ProfileStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(CalmTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(CalmTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .shadow(color: CalmTheme.primary.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

// MARK: - AboutView
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    VStack(spacing: 12) {
                        AlmaLogo(size: 80)
                        Text("Alma")
                            .font(.largeTitle.bold())
                            .foregroundColor(CalmTheme.textPrimary)
                        Text("Versão 1.0.0")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                    .padding(.top, 20)

                    aboutCard(icon: "heart.fill", color: .pink, title: "Nossa Missão",
                        body: "A Alma nasceu para ser sua companheira de bem-estar emocional. Acreditamos que cuidar da mente é tão importante quanto cuidar do corpo — e que todos merecem acesso a uma mentora empática, disponível a qualquer hora.\n\nNossa missão é democratizar o apoio emocional e tornar o mindfulness acessível a todos.")

                    aboutCard(icon: "brain.head.profile", color: CalmTheme.primary, title: "Como Funciona",
                        body: "A Alma usa inteligência artificial avançada para ouvi-la sem julgamentos. As sessões de chat são processadas de forma segura e seus dados de saúde são lidos diretamente do Apple Health — nunca saem do seu dispositivo.\n\nAs meditações guiadas e os sons terapêuticos são desenvolvidos com base em evidências científicas sobre bem-estar.")

                    aboutCard(icon: "cpu", color: .orange, title: "Tecnologia",
                        body: "Construída com SwiftUI para uma experiência nativa no iOS e Apple Watch. Integrada com HealthKit para dados de saúde em tempo real. A IA conversacional é alimentada por modelos de linguagem de última geração.\n\nTodos os dados sensíveis são criptografados e sua privacidade é nossa prioridade.")

                    aboutCard(icon: "person.2.fill", color: .green, title: "Feito com ♡",
                        body: "A Alma é desenvolvida com dedicação, por uma equipe que acredita que a tecnologia pode fazer o bem. Cada funcionalidade é pensada para genuinamente melhorar o seu bem-estar.")

                    Text("© 2026 Alma App. Todos os direitos reservados.")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
            .background(CalmTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Sobre a Alma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }.foregroundColor(CalmTheme.primary)
                }
            }
        }
    }

    private func aboutCard(icon: String, color: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.body).foregroundColor(color)
                    .frame(width: 30, height: 30).background(color.opacity(0.12)).cornerRadius(8)
                Text(title).font(.headline.bold()).foregroundColor(CalmTheme.textPrimary)
            }
            Text(body).font(.subheadline).foregroundColor(CalmTheme.textSecondary)
                .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(CalmTheme.surface).cornerRadius(CalmTheme.rMedium)
    }
}

// MARK: - PrivacyView
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 52))
                            .foregroundColor(CalmTheme.primary)
                        Text("Sua privacidade\né sagrada para nós")
                            .font(.title2.bold())
                            .foregroundColor(CalmTheme.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    privacyCard(icon: "lock.fill", color: .green, title: "Dados de Saúde",
                        body: "Seus dados do Apple Health (frequência cardíaca, sono, passos, variabilidade) são lidos diretamente no seu dispositivo e NUNCA saem do seu dispositivo. São usados exclusivamente para personalizar sua experiência dentro do app.")

                    privacyCard(icon: "bubble.left.and.bubble.right.fill", color: CalmTheme.primary, title: "Conversas com a Alma",
                        body: "As mensagens são processadas por sistemas de IA (OpenAI) sob acordo de confidencialidade. Não compartilhamos conteúdo com outros terceiros nem para publicidade. Você pode excluir o histórico a qualquer momento.")

                    privacyCard(icon: "eye.slash.fill", color: .orange, title: "Sem Publicidade",
                        body: "A Alma não contém publicidade. Não vendemos seus dados a anunciantes. Nosso modelo de negócio baseia-se apenas nas assinaturas — o que significa que nossos interesses estão sempre alinhados com os seus.")

                    privacyCard(icon: "icloud.and.arrow.down", color: .blue, title: "Armazenamento e Segurança",
                        body: "Os dados da conta são armazenados criptografados. Usamos Firebase Authentication com conexões seguras. Seus dados biométricos nunca saem do seu dispositivo Apple — processados localmente pelo iOS.")

                    privacyCard(icon: "hand.raised.fill", color: .red, title: "Seus Direitos (Proteção de Dados)",
                        body: "Você tem direito a acessar, corrigir ou excluir todos os dados pessoais que temos sobre você. Para exercer esses direitos, entre em contato em privacidade@almaapp.pt. Responderemos em até 30 dias úteis, conforme a LGPD e o RGPD.")

                    VStack(spacing: 4) {
                        Text("Política de Privacidade completa em")
                            .font(.caption).foregroundColor(CalmTheme.textSecondary)
                        Text("almaapp.pt/privacidade")
                            .font(.caption.bold()).foregroundColor(CalmTheme.primary)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
            .background(CalmTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Privacidade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { dismiss() }.foregroundColor(CalmTheme.primary)
                }
            }
        }
    }

    private func privacyCard(icon: String, color: Color, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.body).foregroundColor(color)
                    .frame(width: 30, height: 30).background(color.opacity(0.12)).cornerRadius(8)
                Text(title).font(.subheadline.bold()).foregroundColor(CalmTheme.textPrimary)
            }
            Text(body).font(.caption).foregroundColor(CalmTheme.textSecondary)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14).background(CalmTheme.surface).cornerRadius(CalmTheme.rMedium)
    }
}

