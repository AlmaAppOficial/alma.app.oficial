//
//  AddFoodView.swift
//  Corpo & Alma
//
//  Fluxo "+" da Dieta — busca de alimento, quantidade e cálculo de macros.
//  Aceita `defaultMealType` para abrir já posicionado na refeição correta.
//

import SwiftUI

// MARK: - AddFoodView

struct AddFoodView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var selected: FoodItem?
    @State private var grams: Double = 100
    @State private var mealType: MealType
    @State private var showScanner = false
    @State private var notFoundCode: String?
    @State private var showCustomForm = false
    @State private var customFormBarcode: String?   // [F3] pré-preenche o cadastro manual
    @State private var lookingUp = false            // [F3] consultando a Open Food Facts
    @State private var lookupError: String?         // [F3] offline / erro da base

    /// Abre o seletor já posicionado na refeição correta (café, almoço, lanche, jantar).
    init(defaultMealType: MealType = .cafe) {
        _mealType = State(initialValue: defaultMealType)
    }

    private var results: [FoodItem] {
        // [F3] alimentos do usuário aparecem junto do catálogo embutido
        let all = model.userFoods.map(\.asFoodItem) + foodDatabase
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(search) ||
            ($0.brand?.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    // [F3] Código lido → cadastro do usuário/cache/catálogo → Open Food Facts → cadastro manual.
    private func resolveBarcode(_ code: String) {
        if let food = model.food(forBarcode: code) {
            withAnimation { selected = food; grams = 100 }
            return
        }
        lookingUp = true
        lookupError = nil
        Task {
            defer { lookingUp = false }
            do {
                let product = try await OpenFoodFactsService.lookup(code)
                withAnimation { selected = product.asFoodItem; grams = 100 }
            } catch ProductLookupError.notFound {
                notFoundCode = code
            } catch let e as ProductLookupError {
                lookupError = e.errorDescription
            } catch {
                lookupError = ProductLookupError.badResponse.errorDescription
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if showCustomForm {
                    CustomFoodForm(mealType: mealType, barcode: customFormBarcode) { dismiss() }
                } else if let food = selected {
                    quantityForm(food)
                } else {
                    searchList
                }
            }
            .overlay {
                if lookingUp {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Buscando produto…").font(.caption).foregroundStyle(Theme.inkSoft)
                        }
                        .padding(24)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(showCustomForm ? "Alimento personalizado" : (selected == nil ? "Adicionar alimento" : "Quantidade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selected == nil && !showCustomForm ? "Cancelar" : "Voltar") {
                        if showCustomForm { showCustomForm = false }
                        else if selected == nil { dismiss() }
                        else { selected = nil }
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in
                    showScanner = false
                    resolveBarcode(code)   // [F3] catálogo → Open Food Facts → cadastro manual
                }
                .ignoresSafeArea()
            }
            .alert("Produto não encontrado", isPresented: Binding(
                get: { notFoundCode != nil },
                set: { if !$0 { notFoundCode = nil } }
            )) {
                Button("Cadastrar manualmente") {
                    customFormBarcode = notFoundCode
                    notFoundCode = nil
                    withAnimation { showCustomForm = true }
                }
                Button("Agora não", role: .cancel) {}
            } message: {
                Text("O código \(notFoundCode ?? "") não está na base de produtos. Cadastre com nome, marca e macros — fica salvo para a próxima leitura.")
            }
            .alert("Não foi possível consultar", isPresented: Binding(
                get: { lookupError != nil },
                set: { if !$0 { lookupError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lookupError ?? "")
            }
        }
    }

    // MARK: - Lista com busca

    private var searchList: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                    TextField("Buscar alimento…", text: $search)
                    Button { showScanner = true } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                    }
                }
                .padding(12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))

                // Seletor de refeição — visível para trocar rapidamente
                Picker("Refeição", selection: $mealType) {
                    ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                // Botão alimento personalizado
                Button { withAnimation { showCustomForm = true } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adicionar alimento personalizado")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primary)
                            Text("Informe kcal, proteína, carbo e gordura")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                    }
                    .padding(12)
                    .background(Theme.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                if results.isEmpty && !search.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                        Text("Nenhum alimento encontrado")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                        Text("Use o botão acima para cadastrar com macros personalizados.")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }

                ForEach(results) { food in
                    Button { withAnimation { selected = food; grams = 100 } } label: {
                        HStack(spacing: 12) {
                            Text(food.emoji).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                Text([food.brand, "\(food.kcalPer100) kcal · 100 g"]
                                        .compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.primary)
                        }
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Formulário de quantidade

    private func quantityForm(_ food: FoodItem) -> some View {
        let f = grams / 100.0
        let kcal: Int = Int((Double(food.kcalPer100) * f).rounded())
        let prot: Int = Int((Double(food.proteinPer100) * f).rounded())
        let carb: Int = Int((Double(food.carbsPer100) * f).rounded())
        let fat:  Int = Int((Double(food.fatPer100) * f).rounded())
        let gramsInt: Int = Int(grams)

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text(food.emoji).font(.system(size: 48))
                    Text(food.name)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                    }
                }
                .padding(.top, 8)

                // Total calculado
                VStack(spacing: 4) {
                    Text("\(kcal)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.coral)
                    Text("kcal em \(gramsInt) g")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()

                // Slider de quantidade
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quantidade").font(.headline).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(gramsInt) g").font(.headline.bold()).foregroundStyle(Theme.primary)
                    }
                    Slider(value: $grams, in: 10...500, step: 10).tint(Theme.primary)
                }
                .cardStyle()

                // Macros calculados
                HStack(spacing: 12) {
                    macro("Proteína", prot, Theme.primary)
                    macro("Carbo", carb, Theme.gold)
                    macro("Gordura", fat, Theme.azure)
                }

                // Refeição
                Picker("Refeição", selection: $mealType) {
                    ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Button {
                    model.addFood(food, grams: Int(grams), to: mealType)
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
            .padding(20)
        }
    }

    private func macro(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value) g").font(.title3.bold()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

// MARK: - Formulário de alimento personalizado

struct CustomFoodForm: View {
    @EnvironmentObject var model: AppModel
    let mealType: MealType
    /// [F3] Código de barras vindo do scanner (produto não encontrado na base).
    let barcode: String?
    let onDone: () -> Void

    @State private var name = ""
    @State private var brand = ""   // [F3] marca/fabricante (opcional)
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    /// [2026-08-06] O peso da porção a que os números acima se referem.
    ///
    /// Nasce "100" porque com 100 a conversão para 100 g é a identidade: quem
    /// não olhar este campo recebe exatamente o comportamento antigo. Uma
    /// correção não pode criar um erro novo para quem ignorou a mudança.
    @State private var porcaoG = "100"
    @State private var selectedMeal: MealType
    @State private var showError = false

    init(mealType: MealType, barcode: String? = nil, onDone: @escaping () -> Void) {
        self.mealType = mealType
        self.barcode = barcode
        self.onDone = onDone
        _selectedMeal = State(initialValue: mealType)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(kcal) != nil &&
        Int(protein) != nil &&
        Int(carbs) != nil &&
        Int(fat) != nil &&
        (Int(porcaoG) ?? 0) > 0
    }

    /// [2026-08-06] CONVERSÃO DA UNIDADE — o conserto.
    ///
    /// O formulário pergunta os macros POR PORÇÃO (é assim que a pessoa pensa
    /// numa marmita) e o `StoredFood` guarda POR 100 G (é assim que o resto do
    /// app calcula). Até hoje os mesmos números iam para os dois lugares, sem
    /// conversão nenhuma: uma marmita de 600 kcal virava 600 kcal POR 100 G, e
    /// a próxima leitura do código de barras a 350 g devolvia 2 100 kcal.
    ///
    /// Mesmo gênero do bug do scan de 05/08 — número mudando de unidade em
    /// silêncio, sem nada na tela denunciando.
    ///
    /// O arredondamento fica AQUI, no item de catálogo, e nunca no número que a
    /// pessoa digitou: o `Meal` recebe o valor por porção intacto.
    ///
    /// CUSTO, com o tamanho certo — [revisão 06/08] a versão anterior deste
    /// comentário dizia "um kcal de deriva" e subestimava o caso ruim:
    /// · em kcal a perda é desprezível — 600 em 350 g viram 171/100 g, que de
    ///   volta a 350 g dão 599;
    /// · em macro PEQUENO com porção GRANDE a perda é total — 1 g de gordura em
    ///   350 g dá 0,29/100 g, que num campo `Int` é **0**, e o macro some do
    ///   item de catálogo para sempre.
    ///
    /// Isso é limitação do campo ser `Int`, não da conversão, e vale para todo
    /// o `StoredFood`. Não arredondo para cima: inflar 0,29 para 1 seria
    /// inventar 3× de gordura em cada uso futuro. Quem for dar precisão a isto
    /// muda o tipo do campo, não esta função. Nada disso toca o `Meal` — o que
    /// entra no diário hoje continua sendo o número digitado.
    static func converterPara100g(_ valorDaPorcao: Int, gramasDaPorcao: Int) -> Int {
        guard gramasDaPorcao > 0 else { return valorDaPorcao }
        return Int((Double(valorDaPorcao) * 100.0 / Double(gramasDaPorcao)).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Nome
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nome do alimento").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    TextField("Ex.: Pão caseiro, Marmita…", text: $name)
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }

                // [F3] Marca (opcional) + código escaneado
                VStack(alignment: .leading, spacing: 6) {
                    Text("Marca / fabricante (opcional)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    TextField("Ex.: Nestlé, Piracanjuba…", text: $brand)
                        .padding(12)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    if let code = barcode {
                        Label("Código \(code) — este produto ficará salvo para a próxima leitura",
                              systemImage: "barcode")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                // [2026-08-06] O peso da porção vem ANTES dos macros, porque é
                // ele que dá sentido aos números seguintes. Sem esta pergunta o
                // formulário não tinha como saber de quanto a pessoa falava — e
                // chutava 100 g, em silêncio.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Peso da porção (g)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    macroField("Ex.: 350", text: $porcaoG, tint: Theme.primary)
                    Text("Os macros abaixo são desta porção. O alimento fica salvo convertido para 100 g, para a próxima vez.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }

                // Grid de macros
                VStack(alignment: .leading, spacing: 6) {
                    // [revisão 06/08] Enquanto o campo está vazio no meio da
                    // digitação, o rótulo dizia "por porção de 0 g" — um número
                    // que não é verdade em tela, que é o gênero de coisa que
                    // este conserto existe para tirar do app. Sem número válido,
                    // o rótulo simplesmente não promete quantidade nenhuma.
                    Text((Int(porcaoG) ?? 0) > 0
                         ? "Macros (por porção de \(Int(porcaoG) ?? 0) g)"
                         : "Macros (por porção)")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    HStack(spacing: 10) {
                        macroField("kcal", text: $kcal, tint: Theme.coral)
                        macroField("Proteína (g)", text: $protein, tint: Theme.primary)
                    }
                    HStack(spacing: 10) {
                        macroField("Carbo (g)", text: $carbs, tint: Theme.gold)
                        macroField("Gordura (g)", text: $fat, tint: Theme.azure)
                    }
                }

                // Refeição
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refeição").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                    Picker("Refeição", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if showError {
                    Text("Preencha todos os campos antes de adicionar.")
                        .font(.caption)
                        .foregroundStyle(Theme.coral)
                }

                Button {
                    guard isValid else { showError = true; return }
                    // [revisão 06/08] `Int(porcaoG) ?? 100` era código morto
                    // perigoso: o `isValid` já garante > 0, então o 100 nunca
                    // dispararia — mas ele é exatamente o "chuta 100 g em
                    // silêncio" que este conserto existe para matar. Bastaria
                    // alguém afrouxar o isValid para o bug voltar sem sinal.
                    // Sem valor de reserva, não há para onde ele voltar.
                    guard let gramas = Int(porcaoG), gramas > 0 else {
                        showError = true; return
                    }
                    let cleanName = name.trimmingCharacters(in: .whitespaces)
                    let cleanBrand = brand.trimmingCharacters(in: .whitespaces)
                    let comMarca = cleanBrand.isEmpty ? cleanName : "\(cleanName) (\(cleanBrand))"
                    let meal = Meal(
                        type: selectedMeal,
                        // [2026-08-06] A porção passa a aparecer no nome. Este
                        // era o único caminho de registro que não dizia de
                        // quanto falava — nem no texto, nem em campo nenhum.
                        name: "\(comMarca) · \(gramas) g",
                        // Os números digitados entram no diário INTACTOS. O
                        // arredondamento da conversão fica só no catálogo.
                        kcal: Int(kcal) ?? 0,
                        protein: Int(protein) ?? 0,
                        carbs: Int(carbs) ?? 0,
                        fat: Int(fat) ?? 0,
                        done: true
                    )
                    model.meals.append(meal)
                    // [F3] Guarda o alimento do usuário — com marca e barcode,
                    // a próxima leitura do mesmo código acha na hora.
                    // [2026-08-06] Agora CONVERTIDO para 100 g. Antes copiava o
                    // valor da porção para o campo por-100-g: uma marmita de
                    // 600 kcal voltava, na leitura seguinte, como 600 kcal/100 g.
                    model.userFoods.append(StoredFood(
                        name: cleanName,
                        brand: cleanBrand.isEmpty ? nil : cleanBrand,
                        kcalPer100:    Self.converterPara100g(Int(kcal) ?? 0,    gramasDaPorcao: gramas),
                        proteinPer100: Self.converterPara100g(Int(protein) ?? 0, gramasDaPorcao: gramas),
                        carbsPer100:   Self.converterPara100g(Int(carbs) ?? 0,   gramasDaPorcao: gramas),
                        fatPer100:     Self.converterPara100g(Int(fat) ?? 0,     gramasDaPorcao: gramas),
                        barcode: barcode
                    ))
                    onDone()
                } label: {
                    Label("Adicionar à \(selectedMeal.rawValue)", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
            }
            .padding(20)
        }
    }

    private func macroField(_ label: String, text: Binding<String>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(tint)
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .padding(10)
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.3), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AddFoodView().environmentObject(AppModel())
}
