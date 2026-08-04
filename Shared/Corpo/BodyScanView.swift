//
//  BodyScanView.swift
//  Corpo & Alma
//
//  Scan corporal com IA — coleta fotos (frente/lado) + medidas e gera o plano.
//

import SwiftUI
import PhotosUI

struct BodyScanView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?
    @State private var analyzing = false
    @State private var result: ScanResult?
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showCameraFront  = false
    @State private var showCameraSide   = false
    @State private var showGalleryFront = false
    @State private var showGallerySide  = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                photosSection
                measuresSection
                analyzeButton
                privacyNote
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scan corporal")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) {
            if let result { ScanResultView(result: result) }
        }
        .onChange(of: frontItem) { item in load(item) { frontData = $0 } }
        .onChange(of: sideItem) { item in load(item) { sideData = $0 } }
        .overlay { if analyzing { analyzingOverlay } }
        .alert("Não foi possível analisar", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: $showCameraFront) {
            CameraPickerView { image in
                frontData = image.jpegData(compressionQuality: 0.8)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCameraSide) {
            CameraPickerView { image in
                sideData = image.jpegData(compressionQuality: 0.8)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showGalleryFront, selection: $frontItem, matching: .images)
        .photosPicker(isPresented: $showGallerySide,  selection: $sideItem,  matching: .images)
    }

    // MARK: Seções

    /// [2026-08-04] Estáticos para o harness assertar o MESMO texto exibido.
    static var tituloDaTela: String {
        AIService.isRealAI ? "Análise corporal com IA"
                                      : "Estimativa corporal por medidas"
    }

    static var chamadaDaTela: String {
        AIService.isRealAI
        ? "Adicione 2 fotos e confirme suas medidas. A IA estima seu perfil e monta um plano de alimentação e treino sob medida."
        : "Confirme suas medidas e o app calcula uma estimativa do seu perfil, com um plano de alimentação e treino. Nesta versão não há análise por IA e as fotos não são usadas."
    }

    static var notaDePrivacidade: String {
        AIService.isRealAI
        ? "Suas fotos são usadas apenas para gerar sua análise e não são compartilhadas. Esta avaliação é informativa e não substitui um profissional de saúde."
        : "Nesta versão nenhuma foto é enviada nem analisada — o resultado vem só das suas medidas. Esta avaliação é informativa e não substitui um profissional de saúde."
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)
            // [2026-08-04 — B8 REABERTO na varredura visual] Esta tela dizia
            // "Análise corporal com IA" e "A IA estima seu perfil" no topo, e
            // no rodapé "A análise por IA não está disponível nesta versão".
            // As duas frases, na mesma tela, ao mesmo tempo. O título vence a
            // ressalva: quem lê de cima para baixo já decidiu que tem IA.
            Text(Self.tituloDaTela)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            Text(Self.chamadaDaTela)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var photosSection: some View {
        HStack(alignment: .top, spacing: 14) {
            photoSlot(
                title: "Frente",
                data: frontData,
                item: $frontItem,
                onCamera: { showCameraFront = true },
                onGallery: { showGalleryFront = true }
            )
            photoSlot(
                title: "Lado",
                data: sideData,
                item: $sideItem,
                onCamera: { showCameraSide = true },
                onGallery: { showGallerySide = true }
            )
        }
    }

    private func photoSlot(
        title: String,
        data: Data?,
        item: Binding<PhotosPickerItem?>,
        onCamera: @escaping () -> Void,
        onGallery: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            // Área de preview
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surfaceAlt)
                if let data, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.title2).foregroundStyle(Theme.primary)
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("toque para adicionar").font(.caption2).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)

            // Botões: Galeria e Câmera
            HStack(spacing: 6) {
                Button { onGallery() } label: {
                    Label("Galeria", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { onCamera() } label: {
                    Label("Câmera", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var measuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suas medidas").font(.headline).foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                measure("\(Int(model.weightKg)) kg", "Peso")
                measure("\(Int(model.heightCm)) cm", "Altura")
                measure("\(model.ageYears)", "Idade")
                measure(model.goal.rawValue, "Objetivo")
            }
        }
        .cardStyle()
    }

    private func measure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // [F1] Com IA real: as DUAS fotos são obrigatórias — sem elas o botão não libera.
    // Sem IA disponível: o botão diz a verdade ("estimativa por medidas, sem IA").
    private var missingPhotos: [String] {
        var missing: [String] = []
        if frontData == nil { missing.append("foto de frente") }
        if sideData == nil { missing.append("foto de lado") }
        return missing
    }

    private var canAnalyze: Bool {
        AIService.isRealAI ? missingPhotos.isEmpty : true
    }

    private var analyzeButton: some View {
        VStack(spacing: 8) {
            Button { analyze() } label: {
                Label(AIService.isRealAI ? "Analisar com IA" : "Gerar estimativa por medidas (sem IA)",
                      systemImage: AIService.isRealAI ? "sparkles" : "ruler")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [Theme.primary, Theme.primaryDeep], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    .opacity(canAnalyze ? 1 : 0.45)
            }
            .disabled(analyzing || !canAnalyze)

            if AIService.isRealAI && !missingPhotos.isEmpty {
                Label("Falta: \(missingPhotos.joined(separator: " e "))",
                      systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if !AIService.isRealAI {
                Text("A análise por IA não está disponível nesta versão. O resultado será uma estimativa calculada só com suas medidas — sem uso de fotos.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var privacyNote: some View {
        // [2026-08-04] Dizia "Suas fotos são usadas apenas para gerar sua
        // análise" numa versão em que foto nenhuma é usada. Descrever um uso
        // que não existe é tão errado quanto esconder um que existe.
        Text(Self.notaDePrivacidade)
            .font(.caption2)
            .foregroundStyle(Theme.inkSoft)
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(.white)
                // [2026-08-03 — B8] Era "Analisando seu corpo com IA…" sobre um
                // cálculo local por medidas. Sem IA no build, o texto mente.
                Text(GeminiConfig.isAvailable
                     ? "Analisando suas fotos…"
                     : "Calculando a partir das suas medidas…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    // MARK: Ações

    private func load(_ item: PhotosPickerItem?, completion: @escaping (Data) -> Void) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    completion(data)
                } else {
                    errorMessage = "Não foi possível carregar a foto. Tente escolher outra imagem."
                }
            } catch {
                #if DEBUG
                print("[BodyScan] Falha ao carregar foto: \(error)")
                #endif
                errorMessage = "Não foi possível carregar a foto. Tente escolher outra imagem."
            }
        }
    }

    private func analyze() {
        analyzing = true
        Task {
            defer { analyzing = false }
            let input = ScanInput(
                weightKg: model.weightKg,
                heightCm: model.heightCm,
                ageYears: model.ageYears,
                bodyFat: model.bodyFat,
                goal: model.goal.rawValue,
                frontPhoto: frontData,
                sidePhoto: sideData
            )
            do {
                let r = try await AIService.make().analyze(input)
                result = r
                showResult = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        BodyScanView().environmentObject(AppModel())
    }
}
