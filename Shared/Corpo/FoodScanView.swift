//
//  FoodScanView.swift
//  Corpo & Alma
//
//  Scan de comida com IA — captura foto do prato e estima macros.
//

import SwiftUI
import PhotosUI

// MARK: - Resultado do scan de comida

struct FoodScanResult {
    let name: String
    var brand: String? = nil   // [F3] marca/fabricante quando visível no rótulo
    let description: String
    let kcalPer100: Int
    let proteinPer100: Int
    let carbsPer100: Int
    let fatPer100: Int
}

// MARK: - Tela principal

struct FoodScanView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var analyzing = false
    @State private var result: FoodScanResult?
    @State private var errorMessage: String?   // [F2] erro honesto, sem mock
    @State private var mealType: MealType = .almoco
    @State private var showCamera = false
    @State private var showGallery = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    photoSlot
                    if photoData != nil && result == nil {
                        analyzeButton
                    }
                    if let msg = errorMessage {
                        errorBanner(msg)
                    }
                    if let r = result {
                        resultSection(r)
                    }
                    privacyNote
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Scan de comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            // [Fusão] onChange de dois parâmetros é iOS 17+; o Alma suporta iOS 16.
            .onChange(of: photoItem) { item in loadPhoto(item) }
            .overlay { if analyzing { analyzingOverlay } }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    photoData = image.jpegData(compressionQuality: 0.8)
                    result = nil
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showGallery, selection: $photoItem, matching: .images)
        }
    }

    // MARK: Seções

    /// [2026-08-04] Estáticos para o harness assertar o MESMO texto exibido.
    static var tituloDaTela: String {
        GeminiConfig.isAvailable ? "Scan de comida com IA"
                                 : "Scan de comida — indisponível nesta versão"
    }

    static var chamadaDaTela: String {
        GeminiConfig.isAvailable
        ? "Tire uma foto do seu prato e a IA estima os macronutrientes em segundos."
        : "A leitura do prato por foto não está disponível nesta versão. Registre o alimento pela busca ou pelo código de barras — o resultado é o mesmo, sem chute."
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.coral)
            // [2026-08-04 — B8 REABERTO] Esta era a pior das quatro: prometia
            // "a IA estima os macronutrientes em segundos" e não tinha nem a
            // ressalva que a tela do scan corporal tinha. A pessoa ia direto
            // para a câmera acreditando na estimativa.
            Text(Self.tituloDaTela)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            Text(Self.chamadaDaTela)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var photoSlot: some View {
        VStack(spacing: 10) {
            // Área de preview
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surfaceAlt)
                    .frame(height: 200)
                if let data = photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.coral)
                        Text("Nenhuma foto selecionada")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("Use a câmera ou escolha da galeria")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Botões de seleção
            HStack(spacing: 12) {
                Button { showGallery = true } label: {
                    Label("Galeria", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { showCamera = true } label: {
                    Label("Câmera", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var analyzeButton: some View {
        Button { analyze() } label: {
            Label("Analisar com IA", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Theme.primary, Theme.primaryDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
        .disabled(analyzing)
    }

    // [F2] Erro visível — substitui o antigo fallback silencioso para mock.
    private func errorBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.coral)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.coral.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    private func resultSection(_ r: FoodScanResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(r.name)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                if let brand = r.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                }
                Text(r.description)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }

            // 4 MacroTiles: kcal / proteína / carboidrato / gordura
            HStack(spacing: 10) {
                macroTile("\(r.kcalPer100)", "kcal", Theme.coral)
                macroTile("\(r.proteinPer100) g", "Prot", Theme.primary)
                macroTile("\(r.carbsPer100) g", "Carbo", Theme.gold)
                macroTile("\(r.fatPer100) g", "Gord", Theme.azure)
            }

            // Picker de refeição
            Picker("Refeição", selection: $mealType) {
                ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // Confirmar e adicionar
            Button {
                let food = FoodItem(
                    name: r.name,
                    kcalPer100: r.kcalPer100,
                    proteinPer100: r.proteinPer100,
                    carbsPer100: r.carbsPer100,
                    fatPer100: r.fatPer100,
                    emoji: "🍽️",
                    brand: r.brand
                )
                model.addFood(food, grams: 100, to: mealType)
                dismiss()
            } label: {
                Label("Adicionar à \(mealType.rawValue)", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
        }
        .cardStyle()
    }

    private func macroTile(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }

    private var privacyNote: some View {
        Text("Esta análise é uma estimativa e não substitui orientação profissional. As fotos são usadas apenas localmente.")
            .font(.caption2)
            .foregroundStyle(Theme.inkSoft)
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text("Analisando seu prato com IA…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    // MARK: Ações

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                photoData = data
                result = nil        // reset ao trocar a foto
                errorMessage = nil
            }
        }
    }

    // [F2] Honestidade: sem IA disponível ou com erro, o app mostra ERRO —
    // nunca um "resultado" inventado que poderia ser adicionado à dieta.
    private func analyze() {
        guard let imageData = photoData else { return }
        analyzing = true
        errorMessage = nil
        Task {
            defer { analyzing = false }
            do {
                guard GeminiConfig.isAvailable else { throw GeminiError.missingKey }
                result = try await GeminiService.analyzeFood(imageData: imageData)
            } catch let e as GeminiError {
                result = nil
                switch e {
                case .missingKey:
                    errorMessage = "A análise por IA não está disponível nesta versão. Adicione o alimento manualmente na aba Dieta."
                case .badResponse:
                    errorMessage = "O serviço de análise respondeu com erro. Verifique a conexão e tente novamente."
                case .parsingFailed:
                    errorMessage = "Não foi possível interpretar a análise. Tente uma foto mais clara do alimento."
                }
            } catch {
                result = nil
                errorMessage = "Sem conexão com o serviço de análise. Verifique a internet e tente novamente."
            }
        }
    }
}

#Preview {
    FoodScanView().environmentObject(AppModel())
}
