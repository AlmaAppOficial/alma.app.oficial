import SwiftUI

// MARK: - Kabbalistic Insight Model
struct KabbalisticInsight {
    let message: String
    let quote: String
    let quoteAuthor: String
    let energy: String
    let element: String
    let color: Color
    let icon: String
}

// MARK: - Kabbalistic Engine
struct KabbalisticEngine {
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
    static func dailyInsight(birthDate: Date) -> KabbalisticInsight {
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

        return KabbalisticInsight(
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

    // MARK: - Philosophical Quotes (33+)
    private static let allQuotes: [(text: String, author: String)] = [
        // Rumi
        ("A jornada da mil milhas começa com um único passo, mas a jornada da alma começa com uma respiração consciente.", "Rumi"),
        ("Você não é uma gota no oceano. Você é o oceano inteiro numa gota.", "Rumi"),
        ("O que você procura está te procurando também.", "Rumi"),
        ("Vire o seu ferimento em sabedoria.", "Rumi"),

        // Lao Tzu
        ("Ao não agir, nada fica por fazer. Quando tudo está completo, nada está quebrado.", "Lao Tzu"),
        ("O Caminho que pode ser falado não é o Caminho eterno.", "Lao Tzu"),
        ("A água é o mais fraco de todas as coisas, mas vence o mais forte.", "Lao Tzu"),
        ("Conhecer os outros é inteligência; conhecer a si mesmo é verdadeira sabedoria.", "Lao Tzu"),

        // Marcus Aurelius
        ("A vida é aquilo em que seus pensamentos a transformam.", "Marco Aurélio"),
        ("Você tem poder sobre sua mente, não sobre eventos externos. Realize isto, e encontrará força.", "Marco Aurélio"),
        ("Muito do que nos preocupa está fora do nosso controle; o que resta está em nossas mãos.", "Marco Aurélio"),
        ("Comece cada dia com uma mente focada no que é verdadeiro, nobre e justo.", "Marco Aurélio"),

        // Buddha
        ("O que você acredita, tornar-se-á verdade.", "Buda"),
        ("Não confie em nada apenas porque o ouviu. Teste tudo com sua própria experiência.", "Buda"),
        ("A mente é tudo. Você se torna aquilo em que pensa.", "Buda"),
        ("O maior presente é ensinar as pessoas a se ajudarem.", "Buda"),

        // Seneca
        ("Não há vento favorável para quem não sabe para onde ir.", "Séneca"),
        ("Vida é aquilo que você faz dela. Sempre foi. Sempre será.", "Séneca"),
        ("Como é que você será livre se não dominar seus pensamentos?", "Séneca"),
        ("O tempo é o tesouro mais valioso de uma pessoa.", "Séneca"),

        // Fernando Pessoa
        ("Eu, em mim mesmo, sou uma multidão.", "Fernando Pessoa"),
        ("Há um tempo em que é preciso abandonar as roupas gastas.", "Fernando Pessoa"),
        ("Tudo vale a pena se a alma não é pequena.", "Fernando Pessoa"),
        ("Ser grande é unir tudo, ligando-o numa visão única.", "Fernando Pessoa"),

        // Carl Jung
        ("Até que você torne consciente o inconsciente, ele dirigirá sua vida.", "Carl Jung"),
        ("O encontro de duas personalidades é como o contacto de duas substâncias químicas.", "Carl Jung"),
        ("A vida não é algo a ser compreendido, mas vivido.", "Carl Jung"),
        ("A sombra é aquela parte de nós que queremos ignorar.", "Carl Jung"),

        // Thich Nhat Hanh
        ("Estar presente é o maior presente que pode dar-se.", "Thich Nhat Hanh"),
        ("O milagre é estar vivo neste momento e respirar.", "Thich Nhat Hanh"),
        ("Quando você bebe o seu chá, apenas beba o seu chá.", "Thich Nhat Hanh"),
        ("A verdadeira compaixão começa consigo mesmo.", "Thich Nhat Hanh"),

        // Additional Philosophers
        ("Conhece-te a ti mesmo.", "Sócrates"),
        ("A escolha, não o acaso, determina o teu destino.", "Jean Nidetch"),
        ("Tudo flui, nada permanece.", "Heráclito"),
        ("Somos feitos daquilo em que pensamos. Tudo, com um pensamento, origina-se no coração.", "Buda"),
        ("O único modo verdadeiro de conhecer uma pessoa é amar-lhe sem esperança.", "Dostoiévski"),
    ]
}
