// QuebraDeJejum.swift
// Alma — Corpo · a refeição que quebra o jejum, montada a partir do que o app
// já sabe. Foundation puro.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ISTO NÃO USA IA, E A DECISÃO É DELIBERADA
//
// O caminho óbvio era mandar duração + perfil + diário para um modelo e pedir
// um prato. Foi considerado e descartado, por quatro motivos — em ordem de
// peso:
//
// 1. **O caminho de IA deste app passa por Cloud Function.** Desde 05/08 a
//    análise saiu da chave no bundle e foi para `analisarFoto`
//    (`functions/src/index.ts`). Uma sugestão por IA exigiria função nova, e
//    esta frente não pode tocar naquele arquivo nem fazer deploy. Um recurso
//    que só sabe falhar é pior do que não oferecer o recurso — é a mesma lição
//    do B8, escrita em `CorpoAcesso.scanDeAlimentoDisponivel`.
//
// 2. **Macro inventado entra no diário.** A sugestão daqui vira `Meal` de
//    verdade, que soma no `kcalByDay` da pessoa. Um modelo que erra 40 % na
//    caloria de um prato contamina o histórico — exatamente o bug F2/B8, em que
//    o scan caía num mock que inventava macros. Aqui cada componente sai do
//    `foodDatabase`, com número que alguém conferiu.
//
// 3. **Isto é reprovável por mutação.** Função pura sobre listas: dá para
//    provar que jejum mais longo produz primeiro prato menor, que alergia
//    declarada some da sugestão, que o total bate com a soma. Um prompt não dá.
//
// 4. **Custo e latência zero, offline.** Quebrar o jejum é o momento em que a
//    pessoa está com fome olhando para o telefone. Meio segundo importa.
//
// O que se perde: variedade. A sugestão é determinística — mesma entrada, mesmo
// prato. Mitigado por `nomesJaRegistradosHoje`, que faz a escolha andar dentro
// do dia, e é uma limitação declarada em vez de escondida.
//
// ═══════════════════════════════════════════════════════════════════════════
// AS DUAS REGRAS QUE GOVERNAM O PRATO — E DE ONDE ELAS VÊM
//
// [26/08] O Assis pediu: *"o que é colocado na boca após a quebra do jejum deve
// ser proteína"*. Foi apurado antes de mexer no código, a evidência sustenta, e
// por isso este arquivo MUDOU — não só o texto da tela.
//
// REGRA 1 — COMEÇAR PEQUENO. Vem da literatura de Ramadã, onde há mais gente
// quebrando jejum longo do que em qualquer ensaio clínico: refeição de quebra
// muito grande, com carboidrato rápido e fritura, aparece junto com pico de
// açúcar no sangue, enjoo, inchaço e saciedade cedo demais. Programas que
// mandam comer pouco primeiro registram menos oscilação de açúcar.
//
// REGRA 2 — PROTEÍNA (E VEGETAL) ANTES DO CARBOIDRATO. Vem dos estudos de
// sequência de alimentos. A MESMA refeição, comida em ordens diferentes, produz
// picos de açúcar diferentes: com proteína e vegetal primeiro, cerca de 29 %
// menos aos 30 minutos e 37 % menos aos 60 (Shukla, Diabetes Care 2015).
// Repetido em vários estudos cruzados.
//
// As duas viram código assim:
//   · `primeiroPrato` é SÓ PROTEÍNA. A fruta que ele tinha até 26/08 saiu — ela
//     era o carboidrato, e abrir a quebra com carboidrato contradiz a regra 2
//     que a própria tela ensina duas telas adiante;
//   · `pratoPrincipal` sai ORDENADO, com o carboidrato por último, e a View
//     numera os itens. A ordem é dado, não decoração — a asserção `J10` prova
//     que o carboidrato é o último item da lista.
//
// A ressalva que não pode sumir: é "pequeno E proteína", nunca "muita
// proteína". Porção grande de qualquer coisa cai mal depois de jejum longo, e é
// por isso que `tetoDoPrimeiroPrato` existe e não subiu.
//
// A citação completa está em `JejumConteudo.sobreAQuebra`.
//
// ═══════════════════════════════════════════════════════════════════════════
// ⚠️ RESTRIÇÃO ALIMENTAR: O QUE ESTE ARQUIVO NÃO PODE ERRAR
//
// `AppModel.dietaryRestrictions` é texto livre ("alergia a amendoim, sem
// lactose"). Interpretar texto livre é chute, e o comentário do
// `CorpoContextSnapshot` já diz a régua: "sugerir amendoim a quem tem alergia
// seria pior que não sugerir nada".
//
// A saída aqui NÃO é interpretar melhor. É reconhecer o que dá para reconhecer,
// e **dizer na tela o que sobrou sem interpretar** — `restricoesNaoLidas`. Um
// filtro que engole em silêncio o que não entendeu é o pior modo de falha
// possível: a pessoa confia porque declarou a alergia, e a alergia estava lá.

import Foundation

// MARK: - Objetivo

/// O objetivo da pessoa, do ponto de vista deste motor.
///
/// Existe em vez de usar o `Goal` de `Models.swift` por um motivo só, e é o
/// mesmo do cabeçalho: `Goal` declara `var tint: Color` e portanto arrasta
/// SwiftUI. Um `import SwiftUI` aqui tiraria este arquivo do alcance do
/// `swiftc` e o motor deixaria de ser reprovável por mutação — que é metade da
/// razão de ele existir. A tradução acontece numa linha, na View.
public enum ObjetivoDaQuebra: Equatable {
    case perder, manter, ganhar
}

// MARK: - Grupos de exclusão

/// O que uma restrição alimentar declarada pode tirar da mesa.
///
/// Fechado de propósito e pequeno de propósito: cada caso aqui é um caso que o
/// leitor de texto livre sabe reconhecer com segurança. Acrescentar caso sem
/// acrescentar as palavras correspondentes em `LeitorDeRestricoes` cria um
/// grupo que nunca é acionado — verde cego.
public enum GrupoAlimentar: String, CaseIterable, Equatable {
    case lactose
    case ovo
    case gluten
    case oleaginosa
    case peixe
    case carne
}

/// Traduz o texto livre da pessoa em grupos a evitar — e confessa o resto.
public enum LeitorDeRestricoes {

    /// Palavras que acionam cada grupo. Minúsculas e sem acento no lado da
    /// comparação (ver `normalizar`).
    static let gatilhos: [(termo: String, grupos: [GrupoAlimentar])] = [
        // Vegano primeiro: é o mais abrangente, e um termo depois não desfaz.
        ("vegano",        [.carne, .peixe, .lactose, .ovo]),
        ("vegana",        [.carne, .peixe, .lactose, .ovo]),
        ("vegan",         [.carne, .peixe, .lactose, .ovo]),
        ("vegetariano",   [.carne, .peixe]),
        ("vegetariana",   [.carne, .peixe]),
        ("lactose",       [.lactose]),
        ("laticinio",     [.lactose]),
        ("leite",         [.lactose]),
        ("queijo",        [.lactose]),
        ("iogurte",       [.lactose]),
        ("whey",          [.lactose]),
        ("ovo",           [.ovo]),
        ("gluten",        [.gluten]),
        ("trigo",         [.gluten]),
        ("celiac",        [.gluten]),
        ("amendoim",      [.oleaginosa]),
        ("castanha",      [.oleaginosa]),
        ("amendoa",       [.oleaginosa]),
        ("noz",           [.oleaginosa]),
        ("oleaginosa",    [.oleaginosa]),
        ("peixe",         [.peixe]),
        ("frutos do mar", [.peixe]),
        ("camarao",       [.peixe]),
        ("atum",          [.peixe]),
        ("salmao",        [.peixe]),
        ("marisco",       [.peixe]),
        ("carne",         [.carne]),
        ("boi",           [.carne]),
        ("bovina",        [.carne]),
        ("frango",        [.carne]),
        ("porco",         [.carne]),
        ("suina",         [.carne])
    ]

    /// Palavras de ligação que não carregam informação e não devem virar
    /// "restrição que não entendi".
    static let ruido: Set<String> = [
        "alergia", "alergica", "alergico", "a", "ao", "as", "aos", "de", "do",
        "da", "dos", "das", "sem", "nao", "não", "como", "e", "ou", "com",
        "intolerancia", "intolerante", "restricao", "evito", "evitar", "tenho",
        "sou", "dieta", "para", "por", "que", "em", "no", "na", "um", "uma"
    ]

    /// Minúsculas, sem acento — para "Amêndoa" casar com "amendoa".
    public static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "pt_BR"))
    }

    /// - Returns: os grupos a evitar e o que sobrou sem ser interpretado.
    public static func ler(_ textoLivre: String) -> (evitar: Set<GrupoAlimentar>, naoLidas: [String]) {
        let bruto = textoLivre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bruto.isEmpty else { return ([], []) }

        let texto = normalizar(bruto)
        var evitar: Set<GrupoAlimentar> = []
        var restante = texto

        for (termo, grupos) in gatilhos where restante.contains(termo) {
            evitar.formUnion(grupos)
            restante = restante.replacingOccurrences(of: termo, with: " ")
        }

        // O que sobrou, palavra por palavra, tirando ruído e pedaços curtos.
        let sobras = restante
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 && !ruido.contains($0) }

        // Sem duplicar, preservando a ordem em que a pessoa escreveu.
        var vistas: Set<String> = []
        let naoLidas = sobras.filter { vistas.insert($0).inserted }

        return (evitar, naoLidas)
    }
}

// MARK: - Papel no prato

/// O que cada item cumpre — e, no prato principal, em que ORDEM ele deve ser
/// comido.
///
/// A ordem dos `case` NÃO é livre: `ordemDeComer` a usa para montar o prato
/// principal, e o carboidrato é o último de propósito (regra 2 do cabeçalho).
/// Reordenar aqui muda o que a tela manda a pessoa comer primeiro.
public enum PapelNoPrato: String, CaseIterable, Equatable {
    case proteina
    case vegetal
    case gordura
    case carboidrato

    /// Ordem de consumo do prato principal. Carboidrato por último.
    public static let ordemDeComer: [PapelNoPrato] = [.proteina, .vegetal, .gordura, .carboidrato]

    public var rotulo: String {
        switch self {
        case .proteina:    return "proteína"
        case .vegetal:     return "vegetal"
        case .gordura:     return "gordura"
        case .carboidrato: return "carboidrato"
        }
    }
}

/// Um item da sugestão: o alimento e o papel que ele cumpre.
///
/// Existe porque a ORDEM virou informação de produto em 26/08. Antes bastava
/// uma lista de `ComponenteDaRefeicao`; agora a tela precisa saber qual item é
/// o carboidrato para poder dizer "este por último", e a asserção precisa
/// conseguir verificar isso sem adivinhar pelo nome do alimento.
public struct ItemDaQuebra: Identifiable, Equatable {
    public let componente: ComponenteDaRefeicao
    public let papel: PapelNoPrato
    public var id: UUID { componente.id }

    public init(componente: ComponenteDaRefeicao, papel: PapelNoPrato) {
        self.componente = componente
        self.papel = papel
    }
}

// MARK: - Candidato

/// Um alimento que o motor pode escolher, com o papel que ele cumpre no prato.
///
/// Os grupos ficam AQUI, na lista curada, e não espalhados pelo `foodDatabase`
/// inteiro. Motivo: o `foodDatabase` tem centenas de entradas e nenhuma delas
/// declara alérgeno. Etiquetar as ~20 que este motor sabe usar é verificável;
/// etiquetar 300 de memória seria inventar dado — e dado inventado sobre
/// alergia é o pior tipo.
struct CandidatoDeQuebra {
    let nome: String
    /// Quantidade de partida, na unidade do alimento. É escalada depois.
    let quantidadeBase: Int
    let grupos: [GrupoAlimentar]
}

// MARK: - Gentileza

/// O quanto a quebra pede cuidado, derivado só da duração do jejum.
public enum GentilezaDaQuebra: String, Equatable {
    /// Menos de 14 h. É um intervalo entre refeições comum; nada de especial.
    case direta
    /// 14 h a 18 h.
    case moderada
    /// 18 h ou mais.
    case cuidadosa

    public static func para(duracao: TimeInterval) -> GentilezaDaQuebra {
        let horas = duracao / 3600
        if horas >= 18 { return .cuidadosa }
        if horas >= 14 { return .moderada }
        return .direta
    }

    /// Minutos sugeridos entre o primeiro prato e o principal. `0` na direta.
    public var intervaloEmMinutos: Int {
        switch self {
        case .direta:     return 0
        case .moderada:   return 20
        case .cuidadosa:  return 30
        }
    }

    /// Teto de calorias do primeiro prato. A porção leve é leve.
    var tetoDoPrimeiroPrato: Int {
        switch self {
        case .direta:     return 0
        case .moderada:   return 250
        case .cuidadosa:  return 200
        }
    }

    public var explicacao: String {
        switch self {
        case .direta:
            return "Menos de 14 horas é um intervalo normal entre refeições. Não precisa de cuidado especial. Só coma o carboidrato por último."
        case .moderada:
            return "Depois de 14 a 18 horas, uma porção pequena de proteína antes do prato principal cai melhor do que sentar e comer tudo de uma vez."
        case .cuidadosa:
            return "Depois de 18 horas, a refeição da quebra é a que mais dá desconforto. Comece com pouca proteína e espere meia hora antes do prato principal."
        }
    }
}

// MARK: - Sugestão

public struct SugestaoDeQuebra: Equatable {
    public let gentileza: GentilezaDaQuebra
    /// Vazio quando `gentileza == .direta`. Quando existe, é **só proteína** —
    /// ver a regra 2 do cabeçalho.
    public let primeiroPrato: [ItemDaQuebra]
    /// **Já na ordem de comer**, com o carboidrato por último. A View mostra a
    /// lista como está; reordenar na tela desfaria a regra.
    public let pratoPrincipal: [ItemDaQuebra]
    public let intervaloEmMinutos: Int
    /// Orçamento calórico usado, e se ele veio da meta da pessoa ou de um
    /// padrão. O app não finge que um padrão é cálculo pessoal — mesma régua do
    /// `metaEhEstimada`.
    public let orcamentoKcal: Int
    public let orcamentoVeioDaMeta: Bool
    /// Restrições declaradas que o leitor não soube interpretar. A tela é
    /// OBRIGADA a mostrar isto quando não for vazio.
    public let restricoesNaoLidas: [String]
    /// Grupos efetivamente evitados, para a tela poder dizer o que respeitou.
    public let gruposEvitados: [GrupoAlimentar]

    public var kcalDoPrimeiroPrato: Int { primeiroPrato.reduce(0) { $0 + $1.componente.kcal } }
    public var kcalDoPratoPrincipal: Int { pratoPrincipal.reduce(0) { $0 + $1.componente.kcal } }
    public var kcalTotal: Int { kcalDoPrimeiroPrato + kcalDoPratoPrincipal }
    public var proteinaTotal: Int {
        (primeiroPrato + pratoPrincipal).reduce(0) { $0 + $1.componente.proteina }
    }
    public var temPrimeiroPrato: Bool { !primeiroPrato.isEmpty }

    /// Todos os componentes, na ordem — para quem só precisa dos números.
    public var componentes: [ComponenteDaRefeicao] {
        (primeiroPrato + pratoPrincipal).map(\.componente)
    }

    /// O primeiro prato é de proteína? Deve ser sempre `true` quando existe.
    /// A asserção `J11` vive disto.
    public var primeiroPratoEhProteico: Bool {
        !primeiroPrato.isEmpty && primeiroPrato.allSatisfy { $0.papel == .proteina }
    }

    /// O carboidrato é o último item do prato principal? A regra da sequência
    /// de alimentos, verificável. `true` também quando não há carboidrato.
    public var carboidratoPorUltimo: Bool {
        guard let indice = pratoPrincipal.lastIndex(where: { $0.papel == .carboidrato })
        else { return true }
        return indice == pratoPrincipal.count - 1
    }
}

// MARK: - O motor

public enum QuebraDeJejum {

    // ── Listas curadas ─────────────────────────────────────────────────────
    //
    // Os nomes têm de existir no catálogo passado em `montar`. Quando um não
    // existe, ele é pulado — e é por isso que cada papel tem mais de uma opção:
    // o catálogo pode mudar sem deixar a sugestão vazia.

    /// Proteína do primeiro prato: macia, fácil de digerir, pouca gordura.
    ///
    /// Ordenada por densidade de proteína, não por gosto: o primeiro prato tem
    /// teto calórico apertado (200 kcal na faixa cuidadosa), então o que rende
    /// mais proteína por caloria vem primeiro. A lentilha fecha a lista porque
    /// é a única que sobrevive a "vegano".
    static let proteinasLeves: [CandidatoDeQuebra] = [
        CandidatoDeQuebra(nome: "Queijo cottage",           quantidadeBase: 150, grupos: [.lactose]),
        CandidatoDeQuebra(nome: "Ovo cozido",               quantidadeBase: 100, grupos: [.ovo]),
        CandidatoDeQuebra(nome: "Iogurte natural integral", quantidadeBase: 200, grupos: [.lactose]),
        CandidatoDeQuebra(nome: "Lentilha cozida",          quantidadeBase: 130, grupos: [])
    ]

    // [26/08] A LISTA `frutas` FOI REMOVIDA, e a remoção é o ponto.
    //
    // Ela existia para o primeiro prato: fruta dá água, potássio e digere
    // fácil. Tudo verdade — e irrelevante diante do problema: fruta é
    // carboidrato, e abrir a quebra com carboidrato é exatamente o contrário do
    // que a regra 2 manda, a mesma regra que a tela de "Saber mais" ensina duas
    // telas adiante. O app não pode dizer "deixe o carboidrato por último" e
    // servir carboidrato primeiro.
    //
    // A hidratação continua coberta, e melhor: pela dica "Água, café e chá não
    // quebram o jejum", que vale para as 16 horas inteiras e não só para o
    // primeiro garfo.

    /// Proteína do prato principal.
    static let proteinas: [CandidatoDeQuebra] = [
        CandidatoDeQuebra(nome: "Peito de frango grelhado", quantidadeBase: 130, grupos: [.carne]),
        CandidatoDeQuebra(nome: "Tilápia grelhada",         quantidadeBase: 140, grupos: [.peixe]),
        CandidatoDeQuebra(nome: "Peito de peru",            quantidadeBase: 130, grupos: [.carne]),
        CandidatoDeQuebra(nome: "Ovo cozido",               quantidadeBase: 100, grupos: [.ovo]),
        CandidatoDeQuebra(nome: "Lentilha cozida",          quantidadeBase: 180, grupos: []),
        CandidatoDeQuebra(nome: "Feijão preto cozido",      quantidadeBase: 180, grupos: [])
    ]

    /// Carboidrato do prato principal — de absorção mais lenta de propósito.
    static let carboidratos: [CandidatoDeQuebra] = [
        CandidatoDeQuebra(nome: "Arroz integral cozido",  quantidadeBase: 120, grupos: []),
        CandidatoDeQuebra(nome: "Batata-doce cozida",     quantidadeBase: 150, grupos: []),
        CandidatoDeQuebra(nome: "Batata inglesa cozida",  quantidadeBase: 160, grupos: []),
        CandidatoDeQuebra(nome: "Cuscuz cozido",          quantidadeBase: 130, grupos: [])
    ]

    static let vegetais: [CandidatoDeQuebra] = [
        CandidatoDeQuebra(nome: "Brócolis cozido",   quantidadeBase: 100, grupos: []),
        CandidatoDeQuebra(nome: "Espinafre cozido",  quantidadeBase: 100, grupos: []),
        CandidatoDeQuebra(nome: "Cenoura cozida",    quantidadeBase: 90,  grupos: []),
        CandidatoDeQuebra(nome: "Tomate",            quantidadeBase: 100, grupos: [])
    ]

    static let gorduras: [CandidatoDeQuebra] = [
        CandidatoDeQuebra(nome: "Azeite de oliva", quantidadeBase: 8, grupos: [])
    ]

    // ── Orçamento ──────────────────────────────────────────────────────────

    /// Piso e teto do orçamento da quebra.
    ///
    /// O teto existe por causa do achado do Ramadã: refeição de quebra muito
    /// grande é o que aparece ligado a pico glicêmico e a desconforto. 1.100
    /// kcal já é uma refeição grande; sugerir mais do que isso de uma vez seria
    /// o app recomendando exatamente o padrão que a literatura desaconselha.
    public static let orcamentoMinimo = 280
    public static let orcamentoMaximo = 1100
    /// Usado quando não há meta calórica. Rotulado como padrão na tela.
    public static let orcamentoSemMeta = 520

    /// Quantas refeições ainda cabem na janela — divide o que resta do dia.
    ///
    /// Uma janela de 8 h costuma comportar duas refeições; de 4 h, uma; a OMAD,
    /// uma. `nil` (o 5:2, que não tem janela diária) é tratado como uma.
    static func refeicoesNaJanela(horasDeJanela: Double?) -> Int {
        guard let h = horasDeJanela else { return 1 }
        return max(1, min(3, Int((h / 3.5).rounded())))
    }

    public static func orcamento(kcalGoal: Int?, kcalConsumidas: Int,
                                 horasDeJanela: Double?) -> (kcal: Int, veioDaMeta: Bool) {
        guard let meta = kcalGoal else { return (orcamentoSemMeta, false) }
        let restante = max(0, meta - max(0, kcalConsumidas))
        let porRefeicao = Double(restante) / Double(refeicoesNaJanela(horasDeJanela: horasDeJanela))
        let bruto = Int(porRefeicao.rounded())
        return (min(orcamentoMaximo, max(orcamentoMinimo, bruto)), true)
    }

    // ── Montagem ───────────────────────────────────────────────────────────

    /// Monta a sugestão.
    ///
    /// - Parameters:
    ///   - duracao: quanto durou o jejum, em segundos.
    ///   - horasDeJanela: da `ProtocoloDeJejum`; `nil` no 5:2.
    ///   - kcalGoal: a meta do dia; `nil` quando a pessoa não tem medidas.
    ///   - kcalConsumidas: o que já entrou no diário hoje.
    ///   - proteinaConsumida / proteinaGoal: para decidir se o prato puxa mais
    ///     proteína. Os dois opcionais pelo mesmo motivo do `kcalGoal`.
    ///   - objetivo: perder / manter / ganhar.
    ///   - restricoesTextoLivre: `AppModel.dietaryRestrictions`, como está.
    ///   - nomesJaRegistradosHoje: para não sugerir de novo o que já foi comido.
    ///   - catalogo: **sem valor padrão de propósito**. `foodDatabase` mora em
    ///     `Models.swift`, que importa SwiftUI; um padrão apontando para lá
    ///     tiraria este arquivo do alcance do `swiftc`. Quem chama passa
    ///     `foodDatabase`; quem testa passa a própria lista.
    public static func montar(
        duracao: TimeInterval,
        horasDeJanela: Double?,
        kcalGoal: Int?,
        kcalConsumidas: Int,
        proteinaConsumida: Int = 0,
        proteinaGoal: Int? = nil,
        objetivo: ObjetivoDaQuebra = .manter,
        restricoesTextoLivre: String = "",
        nomesJaRegistradosHoje: [String] = [],
        catalogo: [FoodItem]
    ) -> SugestaoDeQuebra {

        let gentileza = GentilezaDaQuebra.para(duracao: duracao)
        let (evitar, naoLidas) = LeitorDeRestricoes.ler(restricoesTextoLivre)
        let (orcamentoTotal, veioDaMeta) = orcamento(kcalGoal: kcalGoal,
                                                     kcalConsumidas: kcalConsumidas,
                                                     horasDeJanela: horasDeJanela)

        let jaComidos = Set(nomesJaRegistradosHoje.map { LeitorDeRestricoes.normalizar($0) })

        // A proteína puxa mais quando o dia está atrasado nela. É o uso concreto
        // do "o que a pessoa registrou antes": quem já bateu a proteína recebe
        // um prato mais equilibrado; quem está longe recebe mais proteína.
        let proteinaAtrasada: Bool = {
            guard let alvo = proteinaGoal, alvo > 0 else { return false }
            return Double(proteinaConsumida) / Double(alvo) < 0.6
        }()

        // ── Primeiro prato: SÓ PROTEÍNA ───────────────────────────────────
        //
        // A regra 2 do cabeçalho, em três linhas. Nada de fruta, nada de
        // carboidrato: o que entra primeiro é proteína, e pouca.
        var primeiro: [ItemDaQuebra] = []
        if gentileza != .direta,
           let leve = escolher(proteinasLeves, evitar: evitar, jaComidos: jaComidos, catalogo: catalogo) {
            let alvo = min(gentileza.tetoDoPrimeiroPrato,
                           max(120, Int(Double(orcamentoTotal) * 0.2)))
            primeiro = ajustarPara(kcal: alvo, componentes: [leve])
                .map { ItemDaQuebra(componente: $0, papel: .proteina) }
        }

        // ── Prato principal, JÁ NA ORDEM DE COMER ─────────────────────────
        let jaNoPrimeiro = primeiro.reduce(0) { $0 + $1.componente.kcal }
        let alvoPrincipal = max(orcamentoMinimo - jaNoPrimeiro, orcamentoTotal - jaNoPrimeiro)

        // Não repetir no principal o que já foi servido no primeiro prato.
        var servidos = jaComidos
        for item in primeiro { servidos.insert(LeitorDeRestricoes.normalizar(item.componente.nome)) }

        // O dicionário é montado por papel e depois percorrido na ordem de
        // `PapelNoPrato.ordemDeComer`. Montar já ordenado seria mais curto e
        // esconderia a regra dentro da sequência de `append` — que é
        // exatamente como ela se perderia numa refatoração distraída.
        var porPapel: [PapelNoPrato: ComponenteDaRefeicao] = [:]

        if var proteina = escolher(proteinas, evitar: evitar, jaComidos: servidos, catalogo: catalogo) {
            // Objetivo e proteína atrasada mexem na porção da proteína, não na
            // escolha do alimento. Mexer na escolha faria a sugestão saltar de
            // frango para lentilha por causa de meio grama — instável e
            // inexplicável para quem olha.
            let reforco = (proteinaAtrasada ? 1.25 : 1.0) * (objetivo == .perder ? 1.15 : 1.0)
            proteina = proteina.com(quantidade: Int((Double(proteina.quantidade) * reforco).rounded()))
            porPapel[.proteina] = proteina
        }
        if let vegetal = escolher(vegetais, evitar: evitar, jaComidos: servidos, catalogo: catalogo) {
            porPapel[.vegetal] = vegetal
        }
        if let gordura = escolher(gorduras, evitar: evitar, jaComidos: servidos, catalogo: catalogo) {
            porPapel[.gordura] = gordura
        }
        if var carbo = escolher(carboidratos, evitar: evitar, jaComidos: servidos, catalogo: catalogo) {
            let fator: Double
            switch objetivo {
            case .perder: fator = 0.75
            case .manter: fator = 1.0
            case .ganhar: fator = 1.3
            }
            carbo = carbo.com(quantidade: Int((Double(carbo.quantidade) * fator).rounded()))
            porPapel[.carboidrato] = carbo
        }

        let papeisPresentes = PapelNoPrato.ordemDeComer.filter { porPapel[$0] != nil }
        let basePrincipal = papeisPresentes.compactMap { porPapel[$0] }
        let principal = zip(ajustarPara(kcal: alvoPrincipal, componentes: basePrincipal),
                            papeisPresentes)
            .map { ItemDaQuebra(componente: $0, papel: $1) }

        return SugestaoDeQuebra(
            gentileza: gentileza,
            primeiroPrato: primeiro,
            pratoPrincipal: principal,
            intervaloEmMinutos: primeiro.isEmpty ? 0 : gentileza.intervaloEmMinutos,
            orcamentoKcal: orcamentoTotal,
            orcamentoVeioDaMeta: veioDaMeta,
            restricoesNaoLidas: naoLidas,
            gruposEvitados: GrupoAlimentar.allCases.filter { evitar.contains($0) }
        )
    }

    // ── Auxiliares ─────────────────────────────────────────────────────────

    /// O primeiro candidato que (a) não é de grupo evitado, (b) não foi comido
    /// hoje e (c) existe no catálogo. Se todos falharem em (b), relaxa o (b) —
    /// repetir o almoço é chato, mas devolver prato vazio é quebrado.
    ///
    /// O (a) NUNCA é relaxado. Restrição alimentar não é preferência.
    static func escolher(_ candidatos: [CandidatoDeQuebra],
                         evitar: Set<GrupoAlimentar>,
                         jaComidos: Set<String>,
                         catalogo: [FoodItem]) -> ComponenteDaRefeicao? {
        let permitidos = candidatos.filter { candidato in
            candidato.grupos.allSatisfy { !evitar.contains($0) }
        }
        let inedito = permitidos.first { candidato in
            !jaComidos.contains(LeitorDeRestricoes.normalizar(candidato.nome))
                && achar(candidato.nome, em: catalogo) != nil
        }
        let escolhido = inedito ?? permitidos.first { achar($0.nome, em: catalogo) != nil }
        guard let candidato = escolhido, let food = achar(candidato.nome, em: catalogo) else {
            return nil
        }
        return ComponenteDaRefeicao(
            nome: food.name,
            quantidade: candidato.quantidadeBase,
            unidade: food.unidade,
            kcalPor100: food.kcalPer100,
            proteinaPor100: food.proteinPer100,
            carboPor100: food.carbsPer100,
            gorduraPor100: food.fatPer100
        )
    }

    static func achar(_ nome: String, em catalogo: [FoodItem]) -> FoodItem? {
        catalogo.first { $0.name == nome }
    }

    /// Escala as quantidades para o conjunto bater no alvo calórico.
    ///
    /// O fator é limitado a 0,5×–2,2×. Sem limite, um alvo de 900 kcal
    /// transformaria 100 g de brócolis em 380 g de brócolis — aritmeticamente
    /// correto e impossível de comer. Com limite, a sugestão às vezes fica
    /// abaixo do alvo, e isso é preferível: a tela mostra o total real, nunca o
    /// alvo, então o número na tela continua verdadeiro.
    ///
    /// Quantidades vão para múltiplos de 5 (e de 1 abaixo de 20, para o azeite
    /// não virar "10 g" quando pede 8). Número redondo é o que a pessoa
    /// consegue servir.
    static func ajustarPara(kcal alvo: Int, componentes: [ComponenteDaRefeicao]) -> [ComponenteDaRefeicao] {
        guard !componentes.isEmpty else { return [] }
        let atual = componentes.reduce(0) { $0 + $1.kcal }
        guard atual > 0, alvo > 0 else { return componentes }

        let fator = min(2.2, max(0.5, Double(alvo) / Double(atual)))
        return componentes.map { componente in
            let bruto = Double(componente.quantidade) * fator
            let arredondado = bruto < 20
                ? max(1, Int(bruto.rounded()))
                : max(5, Int((bruto / 5).rounded() * 5))
            return componente.com(quantidade: arredondado)
        }
    }
}
