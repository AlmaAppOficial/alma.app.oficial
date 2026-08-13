//
//  OpenFoodFacts.swift
//  Corpo & Alma
//
//  Consulta de produtos por código de barras na base Open Food Facts
//  (gratuita, sem API key, com marca/fabricante e boa cobertura BR/PT).
//  Produtos consultados ficam em cache local — a próxima leitura do mesmo
//  código não vai à rede. Nada além do código de barras é enviado.
//

import Foundation

// MARK: - Produto em cache (Codable, persiste em UserDefaults)

struct CachedProduct: Codable, Equatable {
    let barcode: String
    let name: String
    let brand: String?

    /// Valores por 100 g/ml **como a base declarou**. `nil` = a Open Food Facts
    /// não tem esse nutriente cadastrado para este produto.
    ///
    /// [2026-08-13] Os quatro eram `Int` não-opcional e o parse fazia
    /// `Int((n?.kcal ?? 0).rounded())`. A distinção existe no JSON — a chave
    /// `energy-kcal_100g` simplesmente não vem quando ninguém preencheu, o que
    /// é comum no catálogo brasileiro — e era destruída na leitura. Um alimento
    /// real com cadastro incompleto entrava na dieta **valendo zero** e
    /// deflacionava o total do dia sem aviso nenhum: a pessoa comia, registrava,
    /// e o app dizia que ela não tinha comido.
    ///
    /// `Optional` aqui é seguro para o cache já gravado em `UserDefaults`
    /// (`offProductCache`) pela mesma razão explicada em `unidade` logo abaixo:
    /// o Swift sintetiza `decodeIfPresent` e o dado antigo continua legível.
    /// O contrário — passar de opcional para não-opcional — é que seria a
    /// armadilha.
    let kcalPer100: Int?
    let proteinPer100: Int?
    let carbsPer100: Int?
    let fatPer100: Int?
    /// [2026-08-12] A unidade lida da embalagem declarada pelo fabricante.
    ///
    /// **OPCIONAL, e isso é a parte importante.** Este tipo é `Codable` e vive
    /// no cache em `UserDefaults` (`offProductCache`). Uma propriedade NÃO
    /// opcional aqui — mesmo com valor padrão — faria o decodificador
    /// sintetizado lançar `keyNotFound` em todo produto já cacheado, e o
    /// `try?` do `cacheDict()` transformaria isso em cache vazio, em silêncio.
    /// É a mesma armadilha descrita no cabeçalho de `UnidadeDeMedida.swift`;
    /// aqui o estrago seria menor (cache se refaz pela rede) mas o mecanismo é
    /// idêntico. `Optional` faz o Swift sintetizar `decodeIfPresent`, e o dado
    /// antigo continua legível.
    ///
    /// `nil` = a base não disse, ou disse algo que não dá para ler → grama.
    let unidade: Unidade?

    /// O produto como item de dieta — `nil` quando a base não tem a energia.
    ///
    /// [2026-08-13] Sem kcal não existe item de dieta honesto: o alimento
    /// entraria valendo 0 e subtrairia do total do dia aquilo que a pessoa
    /// realmente comeu. Quem chama decide o que fazer com o `nil` (o fluxo da
    /// Dieta oferece o cadastro manual, já com nome e marca preenchidos).
    ///
    /// **Fronteira conhecida, declarada de propósito:** quando a energia
    /// existe mas um MACRO não, o macro vira 0 aqui. `FoodItem` — e o
    /// `StoredFood` que ele alimenta — carrega os macros como `Int`
    /// não-opcional, e `StoredFood` é `Codable` gravado em `UserDefaults`.
    /// Torná-los opcionais é refatoração da dieta inteira com um decodificador
    /// sintetizado no meio do caminho (a armadilha do topo de
    /// `UnidadeDeMedida.swift`), e não cabe junto com esta correção. O estrago
    /// é menor e de outra natureza: afeta a meta de proteína/carbo/gordura,
    /// não o total calórico do dia.
    var asFoodItem: FoodItem? {
        guard let kcal = kcalPer100 else { return nil }
        return FoodItem(name: name, kcalPer100: kcal,
                        proteinPer100: proteinPer100 ?? 0,
                        carbsPer100: carbsPer100 ?? 0,
                        fatPer100: fatPer100 ?? 0, emoji: "🛒",
                        barcode: barcode, brand: brand,
                        unidade: unidade ?? .padraoHistorico)
    }
}

// MARK: - Erros

enum ProductLookupError: LocalizedError {
    case offline
    case notFound
    case badResponse

    var errorDescription: String? {
        switch self {
        case .offline:     return "Sem conexão. Verifique a internet e tente de novo, ou cadastre o produto manualmente."
        case .notFound:    return "Produto não encontrado na base. Você pode cadastrá-lo manualmente."
        case .badResponse: return "A base de produtos respondeu com erro. Tente novamente."
        }
    }
}

// MARK: - Serviço

enum OpenFoodFactsService {

    private static let cacheKey = "offProductCache"

    // Resposta mínima da API v2
    private struct OFFResponse: Decodable {
        struct Product: Decodable {
            let product_name: String?
            let brands: String?
            let nutriments: Nutriments?
            /// [2026-08-12] Quantidade líquida da embalagem ("1 L", "395 g").
            /// É daqui que sai a unidade — do que o fabricante declarou, não de
            /// um palpite sobre o nome. Ver `Unidade.daEmbalagem`.
            let quantity: String?
        }
        struct Nutriments: Decodable {
            let kcal: Double?
            let proteins: Double?
            let carbs: Double?
            let fat: Double?

            enum CodingKeys: String, CodingKey {
                case kcal = "energy-kcal_100g"
                case proteins = "proteins_100g"
                case carbs = "carbohydrates_100g"
                case fat = "fat_100g"
            }
        }
        let status: Int?
        let product: Product?
    }

    // MARK: Cache local

    static func cached(_ barcode: String) -> CachedProduct? {
        cacheDict()[barcode]
    }

    private static func cacheDict() -> [String: CachedProduct] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: CachedProduct].self, from: data) else { return [:] }
        return dict
    }

    static func saveToCache(_ product: CachedProduct) {
        var dict = cacheDict()
        dict[product.barcode] = product
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    // MARK: Consulta (cache → rede)

    /// Busca um produto pelo código de barras. Usa o cache local primeiro.
    static func lookup(_ barcode: String) async throws -> CachedProduct {
        if let hit = cached(barcode) { return hit }

        let fields = "product_name,brands,nutriments,quantity"
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            throw ProductLookupError.badResponse
        }
        var request = URLRequest(url: url)
        // Identificação pedida pela política da Open Food Facts.
        request.setValue("CorpoEAlma-iOS - contato: alma.app.oficial@gmail.com", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductLookupError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw ProductLookupError.badResponse }
        if http.statusCode == 404 { throw ProductLookupError.notFound }
        guard (200..<300).contains(http.statusCode) else { throw ProductLookupError.badResponse }

        let product = try produto(deJSON: data, barcode: barcode)
        saveToCache(product)
        return product
    }

    // MARK: Parse (separado da rede de propósito — é o que dá para verificar)

    /// Constrói o produto a partir do corpo cru devolvido pela Open Food Facts.
    ///
    /// Existe separado de `lookup` porque a REGRA que interessa não é a
    /// chamada HTTP, é o que se faz com o JSON — e um teste que precisasse de
    /// rede não seria teste, seria sorteio. Aqui dá para alimentar a resposta
    /// exata que a base devolve para um produto com cadastro incompleto e
    /// exigir que o resultado diga "não sei" em vez de "zero".
    ///
    /// - Throws: `ProductLookupError.notFound` quando não há produto ou nome.
    static func produto(deJSON data: Data, barcode: String) throws -> CachedProduct {
        guard let decoded = try? JSONDecoder().decode(OFFResponse.self, from: data),
              decoded.status == 1,
              let p = decoded.product,
              let rawName = p.product_name, !rawName.isEmpty else {
            throw ProductLookupError.notFound
        }

        let n = p.nutriments
        return CachedProduct(
            barcode: barcode,
            name: rawName,
            brand: p.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            // `map`, não `?? 0`. Campo ausente continua ausente até o fim.
            kcalPer100: inteiro(n?.kcal),
            proteinPer100: inteiro(n?.proteins),
            carbsPer100: inteiro(n?.carbs),
            fatPer100: inteiro(n?.fat),
            unidade: Unidade.daEmbalagem(p.quantity)
        )
    }

    /// Arredonda preservando a ausência. `nil` entra, `nil` sai.
    ///
    /// Valor não finito (`NaN`/infinito, que um JSON malformado consegue
    /// produzir) também vira `nil`: `Int(Double.nan)` é crash em Swift, e
    /// "número impossível" é tão pouco informativo quanto ausência.
    private static func inteiro(_ valor: Double?) -> Int? {
        guard let v = valor, v.isFinite, v >= 0 else { return nil }
        return Int(v.rounded())
    }
}
