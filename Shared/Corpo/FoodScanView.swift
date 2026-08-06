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

    /// Os quatro números para UMA quantidade qualquer.
    ///
    /// [2026-08-06] Virou função com parâmetro porque a porção deixou de ser um
    /// decreto: a pessoa pode ajustar antes de confirmar (ver `porcaoAjustada`).
    /// A conta em si não mudou — continua saindo toda de `AppModel.escalarPor100`,
    /// a mesma função que o `AppModel.addFood` usa. É isso que torna impossível a
    /// tela dizer uma coisa e o registro gravar outra, que era o bug de 05/08.
    func macros(para gramas: Int) -> (kcal: Int, proteina: Int, carbo: Int, gordura: Int) {
        (kcal:     AppModel.escalarPor100(kcalPer100,    gramas: gramas),
         proteina: AppModel.escalarPor100(proteinPer100, gramas: gramas),
         carbo:    AppModel.escalarPor100(carbsPer100,   gramas: gramas),
         gordura:  AppModel.escalarPor100(fatPer100,     gramas: gramas))
    }

    /// Os números da porção que a IA estimou, sem ajuste nenhum.
    /// Mantido para as asserções H2/H2b/H2d, que provam o conserto de 05/08 e
    /// continuam falando exatamente do que falavam.
    var macrosDaPorcao: (kcal: Int, proteina: Int, carbo: Int, gordura: Int) {
        macros(para: porcaoG)
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

    /// [2026-08-06] O ajuste da pessoa POR CIMA da estimativa da IA.
    ///
    /// Nasce `nil` de propósito: a estimativa já vem preenchida como ponto de
    /// partida, e quem concorda com ela não precisa tocar em nada. `nil` também
    /// é o que distingue "aceitei o que a IA leu" de "corrigi para 450 g" — por
    /// isso não sobrescrevo `result.porcaoG`. A estimativa continua visível
    /// depois do ajuste, porque é vendo a diferença entre o que a máquina leu e
    /// o que ela corrigiu que a pessoa aprende quanto confiar na leitura.
    @State private var porcaoAjustada: Int?

    /// A quantidade que vale AGORA — a única lida pelos tiles, pelo rótulo do
    /// botão e pelo registro. Ver `resultSection`.
    private func porcaoEmUso(_ r: FoodScanResult) -> Int {
        porcaoAjustada ?? r.porcaoG
    }

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
                    porcaoAjustada = nil   // foto nova, estimativa nova
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

    /// [2026-08-06] Os dois textos que carregam a quantidade, como FUNÇÃO.
    ///
    /// Enquanto viviam soltos dentro do corpo da View, "o que o botão promete"
    /// era uma string que nenhuma asserção conseguia ler. Sendo função estática,
    /// a View e o harness leem a MESMA fonte, e dá para afirmar o que antes só
    /// dava para olhar: que o número prometido no botão é o número gravado.
    static func rotuloDaPorcao(gramas: Int) -> String {
        "Valores para \(gramas) g"
    }

    static func rotuloDeConfirmacao(gramas: Int, refeicao: MealType) -> String {
        "Adicionar \(gramas) g à \(refeicao.rawValue)"
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
        // ═══════════════════════════════════════════════════════════════════
        // [2026-08-06] UMA quantidade, três consumidores.
        //
        // `gramas` é lido pelos tiles, pelo rótulo do botão e pela chamada de
        // `addFood`. Não há segunda variável, então divergir exigiria alguém
        // criar uma — que é exatamente a mutação que a asserção E1 procura.
        //
        // É a mesma ideia do conserto de 05/08, agora com a porção podendo
        // mudar: naquele dia o problema era a tela mostrar um número e o
        // registro gravar outro; deixar a porção editável reabriria essa porta
        // se cada ponta lesse a sua própria fonte.
        // ═══════════════════════════════════════════════════════════════════
        let gramas = porcaoEmUso(r)
        let macros = r.macros(para: gramas)

        return VStack(alignment: .leading, spacing: 16) {
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
            Text(Self.rotuloDaPorcao(gramas: gramas))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 10) {
                macroTile("\(macros.kcal)", "kcal", Theme.coral)
                macroTile("\(macros.proteina) g", "Prot", Theme.primary)
                macroTile("\(macros.carbo) g", "Carbo", Theme.gold)
                macroTile("\(macros.gordura) g", "Gord", Theme.azure)
            }

            // O ajuste fica ENTRE os números e o botão: a pessoa mexe e vê os
            // quatro números mudarem logo acima, antes de confirmar.
            porcaoEditor(r, gramas: gramas)

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
            //
            // [2026-08-06] E agora grava a porção EM USO, não a estimada: se a
            // pessoa corrigiu para 450 g, é 450 g que entra na dieta.
            Button {
                model.addFood(r.comoFoodItem, grams: gramas, to: mealType)
                dismiss()
            } label: {
                Label(Self.rotuloDeConfirmacao(gramas: gramas, refeicao: mealType),
                      systemImage: "checkmark")
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

    // MARK: Ajuste da porção

    /// [2026-08-06] O controle que faltava.
    ///
    /// A IA acerta a proporção do prato e erra o tamanho — foi a queixa que
    /// abriu este trabalho. A estimativa vem preenchida, e quem concorda com ela
    /// não toca em nada; quem olhou o prato e sabe que era mais, arrasta.
    private func porcaoEditor(_ r: FoodScanResult, gramas: Int) -> some View {
        // O slider do AddFoodView para em 500 g, o que não cobre um prato
        // cheio. Aqui a faixa acompanha a estimativa quando ela é grande.
        let limite = Double(max(1000, r.porcaoG * 2))
        // E o piso acompanha a estimativa quando ela é pequena. `porcaoG` só
        // garante ser ≥ 1 (ver `enviarParaAnalise`); com o piso fixo em 10, uma
        // estimativa de 5 g deixaria o rótulo dizendo "5 g" e o slider parado
        // em 10 — número mostrado diferente de número representado, que é a
        // família de bug que este trabalho inteiro existe para fechar.
        let piso = min(10, max(1, r.porcaoG))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quantidade")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(gramas) g")
                    .font(.headline.bold())
                    .foregroundStyle(Theme.primary)
            }

            HStack(spacing: 12) {
                ajusteBotao("minus", habilitado: gramas > piso) {
                    porcaoAjustada = max(piso, gramas - 5)
                }
                Slider(
                    value: Binding<Double>(
                        get: { Double(gramas) },
                        set: { novo in porcaoAjustada = max(piso, Int(novo.rounded())) }
                    ),
                    // [revisão 06/08] SEM `step:`. Com passo de 5 a grade do
                    // slider ancorava no piso (10, 15, 20…) e a estimativa da
                    // IA é inteiro qualquer: um prato de 247 g pulava para 245
                    // ao primeiro toque, e os botões −/+ andavam por 242, 237…,
                    // uma grade que nunca encontrava a do slider. Dois
                    // controles discordando sobre quais números existem é a
                    // mesma família de bug que este trabalho fecha. Contínuo,
                    // com o `set` arredondando para Int, todo grama é
                    // alcançável e as duas grades viram uma só.
                    in: Double(piso)...limite
                )
                .tint(Theme.primary)
                ajusteBotao("plus", habilitado: Double(gramas) < limite) {
                    porcaoAjustada = min(Int(limite), gramas + 5)
                }
            }

            // A estimativa da IA nunca some de vista. Depois de ajustar, a
            // pessoa continua vendo o que a máquina tinha lido — e volta em um
            // toque se tiver exagerado na correção.
            if gramas != r.porcaoG {
                Button {
                    porcaoAjustada = nil
                } label: {
                    Label("A IA estimou \(r.porcaoG) g · voltar à estimativa",
                          systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            } else {
                Text("Estimativa da IA. Ajuste se o prato tinha mais ou menos que isso.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }

    private func ajusteBotao(_ simbolo: String, habilitado: Bool,
                             acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Image(systemName: "\(simbolo).circle.fill")
                .font(.title2)
                .foregroundStyle(habilitado ? Theme.primary : Theme.inkSoft.opacity(0.35))
        }
        .buttonStyle(.plain)
        .disabled(!habilitado)
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
                porcaoAjustada = nil
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
                // Análise nova zera o ajuste: o ponto de partida volta a ser a
                // estimativa desta foto, não a correção que a pessoa fez na
                // anterior.
                porcaoAjustada = nil
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
                porcaoAjustada = nil
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    FoodScanView().environmentObject(AppModel())
}
