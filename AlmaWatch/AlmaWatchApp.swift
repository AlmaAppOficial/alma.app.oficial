// AlmaWatchApp.swift
// Alma — app do Apple Watch, ponto de entrada.
//
// Além da cena principal, registra a cena de notificação: os lembretes do
// iPhone (manhã/noite, água, treino, suplementos) espelham no relógio e,
// com a categoria ALMA_LEMBRETE, ganham a cara do Alma em vez do cartão
// genérico do sistema.

import SwiftUI
import WatchKit

@main
struct AlmaWatchApp: App {

    init() {
        // Acorda a ponte com o iPhone já na abertura (recebe contexto pendente).
        _ = WatchSync.shared
    }

    var body: some Scene {
        WindowGroup {
            AlmaWatchContentView()
        }

        WKNotificationScene(controller: NotificationController.self,
                            category: "ALMA_LEMBRETE")
    }
}
