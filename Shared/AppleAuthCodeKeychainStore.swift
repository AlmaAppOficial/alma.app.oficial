import Foundation
import Security

/// Armazena o authorizationCode do Apple Sign In no Keychain
/// para uso posterior na revogação de token (Apple Guideline 5.1.1(v)).
///
/// O authorizationCode só é entregue pela Apple no momento do login,
/// e precisa ser salvo para ser usado depois na deleção de conta via
/// Auth.auth().revokeToken(withAuthorizationCode:).
enum AppleAuthCodeKeychainStore {

    private static let service = "com.almaapp.app.apple-auth-code"
    private static let account = "appleAuthorizationCode"

    /// Salva (ou substitui) o authorizationCode no Keychain.
    static func save(_ code: String) {
        guard let data = code.data(using: .utf8) else { return }

        // Remove valor antigo antes de inserir o novo (evita errSecDuplicateItem)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ AppleAuthCodeKeychainStore.save failed: \(status)")
        }
    }

    /// Recupera o authorizationCode salvo (nil se não existir — usuário antigo).
    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let code = String(data: data, encoding: .utf8) else {
            return nil
        }
        return code
    }

    /// Remove o authorizationCode do Keychain (chamar após revogação bem-sucedida).
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
