// NotificationController.swift
// Alma Watch — a cara das notificações do Alma no pulso.
// Recebe os lembretes com categoria ALMA_LEMBRETE (manhã/noite da Alma,
// água/refeição/treino/suplemento do Corpo) e apresenta no visual da marca.

import SwiftUI
import WatchKit
import UserNotifications

final class NotificationController: WKUserNotificationHostingController<NotificationView> {

    private var titulo = "Alma"
    private var corpo = ""

    override var body: NotificationView {
        NotificationView(titulo: titulo, corpo: corpo)
    }

    override func didReceive(_ notification: UNNotification) {
        titulo = notification.request.content.title
        corpo = notification.request.content.body
    }
}

struct NotificationView: View {
    let titulo: String
    let corpo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(WatchTheme.almaText)
                Text(titulo)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(WatchTheme.almaBright)
            }
            Text(corpo)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(WatchTheme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WatchTheme.heroAlma,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
