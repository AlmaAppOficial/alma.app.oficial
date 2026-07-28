// FeminineHealthView.swift
// Alma App — Saúde Feminina (ciclo menstrual + gravidez)
// Aparece apenas para utilizadoras identificadas como mulheres
//
// [Build 84 — 2026-07-28] Refatorada para usar o CycleCalculator (motor puro
// e testado). Correções e novidades:
//   • Dia do ciclo em dias de calendário, sem "dar a volta" quando atrasa
//   • Duração da menstruação configurável (antes: 5 dias fixos)
//   • Previsão pela média dos últimos ciclos registrados (quando houver
//     histórico), com faixa de variação e selo Regular/Irregular
//   • Histórico de ciclos + registro de sintomas do dia
//   • Estado vazio honesto (antes mostrava "Dia 1 de 28" sem dado nenhum)
//   • Aviso: estimativas de autoconhecimento, não contracepção/diagnóstico

import SwiftUI

struct FeminineHealthView: View {

    // Dados sensíveis de saúde — persistidos no Keychain via FeminineHealthSecureStore
    // (migração transparente do UserDefaults legado na primeira leitura)
    @State private var lastPeriodTimestamp: Double = 0
    @State private var cycleLength: Int = 28
    @State private var periodLength: Int = 5
    @State private var periodHistory: [Double] = []
    @State private var symptomsToday: Set<String> = []
    @State private var pregnancyMode: Bool = false
    @State private var dueDateTimestamp: Double = 0

    @State private var showCyclePicker = false
    @State private var showPregnancyPicker = false
    @State private var showCycleLengthPicker = false
    @State private var showPeriodLengthPicker = false
    @State private var tempDate = Date()

    private let pink = Color(red: 0.90, green: 0.45, blue: 0.65)
    private let softPink = Color(red: 0.98, green: 0.90, blue: 0.94)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // Header
                headerSection

                if pregnancyMode {
                    // Modo gravidez
                    pregnancySection
                } else if lastPeriodTimestamp <= 0 {
                    // Sem registro ainda — não inventa "Dia 1"
                    emptyStateSection
                } else {
                    // Modo ciclo menstrual
                    cycleSection
                    fertilitySection
                    statsSection
                    symptomSection
                    historySection
                    settingsSection
                }

                // Toggle modo
                modeToggle

                if !pregnancyMode {
                    disclaimerFootnote
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Saúde Feminina")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadSecureData() }
        .onChange(of: pregnancyMode) { newValue in
            FeminineHealthSecureStore.pregnancyMode = newValue
        }
        .onChange(of: cycleLength) { newValue in
            FeminineHealthSecureStore.cycleLength = newValue
        }
        .onChange(of: periodLength) { newValue in
            FeminineHealthSecureStore.periodLength = newValue
        }
    }

    // MARK: - Secure Store
    private func loadSecureData() {
        lastPeriodTimestamp = FeminineHealthSecureStore.lastPeriodTimestamp
        cycleLength = FeminineHealthSecureStore.cycleLength
        periodLength = FeminineHealthSecureStore.periodLength
        periodHistory = FeminineHealthSecureStore.periodHistory
        pregnancyMode = FeminineHealthSecureStore.pregnancyMode
        dueDateTimestamp = FeminineHealthSecureStore.dueDateTimestamp
        symptomsToday = Set(FeminineHealthSecureStore.symptomsByDay[todayKey] ?? [])
    }

    /// Registra um início de menstruação: atualiza histórico + último início.
    private func registerPeriodStart(_ date: Date) {
        let dates = CycleCalculator.updatedHistory(historyDates, adding: date)
        periodHistory = dates.map { $0.timeIntervalSince1970 }
        FeminineHealthSecureStore.periodHistory = periodHistory
        if let latest = dates.last {
            lastPeriodTimestamp = latest.timeIntervalSince1970
            FeminineHealthSecureStore.lastPeriodTimestamp = lastPeriodTimestamp
        }
    }

    // MARK: - Dados derivados (via CycleCalculator)

    private var historyDates: [Date] {
        periodHistory.map { Date(timeIntervalSince1970: $0) }
    }

    /// Duração efetiva do ciclo: média dos últimos ciclos registrados quando
    /// houver histórico; senão, o valor manual configurado.
    private var effectiveCycleLength: Int {
        CycleCalculator.averageCycleLength(history: historyDates) ?? cycleLength
    }

    private var completedCycleCount: Int {
        CycleCalculator.cycleLengths(history: historyDates).count
    }

    private var snapshot: CycleSnapshot {
        CycleCalculator.snapshot(
            lastPeriodStart: Date(timeIntervalSince1970: lastPeriodTimestamp),
            cycleLength: effectiveCycleLength,
            periodLength: periodLength,
            today: Date()
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(pink.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: "figure.stand.dress")
                    .font(.system(size: 26))
                    .foregroundColor(pink)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(pregnancyMode ? "Gravidez" : "Ciclo Menstrual")
                    .font(.title3.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text(pregnancyMode ? "Acompanhe sua jornada" : "Conheça seu corpo")
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Estado vazio [Build 84]
    private var emptyStateSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "drop.circle")
                .font(.system(size: 44))
                .foregroundColor(pink)
            Text("Vamos começar?")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)
            Text("Registre o primeiro dia da sua última menstruação para ver previsões do ciclo, ovulação e janela fértil.")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                tempDate = Date()
                showCyclePicker = true
            } label: {
                Label("Registrar início da menstruação", systemImage: "drop.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(pink)
                    .foregroundColor(.white)
                    .cornerRadius(CalmTheme.rSmall)
            }
        }
        .padding(20)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .sheet(isPresented: $showCyclePicker) { periodDateSheet }
    }

    // MARK: - Cycle Section
    private var cycleSection: some View {
        let snap = snapshot
        let length = effectiveCycleLength
        let phase = phaseInfo(snap.phase)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Ciclo Atual")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            HStack(spacing: 0) {
                ForEach(0..<length, id: \.self) { day in
                    let d = day + 1
                    Circle()
                        .fill(dayColor(day: d, snap: snap, length: length))
                        .frame(height: 8)
                        .overlay(
                            Circle().stroke(
                                (d == snap.day && !snap.isLate) ? pink : Color.clear,
                                lineWidth: 2
                            )
                        )
                }
            }
            .padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dia \(snap.day)\(snap.isLate ? "" : " de \(length)")")
                        .font(.title2.bold())
                        .foregroundColor(pink)
                    if snap.isLate {
                        Text("Atraso de \(snap.daysLate) \(snap.daysLate == 1 ? "dia" : "dias")")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                        Text("Atrasos acontecem — estresse, sono e rotina influenciam.")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    } else {
                        Text(phase.name)
                            .font(.caption.bold())
                            .foregroundColor(phase.color)
                        Text(phase.description)
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Próxima menstruação")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                    Text(nextPeriodText(snap))
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
            }

            Button {
                tempDate = Date()
                showCyclePicker = true
            } label: {
                Label("Registrar início da menstruação", systemImage: "drop.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(pink.opacity(0.1))
                    .foregroundColor(pink)
                    .cornerRadius(CalmTheme.rSmall)
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .shadow(color: pink.opacity(0.08), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showCyclePicker) { periodDateSheet }
    }

    private var periodDateSheet: some View {
        DatePickerSheet(title: "Início da menstruação", date: $tempDate, maxDate: Date()) {
            registerPeriodStart(tempDate)
        }
    }

    // MARK: - Fertility Window
    private var fertilitySection: some View {
        let snap = snapshot
        let isFertile = !snap.isLate && snap.fertileWindow.contains(snap.day)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundColor(isFertile ? Color.orange : CalmTheme.textSecondary)
                Text("Janela Fértil")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Spacer()
                if isFertile {
                    Text("AGORA")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }

            Text("Ovulação prevista: dia \(snap.ovulationDay) do ciclo")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
            Text("Período fértil: dias \(snap.fertileWindow.lowerBound) – \(snap.fertileWindow.upperBound)")
                .font(.caption)
                .foregroundColor(CalmTheme.textSecondary)
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Meus ciclos (estatísticas) [Build 84]
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meus Ciclos")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            if completedCycleCount == 0 {
                Text("Registre as próximas menstruações para ver a duração média e a regularidade dos seus ciclos.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
            } else {
                statRow(
                    title: "Duração média do ciclo",
                    value: "\(effectiveCycleLength) dias",
                    badge: CycleCalculator.normalCycleRange.contains(effectiveCycleLength)
                        ? ("NORMAL", .green) : ("ATÍPICO", .orange)
                )
                Divider().opacity(0.4)
                statRow(
                    title: "Duração da menstruação",
                    value: "\(periodLength) dias",
                    badge: CycleCalculator.normalPeriodRange.contains(periodLength)
                        ? ("NORMAL", .green) : ("ATÍPICA", .orange)
                )
                if let range = CycleCalculator.cycleLengthRange(history: historyDates) {
                    Divider().opacity(0.4)
                    statRow(
                        title: "Variação entre ciclos",
                        value: range.lowerBound == range.upperBound
                            ? "\(range.lowerBound) dias"
                            : "\(range.lowerBound)–\(range.upperBound) dias",
                        badge: CycleCalculator.isRegular(range: range)
                            ? ("REGULAR", .green) : ("IRREGULAR", .orange)
                    )
                }
                Text("Base: seus últimos \(min(completedCycleCount, 6)) \(completedCycleCount == 1 ? "ciclo completo" : "ciclos completos") registrados.")
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    private func statRow(title: String, value: String, badge: (String, Color)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: badge.1 == .green ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.caption2)
                Text(badge.0)
                    .font(.caption2.bold())
            }
            .foregroundColor(badge.1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(badge.1.opacity(0.12))
            .cornerRadius(8)
        }
    }

    // MARK: - Sintomas de hoje [Build 84]
    private static let symptomOptions: [(id: String, label: String)] = [
        ("colica", "Cólica"),
        ("dor_cabeca", "Dor de cabeça"),
        ("inchaco", "Inchaço"),
        ("sensibilidade", "Sensibilidade"),
        ("humor_instavel", "Humor instável"),
        ("energia_baixa", "Energia baixa"),
        ("fluxo_intenso", "Fluxo intenso"),
        ("fluxo_leve", "Fluxo leve"),
    ]

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private var symptomSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Como você está hoje?")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            FlowChips(
                options: Self.symptomOptions,
                selected: symptomsToday,
                accent: pink
            ) { id in
                if symptomsToday.contains(id) {
                    symptomsToday.remove(id)
                } else {
                    symptomsToday.insert(id)
                }
                var all = FeminineHealthSecureStore.symptomsByDay
                if symptomsToday.isEmpty {
                    all.removeValue(forKey: todayKey)
                } else {
                    all[todayKey] = Array(symptomsToday).sorted()
                }
                FeminineHealthSecureStore.symptomsByDay = all
            }

            if !symptomsToday.isEmpty {
                Text("Registrado — isso fica só no seu aparelho.")
                    .font(.caption2)
                    .foregroundColor(CalmTheme.textSecondary)
            }
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Histórico [Build 84]
    private var historySection: some View {
        let dates = historyDates.sorted()
        let lengths = CycleCalculator.cycleLengths(history: dates)

        return Group {
            if lengths.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Histórico")
                        .font(.headline)
                        .foregroundColor(CalmTheme.textPrimary)

                    // Ciclo atual (em andamento)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ciclo atual: \(snapshot.day) \(snapshot.day == 1 ? "dia" : "dias")")
                                .font(.subheadline.bold())
                                .foregroundColor(CalmTheme.textPrimary)
                            Text("Começou em \(shortDate(Date(timeIntervalSince1970: lastPeriodTimestamp)))")
                                .font(.caption)
                                .foregroundColor(CalmTheme.textSecondary)
                        }
                        Spacer()
                    }

                    // Ciclos completos (mais recente primeiro)
                    ForEach(Array(completedCycles(dates: dates).enumerated()), id: \.offset) { _, cycle in
                        Divider().opacity(0.4)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(cycle.length) dias")
                                    .font(.subheadline.bold())
                                    .foregroundColor(CalmTheme.textPrimary)
                                Text("\(shortDate(cycle.start)) – \(shortDate(cycle.end))")
                                    .font(.caption)
                                    .foregroundColor(CalmTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(CalmTheme.surface)
                .cornerRadius(CalmTheme.rMedium)
            }
        }
    }

    private struct CompletedCycle {
        let start: Date
        let end: Date
        let length: Int
    }

    /// Ciclos completos (par de inícios consecutivos), mais recentes primeiro, máx. 6.
    private func completedCycles(dates: [Date]) -> [CompletedCycle] {
        guard dates.count >= 2 else { return [] }
        var result: [CompletedCycle] = []
        let calendar = Calendar.current
        for i in stride(from: dates.count - 1, through: 1, by: -1) {
            let start = dates[i - 1]
            let nextStart = dates[i]
            let length = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: start),
                to: calendar.startOfDay(for: nextStart)
            ).day ?? 0
            guard (15...120).contains(length) else { continue }
            let end = calendar.date(byAdding: .day, value: -1, to: nextStart) ?? nextStart
            result.append(CompletedCycle(start: start, end: end, length: length))
            if result.count >= 6 { break }
        }
        return result
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMM"
        return f.string(from: date)
    }

    // MARK: - Ajustes [Build 84]
    private var settingsSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duração do ciclo")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text(completedCycleCount > 0
                         ? "Média automática: \(effectiveCycleLength) dias · manual: \(cycleLength)"
                         : "\(cycleLength) dias")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Spacer()
                Button {
                    showCycleLengthPicker = true
                } label: {
                    Text("Ajustar")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(pink.opacity(0.12))
                        .foregroundColor(pink)
                        .cornerRadius(8)
                }
            }
            .padding(16)

            Divider().opacity(0.4).padding(.horizontal, 16)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duração da menstruação")
                        .font(.subheadline.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("\(periodLength) dias")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Spacer()
                Button {
                    showPeriodLengthPicker = true
                } label: {
                    Text("Ajustar")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(pink.opacity(0.12))
                        .foregroundColor(pink)
                        .cornerRadius(8)
                }
            }
            .padding(16)
        }
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .sheet(isPresented: $showCycleLengthPicker) {
            CycleLengthPickerSheet(cycleLength: $cycleLength)
        }
        .sheet(isPresented: $showPeriodLengthPicker) {
            PeriodLengthPickerSheet(periodLength: $periodLength)
        }
    }

    private var disclaimerFootnote: some View {
        Text("As previsões são estimativas para autoconhecimento e podem variar. Não use como método contraceptivo nem como diagnóstico — em caso de dúvida, procure seu médico.")
            .font(.caption2)
            .foregroundColor(CalmTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    // MARK: - Pregnancy Section
    private var pregnancySection: some View {
        let weeks = pregnancyWeeks
        let daysRemaining = daysUntilDueDate

        return VStack(spacing: 14) {
            // Semanas
            VStack(spacing: 8) {
                Text("\(weeks)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(pink)
                Text("semanas de gravidez")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                if daysRemaining > 0 {
                    Text("Faltam \(daysRemaining) dias para o parto previsto")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
            }
            .padding(20)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)

            // Progresso trimestre — [Build 84] boundaries alinhados ao texto
            let trimester = CycleCalculator.trimester(weeks: weeks)
            VStack(alignment: .leading, spacing: 8) {
                Text("Trimestre \(trimester)")
                    .font(.headline)
                    .foregroundColor(CalmTheme.textPrimary)
                Text(trimesterDescription(trimester))
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineSpacing(4)
            }
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)

            // DPP
            Button {
                tempDate = dueDateTimestamp > 0
                    ? Date(timeIntervalSince1970: dueDateTimestamp)
                    : (Calendar.current.date(byAdding: .day, value: 280, to: Date()) ?? Date())
                showPregnancyPicker = true
            } label: {
                Label("Definir data prevista do parto", systemImage: "calendar.badge.plus")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(pink.opacity(0.1))
                    .foregroundColor(pink)
                    .cornerRadius(CalmTheme.rSmall)
            }
        }
        .sheet(isPresented: $showPregnancyPicker) {
            DatePickerSheet(title: "Data Prevista do Parto", date: $tempDate) {
                dueDateTimestamp = tempDate.timeIntervalSince1970
                FeminineHealthSecureStore.dueDateTimestamp = dueDateTimestamp
            }
        }
    }

    // MARK: - Mode Toggle
    private var modeToggle: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $pregnancyMode) {
                HStack(spacing: 10) {
                    Image(systemName: pregnancyMode ? "figure.maternity" : "arrow.2.circlepath")
                        .foregroundColor(pink)
                        .frame(width: 32, height: 32)
                        .background(pink.opacity(0.1))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pregnancyMode ? "Modo Gravidez" : "Ativar modo Gravidez")
                            .font(.subheadline)
                            .foregroundColor(CalmTheme.textPrimary)
                        Text(pregnancyMode ? "Acompanhando sua gravidez" : "Mude para acompanhamento gestacional")
                            .font(.caption)
                            .foregroundColor(CalmTheme.textSecondary)
                    }
                }
            }
            .tint(pink)
            .padding(16)
            .background(CalmTheme.surface)
            .cornerRadius(CalmTheme.rMedium)
        }
    }

    // MARK: - Helpers

    private func nextPeriodText(_ snap: CycleSnapshot) -> String {
        let days = snap.daysUntilNextPeriod
        if days == 0 { return "Hoje" }
        if days == 1 { return "Amanhã" }
        if days <= 7 { return "em \(days) dias" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: snap.nextPeriodDate)
    }

    private var pregnancyWeeks: Int {
        guard dueDateTimestamp > 0 else { return 0 }
        return CycleCalculator.gestationalWeeks(
            dueDate: Date(timeIntervalSince1970: dueDateTimestamp),
            today: Date()
        )
    }

    private var daysUntilDueDate: Int {
        guard dueDateTimestamp > 0 else { return 0 }
        let dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }

    private func dayColor(day: Int, snap: CycleSnapshot, length: Int) -> Color {
        if day <= min(periodLength, length) { return Color.red.opacity(0.6) }
        if snap.fertileWindow.contains(day) { return Color.orange.opacity(0.5) }
        if day == snap.day && !snap.isLate { return pink }
        if day < snap.day { return pink.opacity(0.3) }
        return CalmTheme.primary.opacity(0.1)
    }

    private struct PhaseInfo {
        let name: String
        let color: Color
        let description: String
    }

    private func phaseInfo(_ kind: CyclePhaseKind) -> PhaseInfo {
        switch kind {
        case .menstrual:
            return PhaseInfo(name: "Menstruação", color: .red, description: "Repouso e autocuidado")
        case .follicular:
            return PhaseInfo(name: "Fase Folicular", color: Color.blue, description: "Energia crescente, criatividade")
        case .ovulation:
            return PhaseInfo(name: "Ovulação", color: .orange, description: "Pico de energia e vitalidade")
        case .luteal:
            return PhaseInfo(name: "Fase Lútea", color: CalmTheme.primary, description: "Introspecção e reflexão")
        }
    }

    private func trimesterDescription(_ trimester: Int) -> String {
        switch trimester {
        case 1: return "1º Trimestre (semanas 1–13): O bebê está desenvolvendo todos os órgãos principais. Você pode sentir náuseas e cansaço — é completamente normal."
        case 2: return "2º Trimestre (semanas 14–27): O período mais confortável para muitas mulheres. O bebê começa a se mexer e já pode ouvir a sua voz."
        default: return "3º Trimestre (semanas 28–40): A fase final. O bebê está ganhando peso e se preparando para o nascimento. Descanse sempre que puder."
        }
    }
}

// MARK: - Chips de sintomas [Build 84]
private struct FlowChips: View {
    let options: [(id: String, label: String)]
    let selected: Set<String>
    let accent: Color
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.id) { option in
                let isOn = selected.contains(option.id)
                Button {
                    onTap(option.id)
                } label: {
                    Text(option.label)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(isOn ? accent.opacity(0.18) : CalmTheme.primary.opacity(0.05))
                        .foregroundColor(isOn ? accent : CalmTheme.textSecondary)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isOn ? accent.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date
    var maxDate: Date? = nil
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // [Build 84] Menstruação não pode começar no futuro (maxDate);
                // a DPP continua livre.
                if let maxDate {
                    DatePicker(title, selection: $date, in: ...maxDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color(red: 0.90, green: 0.45, blue: 0.65))
                        .padding()
                } else {
                    DatePicker(title, selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color(red: 0.90, green: 0.45, blue: 0.65))
                        .padding()
                }
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        onConfirm()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Cycle Length Picker
struct CycleLengthPickerSheet: View {
    @Binding var cycleLength: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Picker("Duração do ciclo", selection: $cycleLength) {
                    ForEach(14...90, id: \.self) { days in
                        Text("\(days) dias").tag(days)
                    }
                }
                .pickerStyle(.wheel)

                if cycleLength < 21 || cycleLength > 40 {
                    Text("Ciclo atípico — considere conversar com seu médico.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Duração do Ciclo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Period Length Picker [Build 84]
struct PeriodLengthPickerSheet: View {
    @Binding var periodLength: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Picker("Duração da menstruação", selection: $periodLength) {
                    ForEach(1...10, id: \.self) { days in
                        Text("\(days) \(days == 1 ? "dia" : "dias")").tag(days)
                    }
                }
                .pickerStyle(.wheel)

                if periodLength < 3 || periodLength > 7 {
                    Text("Fora da faixa típica (3–7 dias) — considere conversar com seu médico.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Duração da Menstruação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { dismiss() }
                }
            }
        }
    }
}
