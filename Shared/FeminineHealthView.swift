// FeminineHealthView.swift
// Alma App — Saúde Feminina (ciclo menstrual + gravidez)
// Aparece apenas para utilizadoras identificadas como mulheres

import SwiftUI

struct FeminineHealthView: View {

    @AppStorage("alma_cycle_lastPeriod") private var lastPeriodTimestamp: Double = 0
    @AppStorage("alma_cycle_length") private var cycleLength: Int = 28
    @AppStorage("alma_pregnancy_mode") private var pregnancyMode: Bool = false
    @AppStorage("alma_pregnancy_dueDate") private var dueDateTimestamp: Double = 0

    @State private var showCyclePicker = false
    @State private var showPregnancyPicker = false
    @State private var showCycleLengthPicker = false
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
                } else {
                    // Modo ciclo menstrual
                    cycleSection
                    fertilitySection
                    cycleHistorySection
                }

                // Toggle modo
                modeToggle

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(CalmTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Saúde Feminina")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Cycle Section
    private var cycleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ciclo Atual")
                .font(.headline)
                .foregroundColor(CalmTheme.textPrimary)

            // Dia atual do ciclo
            let dayInCycle = currentCycleDay
            let phase = cyclePhase(day: dayInCycle)

            HStack(spacing: 0) {
                ForEach(0..<cycleLength, id: \.self) { day in
                    let d = day + 1
                    Circle()
                        .fill(dayColor(day: d))
                        .frame(height: 8)
                        .overlay(
                            Circle().stroke(d == dayInCycle ? pink : Color.clear, lineWidth: 2)
                        )
                }
            }
            .padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dia \(dayInCycle) de \(cycleLength)")
                        .font(.title2.bold())
                        .foregroundColor(pink)
                    Text(phase.name)
                        .font(.caption.bold())
                        .foregroundColor(phase.color)
                    Text(phase.description)
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Próxima menstruação")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                    Text(nextPeriodText)
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                }
            }

            Button {
                tempDate = lastPeriodTimestamp > 0
                    ? Date(timeIntervalSince1970: lastPeriodTimestamp)
                    : Date()
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
        .sheet(isPresented: $showCyclePicker) {
            DatePickerSheet(title: "Início da menstruação", date: $tempDate) {
                lastPeriodTimestamp = tempDate.timeIntervalSince1970
            }
        }
    }

    // MARK: - Fertility Window
    private var fertilitySection: some View {
        let ovulationDay = cycleLength - 14
        let fertileStart = ovulationDay - 5
        let fertileEnd = ovulationDay + 1
        let today = currentCycleDay
        let isFertile = today >= fertileStart && today <= fertileEnd

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

            Text("Ovulação prevista: dia \(ovulationDay)")
                .font(.subheadline)
                .foregroundColor(CalmTheme.textSecondary)
            Text("Período fértil: dias \(fertileStart) – \(fertileEnd)")
                .font(.caption)
                .foregroundColor(CalmTheme.textSecondary)
        }
        .padding(16)
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
    }

    // MARK: - Cycle Length Picker
    private var cycleHistorySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Duração do ciclo")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                Text("\(cycleLength) dias")
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
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .sheet(isPresented: $showCycleLengthPicker) {
            CycleLengthPickerSheet(cycleLength: $cycleLength)
        }
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

            // Progresso trimestre
            let trimester = min(weeks / 13 + 1, 3)
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
                    : Calendar.current.date(byAdding: .day, value: 280, to: Date())!
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
    private var currentCycleDay: Int {
        guard lastPeriodTimestamp > 0 else { return 1 }
        let last = Date(timeIntervalSince1970: lastPeriodTimestamp)
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        let day = (days % cycleLength) + 1
        return max(1, min(day, cycleLength))
    }

    private var nextPeriodText: String {
        guard lastPeriodTimestamp > 0 else { return "—" }
        let last = Date(timeIntervalSince1970: lastPeriodTimestamp)
        guard let next = Calendar.current.date(byAdding: .day, value: cycleLength, to: last) else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: next).day ?? 0
        if days <= 0 { return "Esta semana" }
        return "em \(days) dias"
    }

    private var pregnancyWeeks: Int {
        guard dueDateTimestamp > 0 else { return 0 }
        let dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
        guard let conception = Calendar.current.date(byAdding: .day, value: -280, to: dueDate) else { return 0 }
        return max(0, Calendar.current.dateComponents([.weekOfYear], from: conception, to: Date()).weekOfYear ?? 0)
    }

    private var daysUntilDueDate: Int {
        guard dueDateTimestamp > 0 else { return 0 }
        let dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0)
    }

    private func dayColor(day: Int) -> Color {
        let current = currentCycleDay
        let ovulation = cycleLength - 14
        if day <= 5 { return Color.red.opacity(0.6) }
        if day >= ovulation - 5 && day <= ovulation + 1 { return Color.orange.opacity(0.5) }
        if day == current { return pink }
        if day < current { return pink.opacity(0.3) }
        return CalmTheme.primary.opacity(0.1)
    }

    private struct CyclePhase {
        let name: String
        let color: Color
        let description: String
    }

    private func cyclePhase(day: Int) -> CyclePhase {
        let ovulation = cycleLength - 14
        switch day {
        case 1...5:
            return CyclePhase(name: "Menstruação", color: .red, description: "Repouso e autocuidado")
        case 6...12:
            return CyclePhase(name: "Fase Folicular", color: Color.blue, description: "Energia crescente, criatividade")
        case _ where day >= ovulation - 1 && day <= ovulation + 1:
            return CyclePhase(name: "Ovulação", color: .orange, description: "Pico de energia e vitalidade")
        default:
            return CyclePhase(name: "Fase Lútea", color: CalmTheme.primary, description: "Introspecção e reflexão")
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

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date
    var onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(title, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color(red: 0.90, green: 0.45, blue: 0.65))
                    .padding()
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
                    ForEach(21...40, id: \.self) { days in
                        Text("\(days) dias").tag(days)
                    }
                }
                .pickerStyle(.wheel)
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
