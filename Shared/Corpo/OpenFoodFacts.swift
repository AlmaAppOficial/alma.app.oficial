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
    let kcalPer100: Int
    let proteinPer100: Int
    let carbsPer100: Int
    let fatPer100: Int

    var asFoodItem: FoodItem {
        FoodItem(name: name, kcalPer100: kcalPer100, proteinPer100: proteinPer100,
                 carbsPer100: carbsPer100, fatPer100: fatPer100, emoji: "🛒",
                 barcode: barcode, brand: brand)
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

        let fields = "product_name,brands,nutriments"
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

        guard let decoded = try? JSONDecoder().decode(OFFResponse.self, from: data),
              decoded.status == 1,
              let p = decoded.product,
              let rawName = p.product_name, !rawName.isEmpty else {
            throw ProductLookupError.notFound
        }

        let n = p.nutriments
        let product = CachedProduct(
            barcode: barcode,
            name: rawName,
            brand: p.brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            kcalPer100: Int((n?.kcal ?? 0).rounded()),
            proteinPer100: Int((n?.proteins ?? 0).rounded()),
            carbsPer100: Int((n?.carbs ?? 0).rounded()),
            fatPer100: Int((n?.fat ?? 0).rounded())
        )
        saveToCache(product)
        return product
    }
}
