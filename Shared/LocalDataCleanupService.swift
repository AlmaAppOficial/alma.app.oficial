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

        // Etapa 2 — varredura por prefixo alma_ (pega keys dinâmicas)
        let allKeys = defaults.dictionaryRepresentation().keys
        let almaPrefixedKeys = allKeys.filter { $0.hasPrefix("alma_") }
        for key in almaPrefixedKeys {
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()

        print("🧹 LocalDataCleanupService.clearAll: removidas \(almaPrefixedKeys.count) keys com prefixo alma_ + lista explícita")

        // Keychain
        clearKeychain()
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
