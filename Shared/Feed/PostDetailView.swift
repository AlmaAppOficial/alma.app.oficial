import SwiftUI

// MARK: - CreateFeedPostView (Build 77 — admin creation flow)
//
// File path kept as PostDetailView.swift to avoid pbxproj edits. The contents
// are the new Build 77 admin-only post creator.
//
// Flow:
//   1. Admin pastes a URL → tap "Buscar Preview"
//   2. Cloud Function tries to fetch OpenGraph metadata.
//      - If success (YouTube/Spotify/Facebook/Twitter/generic) → post is
//        already saved server-side. We dismiss with success.
//      - If Instagram, or OG fetch fails → server returns mode: "manual",
//        we expand the form for the admin to type the title and description,
//        then re-call with manualTitle/manualDescription.

struct CreateFeedPostView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var url: String = ""
    @State private var manualTitle: String = ""
    @State private var manualDescription: String = ""

    @State private var detectedSource: FeedSource = .generic
    @State private var showManualForm: Bool = false
    @State private var manualReason: String = ""

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    private let repository = FeedRepository.shared

    var body: some View {
        NavigationStack {
            ZStack {
                CalmTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        urlField

                        if showManualForm {
                            manualFormSection
                        }

                        if let errorMessage {
                            banner(text: errorMessage, color: .red)
                        }
                        if let successMessage {
                            banner(text: successMessage, color: .green)
                        }

                        submitButton

                        Spacer(minLength: 24)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nova publicação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundColor(CalmTheme.primary)
                }
            }
        }
    }

    // MARK: - URL field

    @ViewBuilder
    private var urlField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Link")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)

            TextField("https://...", text: $url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(12)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
                .onChange(of: url) { newValue in
                    if showManualForm {
                        showManualForm = false
                        manualReason = ""
                    }
                    detectedSource = detectSource(from: newValue)
                }

            if !url.isEmpty {
                HStack(spacing: 8) {
                    SourceBadge(source: detectedSource)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Manual form section

    @ViewBuilder
    private var manualFormSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let intro: String = {
                if detectedSource == .instagram {
                    return "Instagram não permite buscar preview automaticamente. Preencha manualmente:"
                }
                return "Não foi possível buscar preview. Preencha manualmente:"
            }()
            Text(intro)
                .font(.system(size: 12))
                .foregroundColor(CalmTheme.textSecondary)

            Text("Título")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)

            TextField("Título da publicação", text: $manualTitle, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))

            Text("Descrição (opcional)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)
                .padding(.top, 4)

            TextField("Curta descrição...", text: $manualDescription, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
        }
        .padding(.top, 4)
    }

    // MARK: - Submit button

    @ViewBuilder
    private var submitButton: some View {
        Button(action: submit) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                Text(submitButtonLabel)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? CalmTheme.primary : CalmTheme.primary.opacity(0.4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
        }
        .disabled(!canSubmit || isSubmitting)
        .padding(.top, 4)
    }

    private var submitButtonLabel: String {
        if showManualForm { return "Publicar" }
        return "Buscar preview e publicar"
    }

    private var canSubmit: Bool {
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if showManualForm {
            return !manualTitle.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    // MARK: - Submit

    private func submit() {
        errorMessage = nil
        successMessage = nil
        isSubmitting = true

        Task {
            do {
                let trimmedURL = url.trimmingCharacters(in: .whitespaces)
                let manualT = showManualForm
                    ? manualTitle.trimmingCharacters(in: .whitespaces) : nil
                let manualD = showManualForm
                    ? manualDescription.trimmingCharacters(in: .whitespaces) : nil

                let result = try await repository.createPost(
                    url: trimmedURL,
                    manualTitle: manualT,
                    manualDescription: manualD
                )

                switch result {
                case .preview:
                    successMessage = "Publicação criada."
                    isSubmitting = false
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    dismiss()

                case .needsManual(let source, let reason):
                    detectedSource = source
                    manualReason = reason
                    showManualForm = true
                    isSubmitting = false
                }
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Source detection (client-side preview only)

    private func detectSource(from url: String) -> FeedSource {
        guard let host = URL(string: url)?.host?.lowercased() else { return .generic }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        if bare == "instagram.com" || bare == "instagr.am" || bare.hasSuffix(".instagram.com") { return .instagram }
        if bare == "youtube.com" || bare == "youtu.be" || bare.hasSuffix(".youtube.com") { return .youtube }
        if bare == "spotify.com" || bare == "open.spotify.com" || bare == "spoti.fi" || bare.hasSuffix(".spotify.com") { return .spotify }
        if bare == "facebook.com" || bare == "fb.com" || bare == "fb.me" || bare == "fb.watch" || bare.hasSuffix(".facebook.com") { return .facebook }
        if bare == "twitter.com" || bare == "x.com" || bare == "t.co" || bare.hasSuffix(".twitter.com") || bare.hasSuffix(".x.com") { return .twitter }
        return .generic
    }

    // MARK: - Banner

    @ViewBuilder
    private func banner(text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: color == .red ? "exclamationmark.circle" : "checkmark.circle")
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(CalmTheme.textPrimary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
    }
}
