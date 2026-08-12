// Refeicao.swift
// Alma — Corpo · a refeição do diário e os componentes que ela pode ter.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE
//
// Pedido do Assis (12/08): o scan grava UM item — "peito de frango grelhado com
// arroz e salada · 100 g" — quando o prato tinha três coisas de tamanhos
// diferentes. Ele quer os componentes separados, cada um com sua quantidade, e
// editáveis DEPOIS de registrados.
//
// O obstáculo nunca foi de tela; era de modelo, e o `MealDetailView` já dizia
// isso desde 06/08, na dívida declarada do próprio cabeçalho: `Meal` não
// guardava nem a quantidade nem a base por 100 — o `addFood` escrevia a porção
// DENTRO da string do nome ("Frango · 250 g") e jogava o número fora. Sem os
// dois números gravados, editar exigiria fazer parsing do nome, que é a pior
// ideia possível.
//
// Este arquivo é o passo (a) daquela dívida: os campos. Só Foundation, pelo
// mesmo motivo do `UnidadeDeMedida.swift` — `_scripts/testes_refeicao.swift`
// compila ISTO, o código de produção, com `swiftc`, e prova as duas coisas que
// precisam de prova: que o dado velho sobrevive, e que o total nunca discorda
// da soma dos componentes.
//
// ── A MESMA ARMADILHA DO `userFoods`, AGORA NUM DADO MAIOR ────────────────
//
// `Meal` é `Codable` e vive em `UserDefaults` na chave `meals`. Um campo novo
// NÃO OPCIONAL aqui — mesmo com valor padrão — faz o decodificador sintetizado
// lançar `keyNotFound` em todo diário já gravado. E `loadMealsForToday` lê com
// `try?`: o erro é engolido e a pessoa encontra o dia em branco, com a comida
// que ela registrou hoje de manhã sumida, sem nenhuma mensagem.
//
// `componentes` é `Optional` de propósito. Para propriedade opcional o Swift
// sintetiza `decodeIfPresent`, e o dado antigo atravessa. A asserção R1 prova
// isso, e R0 é o canário que mostra a armadilha existindo.
//
// `nil` e `[]` NÃO são a mesma coisa aqui, e a diferença é usada:
//   · `nil` = refeição registrada antes disto existir, ou item avulso sem
//     decomposição. A tela mostra o total e não oferece edição por componente.
//   · `[]`  = não deve acontecer. Se acontecer, é bug de quem construiu.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

// MARK: - Tipo de refeição

/// ⚠️ OS `rawValue` DESTE ENUM ESTÃO GRAVADOS NO DISCO.
///
/// `MealType` é `Codable` e viaja dentro de cada `Meal` persistido na chave
/// `meals`. O `rawValue` é o que está escrito no JSON do aparelho de quem já
/// usa o app — trocar "Café da manhã" por "Café" faria todo `Meal` de café
/// existente lançar `dataCorrupted`, e o `try?` do `loadMealsForToday`
/// transformaria isso em diário vazio, sem aviso.
///
/// (Escrevo isto porque quase aconteceu: ao mover o enum para cá em 12/08 eu
/// digitei `= "Café"` de memória. O texto certo é o que está abaixo.)
///
/// Para mudar o que a TELA mostra sem mexer no disco, acrescente uma
/// propriedade de rótulo — nunca mexa no `rawValue`.
public enum MealType: String, CaseIterable, Identifiable, Codable {
    case cafe = "Café da manhã"
    case almoco = "Almoço"
    case lanche = "Lanche"
    case jantar = "Jantar"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .cafe:   return "sunrise.fill"
        case .almoco: return "sun.max.fill"
        case .lanche: return "cup.and.saucer.fill"
        case .jantar: return "moon.stars.fill"
        }
    }
}

// MARK: - Escala

/// Os macros de uma quantidade qualquer, a partir da base por 100.
///
/// [2026-08-12] Mudou de casa (era `AppModel.escalarPor100`) para poder ser
/// exercitada sem simulador. `AppModel.escalarPor100` continua existindo e
/// chama esta — a asserção H2d, provada em 06/08, fala do nome de lá e continua
/// falando da mesma conta. Duas implementações da mesma escala seria o começo do
/// bug que H2 fechou; por isso uma delega para a outra em vez de repetir a
/// fórmula.
public func escalarPor100(_ valorPor100: Int, quantidade: Int) -> Int {
    Int((Double(valorPor100) * Double(quantidade) / 100.0).rounded())
}

// MARK: - Componente da refeição

/// Uma das coisas que estavam no prato: "arroz branco, 150 g".
///
/// Guarda a quantidade E a base por 100 — os dois números que faltavam para
/// poder editar. Com eles, mudar 150 g para 220 g é uma multiplicação; sem
/// eles, seria adivinhação em cima de uma string.
public struct ComponenteDaRefeicao: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var nome: String
    /// Na unidade abaixo. Nunca negativa — ver `init`.
    public var quantidade: Int
    public var unidade: Unidade = .grama
    public var kcalPor100: Int
    public var proteinaPor100: Int
    public var carboPor100: Int
    public var gorduraPor100: Int

    public init(id: UUID = UUID(), nome: String, quantidade: Int,
                unidade: Unidade = .grama, kcalPor100: Int, proteinaPor100: Int,
                carboPor100: Int, gorduraPor100: Int) {
        self.id = id
        self.nome = nome
        // Um componente de quantidade negativa subtrairia calorias do dia. É a
        // classe de entrada que ninguém digita de propósito e que aparece por
        // um `-` num campo de texto ou por um número esquisito vindo da IA.
        self.quantidade = max(0, quantidade)
        self.unidade = unidade
        self.kcalPor100 = max(0, kcalPor100)
        self.proteinaPor100 = max(0, proteinaPor100)
        self.carboPor100 = max(0, carboPor100)
        self.gorduraPor100 = max(0, gorduraPor100)
    }

    private enum CodingKeys: String, CodingKey {
        case id, nome, quantidade, unidade
        case kcalPor100, proteinaPor100, carboPor100, gorduraPor100
    }

    /// À mão pelo mesmo motivo do `StoredFood`: `unidade` é não-opcional e o
    /// decodificador sintetizado exigiria a chave. Ver o cabeçalho.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nome           = try c.decode(String.self, forKey: .nome)
        quantidade     = max(0, try c.decode(Int.self, forKey: .quantidade))
        kcalPor100     = try c.decode(Int.self, forKey: .kcalPor100)
        proteinaPor100 = try c.decode(Int.self, forKey: .proteinaPor100)
        carboPor100    = try c.decode(Int.self, forKey: .carboPor100)
        gorduraPor100  = try c.decode(Int.self, forKey: .gorduraPor100)
        unidade        = try Unidade.lerRetrocompativel(de: c, chave: .unidade)
    }

    public var kcal: Int     { escalarPor100(kcalPor100, quantidade: quantidade) }
    public var proteina: Int { escalarPor100(proteinaPor100, quantidade: quantidade) }
    public var carbo: Int    { escalarPor100(carboPor100, quantidade: quantidade) }
    public var gordura: Int  { escalarPor100(gorduraPor100, quantidade: quantidade) }

    /// "Arroz branco · 150 g" — o texto da linha na tela.
    public var descricao: String { "\(nome) · \(textoDaQuantidade(quantidade, unidade))" }

    /// Uma cópia com outra quantidade. É a operação da edição.
    public func com(quantidade nova: Int) -> ComponenteDaRefeicao {
        var c = self
        c.quantidade = max(0, nova)
        return c
    }
}

// MARK: - Refeição

/// Um registro do diário alimentar.
///
/// [2026-07-29] `Codable` para persistir as refeições do dia (antes o array
/// `meals` vivia só em memória e tudo que o usuário adicionava sumia ao fechar).
public struct Meal: Identifiable, Codable, Equatable {
    public var id = UUID()
    public let type: MealType
    public let name: String
    public let kcal: Int
    public let protein: Int   // g
    public let carbs: Int     // g
    public let fat: Int       // g
    public var done: Bool
    /// [2026-08-12] Os componentes, quando esta refeição foi decomposta.
    ///
    /// OPCIONAL — ler o cabeçalho do arquivo antes de pensar em tirar o `?`.
    public var componentes: [ComponenteDaRefeicao]?

    public init(id: UUID = UUID(), type: MealType, name: String, kcal: Int,
                protein: Int, carbs: Int, fat: Int, done: Bool,
                componentes: [ComponenteDaRefeicao]? = nil) {
        self.id = id
        self.type = type
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.done = done
        self.componentes = componentes
    }

    // ═══════════════════════════════════════════════════════════════════════
    // O INVARIANTE: com componentes, o total É a soma deles.
    //
    // Dois números para a mesma coisa — o total gravado e a soma dos
    // componentes — é a definição do bug que este app passou agosto fechando
    // (a tela dizia 250 g, o diário gravava 100 g). Deixar a refeição editável
    // reabre essa porta de par em par: basta alguém mudar um componente e
    // esquecer de refazer a soma.
    //
    // A saída não é lembrar de somar: é não existir caminho que não some. Os
    // DOIS construtores abaixo são os únicos jeitos de uma refeição ganhar
    // componentes, e os dois calculam os totais a partir deles. Escrever um
    // total divergente exigiria chamar o `init` cru com `componentes:` — que é
    // exatamente a mutação que a asserção R3 procura.
    // ═══════════════════════════════════════════════════════════════════════

    /// Refeição montada a partir dos componentes. Os totais saem da soma.
    public static func comComponentes(type: MealType, name: String,
                                      componentes: [ComponenteDaRefeicao],
                                      done: Bool = true,
                                      id: UUID = UUID()) -> Meal {
        Meal(id: id, type: type, name: name,
             kcal:    componentes.reduce(0) { $0 + $1.kcal },
             protein: componentes.reduce(0) { $0 + $1.proteina },
             carbs:   componentes.reduce(0) { $0 + $1.carbo },
             fat:     componentes.reduce(0) { $0 + $1.gordura },
             done: done,
             componentes: componentes)
    }

    /// A mesma refeição com outros componentes — e os totais refeitos.
    ///
    /// Preserva `id` e `done` de propósito: editar a quantidade do arroz não
    /// pode desmarcar a refeição como consumida nem criar uma linha nova no
    /// diário. Preserva `name` porque o nome é do prato, não dos componentes.
    public func trocandoComponentes(_ novos: [ComponenteDaRefeicao]) -> Meal {
        Meal.comComponentes(type: type, name: name, componentes: novos,
                            done: done, id: id)
    }

    /// Confere o invariante. Existe para as asserções e para o `#if DEBUG` —
    /// não é chamada em caminho de produção, e é de propósito: um `assert` numa
    /// soma de inteiros não paga o risco de derrubar o app de alguém no meio do
    /// almoço.
    public var totaisBatemComOsComponentes: Bool {
        guard let c = componentes else { return true }   // sem componentes, nada a bater
        return kcal    == c.reduce(0) { $0 + $1.kcal }
            && protein == c.reduce(0) { $0 + $1.proteina }
            && carbs   == c.reduce(0) { $0 + $1.carbo }
            && fat     == c.reduce(0) { $0 + $1.gordura }
    }

    /// "Arroz 150 g · Frango 120 g · Salada 60 g" — para a linha do diário.
    public var resumoDosComponentes: String? {
        guard let c = componentes, !c.isEmpty else { return nil }
        return c.map { "\($0.nome) \(textoDaQuantidade($0.quantidade, $0.unidade))" }
                .joined(separator: " · ")
    }

    /// Esta refeição pode ser editada por componente?
    public var editavel: Bool { (componentes?.isEmpty == false) }
}
