import SwiftUI
import FirebaseAnalytics

struct PaywallView: View {
    let offer: PricingOffer
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var store: StoreKitManager
    @EnvironmentObject var access: AccessManager
    @State private var isAnimating = false
    @State private var sheetHeight: CGFloat = .zero

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(CalmTheme.textSecondary)
                            .padding(16)
                    }
                }
                .background(CalmTheme.surface)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero Section with Gradient Background
                        VStack(spacing: 16) {
                            // Badge/Emoji
                            if let badge = offer.badge {
                                Text(badge)
                                    .font(.system(size: 48))
                                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                            isAnimating = true
                                        }
                                    }
                            }

                            // Title
                            Text(offer.title)
                                .font(.system(size: 28, weight: .bold, design: .default))
                                .foregroundColor(CalmTheme.textPrimary)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)

                            // Subtitle
                            Text(offer.subtitle)
                                .font(.subheadline)
                                .foregroundColor(CalmTheme.textSecondary)
                                .multilineTextAlignment(.center)

                            // Countdown if applicable
                            if let countdown = offer.countdown, countdown > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption)
                                    Text("\(countdown) dias restantes")
                                        .font(.caption.bold())
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [
                                    colorFromHex(offer.backgroundColor).opacity(0.15),
                                    colorFromHex(offer.backgroundColor).opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)

                        // Price Section
                        VStack(spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("R$")
                                    .font(.subheadline.bold())
                                    .foregroundColor(CalmTheme.textSecondary)

                                Text(String(format: "%.2f", offer.price))
                                    .font(.system(size: 44, weight: .bold, design: .default))
                                    .foregroundColor(colorFromHex(offer.backgroundColor))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(offer.period)
                                        .font(.caption)
                                        .foregroundColor(CalmTheme.textSecondary)

                                    if let discount = offer.discountPercent {
                                        Text("−\(discount)%")
                                            .font(.caption.bold())
                                            .foregroundColor(.green)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            // Description
                            Text(offer.description)
                                .font(.caption)
                                .foregroundColor(CalmTheme.textSecondary)
                                .lineLimit(3)
                        }

                        // Risk Reversal
                        VStack(spacing: 10) {
                            riskReversalItem(icon: "checkmark.circle.fill", text: "7 dias grátis")
                            riskReversalItem(icon: "checkmark.circle.fill", text: "Cancele quando quiser")
                            riskReversalItem(icon: "checkmark.circle.fill", text: "Sem surpresas")
                        }
                        .padding(16)
                        .background(CalmTheme.surface.opacity(0.5))
                        .cornerRadius(12)

                        // Included Features
                        VStack(alignment: .leading, spacing: 12) {
                            Text("O que está incluído")
                                .font(.subheadline.bold())
                                .foregroundColor(CalmTheme.textPrimary)

                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(offer.includedFeatures, id: \.self) { feature in
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(colorFromHex(offer.accentColor))
                                            .frame(width: 20)

                                        Text(feature)
                                            .font(.footnote)
                                            .foregroundColor(CalmTheme.textPrimary)
                                            .lineLimit(2)

                                        Spacer()
                                    }
                                }
                            }
                        }

                        // Social Proof
                        if let socialProof = offer.socialProof {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(socialProof)
                                    .font(.caption)
                                    .foregroundColor(CalmTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(CalmTheme.surface)
                            .cornerRadius(8)
                        }

                        // Urgency Text
                        if let urgencyText = offer.urgencyText {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text(urgencyText)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(20)
                }

                // CTA Button
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            // Tentar compra via Apple IAP
                            if let product = store.monthlyProduct {
                                let success = await store.purchase(product)
                                if success {
                                    await access.refresh()
                                    onSubscribe()
                                }
                            } else {
                                // Produto ainda não carregado — tentar novamente
                                await store.loadProducts()
                                if let product = store.monthlyProduct {
                                    let success = await store.purchase(product)
                                    if success {
                                        await access.refresh()
                                        onSubscribe()
                                    }
                                }
                            }
                        }
                    }) {
                        Group {
                            if store.isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(offer.cta)
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [
                                    colorFromHex(offer.backgroundColor),
                                    colorFromHex(offer.backgroundColor).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: colorFromHex(offer.backgroundColor).opacity(0.4), radius: 12, x: 0, y: 8)
                    }
                    .disabled(store.isPurchasing)

                    if let error = store.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }

                    Text("Renovação automática · Cancele quando quiser\nTermos de serviço · Política de privacidade")
                        .font(.caption)
                        .foregroundColor(CalmTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(20)
                .background(CalmTheme.surface)
            }
            .background(CalmTheme.background)
            .cornerRadius(24, corners: [.topLeft, .topRight])
            .transition(.move(edge: .bottom))
        }
        .onAppear {
            Task {
                await recordPaywallShown()
            }
        }
    }

    private func riskReversalItem(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundColor(CalmTheme.primary)
                .frame(width: 20)

            Text(text)
                .font(.footnote)
                .foregroundColor(CalmTheme.textPrimary)

            Spacer()
        }
    }

    private func recordPaywallShown() async {
        let manager = DynamicPricingManager.shared
        await manager.recordPaywallShown(offer: offer)
    }

    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Preview
#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        let standardOffer = PricingOffer(
            variant: .control,
            title: "Comece sua jornada",
            subtitle: "7 dias grátis para explorar",
            price: 24.99,
            period: "/mês",
            cta: "Iniciar 7 dias grátis",
            description: "Acesso completo por 7 dias, depois R$ 24,99/mês. Cancele quando quiser.",
            includedFeatures: [
                "500+ meditações guiadas",
                "Sons ambientes relaxantes",
                "Exercícios de respiração",
                "Insights de humor diário"
            ],
            socialProof: "4.8 ★ · 2.400 avaliações"
        )

        Group {
            PaywallView(
                offer: standardOffer,
                onSubscribe: {},
                onDismiss: {}
            )
            .preferredColorScheme(.dark)

            PaywallView(
                offer: standardOffer,
                onSubscribe: {},
                onDismiss: {}
            )
            .preferredColorScheme(.light)
        }
    }
}
#endif

// MARK: - Custom Rounded Corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
