// UnidadeDeMedida.swift
// Alma — Corpo · a unidade em que um alimento é medido, e os dois tipos de dado
// que a carregam.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE, E POR QUE SÓ IMPORTA `Foundation`
//
// Duas razões, e a segunda é a que importa mais.
//
// 1. PEDIDO DO ASSIS (12/08): "ao adicionar leite só oferece grama; tudo que é
//    líquido deveria ser em mililitro". Até aqui o app inteiro media em grama,
//    e a letra "g" estava chumbada em oito lugares diferentes da interface.
//
// 2. REGRA 4 DO CLAUDE.md — asserção não encosta em dado real. `Models.swift`
//    importa SwiftUI, depende de `UserDefaults` e arrasta meia dúzia de outros
//    arquivos junto; nada dele compila fora do aparelho. A decisão que este
//    trabalho precisa provar — "um alimento gravado ANTES da unidade existir
//    continua legível?" — é Foundation puro.
//
//    Trazendo `FoodItem` e `StoredFood` para cá (eles nunca dependeram de
//    SwiftUI; estavam em `Models.swift` só por vizinhança), o harness
//    `_scripts/testes_unidade.swift` compila ESTE ARQUIVO, o de produção, com
//    `swiftc` direto — sem simulador, sem cópia, sem reimplementação. Testar
//    uma cópia do decoder provaria que a cópia funciona.
//
// ── A ARMADILHA QUE ESTE ARQUIVO EXISTE PARA NÃO PISAR ─────────────────────
//
// `StoredFood` é `Codable` e vive em `UserDefaults` na chave `userFoods`. Em
// Swift, o decoder SINTETIZADO chama `decode(_:forKey:)` para toda propriedade
// não-opcional — INCLUSIVE as que têm valor padrão. Ou seja:
//
//     var unidade: Unidade = .grama        // ← parece inofensivo
//
// faz TODO alimento personalizado gravado antes desta versão lançar
// `keyNotFound`. E o `AppModel.init` lê com `try?`, então o erro é engolido: a
// lista simplesmente volta vazia. A pessoa abre o app e os alimentos que ela
// cadastrou sumiram, sem erro na tela, sem log, sem nada. Na primeira vez que
// ela cadastrar qualquer coisa nova, o `didSet` regrava por cima e a perda
// vira permanente.
//
// Por isso o `init(from:)` abaixo é ESCRITO À MÃO. Não é preciosismo nem
// preferência de estilo: é a única forma de o campo novo ser não-opcional e o
// dado velho continuar de pé. A asserção U3 prova isso por mutação — trocar
// este init pelo sintetizado deixa o teste vermelho.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

// MARK: - Unidade

/// Grama ou mililitro. Duas unidades, uma aritmética.
///
/// A conta não muda com a unidade: os macros são sempre "por 100 <unidade>", e
/// escalar 250 ml de leite usa exatamente a mesma multiplicação que escalar
/// 250 g de arroz. O que muda é o RÓTULO — e é aí que mora o bug.
///
/// ── POR QUE NÃO EXISTE UM `Unidade(paraAlimentoChamado:)` ──────────────────
///
/// A versão rápida deste recurso seria adivinhar a unidade pelo nome: uma lista
/// com "leite", "suco", "água" e um `contains`. Ela é tentadora porque conserta
/// o caso do Assis em dez minutos e porque parece que não custa nada.
///
/// Custa. É literalmente o bug que custou dois dias em 06/08 (`AddFoodView`,
/// commit 9ba23fc): um número trocando de unidade sem que a tela dissesse.
/// Adivinhar por nome erra em silêncio nos dois sentidos — "leite em pó" e
/// "creme de leite" são medidos em grama e casam com "leite"; "caldo de cana"
/// não casa com nada e é líquido — e a pessoa não tem como perceber, porque a
/// interface fica igual nos dois casos.
///
/// A regra deste arquivo é outra: **a unidade é um DADO do alimento, nunca uma
/// inferência sobre ele.** No catálogo embutido ela é declarada item a item
/// (`Models.swift`, curadoria escrita à mão, revisável em diff). No alimento
/// personalizado quem escolhe é a pessoa, num controle visível. Em produto de
/// código de barras ela vem da base ou, na falta, é grama — e o rótulo diz
/// grama, que é o que de fato está sendo contado.
///
/// Declarar item a item numa lista versionada NÃO é a mesma coisa que inferir
/// por nome em tempo de execução, ainda que as duas coisas envolvam uma lista:
/// a primeira é revisável antes de subir e erra de forma visível no diff; a
/// segunda decide sozinha, no aparelho da pessoa, sobre nomes que ninguém nunca
/// viu.
public enum Unidade: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case grama = "g"
    case mililitro = "ml"

    public var id: String { rawValue }

    /// O que aparece colado no número: "250 g", "200 ml".
    public var abreviacao: String { rawValue }

    /// Para frases: "gramas", "mililitros".
    public var plural: String {
        switch self {
        case .grama:     return "gramas"
        case .mililitro: return "mililitros"
        }
    }

    /// A base nutricional como quantidade: "100 g" / "100 ml".
    public var cem: String { "100 \(rawValue)" }

    /// O rótulo da base nutricional: "por 100 g" / "por 100 ml".
    public var base100: String { "por \(cem)" }

    /// A unidade de tudo que foi gravado antes desta versão existir.
    ///
    /// Não é um palpite: até 12/08/2026 o app só media em grama, então todo
    /// registro sem campo de unidade É grama. Ter isto nomeado (em vez de um
    /// `.grama` solto espalhado por seis arquivos) é o que permite responder
    /// "por que grama aqui?" sem reabrir o histórico do git.
    public static let padraoHistorico: Unidade = .grama

    /// Lê a unidade de um JSON que pode não ter o campo — e nunca lança por
    /// causa disso.
    ///
    /// Duas tolerâncias, com motivos diferentes:
    ///
    /// · **Campo ausente** → `padraoHistorico`. É o caso do dado antigo, e é
    ///   simplesmente a verdade: aquele alimento foi cadastrado em grama.
    ///
    /// · **Texto desconhecido** (um "oz" que uma versão futura tenha gravado)
    ///   → também `padraoHistorico`, e aqui é uma TROCA CONSCIENTE, não
    ///   descuido. Lançar seria coerente com "não mostre unidade errada", mas o
    ///   `try?` do `AppModel` transforma qualquer lance em lista vazia: o preço
    ///   de recusar um rótulo estranho seria apagar TODOS os alimentos da
    ///   pessoa, inclusive os que estão perfeitos. Um rótulo errado num item é
    ///   menos grave que a perda silenciosa da coleção inteira, que é
    ///   exatamente o desastre que este arquivo existe para impedir.
    public static func lerRetrocompativel<K: CodingKey>(
        de container: KeyedDecodingContainer<K>,
        chave: K
    ) throws -> Unidade {
        guard let bruto = try container.decodeIfPresent(String.self, forKey: chave) else {
            return padraoHistorico
        }
        return Unidade(rawValue: bruto) ?? padraoHistorico
    }

    /// A unidade que o FABRICANTE declarou na embalagem, quando dá para ler.
    ///
    /// Entra o campo `quantity` da Open Food Facts — "1 L", "200 ml", "395 g",
    /// "500g". Sai `.mililitro` se a embalagem é vendida por volume, `.grama` se
    /// por massa, e `nil` quando o texto não diz nem uma coisa nem outra.
    ///
    /// ── ISTO NÃO É A ADIVINHAÇÃO POR NOME QUE A NOTA ACIMA RECUSA ──────────
    ///
    /// A diferença não é de grau, é de natureza. Adivinhar por nome é o app
    /// opinando sobre o que "leite" provavelmente é. Aqui o app está LENDO um
    /// dado que o fabricante declarou sobre aquele produto específico: um item
    /// vendido em 1 L é líquido, ponto — não é uma probabilidade, é a
    /// embalagem. Por isso "Leite em pó · 400 g" cai em `.grama` sem nenhum
    /// caso especial, enquanto a lista de nomes erraria nele.
    ///
    /// Só reconhece marcador EXPLÍCITO. Sem marcador → `nil`, e quem chama usa
    /// grama, que é o que já acontecia. Inventar aqui seria trocar uma
    /// adivinhação por outra.
    public static func daEmbalagem(_ texto: String?) -> Unidade? {
        guard let texto, !texto.isEmpty else { return nil }
        let limpo = texto
            .folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "pt_BR"))
            .replacingOccurrences(of: ",", with: ".")

        // A unidade é o que vem DEPOIS do número. Pegar a última ocorrência
        // evita casar com o "l" de "light" ou o "g" de "grande" no meio do nome.
        // `cl`/`dl` entram porque aparecem em rótulo europeu, que a base tem
        // bastante.
        let volume = ["ml", "millilitros", "mililitros", "cl", "dl", "l", "lt", "litro", "litros"]
        let massa  = ["mg", "g", "gr", "grama", "gramas", "kg", "quilo", "quilos"]

        // Varre da direita para a esquerda: a última unidade citada é a da
        // quantidade líquida ("Caixa 12 x 1 L" → L).
        let pedacos = limpo
            .replacingOccurrences(of: "[^a-z0-9. ]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0 == " " })
            .map(String.init)

        for pedaco in pedacos.reversed() {
            // "350ml" vem grudado: separa o sufixo alfabético do número.
            let sufixo = String(pedaco.drop(while: { $0.isNumber || $0 == "." }))
            guard !sufixo.isEmpty else { continue }
            if volume.contains(sufixo) { return .mililitro }
            if massa.contains(sufixo)  { return .grama }
        }
        return nil
    }
}

// MARK: - Quantidade formatada

/// O texto de uma quantidade, com a sua unidade — em UM lugar só.
///
/// Antes desta função a letra "g" era digitada à mão em oito pontos da
/// interface (`AddFoodView` ×3, `FoodScanView` ×3, `AppModel.addFood`,
/// `CustomFoodForm`). Enquanto tudo era grama isso passava despercebido; com
/// duas unidades, cada ponto desses é um lugar onde a tela pode dizer "g" sobre
/// um número que representa ml.
///
/// Sendo função, o harness lê a MESMA fonte que a tela — que é o desenho que
/// tornou possível provar o conserto da porção em 06/08.
public func textoDaQuantidade(_ valor: Int, _ unidade: Unidade) -> String {
    "\(valor) \(unidade.abreviacao)"
}

// MARK: - Alimento (catálogo, busca, resultado de scan)

/// Um alimento com os macros por 100 unidades. Não é persistido — é o que
/// circula entre a busca, o catálogo e a tela de quantidade.
public struct FoodItem: Identifiable {
    public let id = UUID()
    public let name: String
    public let kcalPer100: Int
    public let proteinPer100: Int
    public let carbsPer100: Int
    public let fatPer100: Int
    public let emoji: String
    public var barcode: String? = nil
    /// Marca/fabricante (vem da Open Food Facts ou do cadastro manual).
    public var brand: String? = nil
    /// [2026-08-12] Em que unidade este alimento é medido.
    ///
    /// Valor padrão `.grama` de propósito: as ~300 entradas do `foodDatabase` e
    /// os dois outros construtores continuam compilando sem mudança, e só os
    /// líquidos precisam dizer alguma coisa. `FoodItem` NÃO é `Codable` (não
    /// tem `Codable` na declaração e nunca é gravado), então aqui o valor padrão
    /// é seguro — a armadilha do decoder sintetizado descrita no topo deste
    /// arquivo vale para `StoredFood`, não para este tipo.
    public var unidade: Unidade = .grama

    public init(name: String, kcalPer100: Int, proteinPer100: Int, carbsPer100: Int,
                fatPer100: Int, emoji: String, barcode: String? = nil,
                brand: String? = nil, unidade: Unidade = .grama) {
        self.name = name
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbsPer100 = carbsPer100
        self.fatPer100 = fatPer100
        self.emoji = emoji
        self.barcode = barcode
        self.brand = brand
        self.unidade = unidade
    }
}

// MARK: - Alimento cadastrado pela pessoa (persistido)

/// Alimento cadastrado pelo usuário — persiste em `UserDefaults`, chave
/// `userFoods`.
///
/// ⚠️ TODO CAMPO NOVO AQUI PASSA PELO `init(from:)` ABAIXO. Ver o cabeçalho do
/// arquivo: acrescentar uma propriedade não-opcional e confiar no decoder
/// sintetizado apaga os alimentos de todo mundo que já usa o app.
public struct StoredFood: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var brand: String?
    public var kcalPer100: Int
    public var proteinPer100: Int
    public var carbsPer100: Int
    public var fatPer100: Int
    public var barcode: String?
    /// [2026-08-12] Grama ou mililitro, escolhido pela pessoa no cadastro.
    public var unidade: Unidade = .grama

    public init(id: UUID = UUID(), name: String, brand: String? = nil,
                kcalPer100: Int, proteinPer100: Int, carbsPer100: Int, fatPer100: Int,
                barcode: String? = nil, unidade: Unidade = .grama) {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcalPer100 = kcalPer100
        self.proteinPer100 = proteinPer100
        self.carbsPer100 = carbsPer100
        self.fatPer100 = fatPer100
        self.barcode = barcode
        self.unidade = unidade
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, brand, kcalPer100, proteinPer100, carbsPer100, fatPer100
        case barcode, unidade
    }

    /// Decodificador À MÃO — e o comentário longo lá em cima é sobre esta
    /// função. Resumo, para quem chegou por aqui:
    ///
    /// o sintetizado usaria `decode` (não `decodeIfPresent`) em `unidade`,
    /// porque a propriedade é não-opcional, e valor padrão NÃO conta para o
    /// decoder. Todo JSON gravado antes de 12/08/2026 — que é todo JSON de todo
    /// usuário existente — não tem essa chave. `keyNotFound`, `try?` engole,
    /// coleção vazia.
    ///
    /// `id` também vai de `decodeIfPresent`: nenhuma versão gravou `StoredFood`
    /// sem `id`, então é cinto sobre suspensório — mas custa uma linha e fecha a
    /// mesma classe de falha caso algum dado tenha sido escrito à mão em teste.
    ///
    /// O `encode(to:)` continua sintetizado (Swift sintetiza cada exigência do
    /// protocolo separadamente), então o que sai no disco inclui `unidade` a
    /// partir de agora, sem código nenhum aqui.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name          = try c.decode(String.self, forKey: .name)
        brand         = try c.decodeIfPresent(String.self, forKey: .brand)
        kcalPer100    = try c.decode(Int.self, forKey: .kcalPer100)
        proteinPer100 = try c.decode(Int.self, forKey: .proteinPer100)
        carbsPer100   = try c.decode(Int.self, forKey: .carbsPer100)
        fatPer100     = try c.decode(Int.self, forKey: .fatPer100)
        barcode       = try c.decodeIfPresent(String.self, forKey: .barcode)
        unidade       = try Unidade.lerRetrocompativel(de: c, chave: .unidade)
    }

    public var asFoodItem: FoodItem {
        FoodItem(name: name, kcalPer100: kcalPer100, proteinPer100: proteinPer100,
                 carbsPer100: carbsPer100, fatPer100: fatPer100, emoji: "📦",
                 barcode: barcode, brand: brand, unidade: unidade)
    }
}
