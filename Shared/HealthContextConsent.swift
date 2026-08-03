// HealthContextConsent.swift
// Alma App — consentimento por categoria para o contexto de saúde da IA
//
// [Build 85 / 2.0 — 2026-07-31]
//
// Dado de saúde é dado pessoal sensível (LGPD Art. 5º, II) e exige consentimento
// ESPECÍFICO por finalidade (Art. 11) — um único "permitir tudo" seria frágil
// juridicamente e assustador na prática. Por isso: um interruptor por categoria,
// TODOS desligados por padrão, cada um com data de aceite (auditável, revogável).
//
// Regra de ouro do projeto (CLAUDE.md / corregedoria):
//   • dado bruto NUNCA sai do aparelho
//   • o que viaja é um resumo curto, montado localmente pelo HealthContextBuilder
//   • nada disso encosta em analytics, Meta ou Crashlytics — proibido pelos
//     próprios termos do HealthKit (dado de saúde não pode virar publicidade)
//
// Pensado para a FUSÃO com o Corpo & Alma: categorias novas (treino, dieta,
// ciclo) entram como mais um `case` — nenhuma outra parte do código muda.

import Foundation

enum HealthConsentCategory: String, CaseIterable, Identifiable {
    /// Passos, minutos de exercício e sono (HealthKit).
    case movementAndSleep = "movimento_sono"
    /// Meditação do dia e sequência (dados do próprio Alma).
    case meditation = "meditacao"
    /// Treino, alimentação, água, peso e suplementos — módulo Corpo.
    case fitnessAndDiet = "treino_dieta"
    /// Humor / check-in — vai como SINAL traduzido, nunca o registro em si.
    case mood = "humor"
    /// Ciclo menstrual — FORA deste build. Gancho pronto para entrar depois,
    /// com consentimento próprio e política de privacidade atualizada.
    case cycle = "ciclo"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movementAndSleep: return "Movimento e sono"
        case .meditation:       return "Meditação e sequência"
        case .fitnessAndDiet:   return "Corpo: treino, comida e peso"
        case .mood:             return "Como você tem se sentido"
        case .cycle:            return "Ciclo menstrual"
        }
    }

    /// O que a Alma passa a perceber — escrito na voz do usuário, sem jargão.
    var explanation: String {
        switch self {
        case .movementAndSleep:
            return "A Alma percebe quando você dormiu pouco ou passou o dia parado, e pode te acolher a partir disso."
        case .meditation:
            return "A Alma sabe se você já meditou hoje e há quantos dias você mantém sua prática."
        case .fitnessAndDiet:
            return "A Alma considera seus treinos, refeições, água, peso e suplementos registrados no Corpo."
        case .mood:
            return "A Alma percebe a tendência do seu humor — nunca o que você escreveu, só o padrão."
        case .cycle:
            return "A Alma considera apenas a fase do seu ciclo — nunca datas nem registros."
        }
    }

    /// Categorias disponíveis nesta versão do app.
    /// `fitnessAndDiet` entra na fusão; `cycle` exige decisão de privacidade.
    var isAvailableNow: Bool {
        switch self {
        // [2026-08-02] fitnessAndDiet e mood liberados: o módulo Corpo está
        // dentro do app e o humor passa a viajar como sinal traduzido.
        case .movementAndSleep, .meditation, .fitnessAndDiet, .mood: return true
        // Ciclo segue FORA por decisão de privacidade do projeto.
        case .cycle: return false
        }
    }

    fileprivate var storageKey: String { "alma_health_consent_\(rawValue)" }
    fileprivate var dateKey: String { "alma_health_consent_\(rawValue)_at" }
}

enum HealthContextConsent {

    private static let store = UserDefaults.standard

    /// Consentimento ativo para a categoria. Padrão: FALSE (opt-in explícito).
    static func isGranted(_ category: HealthConsentCategory) -> Bool {
        guard category.isAvailableNow else { return false }
        return store.bool(forKey: category.storageKey)
    }

    /// Registra (ou revoga) o consentimento, guardando a data para auditoria.
    static func set(_ granted: Bool, for category: HealthConsentCategory) {
        store.set(granted, forKey: category.storageKey)
        if granted {
            store.set(Date(), forKey: category.dateKey)
        } else {
            store.removeObject(forKey: category.dateKey)
        }
    }

    static func grantedDate(for category: HealthConsentCategory) -> Date? {
        store.object(forKey: category.dateKey) as? Date
    }

    /// Alguma categoria ativa? Se não, nenhum contexto é montado nem enviado —
    /// a Alma se comporta exatamente como antes desta versão.
    static var hasAnyConsent: Bool {
        HealthConsentCategory.allCases.contains { isGranted($0) }
    }

    /// Revoga tudo (usado no logout e na deleção de conta).
    static func revokeAll() {
        for category in HealthConsentCategory.allCases {
            store.removeObject(forKey: category.storageKey)
            store.removeObject(forKey: category.dateKey)
        }
    }
}
