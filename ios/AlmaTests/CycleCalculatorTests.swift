// CycleCalculatorTests.swift
// Alma App — Testes unitários do motor de ciclo menstrual
//
// [Build 84 — 2026-07-28] O projeto Xcode não tem target de unit-test
// (os targets "Tests iOS/macOS" são bundles de UI-test desatualizados),
// então esta suíte roda como executável standalone:
//
//   swiftc -parse-as-library Shared/CycleCalculator.swift \
//          ios/AlmaTests/CycleCalculatorTests.swift -o /tmp/cycle_tests
//   /tmp/cycle_tests            # exit 0 = tudo passou
//
// Cobre: paridade com a referência clínica (e com o app Flo usado como
// referência de UX), ciclos regulares e irregulares, viradas de mês e de
// ano, ano bissexto, atrasos (sem "dar a volta"), clamps de ciclos curtos,
// fases, histórico/média/variação e gravidez (semanas + trimestre).

import Foundation

@main
struct CycleCalculatorTests {

    static var passed = 0
    static var failed = 0

    // Calendário fixo (São Paulo) para resultados determinísticos.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        c.locale = Locale(identifier: "pt_BR")
        return c
    }()

    static let utcCal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, calendar: Calendar? = nil) -> Date {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d; comps.hour = h; comps.minute = min
        return (calendar ?? cal).date(from: comps)!
    }

    static func check(_ name: String, _ actual: @autoclosure () -> Int, _ expected: Int) {
        let a = actual()
        if a == expected {
            passed += 1
            print("  ✅ \(name) → \(a)")
        } else {
            failed += 1
            print("  ❌ \(name) → esperado \(expected), obtido \(a)")
        }
    }

    static func checkDate(_ name: String, _ actual: Date, _ y: Int, _ m: Int, _ d: Int, calendar: Calendar? = nil) {
        let c = calendar ?? cal
        let comps = c.dateComponents([.year, .month, .day], from: actual)
        if comps.year == y && comps.month == m && comps.day == d {
            passed += 1
            print("  ✅ \(name) → \(String(format: "%02d/%02d/%04d", comps.day!, comps.month!, comps.year!))")
        } else {
            failed += 1
            print("  ❌ \(name) → esperado \(String(format: "%02d/%02d/%04d", d, m, y)), obtido \(String(format: "%02d/%02d/%04d", comps.day ?? 0, comps.month ?? 0, comps.year ?? 0))")
        }
    }

    static func checkBool(_ name: String, _ actual: Bool, _ expected: Bool) {
        if actual == expected {
            passed += 1
            print("  ✅ \(name) → \(actual)")
        } else {
            failed += 1
            print("  ❌ \(name) → esperado \(expected), obtido \(actual)")
        }
    }

    static func checkPhase(_ name: String, _ actual: CyclePhaseKind, _ expected: CyclePhaseKind) {
        if actual == expected {
            passed += 1
            print("  ✅ \(name) → \(actual)")
        } else {
            failed += 1
            print("  ❌ \(name) → esperado \(expected), obtido \(actual)")
        }
    }

    static func main() {
        print("═══ CycleCalculatorTests — \(Date()) ═══\n")

        grupo1_paridadeReferencia()
        grupo2_diasDeCalendario()
        grupo3_atrasoSemWrap()
        grupo4_viradasDeMesEAno()
        grupo5_anoBissexto()
        grupo6_proximaMenstruacaoHoje()
        grupo7_ciclosCurtosClamps()
        grupo8_fases()
        grupo9_historicoMediaVariacao()
        grupo10_gravidez()
        grupo11_independenciaDeFusoHorario()

        print("\n═══ RESULTADO: \(passed) passaram, \(failed) falharam ═══")
        exit(failed == 0 ? 0 : 1)
    }

    // ── Grupo 1: paridade com a referência (cenário real dos prints do Flo) ──
    // Última menstruação 20/07/2026, ciclo médio 29, menstruação 4 dias,
    // hoje 28/07/2026. Flo mostra: "Ciclo atual: 9 dias", ovulação 03/08
    // (dia 15), próxima menstruação 18–21/08.
    static func grupo1_paridadeReferencia() {
        print("— Grupo 1: paridade com referência clínica (cenário dos prints) —")
        let last = date(2026, 7, 20)
        let today = date(2026, 7, 28)
        let snap = CycleCalculator.snapshot(
            lastPeriodStart: last, cycleLength: 29, periodLength: 4,
            today: today, calendar: cal
        )
        check("dia do ciclo em 28/07 (Flo: 9)", snap.day, 9)
        check("dia da ovulação (Flo: dia 15 = 03/08)", snap.ovulationDay, 15)
        checkDate("próxima menstruação (Flo: 18/08)", snap.nextPeriodDate, 2026, 8, 18)
        check("dias até a próxima menstruação", snap.daysUntilNextPeriod, 21)
        checkBool("não está atrasada", snap.isLate, false)
        check("janela fértil começa (dia)", snap.fertileWindow.lowerBound, 10)
        check("janela fértil termina (dia)", snap.fertileWindow.upperBound, 16)
        checkPhase("fase no dia 9 (menstruação de 4d → folicular)", snap.phase, .follicular)
        print("")
    }

    // ── Grupo 2: dias de CALENDÁRIO, não intervalos de 24h ──
    static func grupo2_diasDeCalendario() {
        print("— Grupo 2: contagem por dia de calendário —")
        // Registrou às 23:30; consulta às 00:10 do dia seguinte → dia 2.
        // (código antigo: intervalo de 40min = 0 dias → ficava no dia 1)
        let last = date(2026, 7, 20, 23, 30)
        let today = date(2026, 7, 21, 0, 10)
        check("23:30 → 00:10 do dia seguinte é dia 2",
              CycleCalculator.cycleDay(lastPeriodStart: last, today: today, calendar: cal), 2)

        // Mesmo dia, horas diferentes → dia 1
        check("mesmo dia (09h → 22h) é dia 1",
              CycleCalculator.cycleDay(lastPeriodStart: date(2026, 7, 20, 9), today: date(2026, 7, 20, 22), calendar: cal), 1)

        // Data futura por engano → clampa em 1
        check("registro no futuro clampa em dia 1",
              CycleCalculator.cycleDay(lastPeriodStart: date(2026, 7, 30), today: date(2026, 7, 28), calendar: cal), 1)
        print("")
    }

    // ── Grupo 3: atraso NÃO dá a volta (bug do módulo) ──
    static func grupo3_atrasoSemWrap() {
        print("— Grupo 3: ciclo atrasado continua contando —")
        let last = date(2026, 6, 22)
        let today = date(2026, 7, 28)
        let snap = CycleCalculator.snapshot(
            lastPeriodStart: last, cycleLength: 28, periodLength: 5,
            today: today, calendar: cal
        )
        // Código antigo: ((36 % 28) + 1) = 9 — fingia ciclo novo sem registro.
        check("dia 37 (código antigo mostrava 9)", snap.day, 37)
        checkBool("isLate", snap.isLate, true)
        check("dias de atraso", snap.daysLate, 9)
        checkDate("próxima prevista rola para frente", snap.nextPeriodDate, 2026, 8, 17)
        checkPhase("fase em atraso = lútea", snap.phase, .luteal)
        print("")
    }

    // ── Grupo 4: viradas de mês e de ano ──
    static func grupo4_viradasDeMesEAno() {
        print("— Grupo 4: viradas de mês e de ano —")
        // Virada de mês
        let snapMes = CycleCalculator.snapshot(
            lastPeriodStart: date(2026, 7, 25), cycleLength: 28, periodLength: 5,
            today: date(2026, 8, 1), calendar: cal
        )
        check("25/07 → 01/08 é dia 8", snapMes.day, 8)
        checkDate("próxima menstruação 22/08", snapMes.nextPeriodDate, 2026, 8, 22)

        // Virada de ano
        let snapAno = CycleCalculator.snapshot(
            lastPeriodStart: date(2026, 12, 20), cycleLength: 28, periodLength: 5,
            today: date(2027, 1, 5), calendar: cal
        )
        check("20/12/2026 → 05/01/2027 é dia 17", snapAno.day, 17)
        checkDate("próxima menstruação 17/01/2027", snapAno.nextPeriodDate, 2027, 1, 17)
        print("")
    }

    // ── Grupo 5: ano bissexto ──
    static func grupo5_anoBissexto() {
        print("— Grupo 5: ano bissexto —")
        // 2028 é bissexto: 01/02 + 28 dias = 29/02/2028
        checkDate("01/02/2028 + ciclo 28 = 29/02/2028 (bissexto)",
                  CycleCalculator.nextPeriodDate(lastPeriodStart: date(2028, 2, 1), cycleLength: 28, today: date(2028, 2, 15), calendar: cal),
                  2028, 2, 29)
        // 2027 não é: 01/02 + 28 dias = 01/03/2027
        checkDate("01/02/2027 + ciclo 28 = 01/03/2027 (não bissexto)",
                  CycleCalculator.nextPeriodDate(lastPeriodStart: date(2027, 2, 1), cycleLength: 28, today: date(2027, 2, 15), calendar: cal),
                  2027, 3, 1)
        print("")
    }

    // ── Grupo 6: previsão que cai HOJE ──
    static func grupo6_proximaMenstruacaoHoje() {
        print("— Grupo 6: previsão caindo hoje —")
        // 30/06 + 28 = 28/07 → hoje. Código antigo pulava para 25/08.
        let next = CycleCalculator.nextPeriodDate(
            lastPeriodStart: date(2026, 6, 30), cycleLength: 28,
            today: date(2026, 7, 28), calendar: cal
        )
        checkDate("previsão de hoje retorna HOJE (não pula ciclo)", next, 2026, 7, 28)
        check("daysUntil = 0 → UI mostra 'Hoje'",
              CycleCalculator.daysUntil(next, today: date(2026, 7, 28), calendar: cal), 0)

        // Registrada HOJE → próxima em um ciclo completo
        checkDate("registrada hoje → próxima em 28 dias",
                  CycleCalculator.nextPeriodDate(lastPeriodStart: date(2026, 7, 28), cycleLength: 28, today: date(2026, 7, 28), calendar: cal),
                  2026, 8, 25)
        print("")
    }

    // ── Grupo 7: ciclos curtos — clamps (antes: "dia 0" e "dias -5 – 1") ──
    static func grupo7_ciclosCurtosClamps() {
        print("— Grupo 7: ciclos curtos (clamps) —")
        check("ciclo 21 → ovulação dia 7", CycleCalculator.ovulationDay(cycleLength: 21), 7)
        check("ciclo 21 → fértil começa dia 2", CycleCalculator.fertileWindow(cycleLength: 21).lowerBound, 2)
        check("ciclo 21 → fértil termina dia 8", CycleCalculator.fertileWindow(cycleLength: 21).upperBound, 8)
        // Mínimo do picker (14): antes exibia ovulação dia 0 e fértil -5–1
        check("ciclo 14 → ovulação clampada em 1", CycleCalculator.ovulationDay(cycleLength: 14), 1)
        check("ciclo 14 → fértil começa dia 1 (sem negativo)", CycleCalculator.fertileWindow(cycleLength: 14).lowerBound, 1)
        check("ciclo 14 → fértil termina dia 2", CycleCalculator.fertileWindow(cycleLength: 14).upperBound, 2)
        print("")
    }

    // ── Grupo 8: fases (ciclo 28, menstruação 5) ──
    static func grupo8_fases() {
        print("— Grupo 8: fases do ciclo —")
        func fase(_ d: Int, _ len: Int = 28, _ p: Int = 5) -> CyclePhaseKind {
            CycleCalculator.phase(day: d, cycleLength: len, periodLength: p)
        }
        checkPhase("dia 1 = menstruação", fase(1), .menstrual)
        checkPhase("dia 5 = menstruação", fase(5), .menstrual)
        checkPhase("dia 6 = folicular", fase(6), .follicular)
        checkPhase("dia 12 = folicular", fase(12), .follicular)
        checkPhase("dia 13 = ovulação (ov−1)", fase(13), .ovulation)
        checkPhase("dia 14 = ovulação", fase(14), .ovulation)
        checkPhase("dia 15 = ovulação (ov+1)", fase(15), .ovulation)
        checkPhase("dia 16 = lútea", fase(16), .luteal)
        checkPhase("dia 28 = lútea", fase(28), .luteal)
        // Menstruação de 4 dias (config): dia 5 já é folicular
        checkPhase("menstruação 4d → dia 5 é folicular", fase(5, 28, 4), .follicular)
        // Menstruação de 7 dias: dia 7 ainda é menstruação
        checkPhase("menstruação 7d → dia 7 é menstruação", fase(7, 28, 7), .menstrual)
        // Guarda: periodLength absurdo não quebra
        checkPhase("periodLength > ciclo não quebra", fase(8, 20, 25), .menstrual)
        print("")
    }

    // ── Grupo 9: histórico, média e variação (irregulares) ──
    static func grupo9_historicoMediaVariacao() {
        print("— Grupo 9: histórico / média / variação —")
        // Cenário dos prints: 21/05 → 22/06 (32d) → 20/07 (28d)
        let historico = [date(2026, 5, 21), date(2026, 6, 22), date(2026, 7, 20)]
        let lengths = CycleCalculator.cycleLengths(history: historico, calendar: cal)
        check("nº de ciclos completos", lengths.count, 2)
        check("ciclo 1 (21/05–22/06) = 32 dias", lengths[0], 32)
        check("ciclo 2 (22/06–20/07) = 28 dias", lengths[1], 28)
        check("média = 30", CycleCalculator.averageCycleLength(history: historico, calendar: cal) ?? -1, 30)
        let range = CycleCalculator.cycleLengthRange(history: historico, calendar: cal)!
        check("variação mín", range.lowerBound, 28)
        check("variação máx", range.upperBound, 32)
        checkBool("28–32 é REGULAR (Δ4 ≤ 7)", CycleCalculator.isRegular(range: range), true)

        // Irregular: 24, 38 → Δ14
        let irregular = [date(2026, 3, 1), date(2026, 3, 25), date(2026, 5, 2)]
        let r2 = CycleCalculator.cycleLengthRange(history: irregular, calendar: cal)!
        check("irregular mín", r2.lowerBound, 24)
        check("irregular máx", r2.upperBound, 38)
        checkBool("24–38 é IRREGULAR (Δ14 > 7)", CycleCalculator.isRegular(range: r2), false)

        // Lacunas implausíveis são ignoradas (registro esquecido por meses)
        let comLacuna = [date(2025, 1, 1), date(2026, 1, 1), date(2026, 1, 10)]
        check("intervalos implausíveis (365d, 9d) ignorados",
              CycleCalculator.cycleLengths(history: comLacuna, calendar: cal).count, 0)

        // updatedHistory: dedupe do mesmo dia + ordenação
        let atualizado = CycleCalculator.updatedHistory(
            [date(2026, 7, 20, 9)], adding: date(2026, 7, 20, 22), calendar: cal
        )
        check("mesmo dia não duplica no histórico", atualizado.count, 1)
        let fora = CycleCalculator.updatedHistory(
            [date(2026, 6, 22), date(2026, 7, 20)], adding: date(2026, 5, 21), calendar: cal
        )
        checkDate("registro retroativo entra ordenado (primeiro)", fora[0], 2026, 5, 21)
        checkDate("último início continua sendo 20/07", fora[2], 2026, 7, 20)

        // Cap de 24 registros
        var muitos: [Date] = []
        for i in 0..<30 { muitos.append(cal.date(byAdding: .day, value: i * 28, to: date(2024, 1, 1))!) }
        let capped = CycleCalculator.updatedHistory(muitos, adding: date(2026, 7, 20), calendar: cal)
        check("histórico limitado a 24 registros", capped.count, 24)
        print("")
    }

    // ── Grupo 10: gravidez ──
    static func grupo10_gravidez() {
        print("— Grupo 10: gravidez —")
        // DPP 01/10/2026, hoje 28/07/2026 → DUM 25/12/2025 → 215 dias = 30 semanas
        check("semanas gestacionais (DPP 01/10, hoje 28/07)",
              CycleCalculator.gestationalWeeks(dueDate: date(2026, 10, 1), today: date(2026, 7, 28), calendar: cal), 30)
        check("semana 13 → 1º trimestre", CycleCalculator.trimester(weeks: 13), 1)
        check("semana 14 → 2º trimestre", CycleCalculator.trimester(weeks: 14), 2)
        // Bug antigo: min(27/13 + 1, 3) = 3, mas o texto da UI diz 2º tri até a 27
        check("semana 27 → 2º trimestre (bug antigo dava 3º)", CycleCalculator.trimester(weeks: 27), 2)
        check("semana 28 → 3º trimestre", CycleCalculator.trimester(weeks: 28), 3)
        // Passou da DPP → clampa em 42
        check("pós-DPP clampa em 42 semanas",
              CycleCalculator.gestationalWeeks(dueDate: date(2026, 7, 1), today: date(2026, 10, 28), calendar: cal), 42)
        // Antes da concepção (DPP muito no futuro) → 0
        check("DPP distante → 0 semanas (sem negativo)",
              CycleCalculator.gestationalWeeks(dueDate: date(2027, 12, 1), today: date(2026, 7, 28), calendar: cal), 0)
        print("")
    }

    // ── Grupo 11: independência de fuso horário ──
    static func grupo11_independenciaDeFusoHorario() {
        print("— Grupo 11: mesmo resultado em UTC e São Paulo —")
        let spDay = CycleCalculator.cycleDay(
            lastPeriodStart: date(2026, 7, 20), today: date(2026, 7, 28), calendar: cal
        )
        let utcDay = CycleCalculator.cycleDay(
            lastPeriodStart: date(2026, 7, 20, 12, 0, calendar: utcCal),
            today: date(2026, 7, 28, 12, 0, calendar: utcCal),
            calendar: utcCal
        )
        check("dia do ciclo em São Paulo", spDay, 9)
        check("dia do ciclo em UTC", utcDay, 9)
        print("")
    }
}
