import SwiftUI

// MARK: - CreateFeedPostView (Build 77 — universal admin creation flow)
//
// File path kept as PostDetailView.swift to avoid pbxproj edits. Contents
// are the Build 77 admin post creator with the universal fetch+create flow.
//
// Phases:
//   .initial   — only URL field + "Buscar dados" button.
//   .fetching  — spinner; backend action=fetch in flight.
//   .editing   — full form: source badge + thumbnail preview + editable
//                title/description (prefilled from OG when available) +
//                live char counter + "Publicar" button.
//   .publishing — spinner during action=create.
//
// All sources share the same flow. Instagram/Facebook simply come back
// from fetch with empty OG fields, opening the form blank for full
// manual entry. No source-specific UI branches.

struct CreateFeedPostView: View {

    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case initial, fetching, editing, publishing
    }

    @State private var url: String = ""
    @State private var source: FeedSource = .generic
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var thumbnail: String? = nil
    @State private var phase: Phase = .initial
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    private let repository = FeedRepository.shared
    private let descMin = FeedRepository.descriptionMin
    private let descMax = FeedRepository.descriptionMax

    var body: some View {
        NavigationStack {
            ZStack {
                CalmTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        urlField

                        if phase == .editing || phase == .publishing {
                            editForm
                        }

                        if let infoMessage {
                            banner(text: infoMessage, color: CalmTheme.primary)
                        }
                        if let errorMessage {
                            banner(text: errorMessage, color: .red)
                        }

                        actionButton

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
                .disabled(phase == .editing || phase == .publishing)
                .onChange(of: url) { newValue in
                    // If the admin edits the URL after fetch, reset to initial
                    // so the form re-runs against the new URL.
                    if phase == .editing {
                        resetToInitial(keepURL: true)
                    }
                    source = detectSource(from: newValue)
                }

            if !url.isEmpty {
                HStack(spacing: 8) {
                    SourceBadge(source: source)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Edit form (shown after fetch)

    @ViewBuilder
    private var editForm: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let thumb = thumbnail, let imgURL = URL(string: thumb) {
                HStack {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(CalmTheme.surface)
                                .overlay(ProgressView().tint(CalmTheme.primary))
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(source.color.opacity(0.1))
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))

                    Text("Preview da imagem")
                        .font(.system(size: 12))
                        .foregroundColor(CalmTheme.textSecondary)

                    Spacer()
                }
            }

            Text("Título")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)

            TextField("Título da publicação", text: $title, axis: .vertical)
                .lineLimit(1...3)
                .padding(12)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))

            Text("Descrição")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CalmTheme.textPrimary)
                .padding(.top, 4)

            TextField("Descrição (entre \(descMin) e \(descMax) caracteres)", text: $description, axis: .vertical)
                .lineLimit(3...8)
                .padding(12)
                .background(CalmTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))

            descriptionCounter
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var descriptionCounter: some View {
        let count = description.trimmingCharacters(in: .whitespacesAndNewlines).count
        let valid = count >= descMin && count <= descMax
        HStack(spacing: 4) {
            Image(systemName: valid ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.system(size: 11))
            Text("\(count) / \(descMin)–\(descMax) caracteres")
                .font(.system(size: 11))
            Spacer()
        }
        .foregroundColor(valid ? .green : .red)
    }

    // MARK: - Action button (label + behavior changes per phase)

    @ViewBuilder
    private var actionButton: some View {
        Button(action: tap) {
            HStack {
                if phase == .fetching || phase == .publishing {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 8)
                }
                Text(buttonLabel)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(buttonEnabled ? CalmTheme.primary : CalmTheme.primary.opacity(0.4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: CalmTheme.rSmall))
        }
        .disabled(!buttonEnabled || phase == .fetching || phase == .publishing)
        .padding(.top, 4)
    }

    private var buttonLabel: String {
        switch phase {
        case .initial:    return "Buscar dados"
        case .fetching:   return "Buscando..."
        case .editing:    return "Publicar"
        case .publishing: return "Publicando..."
        }
    }

    private var buttonEnabled: Bool {
        switch phase {
        case .initial:
            return !url.trimmingCharacters(in: .whitespaces).isEmpty
        case .fetching, .publishing:
            return false
        case .editing:
            let titleOK = !title.trimmingCharacters(in: .whitespaces).isEmpty
            let descCount = description.trimmingCharacters(in: .whitespacesAndNewlines).count
            return titleOK && descCount >= descMin && descCount <= descMax
        }
    }

    // MARK: - Actions

    private func tap() {
        switch phase {
        case .initial:  fetch()
        case .editing:  publish()
        default:        break
        }
    }

    private func fetch() {
        errorMessage = nil
        infoMessage = nil
        phase = .fetching

        Task {
            do {
                let result = try await repository.fetchOG(
                    url: url.trimmingCharacters(in: .whitespaces)
                )
                source = result.source
                title = result.title
                description = result.description
                thumbnail = result.thumbnail
                if title.isEmpty && description.isEmpty && thumbnail == nil {
                    infoMessage = "Não foi possível buscar preview automático. Preencha manualmente abaixo."
                }
                phase = .editing
            } catch {
                errorMessage = error.localizedDescription
                phase = .initial
            }
        }
    }

    private func publish() {
        errorMessage = nil
        infoMessage = nil
        phase = .publishing

        Task {
            do {
                _ = try await repository.createPost(
                    url: url.trimmingCharacters(in: .whitespaces),
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    thumbnail: thumbnail
                )
                infoMessage = "Publicação criada."
                try? await Task.sleep(nanoseconds: 600_000_000)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                phase = .editing
            }
        }
    }

    private func resetToInitial(keepURL: Bool) {
        if !keepURL { url = "" }
        source = .generic
        title = ""
        description = ""
        thumbnail = nil
        phase = .initial
        errorMessage = nil
        infoMessage = nil
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
            Image(systemName: color == .red ? "exclamationmark.circle" : "info.circle")
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
