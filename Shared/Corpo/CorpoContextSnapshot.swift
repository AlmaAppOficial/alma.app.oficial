// CorpoContextSnapshot.swift
// Alma — Corpo · o que o módulo entrega ao contexto da IA
//
// [2026-08-02] A promessa central do Assis: "a IA tem que analisar o usuário
// num todo". Antes, a Alma via só sono, passos, exercício e meditação — não
// sabia se a pessoa comeu, bebeu água, treinou ou quanto pesa.
//
// Regras (as mesmas do HealthContextBuilder):
//   • RESUMO, nunca dump: "Alimentação: 1.850 kcal em 3 refeições" e não a
//     lista de alimentos;
//   • só entra o que tem registro REAL — campo sem dado não vira linha;
//   • nada daqui é gravado no servidor: é efêmero, vive só naquele prompt;
//   • restrições e condições viajam porque mudam o que a Alma pode sugerir —
//     sugerir amendoim a quem tem alergia seria pior que não sugerir nada.

import Foundation

struct CorpoContextSnapshot {

    let linhaAlimentacao: String?
    let linhaAgua: String?
    let linhaTreino: String?
    let linhaPeso: String?
    let linhaSuplementos: String?
    let linhaPerfil: String?

    /// [2026-08-03 — B4] O default `AppModel()` continua, mas agora é seguro: o
    /// init parou de carimbar `lastWaterDate` sem zerar o valor no disco, que
    /// era o que fazia instâncias descartáveis ressuscitarem a água de ontem.
    /// Ainda assim, prefira injetar o model do ambiente — construir um AppModel
    /// decodifica ~6 blobs JSON, e isto roda a cada mensagem de chat.
    @MainActor
    static func atual(model: AppModel = AppModel()) -> CorpoContextSnapshot {
        CorpoContextSnapshot(
            linhaAlimentacao: alimentacao(model),
            linhaAgua: agua(model),
            linhaTreino: treino(model),
            linhaPeso: peso(model),
            linhaSuplementos: suplementos(model),
            linhaPerfil: perfil(model)
        )
    }

    // MARK: - Linhas

    // Daqui para baixo só há EXTRAÇÃO: puxar o valor do model e entregar à
    // camada de formatação (CorpoContextFormat), que é pura e testada.

    @MainActor
    private static func alimentacao(_ m: AppModel) -> String? {
        CorpoContextFormat.alimentacao(
            kcal: m.kcalConsumed,
            refeicoesFeitas: m.meals.filter { $0.done }.count,
            meta: m.kcalGoal,
            proteina: m.proteinConsumed
        )
    }

    @MainActor
    private static func agua(_ m: AppModel) -> String? {
        CorpoContextFormat.agua(ml: m.waterMl, metaMl: m.waterGoalMl)
    }

    @MainActor
    private static func treino(_ m: AppModel) -> String? {
        let cal = Calendar.current
        let ultimosSete = (0..<7)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
            .map(CorpoInsightsEngine.chaveDia)

        return CorpoContextFormat.treino(
            treinouHoje: m.workoutDays.contains(CorpoInsightsEngine.chaveDia(Date())),
            vezesNaSemana: ultimosSete.filter { m.workoutDays.contains($0) }.count
        )
    }

    @MainActor
    private static func peso(_ m: AppModel) -> String? {
        let ordenado = m.weightLog.sorted { $0.date < $1.date }

        // Sem histórico, cai para a medida do perfil — que também é um registro
        // real, informado pela pessoa.
        guard let ultimo = ordenado.last else {
            return CorpoContextFormat.peso(atual: m.weightKg, variacao: nil)
        }
        let variacao = ordenado.count >= 2 ? ultimo.kg - ordenado[0].kg : nil
        return CorpoContextFormat.peso(atual: ultimo.kg, variacao: variacao)
    }

    @MainActor
    private static func suplementos(_ m: AppModel) -> String? {
        CorpoContextFormat.suplementos(
            tomadosHoje: m.supplements.filter { m.supplementTakenToday($0) }.count,
            total: m.supplements.count
        )
    }

    /// Objetivo, restrições e limitações — o que muda o que a Alma PODE sugerir.
    @MainActor
    private static func perfil(_ m: AppModel) -> String? {
        CorpoContextFormat.perfil(
            objetivo: m.goal.rawValue,
            restricoes: m.dietaryRestrictions,
            condicoes: m.healthConditions
        )
    }
}
