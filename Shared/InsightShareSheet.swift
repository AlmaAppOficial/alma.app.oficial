import SwiftUI

struct InsightShareSheet: View {
    let insight: GuidanceInsight
    @Binding var isPresented: Bool

    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showActivitySheet = false

    private let renderWidth:  CGFloat = 1080
    private let renderHeight: CGFloat = 1350

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Card preview — GeometryReader measures real available width,
                // aspectRatio constrains height to card proportions (4:5),
                // containerWidth flows into card so all sizes scale proportionally.
                GeometryReader { geo in
                    InsightShareCardView(
                        quote: insight.quote,
                        author: insight.quoteAuthor,
                        containerWidth: geo.size.width
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rMedium))
                    .shadow(color: CalmTheme.primary.opacity(0.35), radius: 20, x: 0, y: 8)
                }
                .aspectRatio(renderWidth / renderHeight, contentMode: .fit)
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer()

                shareButton
                    .padding(.horizontal, 24)

                Button("Cancelar") { fechar() }
                    .font(.subheadline)
                    .foregroundColor(CalmTheme.textSecondary)
                    .padding(.bottom, 32)
            }
            .navigationTitle("Compartilhar insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") { fechar() }
                        .foregroundColor(CalmTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showActivitySheet) {
            if let image = renderedImage {
                ShareSheet(items: [image], isPresented: $showActivitySheet)
            }
        }
    }

    /// Fecha a tela. Zera o sheet filho ANTES de fechar o pai.
    ///
    /// [2026-08-04] Cinto e suspensório do bug da tela presa. O conserto de
    /// verdade está no `completionWithItemsHandler` do `ShareSheet` — mas se um
    /// dia esse handler deixar de disparar por qualquer motivo, o SwiftUI
    /// voltaria a achar que há um sheet filho aberto e engoliria o fechamento
    /// do pai. Limpar o estado do filho aqui custa uma linha e tira essa
    /// dependência do caminho de saída da pessoa.
    private func fechar() {
        showActivitySheet = false
        isPresented = false
    }

    private var shareButton: some View {
        Button(action: renderAndShare) {
            HStack(spacing: 8) {
                if isRendering {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isRendering ? "Preparando..." : "Compartilhar")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isRendering ? CalmTheme.primary.opacity(0.6) : CalmTheme.primary)
            .cornerRadius(CalmTheme.rMedium)
        }
        .disabled(isRendering)
    }

    @MainActor
    private func renderAndShare() {
        isRendering = true
        Task {
            let card = InsightShareCardView(
                quote: insight.quote,
                author: insight.quoteAuthor,
                containerWidth: renderWidth
            )
            .frame(width: renderWidth, height: renderHeight)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 2.0
            renderedImage = renderer.uiImage
            isRendering = false
            if renderedImage != nil {
                showActivitySheet = true
            }
        }
    }
}
