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
//    commit.
//
// ═══════════════════════════════════════════════════════════════════════════
// A REGRA DE ESCRITA — REVISADA EM 26/08/2026
//
// A primeira versão deste arquivo foi reprovada pelo Assis, e com razão:
// *"as escritas estão em um português muito arcaico e pouco claras para os
// usuários"*. Exemplos do que saiu: "o líquido que vem da comida some junto com
// ela", "quebrou é quebrado", "refeições de quebra muito grandes, carregadas de
// carboidrato de absorção rápida e fritura, aparecem associadas a picos de
// glicose acentuados e a sintomas como saciedade precoce, distensão e náusea".
// A última é frase de artigo científico colada numa tela de celular.
//
// As regras agora, e elas valem para toda frase nova:
//
//   1. UMA IDEIA POR FRASE. Frase curta. Voz ativa.
//   2. PALAVRA DO DIA A DIA. "açúcar no sangue", não "variabilidade glicêmica".
//      "enjoo", não "náusea". "inchaço", não "distensão".
//   3. A INFORMAÇÃO PRIMEIRO, o contexto depois — se vier.
//   4. SE PRECISA DE DUAS LEITURAS, ESTÁ ERRADA. A pessoa está no celular,
//      rolando a tela, com fome.
//
// O QUE **NÃO** MUDOU, e não pode mudar: o rótulo de força da evidência, a
// fonte, a URL e as ressalvas. Simplificar a língua não é apagar o
// "resultados mistos". Clareza não é infantilizar — quem lê é adulto, só não
// está com tempo.
//
// ═══════════════════════════════════════════════════════════════════════════
// FONTES CONFERIDAS EM 26/08/2026.
//
// Este é o tipo de arquivo que envelhece calado: a literatura muda e o texto
// continua parecendo certo. Quem revisar: confira na fonte em vez de confiar
// neste cabeçalho, e atualize `jejumFontesConferidasEm`.

import Foundation

/// Quando as fontes deste arquivo foram conferidas pela última vez.
/// Aparece na tela, no rodapé das fontes. Um app que cita fonte tem de dizer
/// de quando é a leitura.
public let jejumFontesConferidasEm = "26/08/2026"

// MARK: - Força da evidência

/// O quanto se pode dizer sobre uma afirmação. Existe porque juntar tudo sob
/// "estudos mostram" é a mentira mais comum deste assunto.
public enum ForcaDaEvidencia: String, Codable, CaseIterable {
    /// Ensaios controlados ou meta-análises, com achado que se repetiu.
    case consolidado
    /// Estudado, com resultados que não fecham entre si.
    case misto
    /// Sobretudo animal, laboratório ou observação. Não dá para afirmar em
    /// pessoas.
    case preliminar

    public var rotulo: String {
        switch self {
        case .consolidado: return "Bem estabelecido"
        case .misto:       return "Resultados mistos"
        case .preliminar:  return "Ainda em estudo"
        }
    }

    /// Uma linha explicando o rótulo, em português de gente.
    public var explicacao: String {
        switch self {
        case .consolidado: return "Vários estudos, com o mesmo resultado."
        case .misto:       return "Bastante estudado. Os resultados não batem entre si."
        case .preliminar:  return "Quase tudo em animais ou laboratório. Não dá para afirmar em pessoas."
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
/// escolher o horário), não afirmações de saúde. As que TÊM base entram na
/// lista de cima, não nesta.
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
            titulo: "Jejum e contar calorias dão o mesmo resultado",
            corpo: """
            Um estudo acompanhou 139 adultos com obesidade durante 12 meses. \
            Metade comia só dentro de uma janela de 8 horas e fazia dieta de \
            menos calorias. A outra metade só fazia a dieta. Os dois grupos \
            terminaram com praticamente a mesma perda de peso e de gordura.

            O que isso quer dizer na prática: o jejum não é um efeito a mais. \
            Ele é um jeito de organizar o dia. Para muita gente, é um jeito mais \
            fácil de comer menos sem ficar pesando comida.
            """,
            forca: .consolidado,
            fonte: "Liu e colegas, New England Journal of Medicine, 2022. Estudo com sorteio, 12 meses, 139 pessoas.",
            url: "https://www.nejm.org/doi/full/10.1056/NEJMoa2114833"
        ),

        AfirmacaoComFonte(
            titulo: "A ordem em que você come muda o pico de açúcar",
            corpo: """
            Comer a proteína e o vegetal antes do carboidrato deixa o açúcar no \
            sangue mais baixo nas horas seguintes.

            Num estudo com pessoas com diabetes tipo 2, a mesma refeição foi \
            comida em duas ordens diferentes. Com a proteína e o vegetal \
            primeiro, o açúcar no sangue ficou cerca de 29% mais baixo aos 30 \
            minutos e 37% mais baixo aos 60 minutos.

            O que ainda não foi mostrado: que essa ordem melhore o controle do \
            diabetes a longo prazo. Os estudos são pequenos e mediram o que \
            acontece logo depois da refeição.
            """,
            forca: .consolidado,
            fonte: "Shukla e colegas, Diabetes Care, 2015. A mesma refeição, em duas ordens.",
            url: "https://diabetesjournals.org/care/article/38/7/e98/30914/Food-Order-Has-a-Significant-Impact-on"
        ),

        AfirmacaoComFonte(
            titulo: "Proteína segura a fome por mais tempo",
            corpo: """
            Uma refeição com mais proteína costuma tirar a fome por mais tempo \
            do que uma refeição com as mesmas calorias e menos proteína. É um \
            achado antigo, que apareceu várias vezes.

            A ressalva: os estudos usam métodos muito diferentes entre si e \
            boa parte tem risco de viés. Dá para confiar na direção. No tamanho \
            do efeito, não.
            """,
            forca: .misto,
            fonte: "Revisão sistemática sobre proteína e apetite, 2020.",
            url: "https://pubmed.ncbi.nlm.nih.gov/32648023/"
        ),

        AfirmacaoComFonte(
            titulo: "O efeito é pequeno, e nem tudo muda",
            corpo: """
            Uma revisão de 2025 juntou vários estudos com mulheres acima do \
            peso que comiam dentro de uma janela.

            Duas coisas melhoraram: o peso e a insulina em jejum.

            Estas não mudaram: IMC, gordura corporal, massa magra, gordura da \
            barriga, colesterol, glicose e pressão.

            Ou seja, alguma coisa se move. Bem menos coisas do que a internet \
            promete.
            """,
            forca: .misto,
            fonte: "Revisão de vários estudos, Frontiers in Nutrition, 2025.",
            url: "https://www.frontiersin.org/journals/nutrition/articles/10.3389/fnut.2025.1664412/full"
        ),

        AfirmacaoComFonte(
            titulo: "Nos estudos, não apareceu mais efeito ruim",
            corpo: """
            Juntando 15 estudos com 1.365 adultos acima do peso, quem jejuou \
            não teve mais efeitos indesejados do que quem não jejuou. Cansaço e \
            dor de cabeça apareceram igual nos dois grupos.

            Isso vale para adultos saudáveis, dentro de um estudo, com \
            acompanhamento. Não vale para todo mundo — veja "Quando não jejuar".
            """,
            forca: .consolidado,
            fonte: "15 estudos com sorteio, somando 1.365 pessoas, 2024.",
            url: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11234547/"
        ),

        AfirmacaoComFonte(
            titulo: "\"Autofagia às 16 horas\" não tem base em gente",
            corpo: """
            Você já viu aquelas tabelas com a hora exata em que a autofagia \
            começaria. Quase todas vêm de estudos com animais.

            Em pessoas, medir autofagia exige tirar um pedaço de tecido e \
            analisar no laboratório. E a hora provavelmente muda de órgão para \
            órgão e de pessoa para pessoa.

            Por isso este app não mostra nenhuma linha do tempo de "fases do \
            jejum". O cronômetro conta horas. É o que ele sabe contar.
            """,
            forca: .preliminar,
            fonte: "Cleveland Clinic, página sobre autofagia.",
            url: "https://my.clevelandclinic.org/health/articles/24058-autophagy"
        ),

        AfirmacaoComFonte(
            titulo: "Jejum aparece junto com risco alimentar",
            corpo: """
            Um estudo no Canadá ouviu cerca de 2.700 pessoas de 16 a 30 anos. \
            Entre as mulheres que tinham jejuado no último ano, apareceram mais \
            comportamentos ligados a transtorno alimentar. Entre os homens, \
            apareceu mais exercício em excesso.

            O estudo mostra que as duas coisas andam juntas. Não mostra que uma \
            causa a outra.

            Está aqui porque é informação que faz diferença antes de começar.
            """,
            forca: .misto,
            fonte: "Ganson e colegas, Eating Behaviors, 2022. Cerca de 2.700 pessoas, num único momento.",
            url: "https://www.sciencedirect.com/science/article/abs/pii/S1471015322000873"
        )
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // COMO QUEBRAR O JEJUM
    //
    // [26/08] O Assis pediu: *"o que é colocado na boca após a quebra do jejum
    // deve ser proteína"*. Foi apurado antes de escrever, e a evidência
    // sustenta — com um recorte que importa e que está no texto abaixo.
    //
    // O que sustenta:
    //   · SEQUÊNCIA DE ALIMENTOS. Proteína e vegetal antes do carboidrato
    //     baixam o pico de açúcar depois da refeição. Repetido em vários
    //     estudos cruzados. O motor `QuebraDeJejum` foi MUDADO por causa disto:
    //     a porção que abre a quebra passou a ser de proteína, e o prato
    //     principal passou a vir ordenado com o carboidrato por último.
    //   · SACIEDADE. Proteína segura a fome por mais tempo — direção confiável,
    //     tamanho do efeito não.
    //
    // O que o texto NÃO deixa passar batido: depois de jejum longo, porção
    // GRANDE de qualquer coisa cai mal. A orientação é "pequeno E proteína",
    // nunca "muita proteína". Sem essa ressalva, a intuição certa vira
    // conselho ruim.
    //
    // ⚠️ O QUE ESTE APP CONTINUA NÃO FAZENDO: assustar com síndrome de
    // realimentação. Ela é real e grave, mas o contexto dela é desnutrição
    // séria e jejum prolongado com acompanhamento. Não descreve alguém
    // fechando uma janela de 16 horas. Ela aparece uma vez, na contraindicação
    // certa, e só.
    // ═══════════════════════════════════════════════════════════════════════

    public static let sobreAQuebra = AfirmacaoComFonte(
        titulo: "Por que começar pequeno e pela proteína",
        corpo: """
        São duas coisas diferentes, e cada uma tem estudo por trás.

        COMEÇAR PEQUENO. No Ramadã, milhões de pessoas quebram jejum longo \
        todos os dias. Nesses estudos, refeições de quebra muito grandes — com \
        muito carboidrato rápido e fritura — aparecem junto com pico de açúcar \
        no sangue, enjoo, inchaço e aquela sensação de estômago cheio rápido \
        demais. Programas que orientam comer pouco primeiro e o prato principal \
        depois registram menos oscilação de açúcar no sangue.

        PROTEÍNA PRIMEIRO. É a mesma ordem que os estudos de sequência de \
        alimentos testaram: proteína e vegetal antes do carboidrato deixam o \
        pico de açúcar menor. Proteína também segura a fome por mais tempo, o \
        que ajuda a não exagerar no prato principal.

        Por isso a sugestão vem em duas partes, a primeira é de proteína, e ela \
        é pequena de propósito. Pequena E proteína — não "muita proteína".
        """,
        forca: .misto,
        fonte: "Estudos sobre alimentação e açúcar no sangue no Ramadã, mais os estudos de sequência de alimentos citados acima.",
        url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11943218/"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // DICAS PRÁTICAS
    //
    // Operação, não afirmação de saúde. Nenhuma promete resultado e nenhuma
    // manda a pessoa aguentar mais tempo — ver "Se passar mal, coma".
    // ═══════════════════════════════════════════════════════════════════════

    public static let dicas: [DicaDeJejum] = [
        DicaDeJejum(
            titulo: "Água, café e chá não quebram o jejum",
            corpo: "Desde que sejam sem açúcar e sem leite. Beba mais do que o normal. Boa parte da água do seu dia vem da comida, e nas horas de jejum ela não vem. Muito do mal-estar do começo é sede, não fome.",
            simbolo: "drop.fill"
        ),
        DicaDeJejum(
            titulo: "Deixe o carboidrato por último",
            corpo: "Coma a proteína e o vegetal primeiro. O arroz, o pão e a batata no fim. Nos estudos, essa ordem deixa o pico de açúcar no sangue menor. Vale para qualquer refeição, não só para a quebra do jejum.",
            simbolo: "list.number"
        ),
        DicaDeJejum(
            titulo: "Não corte o café no mesmo dia",
            corpo: "Se você parar com o café junto com o começo do jejum, vai ter dor de cabeça — e vai achar que a culpa foi do jejum. Mude uma coisa de cada vez.",
            simbolo: "cup.and.saucer.fill"
        ),
        DicaDeJejum(
            titulo: "Escolha o horário pela sua rotina",
            corpo: "Se a sua janela fechar antes do jantar de domingo em família, você não vai manter. O melhor horário é o que cabe na sua semana.",
            simbolo: "calendar.badge.clock"
        ),
        DicaDeJejum(
            titulo: "Olhe a proteína do dia",
            corpo: "Comer em menos horas costuma fazer a pessoa comer menos proteína sem perceber. A aba Dieta mostra quanto você já comeu hoje.",
            simbolo: "fork.knife"
        ),
        DicaDeJejum(
            titulo: "Se passar mal, coma",
            corpo: "Tontura, tremor, dor de cabeça forte ou mal-estar que não passa: encerre o jejum. Não é para aguentar. Parar antes da meta não apaga o que você já fez.",
            simbolo: "hand.raised.fill"
        ),
        DicaDeJejum(
            titulo: "Um dia fora não estraga nada",
            corpo: "A sequência conta os dias em que você fechou a janela. Se perder um dia, a conta começa de novo. Só isso. Não tem castigo e não tem compensar em dobro amanhã.",
            simbolo: "arrow.counterclockwise"
        )
    ]

    // ═══════════════════════════════════════════════════════════════════════
    // CONTRAINDICAÇÕES
    //
    // "Informe de forma clara e sem drama, uma vez, e siga." Por isso:
    //   · aparece UMA vez, no primeiro acesso, e depois vive numa aba onde quem
    //     quiser encontra (`JejumStore.avisoDeSaudeVisto`);
    //   · não pergunta nada. O app já sabe parte disto — sexo, ciclo, gravidez,
    //     peso e altura — e perguntar de novo o que já se sabe é o começo do
    //     questionário de triagem que ninguém pediu;
    //   · não bloqueia ninguém. Informar é diferente de barrar, e barrar seria
    //     tratar adulto como incapaz.
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
            corpo: "Nos dois casos o corpo precisa de mais energia e mais nutrientes. Restringir o horário de comer vai na direção contrária. A orientação médica é não jejuar."
        ),
        .diabetesEInsulina: Contraindicacao(
            titulo: "Diabetes tipo 1 ou uso de insulina",
            corpo: "O risco é o açúcar no sangue cair demais, e cai rápido. Quem usa insulina, ou remédio que faz o corpo soltar mais insulina, precisa ajustar a dose antes de jejuar. Isso é conversa com o médico que receita, não com um app."
        ),
        .transtornoAlimentar: Contraindicacao(
            titulo: "Histórico de transtorno alimentar",
            corpo: "Jejuar é restringir de propósito e ignorar a fome. São os mesmos comportamentos de um transtorno alimentar. Para quem já passou por isso, um cronômetro pode reacender o que custou a passar."
        ),
        .adolescentes: Contraindicacao(
            titulo: "Adolescentes",
            corpo: "Corpo em crescimento precisa comer mais vezes, não menos. E a adolescência é a fase em que mais aparece transtorno alimentar."
        ),
        .pesoMuitoBaixo: Contraindicacao(
            titulo: "Peso muito baixo",
            corpo: "Com IMC baixo, ou depois de perder peso sem querer, restringir mais tem risco de verdade. Inclusive na hora de voltar a comer, que nesses casos precisa de acompanhamento."
        ),
        .outrasCondicoes: Contraindicacao(
            titulo: "Outras situações: converse antes",
            corpo: "Remédio que precisa ser tomado junto com comida. Doença nos rins ou no fígado. Pedra na vesícula. Qualquer tratamento em andamento. Não é proibição. É uma pergunta para fazer a quem cuida de você."
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
    Aqui o jejum é um cronômetro e um registro seu. A Alma cuida do seu \
    bem-estar e não substitui médico nem nutricionista.
    """

    /// A linha que aparece junto do cronômetro. Menor ainda.
    public static let disclaimerCurto =
        "Cronômetro e registro. Não é orientação médica."
}
