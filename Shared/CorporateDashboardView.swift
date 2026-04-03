import SwiftUI
import Charts

/// Corporate Dashboard for HR Administrators
/// All data is ANONYMOUS and AGGREGATED - no individual employee data visible
/// Features: engagement metrics, department breakdowns, stress alerts, user management, PDF export
struct CorporateDashboardView: View {
    @StateObject private var viewModel = CorporateDashboardViewModel()
    @State private var selectedTab: DashboardTab = .overview
    @State private var showingDateRangePicker = false
    @State private var showingExportOptions = false
    @Environment(\.colorScheme) var colorScheme

    enum DashboardTab: String, CaseIterable {
        case overview = "Visão Geral"
        case departments = "Departamentos"
        case trends = "Tendências"
        case alerts = "Alertas"
        case users = "Usuários"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    corporateHeaderView

                    // Tabs
                    tabNavigationView

                    // Content
                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewTabView
                        case .departments:
                            departmentsTabView
                        case .trends:
                            trendsTabView
                        case .alerts:
                            alertsTabView
                        case .users:
                            usersTabView
                        }
                    }
                    .transition(.opacity)

                    Spacer()
                }
            }
            .navigationTitle("Alma Empresas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingExportOptions = true }) {
                            Label("Exportar Relatório", systemImage: "arrow.down.doc")
                        }
                        Button(action: { viewModel.refresh() }) {
                            Label("Atualizar", systemImage: "arrow.clockwise")
                        }
                        Button(action: { /* settings */ }) {
                            Label("Configurações", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            exportOptionsSheet
        }
    }

    // MARK: - Header View

    var corporateHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bem-vindo, \(viewModel.adminName)")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(viewModel.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { viewModel.logout() }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding()

            Divider()
                .padding(.horizontal)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Tab Navigation

    var tabNavigationView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selectedTab == tab ? .purple : .secondary)

                            if selectedTab == tab {
                                Capsule()
                                    .frame(height: 3)
                                    .foregroundStyle(.purple)
                            }
                        }
                        .frame(height: 44)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGray6))
    }

    // MARK: - Overview Tab

    var overviewTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Key Metrics Row 1
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Taxa de Engajamento",
                        value: viewModel.engagementRate,
                        unit: "%",
                        icon: "chart.bar.fill",
                        color: .blue,
                        subtitle: "Colaboradores ativos"
                    )

                    MetricCard(
                        title: "Sessões/Semana",
                        value: String(format: "%.1f", viewModel.avgSessionsPerWeek),
                        unit: "média",
                        icon: "meditation",
                        color: .purple,
                        subtitle: "Por colaborador"
                    )
                }

                // Key Metrics Row 2
                HStack(spacing: 12) {
                    MetricCard(
                        title: "Tempo Total",
                        value: viewModel.totalMeditationTime,
                        unit: "horas",
                        icon: "hourglass.bottomhalf.fill",
                        color: .green,
                        subtitle: "Consumo agregado"
                    )

                    MetricCard(
                        title: "Streak Médio",
                        value: String(viewModel.avgStreak),
                        unit: "dias",
                        icon: "flame.fill",
                        color: .orange,
                        subtitle: "Frequência de uso"
                    )
                }

                Divider()
                    .padding(.vertical, 8)

                // Stress Alert Banner (if needed)
                if viewModel.hasStressAlert {
                    stressAlertBanner
                }

                // Top Categories
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Meditações Mais Populares")
                            .font(.headline)
                        Spacer()
                        Text("Top 5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        ForEach(viewModel.topCategories, id: \.id) { category in
                            HStack {
                                Text(category.name)
                                    .font(.system(.body, design: .default))
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(category.count) sessões")
                                        .font(.system(.caption, design: .default))
                                        .foregroundStyle(.secondary)
                                    GeometryReader { geo in
                                        RoundedRectangle(cornerRadius: 4)
                                            .foregroundStyle(.purple.opacity(0.3))
                                            .overlay(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .foregroundStyle(.purple)
                                                    .frame(width: geo.size.width * CGFloat(category.percentage / 100))
                                            }
                                    }
                                    .frame(height: 6)
                                }
                                .frame(width: 100)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

                // Engagement Distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text("Distribuição de Streaks")
                        .font(.headline)

                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(viewModel.streakDistribution, id: \.range) { item in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .foregroundStyle(.purple.opacity(0.8))
                                    .frame(height: CGFloat(item.count * 2))

                                Text(item.range)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 150)

                    HStack(spacing: 16) {
                        Label("\(viewModel.totalActiveUsers) colaboradores ativos",
                              systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    // MARK: - Departments Tab

    var departmentsTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(viewModel.departmentMetrics, id: \.id) { dept in
                    departmentCard(for: dept)
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    func departmentCard(for dept: DepartmentMetric) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dept.name)
                        .font(.headline)
                    Text("\(dept.userCount) colaboradores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(dept.engagementRate)%")
                    .font(.system(.headline, design: .default))
                    .foregroundStyle(.purple)
            }

            Divider()

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessões/Semana")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", dept.avgSessionsPerWeek))
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tempo Médio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(dept.avgTimePerSession) min")
                        .font(.headline)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Streak Médio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(dept.avgStreak) dias")
                        .font(.headline)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Trends Tab

    var trendsTabView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Weekly Trend Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tendência de Engajamento (Últimas 12 Semanas)")
                        .font(.headline)

                    Chart(viewModel.weeklyTrends, id: \.week) { data in
                        LineMark(
                            x: .value("Semana", data.week),
                            y: .value("Engajamento %", data.engagementRate)
                        )
                        .foregroundStyle(.purple)

                        PointMark(
                            x: .value("Semana", data.week),
                            y: .value("Engajamento %", data.engagementRate)
                        )
                        .foregroundStyle(.purple)
                    }
                    .frame(height: 200)
                    .chartYScale(domain: [0, 100])
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

                // Monthly Sessions Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sessões por Mês (Últimos 3 Meses)")
                        .font(.headline)

                    Chart(viewModel.monthlySessions, id: \.month) { data in
                        BarMark(
                            x: .value("Mês", data.month),
                            y: .value("Sessões", data.sessionCount)
                        )
                        .foregroundStyle(.purple.opacity(0.6))
                    }
                    .frame(height: 200)
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )

                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    // MARK: - Alerts Tab

    var alertsTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.momentoDeAlertaItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)

                        Text("Tudo bem por aqui!")
                            .font(.headline)

                        Text("Nenhum indicador de alerta detectado. Seu time está em bom estado.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(viewModel.momentoDeAlertaItems, id: \.id) { alert in
                        momentoDeAlertaCard(for: alert)
                    }
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    func momentoDeAlertaCard(for alert: MomentoDeAlerta) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: alert.severity == .high ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(alert.severity == .high ? .red : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                    Text(alert.timeDetected)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            Text(alert.description)
                .font(.body)
                .foregroundStyle(.primary)

            if let recommendation = alert.recommendation {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Recomendação", systemImage: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text(recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(alert.severity == .high ? Color.red.opacity(0.05) : Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(alert.severity == .high ? Color.red.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Users Tab

    var usersTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Import Users Section
                Button(action: { viewModel.showingCSVImport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Importar Usuários (CSV)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.purple)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }

                // Send Invites Section
                Button(action: { viewModel.showingSendInvites = true }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Enviar Convites por Email")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundStyle(.purple)
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }

                Divider()
                    .padding(.vertical, 8)

                // Users List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Usuários Convidados")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.invitedUsers.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.invitedUsers, id: \.id) { user in
                        userRowView(for: user)
                    }
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
    }

    func userRowView(for user: InvitedUser) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.purple.opacity(0.6))

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(user.status.displayName)
                    .font(.caption)
                    .foregroundStyle(user.status == .active ? .green : .secondary)

                if !user.inviteSentDate.isEmpty {
                    Text(user.inviteSentDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Stress Alert Banner

    var stressAlertBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text("Momento de Alerta Detectado")
                    .font(.headline)
                    .foregroundStyle(.red)

                Text("Padrões agregados sugerem aumento de estresse. Considere enviar conteúdo temático.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { selectedTab = .alerts }) {
                Text("Ver")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Export Options Sheet

    var exportOptionsSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Formato de Exportação")
                    .font(.headline)

                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.exportPDF()
                        showingExportOptions = false
                    }) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.red)
                            Text("Exportar como PDF")
                            Spacer()
                            Image(systemName: "arrow.down")
                        }
                        .foregroundStyle(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        viewModel.exportCSV()
                        showingExportOptions = false
                    }) {
                        HStack {
                            Image(systemName: "tablecells")
                                .foregroundStyle(.green)
                            Text("Exportar como CSV")
                            Spacer()
                            Image(systemName: "arrow.down")
                        }
                        .foregroundStyle(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto") {
                        showingExportOptions = false
                    }
                }
            }
        }
    }
}

// MARK: - Metric Card Component

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundStyle(color)

                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color.opacity(0.5))
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Models & Data Models

@MainActor
class CorporateDashboardViewModel: ObservableObject {
    @Published var adminName = "Maria"
    @Published var companyName = "Tech Corp Brasil"
    @Published var engagementRate = 67
    @Published var avgSessionsPerWeek = 2.3
    @Published var totalMeditationTime = "1,240"
    @Published var avgStreak = 8
    @Published var totalActiveUsers = 125
    @Published var hasStressAlert = true

    @Published var topCategories: [CategoryMetric] = [
        .init(id: "1", name: "Foco & Produtividade", count: 450, percentage: 28),
        .init(id: "2", name: "Ansiedade & Estresse", count: 380, percentage: 24),
        .init(id: "3", name: "Sono Melhor", count: 320, percentage: 20),
        .init(id: "4", name: "Meditação para Liderança", count: 220, percentage: 14),
        .init(id: "5", name: "Inteligência Emocional", count: 190, percentage: 12),
    ]

    @Published var streakDistribution: [StreakRange] = [
        .init(range: "1-3 dias", count: 15),
        .init(range: "4-7 dias", count: 32),
        .init(range: "8-14 dias", count: 45),
        .init(range: "15-30 dias", count: 28),
        .init(range: "30+ dias", count: 5),
    ]

    @Published var departmentMetrics: [DepartmentMetric] = [
        .init(id: "1", name: "Tecnologia", userCount: 45, engagementRate: 75, avgSessionsPerWeek: 2.8, avgTimePerSession: 12, avgStreak: 10),
        .init(id: "2", name: "Recursos Humanos", userCount: 12, engagementRate: 92, avgSessionsPerWeek: 3.5, avgTimePerSession: 14, avgStreak: 15),
        .init(id: "3", name: "Financeiro", userCount: 28, engagementRate: 54, avgSessionsPerWeek: 1.9, avgTimePerSession: 10, avgStreak: 5),
        .init(id: "4", name: "Marketing", userCount: 18, engagementRate: 78, avgSessionsPerWeek: 2.6, avgTimePerSession: 11, avgStreak: 9),
        .init(id: "5", name: "Operações", userCount: 22, engagementRate: 61, avgSessionsPerWeek: 2.1, avgTimePerSession: 10, avgStreak: 6),
    ]

    @Published var weeklyTrends: [WeeklyTrend] = (1...12).map { week in
        let baseRate = 60 + Int.random(in: -10...15)
        return .init(week: "S\(week)", engagementRate: Double(baseRate))
    }

    @Published var monthlySessions: [MonthlySessions] = [
        .init(month: "Janeiro", sessionCount: 1200),
        .init(month: "Fevereiro", sessionCount: 1450),
        .init(month: "Março", sessionCount: 1680),
    ]

    @Published var momentoDeAlertaItems: [MomentoDeAlerta] = [
        .init(
            id: "1",
            title: "Queda em Engajamento - Departamento Financeiro",
            description: "Redução de 35% em sessões na última semana comparado à média histórica.",
            severity: .high,
            timeDetected: "Detectado há 2 dias",
            recommendation: "Considere enviar conteúdo sobre 'Gestão de Estresse Financeiro' ou agendar check-in com liderança do departamento."
        ),
        .init(
            id: "2",
            title: "Aumento em Meditações de Ansiedade",
            description: "60% crescimento em acessos a conteúdo de ansiedade nos últimos 3 dias.",
            severity: .medium,
            timeDetected: "Detectado há 1 dia",
            recommendation: "Considere promover meditações de alívio rápido ou enviar dica de bem-estar coletiva."
        ),
    ]

    @Published var invitedUsers: [InvitedUser] = [
        .init(id: "1", name: "Ana Silva", email: "ana.silva@techcorp.com", status: .active, inviteSentDate: "2 mar"),
        .init(id: "2", name: "Bruno Costa", email: "bruno.costa@techcorp.com", status: .active, inviteSentDate: "2 mar"),
        .init(id: "3", name: "Carolina Santos", email: "carolina@techcorp.com", status: .pending, inviteSentDate: "5 mar"),
        .init(id: "4", name: "Diego Oliveira", email: "diego@techcorp.com", status: .active, inviteSentDate: "1 mar"),
    ]

    @Published var showingCSVImport = false
    @Published var showingSendInvites = false

    func refresh() {
        // Refresh data from backend
    }

    func logout() {
        // Handle logout
    }

    func exportPDF() {
        // Generate and export PDF report
        print("Exporting PDF...")
    }

    func exportCSV() {
        // Generate and export CSV report
        print("Exporting CSV...")
    }
}

// MARK: - Data Models

struct CategoryMetric: Identifiable {
    let id: String
    let name: String
    let count: Int
    let percentage: Double
}

struct StreakRange: Identifiable {
    let id = UUID()
    let range: String
    let count: Int
}

struct DepartmentMetric: Identifiable {
    let id: String
    let name: String
    let userCount: Int
    let engagementRate: Int
    let avgSessionsPerWeek: Double
    let avgTimePerSession: Int
    let avgStreak: Int
}

struct WeeklyTrend: Identifiable {
    let id = UUID()
    let week: String
    let engagementRate: Double
}

struct MonthlySessions: Identifiable {
    let id = UUID()
    let month: String
    let sessionCount: Int
}

enum AlertSeverity {
    case high
    case medium
}

struct MomentoDeAlerta: Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: AlertSeverity
    let timeDetected: String
    let recommendation: String?
}

enum UserStatus {
    case active
    case pending

    var displayName: String {
        switch self {
        case .active:
            return "Ativo"
        case .pending:
            return "Pendente"
        }
    }
}

struct InvitedUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let status: UserStatus
    let inviteSentDate: String
}

#Preview {
    CorporateDashboardView()
}
