// CorpoInsightsEngine.swift
// Alma — Corpo · métricas de verdade para a aba Insights
//
// [Honestidade 2026-08-02] Substitui as quatro frases hardcoded e os dois
// gráficos inventados que existiam no AppModel. Regras desta camada:
//
//   1. Todo número sai de registro real do usuário (refeições, treinos, água,
//      peso) ou do HealthKit. Nada é semeado, estimado ou "de exemplo".
//   2. Cada métrica declara quantos dias de dado ela tem. Abaixo do mínimo,
//      ela NÃO é exibida — a UI mostra o que falta registrar.
//   3. Nenhuma métrica afirma causa ("você dormiu melhor PORQUE…"). Descrever
//      é nosso; interpretar é da Alma, com os guardrails dela.

import Foundation

/// Um registro de peso feito pelo usuário.
struct WeightEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    let date: Date
    let kg: Double
}

/// Métrica pronta para exibição — já com o aviso de base de dados.
struct CorpoMetric: Identifiable {
    let id = UUID()
    let titulo: String
    let valor: String
    /// Comparação com o período anterior, quando há base para isso.
    let variacao: String?
    /// Quantos dias de dado real sustentam este número.
    let diasDeDados: Int
    let systemImage: String
}

enum CorpoInsightsEngine {

    /// Mínimo de dias registrados para uma métrica semanal ser honesta.
    static let minimoDiasSemana = 3
    /// Mínimo de pesagens para falar em tendência de peso.
    static let minimoPesagens = 2

    private static var formatadorDia: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func chaveDia(_ data: Date) -> String { formatadorDia.string(from: data) }

    /// Últimos `dias` dias (mais antigo primeiro).
    private static func ultimosDias(_ dias: Int, ate hoje: Date = Date()) -> [Date] {
        let cal = Calendar.current
        return (0..<dias).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: hoje))
        }
    }

    // MARK: - Métricas

    /// Calorias: média dos dias COM registro. Não conta dia sem registro como
    /// zero — isso rebaixaria a média e mentiria sobre o consumo.
    static func mediaCalorias(kcalByDay: [String: Int], hoje: Date = Date()) -> CorpoMetric? {
        let dias = ultimosDias(7, ate: hoje).map(chaveDia)
        let registrados = dias.compactMap { kcalByDay[$0] }.filter { $0 > 0 }
        guard registrados.count >= minimoDiasSemana else { return nil }

        let media = registrados.reduce(0, +) / registrados.count

        // Semana anterior, para variação — só se também tiver base.
        let cal = Calendar.current
        let seteAtras = cal.date(byAdding: .day, value: -7, to: hoje) ?? hoje
        let diasAnt = ultimosDias(7, ate: seteAtras).map(chaveDia)
        let regAnt = diasAnt.compactMap { kcalByDay[$0] }.filter { $0 > 0 }

        var variacao: String? = nil
        if regAnt.count >= minimoDiasSemana {
            let mediaAnt = regAnt.reduce(0, +) / regAnt.count
            if mediaAnt > 0 {
                let delta = Int(((Double(media) - Double(mediaAnt)) / Double(mediaAnt) * 100).rounded())
                if delta != 0 {
                    variacao = delta > 0 ? "+\(delta)% vs. semana anterior" : "\(delta)% vs. semana anterior"
                }
            }
        }

        return CorpoMetric(
            titulo: "Calorias por dia",
            valor: "\(media) kcal",
            variacao: variacao,
            diasDeDados: registrados.count,
            systemImage: "flame.fill"
        )
    }

    /// Treinos concluídos nos últimos 7 dias. Contagem, não estimativa —
    /// aparece a partir do primeiro treino.
    static func treinosNaSemana(workoutDays: Set<String>, hoje: Date = Date()) -> CorpoMetric? {
        let dias = ultimosDias(7, ate: hoje).map(chaveDia)
        let feitos = dias.filter { workoutDays.contains($0) }.count
        guard feitos > 0 else { return nil }

        let cal = Calendar.current
        let seteAtras = cal.date(byAdding: .day, value: -7, to: hoje) ?? hoje
        let anteriores = ultimosDias(7, ate: seteAtras).map(chaveDia).filter { workoutDays.contains($0) }.count

        var variacao: String? = nil
        if anteriores > 0 {
            let delta = feitos - anteriores
            if delta > 0 { variacao = "+\(delta) vs. semana anterior" }
            else if delta < 0 { variacao = "\(delta) vs. semana anterior" }
        }

        return CorpoMetric(
            titulo: "Treinos na semana",
            valor: feitos == 1 ? "1 treino" : "\(feitos) treinos",
            variacao: variacao,
            // [2026-08-04] Era `7` fixo: a tela dizia "1 treino · com base em
            // 7 registros" para quem tinha UM treino. O rodapé existe para
            // dizer o tamanho da amostra — inflá-lo é mentir sobre a
            // confiabilidade do próprio número que está logo acima.
            diasDeDados: feitos,
            systemImage: "dumbbell.fill"
        )
    }

    /// Tendência de peso — exige pelo menos duas pesagens reais.
    static func tendenciaPeso(weightLog: [WeightEntry]) -> CorpoMetric? {
        let ordenado = weightLog.sorted { $0.date < $1.date }
        guard ordenado.count >= minimoPesagens,
              let primeiro = ordenado.first, let ultimo = ordenado.last else { return nil }

        let delta = ultimo.kg - primeiro.kg
        let dias = Calendar.current.dateComponents([.day], from: primeiro.date, to: ultimo.date).day ?? 0

        let sinal = delta > 0 ? "+" : ""
        let variacao = dias > 0
            ? "\(sinal)\(String(format: "%.1f", delta)) kg em \(dias) \(dias == 1 ? "dia" : "dias")"
            : nil

        return CorpoMetric(
            titulo: "Peso atual",
            valor: String(format: "%.1f kg", ultimo.kg),
            variacao: variacao,
            diasDeDados: ordenado.count,
            systemImage: "scalemass.fill"
        )
    }

    /// Série real de calorias para o gráfico — só os dias com registro.
    /// Devolve vazio quando não há base; a UI não desenha gráfico vazio.
    static func serieCalorias(kcalByDay: [String: Int], hoje: Date = Date()) -> [DayPoint] {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "E"

        let pontos: [DayPoint] = ultimosDias(7, ate: hoje).compactMap { dia in
            guard let kcal = kcalByDay[chaveDia(dia)], kcal > 0 else { return nil }
            let rotulo = f.string(from: dia).prefix(3).capitalized
            return DayPoint(label: String(rotulo), value: Double(kcal))
        }
        _ = cal
        return pontos.count >= minimoDiasSemana ? pontos : []
    }

    /// Série real de peso para o gráfico.
    static func seriePeso(weightLog: [WeightEntry]) -> [DayPoint] {
        let ordenado = weightLog.sorted { $0.date < $1.date }.suffix(14)
        guard ordenado.count >= minimoPesagens else { return [] }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d/M"
        return ordenado.map { DayPoint(label: f.string(from: $0.date), value: $0.kg) }
    }

    // MARK: - Estado da aba

    /// Todas as métricas que têm base real hoje.
    static func metricas(model: AppModel) -> [CorpoMetric] {
        [
            mediaCalorias(kcalByDay: model.kcalByDay),
            treinosNaSemana(workoutDays: model.workoutDays),
            tendenciaPeso(weightLog: model.weightLog)
        ].compactMap { $0 }
    }

    /// O que o usuário precisa registrar para a aba ganhar conteúdo — texto
    /// honesto, específico, sem prometer análise que não existe.
    static func oQueFalta(model: AppModel) -> [String] {
        var faltas: [String] = []
        let diasComKcal = model.kcalByDay.values.filter { $0 > 0 }.count
        if diasComKcal < minimoDiasSemana {
            let faltam = minimoDiasSemana - diasComKcal
            faltas.append("registre suas refeições por mais \(faltam) \(faltam == 1 ? "dia" : "dias") para eu acompanhar sua alimentação")
        }
        if model.workoutDays.isEmpty {
            faltas.append("conclua um treino para eu acompanhar sua constância")
        }
        if model.weightLog.count < minimoPesagens {
            faltas.append("registre seu peso ao menos duas vezes para eu ver sua tendência")
        }
        return faltas
    }
}
