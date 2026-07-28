// ChatHistoryStore.swift
// Alma App — Persistência local do histórico do chat da Alma
//
// [Build 84 — 2026-07-28] Correção: a conversa sumia ao sair do chat porque
// `ChatView.messages` era apenas @State em memória. O servidor já gravava o
// histórico em Firestore (users/{uid}/messages, escrito pela Cloud Function),
// mas o app nunca o lia.
//
// Estratégia em duas camadas:
//   1. Cache local (JSON por usuário em Application Support, excluído do
//      backup do iCloud) — leitura instantânea ao abrir o chat, sobrevive a
//      fechar o app, funciona offline.
//   2. Hidratação do Firestore — se o cache local estiver vazio (primeira
//      execução desta versão ou reinstalação), busca as últimas mensagens em
//      users/{uid}/messages (regra do Firestore permite leitura pelo próprio
//      usuário) e semeia o cache local.
//
// Privacidade (mesmo padrão do UserMemoryManager/LocalDataCleanupService):
//   • arquivo separado por uid — troca de conta nunca vaza conversa
//   • deleteAll() chamado no logout e na deleção de conta
//   • Avisos transitórios (erros de rede etc., `isTransient`) não são gravados

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class ChatHistoryStore {

    static let shared = ChatHistoryStore()

    /// Máximo de mensagens mantidas no cache local (as mais recentes).
    private let maxStoredMessages = 500

    /// Quantas mensagens buscar do Firestore ao hidratar um cache vazio.
    private let remoteHydrationLimit = 100

    private let queue = DispatchQueue(label: "com.almaapp.chat-history", qos: .utility)

    private init() {}

    // MARK: - API

    /// Carrega o histórico local do usuário atual (síncrono, rápido — JSON local).
    func loadLocal(uid: String) -> [ChatMessage] {
        guard let url = fileURL(for: uid),
              let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode([ChatMessage].self, from: data)) ?? []
    }

    /// Acrescenta uma mensagem ao histórico local (ignora transitórias).
    func append(_ message: ChatMessage, uid: String) {
        guard !message.isTransient else { return }
        queue.async { [weak self] in
            guard let self else { return }
            var current = self.loadLocal(uid: uid)
            current.append(message)
            if current.count > self.maxStoredMessages {
                current.removeFirst(current.count - self.maxStoredMessages)
            }
            self.write(current, uid: uid)
        }
    }

    /// Substitui o histórico local inteiro (usado na hidratação do Firestore).
    func replaceAll(_ messages: [ChatMessage], uid: String) {
        queue.async { [weak self] in
            guard let self else { return }
            var kept = messages.filter { !$0.isTransient }
            if kept.count > self.maxStoredMessages {
                kept.removeFirst(kept.count - self.maxStoredMessages)
            }
            self.write(kept, uid: uid)
        }
    }

    /// Busca o histórico remoto (users/{uid}/messages) para hidratar cache vazio.
    /// Retorna em ordem cronológica. Falha silenciosa (offline etc.) → [].
    func fetchRemoteHistory(uid: String) async -> [ChatMessage] {
        do {
            let snap = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: remoteHydrationLimit)
                .getDocuments()

            let messages: [ChatMessage] = snap.documents.reversed().compactMap { doc in
                let data = doc.data()
                guard let role = data["role"] as? String,
                      let content = data["content"] as? String else { return nil }
                let ts = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                return ChatMessage(text: content, isUser: role == "user", timestamp: ts)
            }
            return messages
        } catch {
            #if DEBUG
            print("ChatHistoryStore: hidratação remota falhou (não-fatal): \(error)")
            #endif
            return []
        }
    }

    // MARK: - Limpeza (logout / deleção de conta / troca de usuário)

    /// Remove todos os arquivos de histórico de chat de todos os usuários.
    static func deleteAll() {
        guard let dir = historyDirectory() else { return }
        try? FileManager.default.removeItem(at: dir)
        print("🧹 ChatHistoryStore: histórico local de chat removido")
    }

    // MARK: - Arquivo

    private static func historyDirectory() -> URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        return base.appendingPathComponent("AlmaChatHistory", isDirectory: true)
    }

    private func fileURL(for uid: String) -> URL? {
        guard let dir = Self.historyDirectory() else { return nil }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // uid vem do Firebase Auth (alfanumérico), mas sanitiza por segurança.
        let safe = uid.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("history-\(safe).json")
    }

    private func write(_ messages: [ChatMessage], uid: String) {
        guard let url = fileURL(for: uid) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(messages) else { return }
        do {
            try data.write(to: url, options: .atomic)
            // Dado pessoal sensível: fora do backup iCloud + protegido em disco.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(values)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            #if DEBUG
            print("ChatHistoryStore: falha ao gravar histórico: \(error)")
            #endif
        }
    }
}
