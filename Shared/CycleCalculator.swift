// CycleCalculator.swift
// Alma App — Motor de cálculo do ciclo menstrual (puro, testável)
//
// [Build 84 — 2026-07-28] Extraído do FeminineHealthView para corrigir a
// lógica de ciclo e permitir testes unitários. Correções em relação à
// implementação anterior (inline na view):
//
//   1. Dia do ciclo contado em DIAS DE CALENDÁRIO (startOfDay), não em
//      intervalos de 24h entre timestamps — registrar a menstruação às 23h
//      não "atrasava" mais o dia do ciclo na manhã seguinte.
//   2. SEM módulo: o dia do ciclo não "dá a volta" silenciosamente quando o
//      ciclo atrasa (antes, dia 30 de um ciclo de 28 virava "dia 2" e o app
//      fingia que uma nova menstruação tinha começado). Agora o dia continua
//      contando e `isLate` sinaliza o atraso — mesmo comportamento do padrão
//      de mercado (ex.: Flo mostra "Ciclo atual: 37 dias").
//   3. Duração da menstruação configurável (antes: 5 dias fixos no código).
//   4. Ovulação/janela fértil com clamp para ciclos curtos (antes: ciclo de
//      14 dias exibia "Ovulação prevista: dia 0" e "Período fértil: dias -5 – 1").
//   5. Previsão baseada no histórico real (média dos últimos ciclos), com
//      classificação Regular/Irregular — antes só havia um número manual.
//   6. Trimestre da gravidez alinhado ao texto exibido (semanas 1–13 / 14–27 /
//      28+; antes a semana 27 caía no 3º trimestre com texto dizendo 2º).
//
// Regras clínicas adotadas (padrão ACOG/literatura):
//   • Fase lútea considerada fixa em ~14 dias → ovulação ≈ duração do ciclo − 14
//   • Janela fértil: 5 dias antes da ovulação até 1 dia depois (sobrevida do
//     espermatozoide ~5 dias; do óvulo ~1 dia)
//   • Ciclo "normal" em adultas: 21–35 dias; menstruação típica: 3–7 dias
//   • Ciclo "regular": variação entre ciclos ≤ 7 dias
//   • Idade gestacional: contada a partir da DUM (= DPP − 280 dias)
//
// IMPORTANTE (UI): previsões são estimativas de autoconhecimento, não método
// contraceptivo nem diagnóstico — o FeminineHealthView exibe esse aviso.

import Foundation

enum CyclePhaseKind: Equatable {
    case menstrual
    case follicular
    case ovulation
    case luteal
}

struct CycleSnapshot: Equatable {
    /// Dia atual do ciclo, contando a partir de 1 no primeiro dia da última
    /// menstruação registrada. NÃO dá a volta: pode passar de `cycleLength`.
    let day: Int
    /// `true` quando o ciclo passou da duração prevista (menstruação atrasada).
    let isLate: Bool
    /// Dias de atraso (0 quando não está atrasada).
    let daysLate: Int
    let phase: CyclePhaseKind
    /// Dia previsto da ovulação (1-based, clampado a [1, cycleLength]).
    let ovulationDay: Int
    /// Janela fértil em dias do ciclo (clampada a [1, cycleLength]).
    let fertileWindow: ClosedRange<Int>
    /// Data prevista do início da próxima menstruação (à meia-noite local).
    let nextPeriodDate: Date
    /// Dias de calendário até a próxima menstruação prevista (0 = hoje).
    let daysUntilNextPeriod: Int
}

enum CycleCalculator {

    /// Duração considerada da fase lútea (padrão clínico ~14 dias).
    static let lutealPhaseDays = 14

    /// Faixa de duração de ciclo considerada normal em adultas (dias).
    static let normalCycleRange = 21...35

    /// Faixa de duração de menstruação considerada típica (dias).
    static let normalPeriodRange = 3...7

    /// Variação máxima entre ciclos para considerá-los regulares (dias).
    static let regularMaxVariation = 7

    // MARK: - Dia do ciclo

    /// Dia do ciclo em dias de calendário (1-based). Nunca menor que 1.
    /// Não aplica módulo — ciclos atrasados continuam contando (dia 30, 31…).
    static func cycleDay(
        lastPeriodStart: Date,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: lastPeriodStart)
        let now = calendar.startOfDay(for: today)
        let days = calendar.dateComponents([.day], from: start, to: now).day ?? 0
        return max(1, days + 1)
    }

    // MARK: - Ovulação e janela fértil

    /// Dia previsto da ovulação: duração do ciclo − 14 (fase lútea),
    /// clampado para nunca sair de [1, cycleLength].
    static func ovulationDay(cycleLength: Int) -> Int {
        guard cycleLength > 0 else { return 1 }
        return min(max(cycleLength - lutealPhaseDays, 1), cycleLength)
    }

    /// Janela fértil: [ovulação − 5, ovulação + 1], clampada a [1, cycleLength].
    static func fertileWindow(cycleLength: Int) -> ClosedRange<Int> {
        let ov = ovulationDay(cycleLength: cycleLength)
        let upperBound = max(cycleLength, 1)
        let start = min(max(ov - 5, 1), upperBound)
        let end = min(max(ov + 1, start), upperBound)
        return start...end
    }

    // MARK: - Fases

    /// Fase do ciclo para um dia. Prioridade: menstruação > ovulação >
    /// folicular/lútea. Dias além de `cycleLength` (atraso) caem na lútea.
    static func phase(day: Int, cycleLength: Int, periodLength: Int) -> CyclePhaseKind {
        let safePeriod = max(1, min(periodLength, max(cycleLength, 1)))
        if day <= safePeriod { return .menstrual }

        let ov = ovulationDay(cycleLength: cycleLength)
        if day >= ov - 1 && day <= ov + 1 { return .ovulation }
        if day < ov - 1 { return .follicular }
        return .luteal
    }

    // MARK: - Próxima menstruação

    /// Primeira data de início de menstruação prevista que seja hoje ou futura.
    /// Sempre pelo menos um ciclo após o último início registrado. Se a
    /// previsão cai hoje, retorna HOJE (a UI mostra "Hoje" — o código antigo
    /// pulava direto para o ciclo seguinte). Anda em passos de `cycleLength`
    /// dias de calendário — viradas de mês/ano e bissextos por conta do Calendar.
    static func nextPeriodDate(
        lastPeriodStart: Date,
        cycleLength: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Date {
        let length = max(1, cycleLength)
        let todayStart = calendar.startOfDay(for: today)
        let anchor = calendar.startOfDay(for: lastPeriodStart)

        func addCycle(_ date: Date) -> Date {
            calendar.date(byAdding: .day, value: length, to: date)
                ?? date.addingTimeInterval(Double(length) * 86_400)
        }

        var next = addCycle(anchor)
        var safety = 0
        while next < todayStart && safety < 1000 {
            next = addCycle(next)
            safety += 1
        }
        return next
    }

    /// Dias de calendário entre hoje e uma data (0 = mesmo dia).
    static func daysUntil(
        _ date: Date,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let a = calendar.startOfDay(for: today)
        let b = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    // MARK: - Snapshot completo

    static func snapshot(
        lastPeriodStart: Date,
        cycleLength: Int,
        periodLength: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> CycleSnapshot {
        let length = max(1, cycleLength)
        let day = cycleDay(lastPeriodStart: lastPeriodStart, today: today, calendar: calendar)
        let next = nextPeriodDate(
            lastPeriodStart: lastPeriodStart,
            cycleLength: length,
            today: today,
            calendar: calendar
        )
        return CycleSnapshot(
            day: day,
            isLate: day > length,
            daysLate: max(0, day - length),
            phase: phase(day: day, cycleLength: length, periodLength: periodLength),
            ovulationDay: ovulationDay(cycleLength: length),
            fertileWindow: fertileWindow(cycleLength: length),
            nextPeriodDate: next,
            daysUntilNextPeriod: max(0, daysUntil(next, today: today, calendar: calendar))
        )
    }

    // MARK: - Histórico de ciclos

    /// Insere um início de menstruação no histórico: remove duplicatas do
    /// mesmo dia, ordena e limita aos `cap` registros mais recentes.
    static func updatedHistory(
        _ history: [Date],
        adding newStart: Date,
        cap: Int = 24,
        calendar: Calendar = .current
    ) -> [Date] {
        var days = history.map { calendar.startOfDay(for: $0) }
        let newDay = calendar.startOfDay(for: newStart)
        days.removeAll { $0 == newDay }
        days.append(newDay)
        days.sort()
        if days.count > cap {
            days.removeFirst(days.count - cap)
        }
        return days
    }

    /// Durações dos ciclos completos (diferenças entre inícios consecutivos),
    /// em dias de calendário, ignorando valores implausíveis (< 15 ou > 120 —
    /// típico de registro esquecido por meses). Mais recentes por último.
    static func cycleLengths(
        history: [Date],
        calendar: Calendar = .current
    ) -> [Int] {
        let sorted = history.map { calendar.startOfDay(for: $0) }.sorted()
        guard sorted.count >= 2 else { return [] }
        var lengths: [Int] = []
        for i in 1..<sorted.count {
            let d = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if (15...120).contains(d) {
                lengths.append(d)
            }
        }
        return lengths
    }

    /// Média (arredondada) dos últimos `window` ciclos completos.
    /// `nil` quando não há ciclos completos no histórico.
    static func averageCycleLength(
        history: [Date],
        window: Int = 6,
        calendar: Calendar = .current
    ) -> Int? {
        let lengths = cycleLengths(history: history, calendar: calendar).suffix(window)
        guard !lengths.isEmpty else { return nil }
        let sum = lengths.reduce(0, +)
        return Int((Double(sum) / Double(lengths.count)).rounded())
    }

    /// Faixa (mín–máx) dos últimos `window` ciclos completos.
    static func cycleLengthRange(
        history: [Date],
        window: Int = 6,
        calendar: Calendar = .current
    ) -> ClosedRange<Int>? {
        let lengths = cycleLengths(history: history, calendar: calendar).suffix(window)
        guard let minL = lengths.min(), let maxL = lengths.max() else { return nil }
        return minL...maxL
    }

    /// Ciclos regulares: variação entre o menor e o maior ≤ 7 dias.
    static func isRegular(range: ClosedRange<Int>) -> Bool {
        (range.upperBound - range.lowerBound) <= regularMaxVariation
    }

    // MARK: - Gravidez

    /// Idade gestacional em semanas completas, contada a partir da DUM
    /// (DPP − 280 dias), clampada a [0, 42].
    static func gestationalWeeks(
        dueDate: Date,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let due = calendar.startOfDay(for: dueDate)
        guard let lmp = calendar.date(byAdding: .day, value: -280, to: due) else { return 0 }
        let days = calendar.dateComponents(
            [.day],
            from: lmp,
            to: calendar.startOfDay(for: today)
        ).day ?? 0
        return min(max(days / 7, 0), 42)
    }

    /// Trimestre alinhado ao texto da UI: 1º = semanas ≤ 13, 2º = 14–27, 3º = 28+.
    static func trimester(weeks: Int) -> Int {
        if weeks <= 13 { return 1 }
        if weeks <= 27 { return 2 }
        return 3
    }
}
