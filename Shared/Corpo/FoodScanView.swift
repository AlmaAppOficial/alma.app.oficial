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

    /// [2026-08-05] A porção que a IA enxergou no prato, COMO NÚMERO.
    ///
    /// Antes ela existia só dentro de `description`, como prosa
    /// ("Porção estimada na foto: 250 g"). Um número que só vive numa frase não
    /// pode ser usado para calcular nada — e não era: o botão registrava
    /// `grams: 100` fixo. A tela dizia 250 g e o diário recebia 100 g.
    ///
    /// Sendo campo, ele alimenta ao mesmo tempo o que a tela mostra e o que
    /// entra na dieta. Ver `macrosDaPorcao` e a asserção H2.
    let porcaoG: Int

    /// Os quatro números que a tela mostra E que vão para o diário.
    ///
    /// Passam pela MESMA função que o `AppModel.addFood` usa
    /// (`AppModel.escalarPor100`). É isso que torna impossível a tela dizer uma
    /// coisa e o registro gravar outra — que era o bug.
    var macrosDaPorcao: (kcal: Int, proteina: Int, carbo: Int, gordura: Int) {
        (kcal:     AppModel.escalarPor100(kcalPer100,    gramas: porcaoG),
         proteina: AppModel.escalarPor100(proteinPer100, gramas: porcaoG),
         carbo:    AppModel.escalarPor100(carbsPer100,   gramas: porcaoG),
         gordura:  AppModel.escalarPor100(fatPer100,     gramas: porcaoG))
    }

    /// O `FoodItem` que vai para o diário. Carrega os valores POR 100 g porque
    /// é assim que o `addFood` os espera — a porção vai separada, no `grams:`.
    var comoFoodItem: FoodItem {
        FoodItem(name: name,
                 kcalPer100: kcalPer100,
                 proteinPer100: proteinPer100,
                 carbsPer100: carbsPer100,
                 fatPer100: fatPer100,
                 emoji: "🍽️",
                 brand: brand)
    }
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
    /// [2026-08-05] Consentimento por envio.
    @State private var mostrarConsentimento = false

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
            .confirmationDialog("Enviar foto para análise?",
                                isPresented: $mostrarConsentimento,
                                titleVisibility: .visible) {
                Button("Enviar foto para análise") { enviarParaAnalise() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(Self.pedidoDeConsentimento)
            }
        }
    }

    // MARK: Seções

    /// [2026-08-04] Estáticos para o harness assertar o MESMO texto exibido.
    static var tituloDaTela: String {
        AIService.isRealAI ? "Scan de comida com IA"
                           : "Scan de comida — indisponível nesta versão"
    }

    static var chamadaDaTela: String {
        AIService.isRealAI
        ? "Tire uma foto do seu prato e a IA estima os macronutrientes. É uma estimativa a partir da imagem — confira a porção antes de adicionar."
        : "A leitura do prato por foto não está disponível nesta versão. Registre o alimento pela busca ou pelo código de barras — o resultado é o mesmo, sem chute."
    }

    /// Mesmo texto do scan corporal — a promessa é a mesma nos dois envios.
    static var pedidoDeConsentimento: String {
        "Enviar esta foto para análise?\n\n"
        + "A foto é analisada e não fica guardada no Alma. O provedor de IA pode "
        + "mantê-la por até 30 dias apenas por segurança, e não a usa para treinar modelos."
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

            // [2026-08-05] Os quatro números são DA PORÇÃO, e o rótulo diz de
            // qual porção. Antes eram por 100 g, sem dizer, logo abaixo de uma
            // frase que anunciava a porção estimada: quem lia "250 g" e "520
            // kcal" somava 520 kcal a um prato que tem 1 300.
            //
            // São exatamente os números que o botão abaixo registra — os dois
            // leem `r.macrosDaPorcao`.
            Text("Valores para os \(r.porcaoG) g estimados na foto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                macroTile("\(r.macrosDaPorcao.kcal)", "kcal", Theme.coral)
                macroTile("\(r.macrosDaPorcao.proteina) g", "Prot", Theme.primary)
                macroTile("\(r.macrosDaPorcao.carbo) g", "Carbo", Theme.gold)
                macroTile("\(r.macrosDaPorcao.gordura) g", "Gord", Theme.azure)
            }

            // Picker de refeição
            Picker("Refeição", selection: $mealType) {
                ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // Confirmar e adicionar
            //
            // [2026-08-05] Era `grams: 100`, fixo, ignorando a porção que a IA
            // estimou e que a tela logo acima anunciava. O app informava uma
            // porção e registrava outra na dieta — e a contagem de calorias,
            // que é o valor inteiro desta parte do app, ficava errada em
            // silêncio, sem nada na tela que denunciasse.
            Button {
                model.addFood(r.comoFoodItem, grams: r.porcaoG, to: mealType)
                dismiss()
            } label: {
                Label("Adicionar \(r.porcaoG) g à \(mealType.rawValue)", systemImage: "checkmark")
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
        // [2026-08-05] Dizia "As fotos são usadas apenas localmente" — frase que
        // deixou de ser verdade no minuto em que a análise foi para a nuvem.
        // Era incondicional, então mentiria em silêncio.
        Text(AIService.isRealAI
             ? "Esta análise é uma estimativa e não substitui orientação profissional. A foto é analisada e não fica guardada no Alma; o provedor de IA pode mantê-la por até 30 dias apenas por segurança, e não a usa para treinar modelos."
             : "Esta análise é uma estimativa e não substitui orientação profissional. As fotos são usadas apenas localmente.")
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
    /// [2026-08-05] O botão abre o consentimento; o envio é o passo seguinte.
    private func analyze() {
        guard photoData != nil else { return }
        mostrarConsentimento = true
    }

    /// Envio de verdade, já com o consentimento daquele envio.
    private func enviarParaAnalise() {
        guard let imageData = photoData else { return }
        analyzing = true
        errorMessage = nil
        Task {
            defer { analyzing = false }
            do {
                let prato = try await AnaliseDeFotoService.analisarPrato(
                    foto: imageData, consentimento: true)
                // A porção vem da IA e agora é NÚMERO, não frase. `max(1,…)`
                // porque porção zero registraria uma refeição de 0 kcal com
                // cara de refeição registrada.
                let porcao = max(1, Int(prato.porcaoG.rounded()))
                result = FoodScanResult(
                    name: prato.nome,
                    brand: nil,
                    description: "Porção estimada na foto: \(porcao) g",
                    kcalPer100: Int(prato.kcalPor100.rounded()),
                    proteinPer100: Int(prato.proteinaPor100.rounded()),
                    carbsPer100: Int(prato.carboPor100.rounded()),
                    fatPer100: Int(prato.gorduraPor100.rounded()),
                    porcaoG: porcao
                )
            } catch {
                // [F2/B8] Erro é erro. Nunca um "resultado" inventado que
                // poderia acabar somado às calorias do dia.
                result = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    FoodScanView().environmentObject(AppModel())
}
