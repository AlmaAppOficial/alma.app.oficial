import SwiftUI

// MARK: - Guidance Insight Model
struct GuidanceInsight {
    let message: String
    let quote: String
    let quoteAuthor: String
    let energy: String
    let element: String
    let color: Color
    let icon: String
}

// MARK: - Guidance Engine
struct GuidanceEngine {
    // MARK: - Life Path Number Calculation
    static func lifePathNumber(birthDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate)

        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1

        let total = year + month + day
        return reduceToSingleDigit(total)
    }

    // MARK: - Personal Year Calculation
    static func personalYear(birthDate: Date) -> Int {
        let today = Date()
        let calendar = Calendar.current
        let birthComponents = calendar.dateComponents([.month, .day], from: birthDate)
        let todayComponents = calendar.dateComponents([.year], from: today)

        let month = birthComponents.month ?? 1
        let day = birthComponents.day ?? 1
        let year = todayComponents.year ?? 2024

        let total = month + day + year
        return reduceToSingleDigit(total)
    }

    // MARK: - Personal Month Calculation
    static func personalMonth(birthDate: Date) -> Int {
        let today = Date()
        let calendar = Calendar.current
        let birthComponents = calendar.dateComponents([.month, .day], from: birthDate)
        let todayComponents = calendar.dateComponents([.month, .year], from: today)

        let month = birthComponents.month ?? 1
        let day = birthComponents.day ?? 1
        let currentMonth = todayComponents.month ?? 1
        let year = todayComponents.year ?? 2024

        let total = month + day + currentMonth + year
        return reduceToSingleDigit(total)
    }

    // MARK: - Daily Insight
    static func dailyInsight(birthDate: Date) -> GuidanceInsight {
        let lifePathNum = lifePathNumber(birthDate: birthDate)
        let personalYearNum = personalYear(birthDate: birthDate)
        let personalMonthNum = personalMonth(birthDate: birthDate)
        let today = Date()
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1

        let messageIndex = dayOfYear % messages(forLifePath: lifePathNum).count
        let quoteIndex = dayOfYear % allQuotes.count

        let message = messages(forLifePath: lifePathNum)[messageIndex]
        let selectedQuote = allQuotes[quoteIndex]

        let energy = energyForDay(lifePathNum, personalYearNum, personalMonthNum)
        let element = elementForNumber(lifePathNum)
        let color = colorForNumber(lifePathNum)
        let icon = iconForNumber(lifePathNum)

        return GuidanceInsight(
            message: message,
            quote: selectedQuote.text,
            quoteAuthor: selectedQuote.author,
            energy: energy,
            element: element,
            color: color,
            icon: icon
        )
    }

    // MARK: - Helper Functions
    private static func reduceToSingleDigit(_ number: Int) -> Int {
        var num = number
        while num >= 10 {
            // Master numbers 11, 22, 33
            if num == 11 || num == 22 || num == 33 {
                return num
            }
            let sum = num.description.compactMap { Int(String($0)) }.reduce(0, +)
            num = sum
        }
        return max(1, num)
    }

    private static func messages(forLifePath num: Int) -> [String] {
        let allMessages: [Int: [String]] = [
            1: [
                "Hoje é dia de liderança. Tome a primeira ação com confiança.",
                "Sua vontade é forte. Use-a para criar algo novo.",
                "Seja pioneiro no seu próprio caminho.",
                "A coragem é o seu presente. Actue com ela.",
                "Lideranças nascem de pequenos passos ousados.",
                "Você é capaz de fazer diferença hoje.",
                "Confie no seu instinto; ele o guia para o certo.",
                "Inovação começa com uma ideia sua. Cultive-a.",
                "Hoje, seja o exemplo que quer ver.",
                "Seu poder está em começar agora.",
            ],
            2: [
                "A harmonia é sua natureza. Procure-a hoje.",
                "Escute com o coração aberto.",
                "Cooperação traz resultados inesperados.",
                "Você é uma ponte entre pessoas. Seja gentil.",
                "Sensibilidade é força, não fraqueza.",
                "A paciência hoje colhe amanhã.",
                "Crie espaço para os outros brilharem.",
                "Seu toque suave transforma situações.",
                "Paz interior é o caminho.",
                "Dualidade é arte; você é um artista.",
            ],
            3: [
                "Sua criatividade é um fogo sagrado.",
                "Comunique sua verdade com alegria.",
                "A expressão é libertação.",
                "Você inspira quando é autêntico.",
                "Hoje, fale o que o seu coração sente.",
                "Criatividade flui quando você está presente.",
                "Sua voz importa. Deixe-a ecoar.",
                "Alegria é contagiosa; compartilhe-a.",
                "Crie sem medo de julgamento.",
                "Sua imaginação é um superpoder.",
            ],
            4: [
                "Construção é o seu dom.",
                "Estabilidade vem de alicerces sólidos.",
                "Trabalho consistente gera frutos.",
                "Você é uma rocha para os outros. Mantenha-se firme.",
                "Disciplina é liberdade disfarçada.",
                "Estrutura liberta, não prende.",
                "Hoje, cuide dos fundamentos.",
                "Sua lealdade é inestimável.",
                "Paciência e método levam ao sucesso.",
                "Você constrói para durar.",
            ],
            5: [
                "Liberdade é sua essência.",
                "Mudança é o seu aliado.",
                "Aproveite a oportunidade de hoje.",
                "Flexibilidade é sabedoria.",
                "Você prospera na diversidade.",
                "Aventura espera por você.",
                "Adaptabilidade é sua força.",
                "Hoje, explore um novo caminho.",
                "Variedade traz crescimento.",
                "Sua energia é contagiosa.",
            ],
            6: [
                "Harmonia em casa é encontrada em você.",
                "Seu cuidado transforma o mundo.",
                "Responsabilidade é amor em acção.",
                "Você cura apenas estando presente.",
                "Beleza está em pequenos gestos.",
                "Família é prioridade sagrada.",
                "Seu equilíbrio inspira outros.",
                "Hoje, cuide de quem ama.",
                "Você é um guardião de paz.",
                "Compaixão é seu idioma nativo.",
            ],
            7: [
                "Profundidade é seu presente.",
                "Busque a verdade dentro de você.",
                "Meditação traz clareza.",
                "Você é um buscador de sabedoria.",
                "Silêncio fala mais alto que ruído.",
                "Introspecção é poder.",
                "Confiança na intuição cresce hoje.",
                "Mistério é professor.",
                "Seu espírito é antena sagrada.",
                "Meditação é a sua oração.",
            ],
            8: [
                "Poder é responsabilidade.",
                "Sucesso é resultado de visão clara.",
                "Abundância é seu direito de nascença.",
                "Você manifesta o que pensa.",
                "Ambição com integridade triunfa.",
                "Riqueza flui através de acções certas.",
                "Autoridade vem de dentro.",
                "Hoje, reclame o seu poder.",
                "Você é um maestro de possibilidades.",
                "Sucesso é uma escolha diária.",
            ],
            9: [
                "Compaixão universal é seu chamado.",
                "Solte o que não serve mais.",
                "Humanidade é sua tribo.",
                "Você é ponte para outros mundos.",
                "Conclusões trazem inícios.",
                "Sabedoria vem de vidas vividas.",
                "Seu legado já está sendo criado.",
                "Hoje, sirva sem esperar retorno.",
                "Universalidade é sua verdade.",
                "Transformação é seu DOM.",
            ],
            11: [
                "Iluminação é o seu caminho.",
                "Você é uma antena de verdade.",
                "Inspiração flui através de você.",
                "Equilibre a dualidade em você.",
                "Intuição é seu compasso sagrado.",
                "Você vê além do comum.",
                "Sabedoria transcendental aguarda você.",
                "Seu potencial é infinito.",
                "Visão clara emerge hoje.",
                "Você é mensageiro de luz.",
            ],
            22: [
                "Você é construtor de legados.",
                "Grandes planos ganham forma hoje.",
                "Mestria é seu destino.",
                "Você transforma sonhos em realidade.",
                "Poder prático está nas suas mãos.",
                "Seu impacto é duradouro.",
                "Estrutura e espiritualidade se encontram em você.",
                "Você faz diferença real no mundo.",
                "Construir com propósito é sua magia.",
                "Legado é obra de seus dias.",
            ],
            33: [
                "Você é mestre do amor incondicional.",
                "Sabedoria compassiva é seu DON.",
                "Curação flui através de você.",
                "Você é guardião de verdade superior.",
                "Seu serviço é sem limites.",
                "Amor absoluto transforma realidades.",
                "Você é canal de graça divina.",
                "Compaixão cósmica habita seu coração.",
                "Humanidade inteira é sua família.",
                "Você é portador de luz.",
            ],
        ]

        return allMessages[num] ?? allMessages[1] ?? []
    }

    private static func energyForDay(_ lifePath: Int, _ personalYear: Int, _ personalMonth: Int) -> String {
        let combined = lifePath + personalYear + personalMonth
        let energies = [
            "Dia de Transformação Interior",
            "Dia de Renovação e Esperança",
            "Dia de Acção Consciente",
            "Dia de Introspecção Profunda",
            "Dia de Libertação",
            "Dia de Harmonia e Cura",
            "Dia de Busca Espiritual",
            "Dia de Manifestação",
            "Dia de Evolução",
            "Dia de Encerramento e Novo Começo",
            "Dia de Iluminação",
            "Dia de Construção de Legado",
            "Dia de Graça Infinita",
            "Dia de Florescimento",
            "Dia de Alquimia Interior",
            "Dia de Conexão Divina",
            "Dia de Sabedoria Ancestral",
            "Dia de Potencial Infinito",
        ]

        return energies[combined % energies.count]
    }

    private static func elementForNumber(_ num: Int) -> String {
        switch num {
        case 1, 5, 9: return "Fogo"
        case 2, 6, 11: return "Água"
        case 3, 7, 22: return "Ar"
        case 4, 8, 33: return "Terra"
        default: return "Éter"
        }
    }

    private static func colorForNumber(_ num: Int) -> Color {
        switch num {
        case 1: return Color(red: 0.85, green: 0.25, blue: 0.25) // Vermelho
        case 2: return Color(red: 0.25, green: 0.6, blue: 0.85) // Azul
        case 3: return Color(red: 1.0, green: 0.85, blue: 0.25) // Amarelo
        case 4: return Color(red: 0.6, green: 0.4, blue: 0.25) // Castanho
        case 5: return Color(red: 1.0, green: 0.6, blue: 0.0) // Laranja
        case 6: return Color(red: 0.9, green: 0.5, blue: 0.7) // Rosa
        case 7: return Color(red: 0.5, green: 0.4, blue: 0.8) // Roxo
        case 8: return Color(red: 0.2, green: 0.2, blue: 0.2) // Preto/Cinzento
        case 9: return Color(red: 0.85, green: 0.85, blue: 0.85) // Prata
        case 11: return Color(red: 0.7, green: 0.9, blue: 1.0) // Azul Claro
        case 22: return Color(red: 0.4, green: 0.7, blue: 0.4) // Verde
        case 33: return Color(red: 1.0, green: 0.85, blue: 0.5) // Ouro
        default: return CalmTheme.primary // Lavanda padrão
        }
    }

    private static func iconForNumber(_ num: Int) -> String {
        switch num {
        case 1: return "flame.fill"
        case 2: return "drop.fill"
        case 3: return "sun.max.fill"
        case 4: return "square.fill"
        case 5: return "wind"
        case 6: return "heart.fill"
        case 7: return "sparkles"
        case 8: return "crown.fill"
        case 9: return "globe"
        case 11: return "lightbulb.fill"
        case 22: return "building.2.fill"
        case 33: return "halo.fill"
        default: return "star.fill"
        }
    }

    // MARK: - Philosophical Quotes (101 — public domain verified)
    private static let allQuotes: [(text: String, author: String)] = [
        // Lao Tzu (Tao Te Ching, ~500 BCE)
        ("A jornada de mil milhas começa com um único passo.", "Lao Tzu"),
        ("Ao não agir, nada fica por fazer. Quando tudo está completo, nada está quebrado.", "Lao Tzu"),
        ("O Caminho que pode ser falado não é o Caminho eterno.", "Lao Tzu"),
        ("A água é o mais fraco de todas as coisas, mas vence o mais forte.", "Lao Tzu"),
        ("Conhecer os outros é inteligência; conhecer a si mesmo é verdadeira sabedoria.", "Lao Tzu"),

        // Rumi (1207–1273)
        ("Você não é uma gota no oceano. Você é o oceano inteiro numa gota.", "Rumi"),
        ("O que você procura está te procurando também.", "Rumi"),
        ("Vire o seu ferimento em sabedoria.", "Rumi"),

        // Marco Aurélio (121–180, Meditações)
        ("A vida é aquilo em que seus pensamentos a transformam.", "Marco Aurélio"),
        ("Você tem poder sobre sua mente, não sobre eventos externos. Realize isto, e encontrará força.", "Marco Aurélio"),
        ("Comece cada dia com uma mente focada no que é verdadeiro, nobre e justo.", "Marco Aurélio"),

        // Buda (~500 BCE, Dhammapada / Kalama Sutta)
        ("Não confie em nada apenas porque o ouviu. Teste tudo com sua própria experiência.", "Buda"),
        ("A mente é tudo. Você se torna aquilo em que pensa.", "Buda"),
        ("Somos feitos daquilo em que pensamos. Tudo, com um pensamento, origina-se no coração.", "Buda"),

        // Sêneca (4 BCE – 65 CE, Epístolas a Lucílio)
        ("Não há vento favorável para quem não sabe para onde ir.", "Sêneca"),

        // Fernando Pessoa (1888–1935, Mensagem)
        ("Tudo vale a pena se a alma não é pequena.", "Fernando Pessoa"),

        // Walt Whitman (1819–1892, Song of Myself) — reatribuída da versão popular errônea a Pessoa
        ("Eu, em mim mesmo, sou uma multidão.", "Walt Whitman"),

        // Sabedoria estoica (paráfrases tradicionais sem fonte primária direta)
        ("Muito do que nos preocupa está fora do nosso controle; o que resta está em nossas mãos.", "Sabedoria estoica"),
        ("Vida é aquilo que você faz dela. Sempre foi. Sempre será.", "Sabedoria estoica"),
        ("Como você será livre se não dominar seus pensamentos?", "Sabedoria estoica"),
        ("O tempo é o tesouro mais valioso de uma pessoa.", "Sabedoria estoica"),

        // Sabedoria budista (paráfrase não canônica)
        ("O maior presente é ensinar as pessoas a se ajudarem.", "Sabedoria budista"),

        // Sabedoria tradicional (paráfrase sem fonte verificável)
        ("Ser grande é unir tudo, ligando-o numa visão única.", "Sabedoria tradicional"),

        // Filósofos clássicos (domínio público)
        ("Conhece-te a ti mesmo.", "Sócrates"),
        ("Tudo flui, nada permanece.", "Heráclito"),
        ("O único modo verdadeiro de conhecer uma pessoa é amar-lhe sem esperança.", "Dostoiévski"),

        // ============================================================
        // Expansão 2026-04-23 — +75 quotes (domínio público verificado)
        // ============================================================

        // Lao Tzu — adicionais (Tao Te Ching)
        ("Os que sabem não falam; os que falam não sabem.", "Lao Tzu"),
        ("Aquele que sabe contentar-se é rico.", "Lao Tzu"),
        ("Sabendo quando parar, não se estará em perigo.", "Lao Tzu"),
        ("Ao ceder como a água, vence-se o mais forte.", "Lao Tzu"),
        ("Quanto mais dá aos outros, mais possui para si.", "Lao Tzu"),

        // Chuang Tzu (Zhuangzi, séc. IV BCE)
        ("O sábio usa a mente como um espelho: nada segura, nada rejeita; recebe mas não guarda.", "Chuang Tzu"),
        ("Sonhei que era uma borboleta. Ao acordar, não sabia se era um homem que sonhara ser borboleta ou uma borboleta a sonhar ser homem.", "Chuang Tzu"),
        ("Feliz o peixe no rio; mas ficamos na margem, dizendo: 'Como pode ele estar feliz?'", "Chuang Tzu"),

        // Confúcio (Analectos, séc. V BCE)
        ("Estude o passado se quiser definir o futuro.", "Confúcio"),
        ("Quando vir um homem sábio, pense em igualar-se a ele. Quando vir um sem virtude, examine a si mesmo.", "Confúcio"),
        ("Aprender sem pensar é inútil. Pensar sem aprender é perigoso.", "Confúcio"),

        // Buda — adicionais (Dhammapada)
        ("O ódio não é aplacado pelo ódio; só pelo amor. Esta é a lei eterna.", "Buda"),
        ("Mesmo uma gota d'água enche o vaso, caindo sem parar.", "Buda"),
        ("Melhor que mil palavras vãs é uma palavra que traga paz.", "Buda"),
        ("Feliz vive o pacífico, que deixou de lado ganho e perda.", "Buda"),
        ("Como uma pedra sólida não é movida pelo vento, o sábio não é abalado pelo louvor ou pela crítica.", "Buda"),

        // Marco Aurélio — adicionais (Meditações)
        ("Não perca tempo discutindo o que um bom homem deve ser. Seja um.", "Marco Aurélio"),
        ("A melhor vingança é não se igualar a quem te ofende.", "Marco Aurélio"),
        ("Ame as pessoas com quem o destino te reuniu, e faça-o com todo o coração.", "Marco Aurélio"),
        ("Considera que o tempo presente é o único que temos; e é curto.", "Marco Aurélio"),
        ("Não vivas como se tivesses mil anos pela frente. Enquanto podes, sê bom.", "Marco Aurélio"),
        ("O obstáculo no caminho torna-se o caminho.", "Marco Aurélio"),

        // Sêneca — adicionais (Epístolas / De Brevitate Vitae)
        ("Tudo pertence aos outros; só o tempo é nosso.", "Sêneca"),
        ("Dificuldades fortalecem a mente, como o trabalho fortalece o corpo.", "Sêneca"),
        ("Toda a vida é um aprender a viver.", "Sêneca"),
        ("Não é que temos pouco tempo; é que perdemos muito.", "Sêneca"),
        ("A vida, se bem usada, é longa.", "Sêneca"),

        // Epicteto (Enchirídion / Discursos)
        ("Não são as coisas que perturbam o ser humano, mas o julgamento que ele faz delas.", "Epicteto"),
        ("É impossível aprender aquilo que se pensa já saber.", "Epicteto"),
        ("Primeiro diga a si mesmo o que você quer ser; depois faça o que tem de fazer.", "Epicteto"),
        ("Se alguém te ferir, lembra que é o seu próprio julgamento que te feriu.", "Epicteto"),

        // Aristóteles (Ética a Nicômaco / Metafísica)
        ("A felicidade depende de nós mesmos.", "Aristóteles"),
        ("A virtude é um meio-termo entre dois extremos.", "Aristóteles"),
        ("O todo é mais que a soma das suas partes.", "Aristóteles"),

        // Heráclito — adicionais (fragmentos)
        ("Ninguém pisa duas vezes no mesmo rio, pois o rio e aquele que o pisa já não são os mesmos.", "Heráclito"),
        ("O caráter do homem é seu destino.", "Heráclito"),
        ("O sol é novo a cada dia.", "Heráclito"),

        // Epicuro (fragmentos)
        ("Não estrague o que você tem desejando o que não tem.", "Epicuro"),
        ("A riqueza não é ter muito, mas precisar de pouco.", "Epicuro"),

        // Sócrates — adicionais (via Platão)
        ("A vida não examinada não vale a pena ser vivida.", "Sócrates"),
        ("Só sei que nada sei.", "Sócrates"),

        // Hipócrates (Aforismos)
        ("A vida é curta; a arte é longa.", "Hipócrates"),

        // Emily Dickinson
        ("A esperança é a coisa com penas que pousa na alma, e canta a melodia sem palavras, e nunca, nunca para.", "Emily Dickinson"),
        ("Eu habito na possibilidade.", "Emily Dickinson"),

        // Walt Whitman — adicional
        ("Eu sou o poeta do corpo, e sou o poeta da alma.", "Walt Whitman"),

        // Rabindranath Tagore
        ("Deixa tua vida dançar levemente nas bordas do tempo, como o orvalho na ponta de uma folha.", "Tagore"),
        ("Não oro pela proteção dos perigos, mas pela coragem de enfrentá-los.", "Tagore"),

        // Khalil Gibran (The Prophet)
        ("Trabalho é amor tornado visível.", "Khalil Gibran"),
        ("Seus filhos não são seus filhos. São filhos e filhas da saudade da vida por si mesma.", "Khalil Gibran"),
        ("A beleza é a eternidade se olhando num espelho.", "Khalil Gibran"),
        ("Você dá pouco quando dá de seus bens. É quando dá de si mesmo que verdadeiramente dá.", "Khalil Gibran"),

        // Leo Tolstói
        ("Todos pensam em mudar o mundo, mas ninguém pensa em mudar a si mesmo.", "Leo Tolstói"),
        ("O amor é a vida. Tudo que eu compreendo, compreendo somente porque amo.", "Leo Tolstói"),
        ("Não há grandeza onde falta simplicidade, bondade e verdade.", "Leo Tolstói"),

        // Montaigne (Ensaios)
        ("Aquele que teme padecer, já padece do que teme.", "Montaigne"),
        ("A vida em si não é nem bem nem mal: é a arena tanto do bem quanto do mal, conforme a tornamos.", "Montaigne"),
        ("Cada homem traz em si a forma inteira da condição humana.", "Montaigne"),

        // Dostoiévski — adicionais
        ("A beleza salvará o mundo.", "Dostoiévski"),
        ("Viver sem esperança é deixar de viver.", "Dostoiévski"),

        // Kierkegaard
        ("A vida só pode ser compreendida olhando para trás, mas só pode ser vivida olhando para frente.", "Kierkegaard"),

        // Nietzsche
        ("Quem tem um porquê pela vida, pode suportar quase qualquer como.", "Nietzsche"),

        // Thoreau
        ("Vá confiante na direção dos seus sonhos. Viva a vida que você imaginou.", "Thoreau"),
        ("O preço de qualquer coisa é a quantidade de vida que você troca por ela.", "Thoreau"),

        // Victor Hugo
        ("Nada é mais poderoso que uma ideia cuja hora chegou.", "Victor Hugo"),

        // Voltaire
        ("O melhor é o inimigo do bom.", "Voltaire"),

        // Provérbios tradicionais
        ("Quando o sábio aponta para a lua, o tolo olha para o dedo.", "Provérbio zen"),
        ("O melhor tempo para plantar uma árvore foi há vinte anos. O segundo melhor tempo é agora.", "Provérbio chinês"),
        ("Caia sete vezes, levante oito.", "Provérbio japonês"),
        ("A paciência é amarga, mas seu fruto é doce.", "Provérbio persa"),
        ("Quem caminha sozinho chega mais rápido; quem caminha acompanhado chega mais longe.", "Provérbio africano"),
        ("Para conhecer a estrada à frente, pergunte àqueles que estão voltando.", "Provérbio chinês"),
        ("Uma única conversa com um sábio vale mais que dez anos de estudo.", "Provérbio chinês"),
        ("Antes de falar, deixe suas palavras passarem por três portões: É verdade? É necessário? É bondoso?", "Provérbio sufi"),
        ("O bambu dobra mas não quebra.", "Provérbio japonês"),
        ("Cada manhã é um renascer.", "Provérbio budista"),
    ]
}
