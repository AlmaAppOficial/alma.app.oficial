import Foundation
import Security

// Limpa dados locais do usuário no logout e na deleção de conta.
//
// Dois modos:
//  • clearAll()           — deleção de conta: apaga TUDO via lista explícita + varredura prefixo "alma_" + Keychain
//  • clearUserData(uid:)  — logout normal: apaga dados do usuário, preserva preferências de UI
//
// Exigido por:
//  - Apple Guideline 5.1.1(v) — deleção deve remover todos os dados locais
//  - LGPD Art. 18 / GDPR Art. 17 — direito ao esquecimento
enum LocalDataCleanupService {

    // MARK: - Account Deletion (nuclear)

    /// Apaga absolutamente todos os UserDefaults do app + entradas do Keychain.
    /// Chamar imediatamente antes de Auth.signOut() no fluxo de deleção de conta.
    static func clearAll() {
        // Estratégia híbrida (Opção 2):
        //   1) Reusa removeAllKnownKeys() — apaga as 31 keys
        //      conhecidas + 3 uiKeys (isDarkMode + áudio).
        //      Em deleção de conta, queremos apagar tudo, inclusive UI.
        //   2) Varre UserDefaults e apaga keys com prefixo "alma_"
        //      (pega keys dinâmicas como alma_user_<uid>_data,
        //       alma_msg_count_<date>) sem tocar em prefs de SDKs
        //      (Firebase, Google, Facebook usam outros prefixos).
        //   3) Não usa removePersistentDomain para evitar tocar em
        //      prefs de frameworks que o app pode precisar depois.

        let defaults = UserDefaults.standard

        // Etapa 1 — lista explícita
        removeAllKnownKeys()

        // [Fusão 2026-08-02] Deleção de conta apaga TUDO, inclusive o carimbo do
        // acesso herdado do Corpo & Alma. No logout comum ele é PRESERVADO —
        // tirar acesso de quem pagou seria erro grave.
        LegacyEntitlementStore.deleteLocal()
        HealthContextConsent.revokeAll()

        // Etapa 2 — varredura por prefixo alma_ (pega keys dinâmicas)
        let allKeys = defaults.dictionaryRepresentation().keys
        let almaPrefixedKeys = allKeys.filter { $0.hasPrefix("alma_") }
        for key in almaPrefixedKeys {
            defaults.removeObject(forKey: key)
        }

        // Etapa 3 — módulo Corpo e perfil compartilhado.
        //
        // [2026-08-03 — BUG B9 da revisão independente]
        // Este serviço só olhava para `UserDefaults.standard` e para o prefixo
        // `alma_`. Os dados do Corpo não têm esse prefixo, e o perfil vive no
        // App Group — ou seja, a "exclusão de conta" deixava para trás peso,
        // altura, gordura corporal, histórico de pesagens, refeições,
        // suplementos, **alergias alimentares**, condições de saúde, nome e
        // data de nascimento.
        //
        // Na prática: quem excluísse a conta e passasse o aparelho adiante
        // entregava junto as próprias alergias. É LGPD Art. 18 e App Store
        // 5.1.1(v), e era uma promessa quebrada — a tela de Ajustes do Corpo
        // dizia, em texto, que a exclusão apagava "os dados dos dois módulos".
        limparDadosDoCorpo(defaults)
        limparPerfilCompartilhado()

        defaults.synchronize()

        // Etapa 4 — lembretes agendados. [A3] Sem isto, notificações de marco
        // ("1 MÊS SEM VÍCIO!") continuavam disparando depois da conta apagada.
        Task { await GradeDeLembretes.limparTudo() }

        print("🧹 LocalDataCleanupService.clearAll: \(almaPrefixedKeys.count) keys alma_ + lista explícita + Corpo + App Group + lembretes")

        // [2026-08-04 — D-2] Zera o singleton do perfil EM MEMÓRIA. Sem isto,
        // apagar o disco não bastava: o nome do excluído voltava na conta
        // seguinte, porque o app não reinicia entre uma sessão e outra.
        UserProfileStore.resetar()

        // Keychain
        clearKeychain()
    }

    /// Chaves do módulo Corpo — nenhuma delas tem prefixo `alma_`, então a
    /// varredura por prefixo passava por cima de todas.
    private static func limparDadosDoCorpo(_ defaults: UserDefaults) {
        let chavesDoCorpo = [
            // Perfil corporal e medidas
            "userName", "goal", "sexBiological", "activityLevel",
            "weightKg", "heightCm", "ageYears", "bodyFat",
            "dietaryRestrictions", "healthConditions",   // alergias e condições
            // Registros do dia a dia
            "mealsToday", "mealsDate", "waterMl", "lastWaterDate",
            "userFoods", "supplements", "supplementsTaken", "supplementsTakenDate",
            "customKcalGoal", "planAppliedAt", "scanResult",
            // Séries históricas
            "weightLog", "kcalByDay", "workoutDays",
            "customWorkouts", "workoutPlan", "mealPlan",
            // Preferências do módulo
            "notifyWater", "notifyMeals", "notifyWorkout",
            "notifySupplements", "supplementHour",
            // [2026-08-04 — D-4] "appearance" era chave ERRADA: o que o app
            // grava é "appearanceMode" (Corpo/Models.swift:268). Mantidas as
            // duas — a antiga pode existir em instalações velhas.
            "appearance", "appearanceMode", "hasOnboarded", "isPremium",
            "trialStartedAt", "healthDisclaimerAccepted",
            // [2026-08-04 — D-4] Faltavam, e todas guardam dado pessoal:
            "offProductCache",          // o que a pessoa escaneou e comeu
            "meta_consent_granted",     // a tela promete apagar o consentimento
            "meta_consent_asked"
        ]
        chavesDoCorpo.forEach { defaults.removeObject(forKey: $0) }
    }

    /// Perfil no App Group — compartilhado entre Alma e Corpo. O serviço nunca
    /// abria esta suite, então nome e data de nascimento sobreviviam à exclusão.
    private static func limparPerfilCompartilhado() {
        guard let suite = UserDefaults(suiteName: "group.com.almaapp.shared") else { return }
        for chave in suite.dictionaryRepresentation().keys where chave.hasPrefix("perfil_") {
            suite.removeObject(forKey: chave)
        }
        // Ponte de entitlement entre os apps: some junto na exclusão de conta.
        // [2026-08-04 — D-3/D-4] `alma_active` faltava (o AccessManager o
        // republica no signOut) e `shared_user_name` também — é o nome gravado
        // pelo C&A standalone, que a varredura por prefixo `perfil_` nunca
        // alcançava.
        ["alma_isPremium", "corpoealma_isPremium",
         "alma_premium_since", "corpoealma_premium_since",
         "alma_active", "corpoealma_active",
         "alma_isPremium_updatedAt", "corpoealma_isPremium_updatedAt",
         "shared_user_name"].forEach {
            suite.removeObject(forKey: $0)
        }
        suite.synchronize()
    }

    // MARK: - Limpeza pendente (D-1)

    /// [2026-08-04 — D-1] A exclusão passa por uma escrita IRREVERSÍVEL no
    /// Firestore. Se o app morrer entre ela e o fim da limpeza, o servidor
    /// apaga a conta e o aparelho fica com os dados de saúde para sempre.
    ///
    /// A marca é gravada antes de qualquer passo irreversível e só sai no fim.
    /// `AlmaApp` a consulta no boot: se ainda estiver lá, a limpeza é
    /// reexecutada. `clearAll()` é idempotente, então repetir é seguro.
    private static let chaveLimpezaPendente = "alma_limpezaPendente"

    static func marcarLimpezaPendente() {
        UserDefaults.standard.set(true, forKey: chaveLimpezaPendente)
        UserDefaults.standard.synchronize()
    }

    static func concluirLimpezaPendente() {
        UserDefaults.standard.removeObject(forKey: chaveLimpezaPendente)
        UserDefaults.standard.synchronize()
    }

    static var temLimpezaPendente: Bool {
        UserDefaults.standard.bool(forKey: chaveLimpezaPendente)
    }

    /// Chamado no boot. Devolve `true` quando havia uma limpeza interrompida.
    @discardableResult
    static func retomarLimpezaPendenteSeNecessario() -> Bool {
        guard temLimpezaPendente else { return false }
        clearAll()
        concluirLimpezaPendente()
        print("⚠️ LocalDataCleanupService: limpeza interrompida foi retomada e concluída no boot")
        return true
    }

    // MARK: - Logout (seletivo)

    /// Apaga dados pessoais e de sessão, preservando preferências de UI (isDarkMode, etc.)
    /// Chamar no logout normal para minimizar rastros do usuário no dispositivo.
    static func clearUserData(uid: String?) {
        let userSpecificKeys: [String] = [
            // StreakManager
            "alma_current_streak",
            "alma_longest_streak",
            "alma_last_meditation_date",
            "alma_total_meditation_days",
            "alma_streak_recoveries_used",
            "alma_last_recovery_date",
            "alma_meditation_history",

            // UserMemoryManager — identidade e perfil
            "alma_user_gender",
            "alma_user_birthTimeSlot",
            "alma_user_birthCity",
            "alma_user_birthCountry",

            // MoodRouter
            "moodHistory",

            // PaywallTriggerManager
            "alma_meditations_completed_count",
            "alma_paywall_streak_shown",
            "alma_last_paywall_shown",
            "alma_day3_paywall_shown",

            // HabitNotificationManager
            "notifications_auto_disabled",
            "last_notification_engagement",
            "notification_open_count",
            "app_install_date",

            // DynamicPricingManager
            "alma_pricing_conversions",
            "alma_pricing_ab_test",
            "alma_user_id",

            // FeedRepository
            "alma_feed_seeded_v1",

            // Feminine health
            "alma_cycle_lastPeriod",
            "alma_cycle_length",
            "alma_pregnancy_mode",
            "alma_pregnancy_dueDate",

            // Addiction tracker
            "alma_addiction_type",
            "alma_addiction_startTimestamp",
            "alma_addiction_isActive",
            "alma_addiction_cigarettesPerDay",
            "alma_addiction_pricePerPack",

            // Onboarding (limpar para que próximo usuário passe pelo fluxo)
            "onboardingComplete",
            "quickOnboardingComplete",
        ]

        let defaults = UserDefaults.standard
        for key in userSpecificKeys {
            defaults.removeObject(forKey: key)
        }

        // Chave dinâmica por UID (UserMemoryManager encrypted blob)
        if let uid = uid, !uid.isEmpty {
            defaults.removeObject(forKey: "alma_user_\(uid)_data")
        }

        // Chaves dinâmicas de mensagens diárias (alma_msg_count_YYYY-MM-DD)
        removePrefixedKeys(prefix: "alma_msg_count_", from: defaults)

        defaults.synchronize()
        print("✅ LocalDataCleanupService: dados do usuário removidos no logout")

        // Keychain
        clearKeychain()
    }

    // MARK: - Keychain

    private static func clearKeychain() {
        AppleAuthCodeKeychainStore.delete()
        FeminineHealthSecureStore.deleteAll()
        // [Build 84] Histórico local do chat da Alma (arquivo em Application
        // Support, por uid) — apagado no logout e na deleção de conta, no mesmo
        // ponto único que os demais dados sensíveis.
        ChatHistoryStore.deleteAll()
        print("✅ LocalDataCleanupService: Keychain limpo")
    }

    // MARK: - Helpers

    /// Remove todas as chaves com determinado prefixo do UserDefaults.
    private static func removePrefixedKeys(prefix: String, from defaults: UserDefaults) {
        let keysToRemove = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix)
        }
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
    }

    /// Fallback: remove chaves conhecidas individualmente (usado se bundleIdentifier for nulo).
    private static func removeAllKnownKeys() {
        clearUserData(uid: nil)
        // Preferências de UI — incluídas apenas no fallback de deleção total
        let uiKeys = ["isDarkMode", "AlmaAmbientSoundPreference", "AlmaAmbientVolume"]
        uiKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
