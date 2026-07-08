// CorpoAlmaBannerView.swift
// Alma App — Banner de cross-promotion: Corpo & Alma
//
// Exibe promoção cruzada para o app parceiro "Corpo & Alma".
// Toque no header expande detalhes; botão CTA abre o app ou a App Store.
// Desconto de 30% destacado conforme identidade da campanha.

import SwiftUI
import UIKit

struct CorpoAlmaBannerView: View {
    @State private var isExpanded = false

    private let teal     = Color(red: 0.12, green: 0.68, blue: 0.50)
    private let tealDeep = Color(red: 0.08, green: 0.50, blue: 0.38)

    // MARK: - Deep link / App Store

    /// Tenta abrir o app Corpo & Alma via URL scheme.
    /// Se não estiver instalado, cai para a página na App Store.
    ///
    /// NOTA: para `canOpenURL` funcionar com schemes customizados, adicione
    /// "corpoealma" em LSApplicationQueriesSchemes no Info.plist do target iOS.
    ///
    /// TODO: quando o app for publicado, substituir a URL da App Store pelo
    /// link definitivo com o ID do app. Ex:
    ///   https://apps.apple.com/app/id1234567890
    private func openCorpoAlmaApp() {
        let schemeURL = URL(string: "corpoealma://")!
        if UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(schemeURL)
            return
        }
        // Fallback: App Store (placeholder — atualizar com ID real quando publicado)
        if let storeURL = URL(string: "https://apps.apple.com/app/corpo-alma/") {
            UIApplication.shared.open(storeURL)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(CalmTheme.surface)
        .cornerRadius(CalmTheme.rMedium)
        .overlay(
            RoundedRectangle(cornerRadius: CalmTheme.rMedium)
                .strokeBorder(
                    LinearGradient(
                        colors: [teal.opacity(0.45), tealDeep.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: teal.opacity(0.10), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.28), value: isExpanded)
    }

    // MARK: - Header row

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: [teal, tealDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 50, height: 50)
                .cornerRadius(12)

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("APP PARCEIRO")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(teal)
                        .kerning(1.2)

                    Text("30% OFF")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(4)
                }

                Text("Corpo & Alma")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)

                Text("Cuide do corpo enquanto nutre a mente")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.bold())
                .foregroundColor(CalmTheme.textSecondary.opacity(0.6))
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.28)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .opacity(0.25)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 8) {
                Text("Mente e corpo em equilíbrio")
                    .font(.subheadline.bold())
                    .foregroundColor(CalmTheme.textPrimary)
                    .padding(.horizontal, 14)

                Text("O Alma cuida da sua mente. O Corpo & Alma cuida do seu corpo — treinos, nutrição e avaliação física. Juntos, formam o par completo para uma vida equilibrada.")
                    .font(.caption)
                    .foregroundColor(CalmTheme.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    benefitChip(icon: "dumbbell.fill",             label: "Treinos")
                    benefitChip(icon: "fork.knife",                label: "Nutrição")
                    benefitChip(icon: "figure.walk",               label: "Atividade")
                    benefitChip(icon: "chart.line.uptrend.xyaxis", label: "Insights")
                    benefitChip(icon: "heart.text.square.fill",    label: "Saúde")
                }
                .padding(.horizontal, 14)
            }

            HStack(spacing: 10) {
                Image(systemName: "tag.fill")
                    .font(.caption.bold())
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("30% de desconto exclusivo")
                        .font(.caption.bold())
                        .foregroundColor(CalmTheme.textPrimary)
                    Text("Para usuários do Alma")
                        .font(.system(size: 10))
                        .foregroundColor(CalmTheme.textSecondary)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.07))
            .cornerRadius(10)
            .padding(.horizontal, 14)

            // CTA: abre o app (se instalado) ou a App Store
            Button(action: openCorpoAlmaApp) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.subheadline)
                    Text("Baixar / Abrir app")
                        .font(.subheadline.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [teal, tealDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Chip helper

    private func benefitChip(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(teal)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(teal.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(teal.opacity(0.2), lineWidth: 0.5)
        )
    }
}

#if DEBUG
#Preview {
    ScrollView {
        CorpoAlmaBannerView()
            .padding()
    }
    .background(Color.gray.opacity(0.08))
}
#endif