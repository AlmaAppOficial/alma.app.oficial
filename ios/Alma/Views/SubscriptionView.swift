import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("✨ Alma Premium")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AlmaTheme.textPrimary)

                        Text("Desbloqueie todas as funcionalidades")
                            .font(.subheadline)
                            .foregroundColor(AlmaTheme.textSecondary)
                    }

                    // Features
                    VStack(spacing: 12) {
                        FeatureRow(icon: "sparkles", title: "Meditações ilimitadas", subtitle: "Acesso a todos os programas de meditação")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Análise avançada", subtitle: "Insights detalhados sobre seu bem-estar")
                        FeatureRow(icon: "brain.head.profile", title: "IA personalizada", subtitle: "Alma adapta-se às suas necessidades")
                        FeatureRow(icon: "bell.badge.fill", title: "Lembretes inteligentes", subtitle: "Notificações personalizadas no melhor momento")
                        FeatureRow(icon: "heart.fill", title: "Relatórios de saúde", subtitle: "Integração completa com Apple Health")
                    }
                    .padding(AlmaTheme.paddingPage)
                    .background(AlmaTheme.card)
                    .cornerRadius(AlmaTheme.radius)

                    // Pricing
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("3,99€/mês")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AlmaTheme.textPrimary)

                            Text("Primeiro mês grátis")
                                .font(.caption)
                                .foregroundColor(AlmaTheme.accent)
                        }

                        Button(action: {
                            // Purchase logic
                        }) {
                            Text("Começar 3 Dias Grátis")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(AlmaTheme.accentGradient)
                                .foregroundColor(.white)
                                .cornerRadius(AlmaTheme.radius)
                        }

                        Text("Após 3 dias, 3,99€/mês. Cancelar a qualquer momento.")
                            .font(.caption2)
                            .foregroundColor(AlmaTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(AlmaTheme.paddingPage)
                    .background(AlmaTheme.card)
                    .cornerRadius(AlmaTheme.radius)

                    Spacer(minLength: 20)
                }
                .padding(AlmaTheme.paddingPage)
            }
            .background(AlmaTheme.background)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AlmaTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AlmaTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AlmaTheme.textSecondary)
            }

            Spacer()
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager())
        .preferredColorScheme(.dark)
}
