import Foundation
import Security

/// Persistência segura dos dados de saúde feminina (ciclo menstrual + gravidez)
/// no Keychain (kSecClassGenericPassword, acessível após o primeiro desbloqueio).
///
/// Substitui o armazenamento anterior em @AppStorage/UserDefaults (plaintext),
/// por se tratar de dados de saúde sensíveis (LGPD Art. 5º, II — dado sensível).
///
/// Migração transparente: na primeira leitura de cada chave, se existir valor
/// legado em UserDefaults, ele é importado para o Keychain e removido do
/// UserDefaults. As chaves mantêm os mesmos nomes usados anteriormente.
enum FeminineHealthSecureStore {

    private static let service = "com.almaapp.app.feminine-health"

    // Mesmos nomes das chaves legadas em UserDefaults (para migração transparente)
    private static let lastPeriodKey = "alma_cycle_lastPeriod"
    private static let cycleLengthKey = "alma_cycle_length"
    private static let pregnancyModeKey = "alma_pregnancy_mode"
    private static let dueDateKey = "alma_pregnancy_dueDate"

    // MARK: - Typed accessors

    /// Timestamp (timeIntervalSince1970) do início da última menstruação. 0 = não definido.
    static var lastPeriodTimestamp: Double {
        get { readDouble(lastPeriodKey) ?? 0 }
        set { write(String(newValue), forKey: lastPeriodKey) }
    }

    /// Duração do ciclo em dias. Padrão: 28.
    static var cycleLength: Int {
        get { readInt(cycleLengthKey) ?? 28 }
        set { write(String(newValue), forKey: cycleLengthKey) }
    }

    /// Modo gravidez ativo.
    static var pregnancyMode: Bool {
        get { readBool(pregnancyModeKey) ?? false }
        set { write(newValue ? "true" : "false", forKey: pregnancyModeKey) }
    }

    /// Timestamp (timeIntervalSince1970) da data prevista do parto. 0 = não definido.
    static var dueDateTimestamp: Double {
        get { readDouble(dueDateKey) ?? 0 }
        set { write(String(newValue), forKey: dueDateKey) }
    }

    // MARK: - Cleanup (logout / deleção de conta)

    /// Remove todos os dados de saúde feminina do Keychain.
    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Typed reads (com migração do UserDefaults legado)

    private static func readDouble(_ key: String) -> Double? {
        if let raw = read(key), let value = Double(raw) { return value }
        // Migração: importa valor legado do UserDefaults e remove de lá
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            let value = defaults.double(forKey: key)
            write(String(value), forKey: key)
            defaults.removeObject(forKey: key)
            return value
        }
        return nil
    }

    private static func readInt(_ key: String) -> Int? {
        if let raw = read(key), let value = Int(raw) { return value }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            let value = defaults.integer(forKey: key)
            write(String(value), forKey: key)
            defaults.removeObject(forKey: key)
            return value
        }
        return nil
    }

    private static func readBool(_ key: String) -> Bool? {
        if let raw = read(key) { return raw == "true" }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            let value = defaults.bool(forKey: key)
            write(value ? "true" : "false", forKey: key)
            defaults.removeObject(forKey: key)
            return value
        }
        return nil
    }

    // MARK: - Keychain primitives

    private static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func write(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Remove valor antigo antes de inserir o novo (evita errSecDuplicateItem)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ FeminineHealthSecureStore.write(\(key)) failed: \(status)")
        }
    }
}
