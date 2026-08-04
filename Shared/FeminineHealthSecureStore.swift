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

    // [Build 84 — 2026-07-28] Novas chaves (sem legado em UserDefaults)
    private static let periodLengthKey = "alma_cycle_periodLength"
    private static let periodHistoryKey = "alma_cycle_periodHistory"
    private static let symptomsKey = "alma_cycle_symptoms"

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

    // MARK: - [Build 84] Duração da menstruação, histórico de ciclos e sintomas

    /// Duração da menstruação em dias. Padrão: 5 (valor que era fixo no código).
    static var periodLength: Int {
        get { readInt(periodLengthKey) ?? 5 }
        set { write(String(newValue), forKey: periodLengthKey) }
    }

    /// Histórico de inícios de menstruação (timestamps, ordem crescente).
    /// Na primeira leitura, semeia com `lastPeriodTimestamp` legado se existir.
    static var periodHistory: [Double] {
        get {
            let decidido = decidirHistórico(bruto: read(periodHistoryKey),
                                            legado: lastPeriodTimestamp)
            if decidido.precisaGravar { persistirHistórico(decidido.lista) }
            return decidido.lista
        }
        set { persistirHistórico(newValue) }
    }

    /// Decide o histórico a partir do que está gravado e do valor legado.
    ///
    /// [2026-08-04] Existe por dois motivos.
    ///
    /// 1) Antes, a migração fazia `periodHistory = seeded` DENTRO do próprio
    ///    getter, e o compilador acusava: "attempting to access 'periodHistory'
    ///    within its own getter". NÃO era recursão infinita — atribuir chama o
    ///    SETTER, não o getter. Está provado em
    ///    `_validacao_20260804/probe_periodHistory.swift`, que reproduz o mesmo
    ///    aviso, roda até o fim e conta 2 chamadas do getter. Mas um getter que
    ///    escreve em si mesmo por caminho indireto é difícil de ler, e o aviso
    ///    ficava permanentemente ligado escondendo os próximos.
    ///
    /// 2) Isolada do Keychain de propósito: assim a REGRA pode ser verificada
    ///    sem gravar nada. Isto é dado de saúde — um teste que escrevesse no
    ///    Keychain de verdade apagaria o histórico real de uma pessoa. Nenhuma
    ///    asserção vale esse preço.
    ///
    /// - Returns: a lista a devolver e se ela ainda precisa ser persistida.
    static func decidirHistórico(bruto: String?, legado: Double) -> (lista: [Double], precisaGravar: Bool) {
        if let raw = bruto,
           let data = raw.data(using: .utf8),
           let lista = try? JSONDecoder().decode([Double].self, from: data) {
            return (lista, false)               // já gravado: nada a migrar
        }
        if legado > 0 {
            return ([legado], true)             // um registro legado vira o 1º item
        }
        return ([], false)                      // nada gravado, nada legado
    }

    /// Grava o histórico no Keychain. Único ponto de escrita da chave —
    /// usado pelo setter e pela migração do valor legado.
    private static func persistirHistórico(_ histórico: [Double]) {
        if let data = try? JSONEncoder().encode(histórico),
           let raw = String(data: data, encoding: .utf8) {
            write(raw, forKey: periodHistoryKey)
        }
    }

    /// Sintomas registrados por dia: ["yyyy-MM-dd": ["colica", "inchaco", …]].
    /// Mantém no máximo 90 dias (os mais recentes).
    static var symptomsByDay: [String: [String]] {
        get {
            guard let raw = read(symptomsKey),
                  let data = raw.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            var capped = newValue
            if capped.count > 90 {
                let sortedKeys = capped.keys.sorted()          // "yyyy-MM-dd" ordena lexicograficamente
                for key in sortedKeys.prefix(capped.count - 90) {
                    capped.removeValue(forKey: key)
                }
            }
            if let data = try? JSONEncoder().encode(capped),
               let raw = String(data: data, encoding: .utf8) {
                write(raw, forKey: symptomsKey)
            }
        }
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
