// LegacyEntitlementStore.swift
// Alma App — entitlement herdado do Corpo & Alma (assinatura única)
//
// [Fusão — 2026-08-02] REQUISITO BLOQUEANTE DA FASE 1
//
// Decisão do Assis: depois da fusão o Corpo & Alma será DESCONTINUADO e passa a
// existir uma assinatura única, no Alma. Quem já assinou o C&A **mantém o
// acesso** — ninguém assina de novo.
//
// O PROBLEMA QUE ISTO RESOLVE
// A ponte de App Group (`corpoealma_isPremium`) só funciona enquanto os DOIS
// apps estão instalados, e o flag vale 30 dias. Depois da descontinuação, o
// assinante que apagar o C&A perderia o acesso pago silenciosamente, em 30 dias.
// StoreKit não ajuda: `Transaction.currentEntitlements` só enxerga compras do
// PRÓPRIO app — a assinatura do C&A é invisível para o Alma.
//
// A SOLUÇÃO
// Na primeira vez que o Alma vê a ponte ativa, ele **carimba um entitlement
// permanente**, em duas camadas:
//   1. Keychain (`kSecAttrAccessibleAfterFirstUnlock`) — funciona offline e
//      sem conta, e sobrevive à remoção do C&A;
//   2. Firestore (`users/{uid}.legacyCorpoEntitlement`) — sobrevive à troca de
//      aparelho e à reinstalação do próprio Alma, amarrado à conta.
//
// A partir do carimbo, o acesso NÃO depende mais da ponte nem de prazo.
//
// JANELA CRÍTICA: o carimbo só acontece enquanto o C&A ainda está instalado.
// Por isso a ordem das fases é inegociável — **capturar antes de descontinuar**.

import Foundation
import Security
import FirebaseAuth
import FirebaseFirestore

enum LegacyEntitlementStore {

    private static let service = "com.almaapp.app.legacy-entitlement"
    private static let account = "corpoealma"
    private static let firestoreField = "legacyCorpoEntitlement"
    private static let firestoreDateField = "legacyCorpoEntitlementAt"

    // MARK: - Leitura

    /// O usuário tem o acesso herdado do Corpo & Alma? (permanente, sem prazo)
    static var isGranted: Bool {
        readKeychain() != nil
    }

    /// Quando o entitlement foi carimbado (para suporte e auditoria).
    static var grantedAt: Date? {
        guard let raw = readKeychain(), let seconds = Double(raw) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    // MARK: - Escrita

    /// Carimba o entitlement herdado. Idempotente: uma vez gravado, não muda a
    /// data. Chamado quando a ponte do C&A aparece ativa.
    static func grant(reason: String) {
        guard !isGranted else { return }

        writeKeychain(String(Date().timeIntervalSince1970))
        print("🎁 LegacyEntitlementStore: acesso herdado do Corpo & Alma carimbado (\(reason))")

        // Espelha na conta para sobreviver a troca de aparelho / reinstalação.
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).setData([
            firestoreField: true,
            firestoreDateField: FieldValue.serverTimestamp(),
            "legacyCorpoEntitlementReason": reason
        ], merge: true) { error in
            if let error {
                print("⚠️ LegacyEntitlementStore: falha ao espelhar no Firestore: \(error.localizedDescription)")
            }
        }
    }

    /// Restaura o entitlement a partir da conta (novo aparelho ou reinstalação
    /// do Alma, quando o C&A já não existe para reativar a ponte).
    @discardableResult
    static func restoreFromAccount() async -> Bool {
        guard !isGranted, let uid = Auth.auth().currentUser?.uid else { return isGranted }
        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if snap.data()?[firestoreField] as? Bool == true {
                writeKeychain(String(Date().timeIntervalSince1970))
                print("🎁 LegacyEntitlementStore: acesso herdado restaurado da conta")
                return true
            }
        } catch {
            print("⚠️ LegacyEntitlementStore: falha ao restaurar da conta: \(error.localizedDescription)")
        }
        return false
    }

    /// Remove o carimbo local. Usado APENAS na deleção de conta — nunca no
    /// logout comum, para não tirar acesso de quem pagou.
    static func deleteLocal() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Keychain

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    private static func writeKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

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
            print("⚠️ LegacyEntitlementStore.write falhou: \(status)")
        }
    }
}
