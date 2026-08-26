// JejumConteudo.swift
// Alma — Corpo · o que o módulo de jejum AFIRMA, e de onde cada afirmação veio.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE O TEXTO MORA NUM ARQUIVO DE DADOS E NÃO DENTRO DAS VIEWS
//
// Três motivos, e o terceiro é o que decide se o módulo passa na revisão das
// lojas.
//
// 1. Texto espalhado por `Text("...")` dentro de `body` não é auditável. Ninguém
//    consegue responder "quais são todas as afirmações de saúde deste app?"
//    lendo seis telas. Aqui a resposta é uma lista.
//
// 2. Toda afirmação carrega a FONTE junto, no mesmo `struct`. Não dá para
//    escrever uma frase nova sem preencher o campo — o compilador exige. Uma
//    afirmação de saúde sem fonte passa a ser um erro de compilação, não um
//    esquecimento.
//
// 3. **NENHUMA PROMESSA DE RESULTADO.** Nada de "emagreça", "cura", "reverte",
//    "garante", "queima gordura", "acelera o metabolismo", "desintoxica". Este
//    projeto já teve problema de política de loja por promessa, e vai declarar
//    categoria de saúde no Play. Com o texto num arquivo só, a proibição vira
//    uma varredura de uma linha — `_scripts/check_promessas_jejum.py` reprova o
//    commit. Se o texto estivesse nas Views, a varredura teria de entender
//    SwiftUI para não dar falso positivo em nome de variável.
//
// ═══════════════════════════════════════════════════════════════════════════
// A REGRA DE ESCRITA
//
// Toda frase desta lista descreve **o que foi observado**, com quem, em que
// desenho de estudo — e nunca o que vai acontecer com quem está lendo. A
// diferença não é de estilo:
//
//   ✗ "O jejum 16/8 emagrece."
//   ✓ "Em ensaios clínicos, jejum e restrição calórica diária produziram perda
//      de peso semelhante quando o total de calorias foi o mesmo."
//
// A segunda é verdadeira, é verificável, e é MAIS útil — porque diz à pessoa a
// coisa que ninguém diz: o jejum é uma forma de organizar o dia, não um efeito
// extra em cima da conta das calorias.
//
// ═══════════════════════════════════════════════════════════════════════════
// FONTES CONFERIDAS EM 26/08/2026.
//
// Este é o tipo de arquivo que envelhece calado: a literatura muda e o texto
// continua parecendo certo. Quem revisar: confira na fonte em vez de confiar
// neste cabeçalho, e atualize `conferidoEm` abaixo.

import Foundation

/// Quando as fontes deste arquivo foram conferidas pela última vez.
/// Aparece na tela, no rodapé das fontes. Um app que cita fonte tem de dizer
/// de quando é a leitura.
public let jejumFontesConferidasEm = "26/08/2026"

// MARK: - Força da evidência

/// O quanto se pode dizer sobre uma afirmação. Existe porque juntar tudo sob
/// "estudos mostram" é a mentira mais comum deste assunto.
public enum ForcaDaEvidencia: String, Codable, CaseIterable {
    /// Ensaios randomizados ou meta-análises com achado repetido.
    case consolidado
    /// Estudado, com resultados que não fecham entre si.
    case misto
    /// Sobretudo animal, laboratório ou observacional. Não dá para afirmar em
    /// humanos.
    case preliminar

    public var rotulo: String {
        switch self {
        case .consolidado: return "Consolidado"
        case .misto:       return "Resultados mistos"
        case .preliminar:  return "Preliminar"
        }
    }

    /// Uma linha explicando o rótulo — porque "preliminar" não quer dizer nada
    /// para quem não trabalha com isso.
    public var explicacao: String {
        switch self {
        case .consolidado: return "Ensaios controlados, achado repetido."
        case .misto:       return "Estudado, mas os resultados não fecham entre si."
        case .preliminar:  return "Sobretudo em animais ou laboratório. Não dá para afirmar em pessoas."
        }
    }
}

// MARK: - Afirmação com fonte

/// Uma coisa que o app diz sobre jejum, e de onde ela veio.
///
/// `fonte` e `forca` NÃO são opcionais de propósito. Ver o motivo 2 no
/// cabeçalho: escrever uma afirmação sem dizer de onde ela veio tem de ser
/// impossível, não desencorajado.
public struct AfirmacaoComFonte: Identifiable, Equatable {
    public var id: String { titulo }
    public let titulo: String
    public let corpo: String
    public let forca: ForcaDaEvidencia
    /// Citação curta, do jeito que aparece na tela.
    public let fonte: String
    /// Para quem quiser conferir. É o que separa "citar" de "parecer que cita".
    public let url: String

    public init(titulo: String, corpo: String, forca: ForcaDaEvidencia,
                fonte: String, url: String) {
        self.titulo = titulo
        self.corpo = corpo
        self.forca = forca
        self.fonte = fonte
        self.url = url
    }
}

// MARK: - Dica prática

/// Uma dica de uso. Sem fonte obrigatória: são coisas de operação (beber água,
/// planejar a janela), não afirmações de saúde. As que TÊM base entram na lista
/// de cima, não nesta.
public struct DicaDeJejum: Identifiable, Equatable {
    public var id: String { titulo }
    public let titulo: String
    public let corpo: String
    public let simbolo: String

    public init(titulo: String, corpo: String, simbolo: String) {
        self.titulo = titulo
        self.corpo = corpo
        self.simbolo = simbolo
    }
}

// MARK: - O conteúdo

public enum JejumConteudo {

    // ═══════════════════════════════════════════════════════════════════════
    // O QUE A LITERATURA OBSERVA
    //
    // Ordem deliberada: a primeira afirmação é a que desmonta a expectativa
    // mágica. Se a pessoa só ler uma, que leia essa.
    // ═══════════════════════════════════════════════════════════════════════

    public static let oQueALiteraturaObserva: [AfirmacaoComFonte] = [

        AfirmacaoComFonte(
            titulo: "Jejum e contar calorias dão resultado parecido",
            corpo: """
            Num ensaio clínico de 12 meses com 139 adultos com obesidade, o grupo \
            que juntou janela alimentar de 8 horas à restrição calórica não perdeu \
            mais peso nem mais gordura do que o grupo que só fez a restrição \
            calórica. Quando o total de calorias é o mesmo, o horário não somou \
            efeito.

            É a informação mais útil desta tela: o jejum é uma forma de organizar \
            o dia — para muita gente, uma forma mais fácil de comer menos sem \
            pesar comida. O que ele não é: um efeito extra por cima da conta.
            """,
            forca: .consolidado,
            fonte: "Liu et al., New England Journal of Medicine, 2022 (ensaio randomizado, 12 meses)",
            url: "https://www.nejm.org/doi/full/10.1056/NEJMoa2114833"
        ),

        AfirmacaoComFonte(
            titulo: "O efeito medido é modesto, e nem tudo se move",
            corpo: """
            Uma revisão sistemática com meta-análise de 2025, em mulheres com \
            sobrepeso e obesidade, observou redução do peso corporal e da insulina \
            de jejum com alimentação em tempo restrito. No mesmo trabalho, não \
            houve efeito significativo sobre IMC, massa gorda, massa magra, \
            gordura visceral, lipídios do sangue, glicose, HOMA-IR ou pressão \
            arterial.

            Duas leituras honestas cabem aqui, e as duas importam: alguma coisa se \
            move, e menos coisas se movem do que a internet promete.
            """,
            forca: .misto,
            fonte: "Frontiers in Nutrition, 2025 (revisão sistemática e meta-análise)",
            url: "https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1664412/full"
        ),

        AfirmacaoComFonte(
            titulo: "Nos ensaios, não apareceu mais efeito adverso",
            corpo: """
            Uma meta-análise de 15 ensaios randomizados, somando 1.365 adultos com \
            sobrepeso ou obesidade, não encontrou risco maior de eventos adversos \
            no jejum intermitente em comparação com os grupos de controle. Fadiga \
            e dor de cabeça não diferiram entre os grupos.

            Isso vale para adultos saudáveis dentro de um estudo, com \
            acompanhamento. Não é um salvo-conduto: ver as contraindicações.
            """,
            forca: .consolidado,
            fonte: "Meta-análise de 15 ensaios randomizados (n = 1.365), 2024",
            url: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11234547/"
        ),

        AfirmacaoComFonte(
            titulo: "\"Autofagia começa em X horas\" não tem base em humanos",
            corpo: """
            As tabelas que circulam marcando a hora exata em que a autofagia \
            começaria vêm, quase todas, de estudos em animais. Em pessoas vivas a \
            autofagia é muito difícil de medir — exige amostra de tecido e técnicas \
            de laboratório — e o momento provavelmente varia por órgão, idade e \
            saúde metabólica.

            Por isso este app não mostra nenhuma linha do tempo de "fases \
            metabólicas". O cronômetro conta horas, que é o que ele sabe contar.
            """,
            forca: .preliminar,
            fonte: "Cleveland Clinic — Autophagy",
            url: "https://my.clevelandclinic.org/health/articles/24058-autophagy"
        ),

        AfirmacaoComFonte(
            titulo: "Há associação com comportamento alimentar de risco",
            corpo: """
            Num estudo canadense com cerca de 2.700 adolescentes e jovens adultos \
            de 16 a 30 anos, quem relatou jejum intermitente no último ano \
            apresentou, entre as mulheres, associação com todos os comportamentos \
            de transtorno alimentar avaliados e pontuação mais alta no EDE-Q. \
            Entre os homens, a associação apareceu com exercício compulsivo e \
            jejum.

            É um estudo transversal: mostra que as duas coisas andam juntas, não \
            que uma cause a outra. Está aqui porque quem usa um cronômetro de \
            jejum merece saber disso antes, e não depois.
            """,
            forca: .misto,
            fonte: "Ganson et al., Eating Behaviors, 2022 (transversal, n ≈ 2.700)",
            url: "https://www.sciencedirect.com/science/article/abs/pii/S1471015322000873"
        )
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // COMO QUEBRAR O JEJUM
    //
    // A parte que o Assis apontou como onde dá para ganhar — e ele está certo,
    // porque quase todo app trata a quebra como "acabou, coma".
    //
    // A base real vem de onde existe mais dado sobre quebrar jejum de verdade:
    // a literatura de Ramadã, com milhões de pessoas quebrando jejum longo todo
    // dia durante um mês. O achado é consistente e é o oposto do que o costume
    // manda: refeições de quebra muito grandes, com carboidrato de alto índice
    // glicêmico e fritura, produzem hiperglicemia pós-prandial severa e
    // sintomas gastrointestinais — saciedade precoce, distensão, náusea.
    // Programas com orientação estruturada, que dividem a quebra em uma porção
    // leve seguida da refeição principal, mostram menor variabilidade
    // glicêmica.
    //
    // ⚠️ O QUE ESTE APP NÃO VAI FAZER: assustar com síndrome de realimentação.
    // Ela é real e é grave, mas o contexto dela é desnutrição severa e jejum
    // prolongado sob acompanhamento — os fatores de risco do NICE são IMC
    // baixo, perda de peso não intencional, dias sem ingestão, eletrólitos já
    // baixos. Nada disso descreve alguém fechando uma janela de 16 horas.
    // Emprestar o nome de uma emergência clínica para vender cuidado com uma
    // janela de 16 h seria exatamente a desonestidade que este arquivo existe
    // para impedir. Ela aparece uma vez, na contraindicação certa, e só.
    // ═══════════════════════════════════════════════════════════════════════

    public static let sobreAQuebra = AfirmacaoComFonte(
        titulo: "Por que a primeira refeição importa",
        corpo: """
        Na literatura de Ramadã — onde muita gente quebra jejum longo todos os \
        dias — refeições de quebra muito grandes, carregadas de carboidrato de \
        absorção rápida e fritura, aparecem associadas a picos de glicose \
        acentuados e a sintomas como saciedade precoce, distensão e náusea. \
        Programas que orientam dividir a quebra numa porção leve seguida da \
        refeição principal registram menor variabilidade glicêmica.

        É por isso que a sugestão desta tela vem em duas partes, e cresce com a \
        duração do seu jejum em vez de ser sempre igual.
        """,
        forca: .misto,
        fonte: "Revisões sobre nutrição e controle glicêmico no Ramadã",
        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11943218/"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // DICAS PRÁTICAS
    //
    // Operação, não afirmação de saúde. Nenhuma delas promete resultado e
    // nenhuma delas manda a pessoa aguentar mais tempo — ver a última.
    // ═══════════════════════════════════════════════════════════════════════

    public static let dicas: [DicaDeJejum] = [
        DicaDeJejum(
            titulo: "Água conta, e conta muito",
            corpo: "Água, café e chá sem açúcar não quebram a janela. Boa parte do mal-estar das primeiras semanas é desidratação simples — o líquido que vem da comida some junto com ela.",
            simbolo: "drop.fill"
        ),
        DicaDeJejum(
            titulo: "Não mude tudo no mesmo dia",
            corpo: "Cortar o café ao mesmo tempo em que se começa a jejuar transforma abstinência de cafeína em \"o jejum não funciona para mim\". Uma coisa de cada vez.",
            simbolo: "cup.and.saucer.fill"
        ),
        DicaDeJejum(
            titulo: "A janela precisa caber na sua vida",
            corpo: "Uma janela que cai em cima do jantar de domingo em família não vai durar um mês. Escolha o horário pela sua rotina, não pelo que rende melhor no papel.",
            simbolo: "calendar.badge.clock"
        ),
        DicaDeJejum(
            titulo: "Proteína na janela, não só na quebra",
            corpo: "Comprimir as refeições costuma comprimir também a proteína do dia. A aba Dieta mostra a sua — vale olhar depois de fechar a janela.",
            simbolo: "fork.knife"
        ),
        DicaDeJejum(
            titulo: "Se passar mal, coma",
            corpo: "Tontura, tremor, dor de cabeça forte ou mal-estar que não passa são motivo para encerrar o jejum, e não para \"aguentar mais um pouco\". Encerrar antes da meta não desfaz nada do que já foi feito.",
            simbolo: "hand.raised.fill"
        ),
        DicaDeJejum(
            titulo: "Um dia fora não apaga o resto",
            corpo: "A sequência aqui conta dias com janela cumprida, e quebrou é quebrado — não existe punição, não existe recuperar dobrando amanhã. Amanhã é um dia novo e vale exatamente o mesmo que qualquer outro.",
            simbolo: "arrow.counterclockwise"
        )
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // CONTRAINDICAÇÕES
    //
    // "Informe de forma clara e sem drama, uma vez, e siga." — o pedido do
    // Assis, literal. Por isso:
    //   · aparece UMA vez, no primeiro acesso, e depois vive numa aba onde quem
    //     quiser encontra (`JejumStore.avisoDeSaudeVisto`);
    //   · não pergunta nada. O app já sabe parte disto — sexo, ciclo, gravidez,
    //     peso e altura — e perguntar de novo o que já se sabe é o começo do
    //     questionário de triagem que ninguém pediu;
    //   · não bloqueia ninguém. Informar é diferente de barrar, e barrar seria
    //     tratar adulto como incapaz.
    //
    // `destacarQuando` é o único uso do que o app sabe: a linha que se aplica à
    // pessoa sobe para o topo e ganha destaque. Nada é enviado para lugar
    // nenhum, e nada é gravado — ver `JejumStore.contraindicacoesDestacadas`.
    // ═══════════════════════════════════════════════════════════════════════

    public struct Contraindicacao: Identifiable, Equatable {
        public var id: String { titulo }
        public let titulo: String
        public let corpo: String

        public init(titulo: String, corpo: String) {
            self.titulo = titulo
            self.corpo = corpo
        }
    }

    /// Identificadores estáveis, para o destaque saber de quem está falando sem
    /// comparar string de título.
    public enum ChaveDeContraindicacao: String, CaseIterable {
        case gravidezEAmamentacao
        case diabetesEInsulina
        case transtornoAlimentar
        case adolescentes
        case pesoMuitoBaixo
        case outrasCondicoes
    }

    public static let contraindicacoes: [ChaveDeContraindicacao: Contraindicacao] = [
        .gravidezEAmamentacao: Contraindicacao(
            titulo: "Gravidez e amamentação",
            corpo: "Nos dois casos a necessidade de energia e de nutrientes aumenta, e restringir horário de comer trabalha contra isso. A orientação clínica é não jejuar."
        ),
        .diabetesEInsulina: Contraindicacao(
            titulo: "Diabetes tipo 1 ou uso de insulina",
            corpo: "O risco aqui é hipoglicemia grave, e ele é imediato. Jejum com insulina ou com secretagogos exige ajuste de dose e acompanhamento — é conversa com quem prescreve, antes de começar."
        ),
        .transtornoAlimentar: Contraindicacao(
            titulo: "Histórico de transtorno alimentar",
            corpo: "Jejuar envolve restringir de propósito e ignorar sinal de fome, que são exatamente os comportamentos de um transtorno alimentar. Para quem já passou por isso, um cronômetro pode reacender o que foi difícil apagar."
        ),
        .adolescentes: Contraindicacao(
            titulo: "Adolescentes",
            corpo: "Corpo em crescimento tem demanda que não combina com janela restrita, e a adolescência é o período de maior incidência de transtorno alimentar."
        ),
        .pesoMuitoBaixo: Contraindicacao(
            titulo: "Peso muito baixo",
            corpo: "Com IMC baixo ou perda de peso recente não intencional, restringir mais tem risco real — inclusive de complicações na retomada da alimentação, que precisam de acompanhamento."
        ),
        .outrasCondicoes: Contraindicacao(
            titulo: "Outras situações que pedem conversa antes",
            corpo: "Uso de medicação com horário preso à refeição, doença renal ou hepática, histórico de cálculo biliar, e qualquer quadro em acompanhamento. Não é proibição — é uma pergunta a fazer a quem cuida de você."
        )
    ]

    /// Na ordem em que aparecem, sem nenhum destaque aplicado.
    public static let contraindicacoesEmOrdem: [ChaveDeContraindicacao] = [
        .gravidezEAmamentacao,
        .diabetesEInsulina,
        .transtornoAlimentar,
        .adolescentes,
        .pesoMuitoBaixo,
        .outrasCondicoes
    ]

    // MARK: - Disclaimer

    /// Curto, como o resto do módulo Corpo já tem (ver `GoalEditorView.disclaimer`).
    public static let disclaimer = """
    O jejum aqui é um cronômetro e um registro seu. A Alma é apoio de bem-estar \
    e não substitui a orientação de um médico ou nutricionista.
    """

    /// A linha que aparece junto do cronômetro. Menor ainda.
    public static let disclaimerCurto =
        "Cronômetro e registro. Não é orientação médica."
}
