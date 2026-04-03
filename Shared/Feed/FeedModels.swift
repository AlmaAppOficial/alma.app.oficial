import Foundation

// MARK: - FeedPost

struct FeedPost: Identifiable, Codable, Equatable {
    var id: String
    let title: String
    let description: String
    let content: String
    let contentType: ContentType
    let categories: [String]
    let author: String
    let authorId: String
    let authorImage: String?
    let coverImage: String?
    let scientificBasis: [String]
    let sources: [String]
    let meditationDuration: Int?   // seconds
    let meditationAudio: String?   // URL string
    let hashtags: [String]
    var likes: Int
    var saves: Int
    var shares: Int
    let createdAt: Date
    let isPublished: Bool
    let isFeatured: Bool

    enum ContentType: String, Codable, CaseIterable {
        case article       = "article"
        case meditation    = "meditation"
        case study         = "study"
        case reflectionCard = "reflection_card"
        case userPost      = "user_post"

        var label: String {
            switch self {
            case .article:        return "Artigo"
            case .meditation:     return "Meditação"
            case .study:          return "Estudo"
            case .reflectionCard: return "Reflexão"
            case .userPost:       return "Post"
            }
        }

        var icon: String {
            switch self {
            case .article:        return "doc.text"
            case .meditation:     return "waveform"
            case .study:          return "magnifyingglass"
            case .reflectionCard: return "quote.bubble"
            case .userPost:       return "person"
            }
        }

        var color: String {
            switch self {
            case .article:        return "#7c3aed"
            case .meditation:     return "#059669"
            case .study:          return "#2563eb"
            case .reflectionCard: return "#d97706"
            case .userPost:       return "#db2777"
            }
        }
    }

    static func == (lhs: FeedPost, rhs: FeedPost) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - UserInteraction

struct UserInteraction: Identifiable, Codable {
    var id: String { postId }
    let userId: String
    let postId: String
    var liked: Bool
    var saved: Bool
    var shared: Bool
    let lastInteractedAt: Date
}

// MARK: - FeedCategory

struct FeedCategory: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let color: String

    static let all = FeedCategory(id: "all", name: "Todos", icon: "🌟", color: "#7c3aed")

    static let defaults: [FeedCategory] = [
        all,
        FeedCategory(id: "ansiedade",    name: "Ansiedade",    icon: "🌊", color: "#2563eb"),
        FeedCategory(id: "meditacao",    name: "Meditação",    icon: "🧘", color: "#059669"),
        FeedCategory(id: "autoestima",   name: "Autoestima",   icon: "💜", color: "#7c3aed"),
        FeedCategory(id: "relacionamentos", name: "Relacionamentos", icon: "💞", color: "#db2777"),
        FeedCategory(id: "sono",         name: "Sono",         icon: "🌙", color: "#4f46e5"),
        FeedCategory(id: "habitos",      name: "Hábitos",      icon: "✨", color: "#d97706"),
        FeedCategory(id: "proposito",    name: "Propósito",    icon: "🎯", color: "#dc2626"),
        FeedCategory(id: "trabalho",     name: "Trabalho",     icon: "💼", color: "#0891b2"),
    ]
}

// MARK: - Sample / Mock Data

extension FeedPost {
    static let samplePosts: [FeedPost] = [

        // ── POST 01 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_001",
            title: "Autoestima Real vs. Ego: Como Diferenciar",
            description: "Análise profunda sobre os sintomas de autoestima genuína versus ego disfarçado. Inclui teste de autoavaliação baseado em evidências.",
            content: """
            A autoestima saudável e o ego inflado frequentemente se confundem. Enquanto a autoestima genuína nasce de uma relação honesta consigo mesmo, o ego é uma proteção frágil contra medos internos.

            **Autoestima genuína:**
            • Segurança interna independente de aprovação
            • Capacidade de reconhecer erros sem se fragmentar
            • Comparação mínima com outros
            • Limite saudável sem agressividade

            **Ego disfarçado:**
            • Necessidade constante de validação
            • Dificuldade de aceitar críticas
            • Comparação social frequente
            • Arrogância como defesa

            A Terapia Cognitivo-Comportamental (TCC) mostra que crenças nucleares sobre si mesmo — "sou capaz", "mereço amor" — são o alicerce da autoestima real. Quando essas crenças são condicionais ("só sou bom se..."), surge o ego como compensação.

            **Prática diária:** Ao final do dia, pergunte: "Agi a partir da segurança ou do medo da rejeição?" Essa pergunta simples revela muito sobre sua fonte de autoestima.
            """,
            contentType: .study,
            categories: ["Autoestima", "Inteligência Emocional"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["TCC", "Psicologia Positiva", "Neurociência"],
            sources: ["APA Journal of Personality", "Nathaniel Branden - The Six Pillars of Self-Esteem"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Autoestima", "#Autoconhecimento", "#Mindset"],
            likes: 248,
            saves: 187,
            shares: 64,
            createdAt: Date().addingTimeInterval(-86400 * 2),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 02 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_002",
            title: "Meditação para Ansiedade: Técnica da Âncora Corporal",
            description: "Meditação guiada de 7 minutos com técnicas de grounding para reduzir sintomas de ansiedade imediatamente.",
            content: """
            Esta meditação combina mindfulness com técnicas somáticas para ancorar sua atenção no corpo e sair do ciclo de pensamentos ansiosos.

            Baseada no protocolo MBSR (Mindfulness-Based Stress Reduction) de Jon Kabat-Zinn, a técnica da âncora corporal usa sensações físicas como ponto de retorno sempre que a mente divaga.

            Encontre uma posição confortável, feche os olhos, e siga o áudio. Ao sentir ansiedade, traga sua atenção para a sola dos pés — a sensação de peso, temperatura e contato com o chão. Este simples gesto ativa o sistema nervoso parassimpático e reduz a resposta de luta-ou-fuga.

            Pesquisas mostram que 8 semanas de prática MBSR reduzem sintomas de ansiedade em até 58% (Hofmann et al., 2010).
            """,
            contentType: .meditation,
            categories: ["Ansiedade", "Meditação"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["MBSR", "Somatic Experiencing", "Neurociência"],
            sources: ["Jon Kabat-Zinn - Full Catastrophe Living", "Hofmann et al. (2010) - J Consult Clin Psychol"],
            meditationDuration: 420,
            meditationAudio: nil,
            hashtags: ["#Ansiedade", "#Meditação", "#Mindfulness"],
            likes: 512,
            saves: 389,
            shares: 143,
            createdAt: Date().addingTimeInterval(-86400 * 1),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 03 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_003",
            title: "Por Que Afirmações Positivas Nem Sempre Funcionam",
            description: "Metodologia baseada em evidências para criar afirmações efetivas ancoradas em crenças reais — sem autoengano.",
            content: """
            Afirmar "sou rico e próspero" quando você está endividado ativa um mecanismo psicológico de rejeição. Seu cérebro detecta a inconsistência e cria resistência.

            A pesquisa de Joanne Wood (Universidade de Waterloo, 2009) mostrou que afirmações positivas podem piorar o humor em pessoas com baixa autoestima.

            **O que funciona de verdade:**

            1. **Afirmações de processo** ao invés de resultado: "Estou tomando medidas para melhorar minha saúde financeira" — mais efetivo que "Sou milionário"

            2. **Perguntas ao invés de afirmações**: "Por que estou ficando mais organizado?" — O cérebro busca provas, não rejeita a afirmação

            3. **Ancoragem em valores**: "Valorizo disciplina e trabalho com isso todos os dias" — crível e motivador

            A ACT (Terapia de Aceitação e Compromisso) sugere focar em ações comprometidas com valores ao invés de tentar mudar pensamentos forçadamente.
            """,
            contentType: .article,
            categories: ["Autoestima", "Hábitos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["ACT", "Psicologia Comportamental"],
            sources: ["Wood et al. (2009) - Psychological Science", "ACT Handbook - Hayes & Strosahl"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#AfirmaçõesPositivas", "#Mindset", "#Psicologia"],
            likes: 334,
            saves: 201,
            shares: 89,
            createdAt: Date().addingTimeInterval(-86400 * 3),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 04 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_004",
            title: "Sono Reparador: Meditação Antes de Dormir",
            description: "15 minutos de relaxamento progressivo e visualização para induzir sono profundo e restaurador.",
            content: """
            O sono é o maior reparador do sistema nervoso. Esta meditação usa técnicas de relaxamento progressivo de Edmund Jacobson combinadas com visualização guiada para preparar corpo e mente para o descanso.

            **Por que funciona:**
            Durante o sono profundo (NREM fase 3), o cérebro consolida memórias, o sistema glinfático remove toxinas e o hormônio do crescimento é liberado. Matthew Walker, neurocientista de UC Berkeley, demonstrou que adultos que dormem menos de 7 horas têm risco 41% maior de ataque cardíaco.

            **Protocolo desta meditação:**
            • Contração e relaxamento muscular progressivo (pés → cabeça)
            • Respiração 4-7-8 para ativação parassimpática
            • Visualização de lugar seguro

            Pratique como ritual noturno fixo — a consistência potencializa os resultados em até 3 semanas.
            """,
            contentType: .meditation,
            categories: ["Sono", "Meditação"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Neurociência do Sono", "Técnica Jacobson", "Cronobiologia"],
            sources: ["Matthew Walker - Why We Sleep (2017)", "NIH Sleep Research Institute"],
            meditationDuration: 900,
            meditationAudio: nil,
            hashtags: ["#Sono", "#Insônia", "#BemEstar"],
            likes: 445,
            saves: 312,
            shares: 78,
            createdAt: Date().addingTimeInterval(-86400 * 4),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 05 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_005",
            title: "O Chão Emocional: Construindo Confiança Interna",
            description: "7 pilares para desenvolver base emocional sólida: confiança, resiliência e segurança interna permanentes.",
            content: """
            Confiança interna não é arrogância — é a certeza de que você consegue lidar com o que a vida apresentar.

            A teoria do apego de John Bowlby mostra que experiências de vinculação segura na infância criam o "chão emocional". Mas a boa notícia: neuroplasticidade permite reconstruí-lo em qualquer idade.

            **Os 7 Pilares:**
            1. **Autoconhecimento** — saber quem você é além dos papeis sociais
            2. **Regulação emocional** — sentir sem ser dominado
            3. **Valores claros** — bússola interna
            4. **Tolerância à frustração** — aceitar que nem tudo é controlável
            5. **Autocompaixão** — tratar a si mesmo como a um amigo querido
            6. **Responsabilidade** — agir sem esperar condições perfeitas
            7. **Presença** — estar aqui agora

            Qual pilar você mais precisa fortalecer hoje?
            """,
            contentType: .reflectionCard,
            categories: ["Autoestima", "Propósito"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Teoria do Apego", "Psicologia Positiva", "Neuroplasticidade"],
            sources: ["Bowlby - Attachment Theory", "Kristin Neff - Self-Compassion (2011)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#ConfiançaInterna", "#Resiliência", "#Autoconhecimento"],
            likes: 621,
            saves: 498,
            shares: 156,
            createdAt: Date().addingTimeInterval(-86400 * 5),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 06 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_006",
            title: "Inteligência Emocional no Trabalho: Gestão de Conflitos",
            description: "Estratégias práticas para comunicação não-violenta, empatia estratégica e resolução de conflitos no ambiente corporativo.",
            content: """
            Daniel Goleman identificou 5 componentes da Inteligência Emocional que predizem sucesso profissional mais do que o QI: autoconsciência, autorregulação, motivação, empatia e habilidades sociais.

            Conflitos no trabalho são inevitáveis. A questão é como você os gerencia.

            **Framework CNV para conflitos:**
            1. **Observação** (sem julgamento): "Nas últimas 3 reuniões, você interrompeu minha fala"
            2. **Sentimento**: "Quando isso acontece, sinto que não sou ouvido"
            3. **Necessidade**: "Preciso de espaço para concluir meu raciocínio"
            4. **Pedido** (específico e ação): "Você poderia esperar eu terminar antes de responder?"

            Esta estrutura desativa a resposta defensiva do interlocutor porque substitui acusações por expressão de necessidades. Estudo da Harvard Business Review (2015) mostrou que times com alta IE têm produtividade 20% maior.
            """,
            contentType: .study,
            categories: ["Trabalho", "Relacionamentos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Goleman IE", "CNV", "Psicologia Organizacional"],
            sources: ["Daniel Goleman - Emotional Intelligence (1995)", "Marshall Rosenberg - Nonviolent Communication"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#InteligênciaEmocional", "#Trabalho", "#Liderança"],
            likes: 287,
            saves: 234,
            shares: 91,
            createdAt: Date().addingTimeInterval(-86400 * 6),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 07 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_007",
            title: "Respiração 4-7-8: O Calmante Natural do Sistema Nervoso",
            description: "Meditação de 5 minutos com a técnica respiratória do Dr. Andrew Weil — comprovada para reduzir ansiedade aguda em minutos.",
            content: """
            A técnica 4-7-8 foi sistematizada pelo Dr. Andrew Weil baseando-se em práticas de pranayama do yoga. Ela funciona ao ativar o nervo vago e aumentar a atividade parassimpática.

            **Como praticar:**
            • Inspire pelo nariz contando 4 segundos
            • Retenha o ar contando 7 segundos
            • Expire completamente pela boca contando 8 segundos
            • Repita 4 ciclos

            **Por que funciona:**
            A expiração longa (8 segundos) ativa o reflexo de mergulho — o mesmo mecanismo que diminui a frequência cardíaca de mergulhadores. O CO2 acumulado na retenção estimula o nervo vago, que acalma diretamente o sistema nervoso.

            Pesquisa da Universidade de Arizona (2019) mostrou redução de 44% nos marcadores fisiológicos de ansiedade após 4 semanas de prática diária.

            Esta meditação guiará você por 5 minutos com instruções de respiração sincronizadas.
            """,
            contentType: .meditation,
            categories: ["Ansiedade", "Meditação"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Pranayama", "Sistema Nervoso Autônomo", "Nervo Vago"],
            sources: ["Dr. Andrew Weil - 4-7-8 Breathing", "Zaccaro et al. (2018) - Frontiers in Human Neuroscience"],
            meditationDuration: 300,
            meditationAudio: nil,
            hashtags: ["#Respiração", "#Ansiedade", "#TécnicaDeRelaxamento"],
            likes: 703,
            saves: 541,
            shares: 198,
            createdAt: Date().addingTimeInterval(-86400 * 7),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 08 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_008",
            title: "O Eixo Intestino-Cérebro: Como Seu Intestino Afeta Sua Saúde Mental",
            description: "Estudo revisado por pares mostra que 95% da serotonina é produzida no intestino. Como sua microbiota impacta ansiedade e depressão.",
            content: """
            Você sabia que seu intestino tem mais de 100 milhões de neurônios — mais do que a medula espinhal? Os cientistas chamam isso de "segundo cérebro" (sistema nervoso entérico).

            **A conexão comprovada:**
            • 95% da serotonina (hormônio do bem-estar) é produzida no intestino
            • Bactérias intestinais produzem GABA, dopamina e outros neurotransmissores
            • O nervo vago transmite sinais intestino→cérebro em ambas direções

            **O que a ciência mostra:**
            Meta-análise publicada no JAMA Psychiatry (2019) com 1.500 participantes mostrou que suplementação de probióticos reduziu sintomas depressivos em 34% comparado ao placebo.

            **O que prejudica sua microbiota:**
            • Dieta ultra-processada (açúcar, ultraprocessados)
            • Antibióticos sem necessidade
            • Estresse crônico (cortisol mata bactérias benéficas)

            **O que fortalece:**
            • Fermentados: kefir, kimchi, chucrute
            • Fibras prebióticas: aveia, banana verde, alho
            • Polifenóis: frutas vermelhas, cacau, azeite
            """,
            contentType: .study,
            categories: ["Saúde Mental", "Hábitos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Eixo Intestino-Cérebro", "Psiconeuroimunologia", "Microbioma"],
            sources: ["Cryan et al. (2019) - Physiological Reviews", "JAMA Psychiatry (2019) - Probiotics meta-analysis", "Gershon - The Second Brain"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#SaúdeMental", "#Microbioma", "#Nutrição", "#Intestino"],
            likes: 892,
            saves: 671,
            shares: 312,
            createdAt: Date().addingTimeInterval(-86400 * 8),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 09 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_009",
            title: "MBSR: O Protocolo de 8 Semanas que Muda o Cérebro",
            description: "Estudo de Harvard com neuroimagem mostrou que 8 semanas de mindfulness aumentam a densidade de matéria cinzenta no hipocampo em 8,5%.",
            content: """
            O programa MBSR (Mindfulness-Based Stress Reduction) foi desenvolvido pelo Dr. Jon Kabat-Zinn na Universidade de Massachusetts em 1979. Hoje é o programa de redução de estresse mais estudado do mundo, com mais de 30.000 publicações científicas.

            **O que acontece no seu cérebro:**
            Pesquisa seminal de Sara Lazar (Harvard, 2011) com neuroimagem de ressonância magnética mostrou que após 8 semanas de MBSR:
            • Aumento de 8,5% na densidade do hipocampo (memória e aprendizado)
            • Redução de 5,4% no volume da amígdala direita (resposta ao medo)
            • Aumento no córtex pré-frontal (tomada de decisão)

            **Os 8 domínios do MBSR:**
            1. Escaneamento corporal (body scan)
            2. Yoga suave consciente
            3. Meditação sentada com foco na respiração
            4. Comer com atenção plena
            5. Mindfulness nas atividades cotidianas
            6. Comunicação consciente
            7. Dia de prática intensiva
            8. Plano de manutenção pessoal

            **Resultados comprovados:**
            • Redução de 47% no cortisol salivar
            • Melhora em 63% dos casos de dor crônica
            • Redução de 58% em sintomas de ansiedade generalizada
            """,
            contentType: .study,
            categories: ["Meditação", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["MBSR", "Neuroplasticidade", "Neuroimagem"],
            sources: ["Lazar et al. (2005) - NeuroReport", "Hölzel et al. (2011) - Psychiatry Research: Neuroimaging", "Kabat-Zinn - Full Catastrophe Living"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#MBSR", "#Mindfulness", "#Neurociência", "#Meditação"],
            likes: 1205,
            saves: 987,
            shares: 445,
            createdAt: Date().addingTimeInterval(-86400 * 9),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 10 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_010",
            title: "Autocompaixão vs. Autocrítica: O Que a Ciência Diz",
            description: "Kristin Neff descobriu que autocompaixão é mais eficaz que autoestima para bem-estar duradouro. Aprenda os 3 componentes essenciais.",
            content: """
            Você se trataria da forma como trata a si mesmo quando erra? Provavelmente não trataria ninguém com tanta dureza.

            Kristin Neff, pesquisadora da Universidade do Texas, passou 15 anos estudando autocompaixão e descobriu algo surpreendente: a autocompaixão é um preditor mais forte de bem-estar psicológico do que a autoestima.

            **Os 3 componentes da autocompaixão (Neff, 2003):**

            1. **Bondade consigo mesmo** — substituir a autocrítica por gentileza
            Ao invés de: "Que idiota, errei de novo"
            Dizer: "Errei, isso é humano. Como posso aprender com isso?"

            2. **Humanidade comum** — reconhecer que sofrer faz parte de ser humano
            A solidão do sofrimento ("só eu passo por isso") amplifica a dor. Reconhecer que todos sofrem reduz essa amplificação.

            3. **Mindfulness** — observar emoções sem julgamento nem supressão
            Nem dramatisar ("tudo está perdido") nem suprimir ("não devo sentir isso").

            **Por que não é fraqueza:**
            Meta-análise de 79 estudos (MacBeth & Gumley, 2012) mostrou que autocompaixão tem correlação negativa forte com ansiedade (r=-0,65) e depressão (r=-0,61).

            Pessoas autocompassivas tomam mais responsabilidade por seus erros — não menos.
            """,
            contentType: .reflectionCard,
            categories: ["Autoestima", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Self-Compassion Theory", "TCC", "ACT"],
            sources: ["Neff (2003) - Self and Identity Journal", "MacBeth & Gumley (2012) - Clinical Psychology Review"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Autocompaixão", "#Autoestima", "#BemEstar", "#Psicologia"],
            likes: 1089,
            saves: 834,
            shares: 378,
            createdAt: Date().addingTimeInterval(-86400 * 10),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 11 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_011",
            title: "Síndrome do Impostor: Por Que Pessoas Competentes Se Sentem Fraudes",
            description: "70% das pessoas experimentam síndrome do impostor em algum momento. Origem psicológica, populações afetadas e estratégias eficazes de superação.",
            content: """
            O termo foi cunhado em 1978 pelas psicólogas Pauline Clance e Suzanne Imes após observar que mulheres bem-sucedidas consistentemente atribuíam seus sucessos à sorte, não à competência.

            **O que é na prática:**
            Síndrome do Impostor é a crença persistente de que você não merece seu sucesso e que eventualmente será "desmascarado" como fraude — mesmo diante de evidências objetivas de competência.

            **Quem mais sofre:**
            Paradoxalmente, afeta desproporcionalmente os mais competentes. Alta sensibilidade, perfeccionismo e alta inteligência são fatores de risco. Uma revisão de 2019 (Bravata et al.) estimou que 70% das pessoas experienciam isso em algum ponto da vida.

            **O ciclo do impostor:**
            Tarefa nova → Ansiedade excessiva → Preparo excessivo OU procrastinação → Sucesso → Atribuição à sorte/esforço excessivo → Não atualiza autoimagem → Tarefa nova...

            **Estratégias baseadas em evidências:**
            1. **Registro de conquistas** — documente evidências objetivas de competência
            2. **Normalização** — converse com pares (quase todos se sentem assim)
            3. **Reframing cognitivo** — "Não sei tudo, mas sei o suficiente para contribuir"
            4. **Mentoria** — ter um mentor reduz significativamente o fenômeno
            5. **Separar sentimento de fato** — sentir-se fraude ≠ ser fraude
            """,
            contentType: .article,
            categories: ["Autoestima", "Trabalho"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Psicologia Cognitiva", "TCC", "Psicologia Positiva"],
            sources: ["Clance & Imes (1978) - Psychotherapy: Theory, Research & Practice", "Bravata et al. (2019) - Journal of General Internal Medicine"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#SíndromeDoImpostor", "#Autoestima", "#Trabalho", "#Psicologia"],
            likes: 1567,
            saves: 1203,
            shares: 589,
            createdAt: Date().addingTimeInterval(-86400 * 11),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 12 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_012",
            title: "Meditação Metta: Cultivando Amor e Bondade",
            description: "Meditação de 10 minutos da tradição Theravada. Estudos mostram que ela aumenta emoções positivas e reduz autocrítica em 4 semanas.",
            content: """
            Metta Bhavana (em pali: "cultivo da bondade amorosa") é uma das práticas meditativas mais antigas do mundo, originada na tradição budista Theravada há 2.500 anos.

            **O que a ciência diz:**
            Barbara Fredrickson (2008) conduziu um estudo com 202 participantes mostrando que 7 semanas de meditação metta aumentaram significativamente emoções positivas, mindfulness, propósito de vida, suporte social e reduziram sintomas de doença.

            **Estrutura desta prática:**
            A meditação começa direcionando bondade a si mesmo, depois a um ser amado, depois a pessoa neutra, depois a pessoa difícil, e finalmente a todos os seres.

            As frases guia:
            "Que eu seja feliz. Que eu seja saudável. Que eu esteja seguro. Que eu viva com leveza."

            Esta sequência progressiva ativa o sistema de cuidado (ocitocina) e reduz a atividade da amígdala.
            """,
            contentType: .meditation,
            categories: ["Meditação", "Autoestima", "Relacionamentos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Budismo Theravada", "Psicologia Positiva", "Neurociência Afetiva"],
            sources: ["Fredrickson et al. (2008) - Journal of Personality and Social Psychology", "Salzberg - Lovingkindness (1995)"],
            meditationDuration: 600,
            meditationAudio: nil,
            hashtags: ["#Metta", "#BondadeAmorosa", "#Meditação", "#Compaixão"],
            likes: 678,
            saves: 512,
            shares: 187,
            createdAt: Date().addingTimeInterval(-86400 * 12),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 13 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_013",
            title: "Neuroplasticidade: Como Mudar Hábitos Mudando o Cérebro",
            description: "A ciência por trás da formação e mudança de hábitos. Por que 21 dias é um mito e o que realmente funciona segundo pesquisas de University College London.",
            content: """
            "Leva 21 dias para formar um hábito" — esse mito foi propagado por Maxwell Maltz em 1960 sem nenhuma evidência científica. A verdade é mais complexa e interessante.

            **O que a pesquisa mostra:**
            Phillippa Lally (UCL, 2010) acompanhou 96 pessoas por 12 semanas formando novos hábitos. O resultado: a automatização de um comportamento levou entre 18 e 254 dias, com média de 66 dias.

            **A neurociência do hábito:**
            Hábitos são armazenados nos gânglios basais — estrutura mais antiga do cérebro evolutivamente. Uma vez codificado, um hábito nunca é deletado; apenas sobrescrito por outro comportamento no mesmo contexto.

            **O loop do hábito (Duhigg):**
            Gatilho → Rotina → Recompensa

            **Para criar novos hábitos:**
            1. Torne óbvio o gatilho (ex: deixe o tênis na porta)
            2. Torne atraente a rotina (agrupe com algo prazeroso)
            3. Torne fácil a execução (reduza a fricção ao mínimo)
            4. Torne satisfatória a recompensa (celebre imediatamente)

            **Para quebrar hábitos ruins:**
            Inverta os 4 passos acima — torne o gatilho invisível, a rotina desatraente, difícil de executar e insatisfatória.
            """,
            contentType: .study,
            categories: ["Hábitos", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Neuroplasticidade", "Behaviorismo", "Ciência Cognitiva"],
            sources: ["Lally et al. (2010) - European Journal of Social Psychology", "Charles Duhigg - The Power of Habit (2012)", "James Clear - Atomic Habits (2018)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Hábitos", "#Neuroplasticidade", "#Comportamento", "#Mindset"],
            likes: 2134,
            saves: 1876,
            shares: 934,
            createdAt: Date().addingTimeInterval(-86400 * 13),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 14 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_014",
            title: "Limites Emocionais: Como Estabelecer Sem Culpa",
            description: "Limites saudáveis não são egoísmo — são auto-respeito. Como identificar, estabelecer e manter limites em relacionamentos sem se sentir culpado.",
            content: """
            Pessoas sem limites claros frequentemente sentem ressentimento crônico, esgotamento e perda de identidade. Paradoxalmente, são as pessoas que mais tentam agradar.

            **O que são limites emocionais:**
            Limites definem onde você termina e o outro começa — em termos de responsabilidade emocional, tempo, energia e valores.

            **Por que é tão difícil:**
            Muitos de nós aprendemos na infância que dizer não = rejeição ou perda de amor. Essa crença nuclear gera culpa automática sempre que estabelecemos um limite.

            **Os 3 tipos de limites:**
            1. **Rígidos** — paredes sem portas. Afasta conexão.
            2. **Porosos** — ausência de limites. Gera esgotamento.
            3. **Flexíveis** — saudável. Adapta-se ao contexto e relação.

            **Como comunicar um limite:**
            Fórmula assertiva:
            "Quando [comportamento específico], sinto [emoção]. Preciso que [pedido claro]. Se isso continuar, vou [consequência]."

            Exemplo: "Quando você faz piadas sobre meu peso, sinto vergonha e tristeza. Preciso que pare. Se continuar, vou deixar a conversa."

            **Lembre:** Estabelecer um limite é informar — não punir, não negociar, não pedir permissão.
            """,
            contentType: .article,
            categories: ["Relacionamentos", "Autoestima"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["TCC", "Terapia do Esquema", "DBT"],
            sources: ["Nedra Tawwab - Set Boundaries, Find Peace (2021)", "Henry Cloud - Boundaries (1992)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Limites", "#Relacionamentos", "#Assertividade", "#AutoRespeito"],
            likes: 1834,
            saves: 1567,
            shares: 712,
            createdAt: Date().addingTimeInterval(-86400 * 14),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 15 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_015",
            title: "Gratidão: As Evidências Científicas por Trás da Prática",
            description: "Estudo de UC Davis com 300 participantes mostrou que escrever gratidão por 3 semanas reduziu sintomas depressivos em 35% e visitas médicas em 28%.",
            content: """
            Gratidão não é pensamento positivo forçado. É uma prática de atenção treinável com efeitos mensuráveis no cérebro e no corpo.

            **O que acontece no cérebro:**
            Robert Emmons (UC Davis) e Michael McCullough conduziram estudo com 300 participantes em 3 grupos:
            • Grupo 1: listou gratidões semanais
            • Grupo 2: listou aborrecimentos
            • Grupo 3: listou eventos neutros

            Após 10 semanas, o grupo de gratidão reportou 25% mais bem-estar subjetivo, dormiu mais, fez mais exercícios e teve menos visitas médicas.

            **Por que funciona neurologicamente:**
            Gratidão ativa o hipotálamo (regulação do sono e estresse) e libera dopamina e serotonina simultaneamente — o que explica seu efeito antidepressivo.

            **Prática eficaz (não clichê):**
            A especificidade é chave. Ao invés de "sou grato pela minha família", escreva:
            "Sou grato pelo momento de hoje de manhã em que minha filha riu enquanto tomávamos café."

            Especificidade previne a adaptação hedônica (o cérebro deixa de responder a estímulos repetidos).

            Pratique 3x por semana, não diariamente — pesquisas indicam que a frequência diária reduz o impacto.
            """,
            contentType: .study,
            categories: ["Hábitos", "Saúde Mental", "Propósito"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Psicologia Positiva", "Neurociência Afetiva", "Psicologia Cognitiva"],
            sources: ["Emmons & McCullough (2003) - Journal of Personality and Social Psychology", "Seligman et al. (2005) - American Psychologist"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Gratidão", "#BemEstar", "#Felicidade", "#PsicologiaPositiva"],
            likes: 987,
            saves: 823,
            shares: 341,
            createdAt: Date().addingTimeInterval(-86400 * 15),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 16 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_016",
            title: "Ritual Matinal para Saúde Mental: O que Funciona de Verdade",
            description: "Análise das rotinas matinais mais estudadas cientificamente: exercício, luz solar, hidratação, journaling e meditação — com impacto comprovado no humor e cognição.",
            content: """
            Não existe rotina matinal perfeita para todos — mas existem componentes com evidências sólidas que você pode adaptar à sua realidade.

            **Os 5 elementos com maior evidência:**

            **1. Luz solar nos primeiros 30 minutos**
            Andrew Huberman (Stanford) demonstrou que exposição a luz solar direta nos primeiros 30 minutos acerta o relógio circadiano, aumenta cortisol saudável no pico correto (manhã) e melhora qualidade do sono noturno em 50%.

            **2. Hidratação imediata**
            Após 7-8 horas sem água, o corpo está 1-2% desidratado — suficiente para reduzir concentração em 10% e aumentar sensação de ansiedade. 500ml ao acordar reverte isso em minutos.

            **3. Movimento (qualquer intensidade)**
            10 minutos de exercício moderado aumentam BDNF (fator de crescimento neural) e dopamina. Não precisa ser academia — uma caminhada serve.

            **4. Não checar o celular nos primeiros 30 minutos**
            Verificar notificações ao acordar coloca o cérebro em modo reativo (cortisol reativo ao invés de cortisol natural de despertar). Isso afeta foco e humor por horas.

            **5. Intenção do dia (2 minutos)**
            Escrever 3 prioridades do dia ativa o córtex pré-frontal e reduz sobrecarga cognitiva.

            Comece com apenas 1 desses elementos e adicione progressivamente.
            """,
            contentType: .article,
            categories: ["Hábitos", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Cronobiologia", "Neurociência", "Psicologia Comportamental"],
            sources: ["Huberman Lab Podcast - Morning Routine Science", "Ratey - Spark: The Revolutionary New Science of Exercise and the Brain (2008)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#RituaMatinal", "#Hábitos", "#Produtividade", "#SaúdeMental"],
            likes: 1456,
            saves: 1234,
            shares: 567,
            createdAt: Date().addingTimeInterval(-86400 * 16),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 17 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_017",
            title: "Apego Ansioso vs. Seguro: Como Seu Estilo Afeta Relacionamentos",
            description: "Teoria do apego de Bowlby e Ainsworth aplicada a relacionamentos adultos. Como identificar seu estilo e como mudar padrões que causam sofrimento.",
            content: """
            Mary Ainsworth, em 1970, identificou 3 estilos de apego em bebês. Décadas depois, pesquisadores descobriram que esses padrões continuam moldando nossos relacionamentos adultos.

            **Os 4 estilos de apego:**

            **1. Seguro (55% da população)**
            Confortável com intimidade e autonomia. Consegue depender de outros sem ansiedade.

            **2. Ansioso-preocupado (20%)**
            Medo de abandono, necessidade constante de reasseguração, ciúme. Paradoxalmente afasta quem ama.

            **3. Evitativo-dispensável (25%)**
            Desconforto com intimidade. Valoriza independência excessiva. Fecha-se emocionalmente.

            **4. Desorganizado/Temeroso (5-10%)**
            Combinação de medo de intimidade E de abandono. Frequentemente ligado a trauma.

            **Por que muda tudo:**
            Levinson & Broemer (2009) mostraram que o estilo de apego prediz satisfação conjugal, conflito e probabilidade de divórcio com acurácia de 62%.

            **A boa notícia — é mutável:**
            Siegel (2010) demonstrou que "experiências relacionais corretivas" — seja em terapia, seja em relacionamentos seguros — podem remodelar o estilo de apego. A neuroplasticidade permite isso.

            **Onde você se reconhece?**
            """,
            contentType: .article,
            categories: ["Relacionamentos", "Autoestima"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Teoria do Apego", "Psicologia do Desenvolvimento", "Neuroplasticidade"],
            sources: ["Bowlby - Attachment and Loss (1969)", "Ainsworth et al. - Patterns of Attachment (1978)", "Levine & Heller - Attached (2010)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#TeoríaDoApego", "#Relacionamentos", "#Autoconhecimento", "#Trauma"],
            likes: 2345,
            saves: 1987,
            shares: 876,
            createdAt: Date().addingTimeInterval(-86400 * 17),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 18 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_018",
            title: "Técnica 5-4-3-2-1: Saia de um Ataque de Pânico em Minutos",
            description: "Técnica de grounding sensorial para interromper imediatamente o ciclo de hiperativação do sistema nervoso durante episódios de ansiedade ou pânico.",
            content: """
            Quando um ataque de pânico começa, seu cérebro entra em modo de sobrevivência — a amígdala sequestra o córtex pré-frontal. A técnica 5-4-3-2-1 usa os sentidos para reconectar você ao momento presente e desativar esse alarme.

            **Por que funciona:**
            A técnica redireciona o processamento do sistema límbico (emocional) para o córtex sensorial (processamento de fatos). Isso literalmente "acalma" a amígdala em tempo real.

            **A prática:**

            Nomeie (em voz alta se possível):
            • **5 coisas que VOCÊ VÊ** — seja específico (não "uma mesa"; mas "uma mesa de madeira com risco no canto")
            • **4 coisas que VOCÊ TOCA** — sinta a textura, temperatura, peso
            • **3 coisas que VOCÊ OUVE** — sons distantes, próximos, internos
            • **2 coisas que VOCÊ CHEIRA** — mesmo que seja "nada especial" ou "ar"
            • **1 coisa que VOCÊ SABOREIA** — observe qualquer sabor na boca

            Após completar, faça 3 respirações profundas.

            **Quando usar:**
            • Antes de situações ansiogênicas
            • Durante um ataque de pânico
            • Ao acordar com pensamentos acelerados
            • Em situações de estresse agudo

            Treine em momentos de calma para ter o recurso disponível nos momentos de crise.
            """,
            contentType: .reflectionCard,
            categories: ["Ansiedade", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Grounding", "Terapia de Exposição", "TCC", "DBT"],
            sources: ["Craske & Barlow - Mastery of Your Anxiety and Panic (2006)", "DBT Skills Training Manual - Linehan (2014)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Pânico", "#Ansiedade", "#Grounding", "#SaúdeMental"],
            likes: 3124,
            saves: 2789,
            shares: 1456,
            createdAt: Date().addingTimeInterval(-86400 * 18),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 19 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_019",
            title: "O Trauma e o Corpo: Por Que 'Só Pensar Diferente' Não Basta",
            description: "Bessel van der Kolk explica por que traumas ficam armazenados no corpo e por que abordagens somáticas são essenciais para a cura.",
            content: """
            "O corpo guarda o placar" — assim Bessel van der Kolk intitulou seu livro seminal após 40 anos pesquisando trauma em Harvard e Boston University.

            **O que acontece no trauma:**
            Experiências traumáticas ficam armazenadas não apenas como memórias verbais no hipocampo, mas como memórias sensoriais e corporais no cerebelo e córtex motor. É por isso que pessoas traumatizadas frequentemente:
            • Têm reações físicas a gatilhos (tensão, taquicardia, náusea)
            • Sentem sensações corporais sem saber por quê
            • Não conseguem "só pensar positivo" e sair do trauma

            **Por que a fala sozinha não basta:**
            A região de Broca (processamento de linguagem) literalmente se desativa durante flashbacks traumáticos — o escaneamento cerebral mostra isso. Não há como "falar sobre" o que o cérebro não consegue processar verbalmente no momento da ativação.

            **Abordagens eficazes:**
            • **EMDR** — reprocessamento de memórias traumáticas via movimentos oculares
            • **Somatic Experiencing** (Levine) — liberação de energia traumática via sensações corporais
            • **Yoga terapêutico** — Van der Kolk demonstrou em RCT que yoga foi tão eficaz quanto psicoterapia para TEPT
            • **TCC focada no trauma**

            Curar trauma exige reconectar corpo e mente — não apenas reestruturar pensamentos.
            """,
            contentType: .study,
            categories: ["Saúde Mental", "Relacionamentos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Neurociência do Trauma", "Somatic Experiencing", "EMDR"],
            sources: ["Van der Kolk - The Body Keeps the Score (2014)", "Levine - Waking the Tiger (1997)", "Van der Kolk et al. (2014) - Journal of Clinical Psychiatry - Yoga RCT"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Trauma", "#TEPT", "#Cura", "#SaúdeMental", "#Corpo"],
            likes: 1678,
            saves: 1456,
            shares: 698,
            createdAt: Date().addingTimeInterval(-86400 * 19),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 20 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_020",
            title: "Body Scan: Meditação de Escaneamento Corporal",
            description: "Meditação de 12 minutos baseada no protocolo MBSR. O body scan reduz dor crônica em 43% e melhora qualidade do sono em participantes de estudos controlados.",
            content: """
            O Body Scan (Escaneamento Corporal) é a prática central do protocolo MBSR. É frequentemente a primeira meditação ensinada porque não requer habilidade prévia — apenas disposição para observar.

            **O que é:**
            Uma jornada sistemática de atenção por todo o corpo, da cabeça aos pés ou vice-versa, observando sensações sem tentar mudá-las.

            **O que não é:**
            Relaxamento muscular progressivo (que pede tensão e soltura). Body scan é apenas observação — você não tenta mudar nada.

            **Evidências clínicas:**
            • Estudos na Clínica de Redução de Estresse de UMass mostraram 43% de redução em dor crônica
            • Kabat-Zinn et al. (1992) publicaram resultados de 4-ano de follow-up mostrando manutenção dos ganhos
            • Específico para insônia: estudo de 2015 (Ong et al.) mostrou body scan melhorando qualidade de sono em 63% dos participantes

            **Postura:**
            Deitado de costas, braços ao longo do corpo, olhos fechados. Esta prática não é sobre dormir — mas se adormecer, é sinal que o corpo precisava de descanso.

            Siga o áudio e simplesmente observe.
            """,
            contentType: .meditation,
            categories: ["Meditação", "Sono", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["MBSR", "Mindfulness", "Neurociência da Dor"],
            sources: ["Kabat-Zinn et al. (1992) - General Hospital Psychiatry", "Ong et al. (2015) - Sleep Medicine - Body Scan for Insomnia"],
            meditationDuration: 720,
            meditationAudio: nil,
            hashtags: ["#BodyScan", "#Mindfulness", "#Meditação", "#Sono"],
            likes: 834,
            saves: 712,
            shares: 234,
            createdAt: Date().addingTimeInterval(-86400 * 20),
            isPublished: true,
            isFeatured: false
        ),

        // ── POST 21 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_021",
            title: "Propósito de Vida e Saúde: O Que 2.000 Estudos Mostram",
            description: "Ter um propósito claro está associado a 23% menos risco de Alzheimer, dormir melhor e viver até 7 anos a mais. A ciência por trás de ikigai e Logoterapia.",
            content: """
            Victor Frankl sobreviveu ao Holocausto e observou que os prisioneiros que tinham um "porquê" para viver sobreviviam mais — mesmo em condições físicas idênticas. Isso formou a base da Logoterapia e foi confirmado décadas depois pela ciência.

            **O que as pesquisas mostram:**

            Patrick Hill (Carleton University, 2014) analisou dados de 7.000 americanos por 14 anos e descobriu que indivíduos com alto propósito de vida tinham:
            • 15% menos mortalidade por qualquer causa
            • Menor risco de ataque cardíaco
            • Melhor saúde cognitiva na velhice

            Neurobiologicamente, propósito ativa o córtex pré-frontal medial e o estriado — regiões associadas à motivação intrínseca e resiliência ao estresse.

            **Ikigai — o conceito japonês:**
            Ikigai (razão de ser) existe na interseção de:
            1. O que você AMA fazer
            2. No que você é BOM
            3. O que o mundo PRECISA
            4. Pelo que você pode ser PAGO

            Você não precisa encontrar ikigai perfeito — mas qualquer movimento nessa direção gera saúde.

            **Exercício:** Escreva respostas para estas 3 perguntas:
            1. O que você faria de graça se dinheiro não importasse?
            2. Quando você perde a noção do tempo?
            3. Que problemas do mundo te incomodam a ponto de você querer resolver?
            """,
            contentType: .reflectionCard,
            categories: ["Propósito", "Saúde Mental", "Hábitos"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Logoterapia", "Psicologia Positiva", "Neurociência"],
            sources: ["Hill & Turiano (2014) - Psychological Science", "Victor Frankl - Man's Search for Meaning (1946)", "García & Miralles - Ikigai (2017)"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Propósito", "#Ikigai", "#Autoconhecimento", "#Significado"],
            likes: 2789,
            saves: 2456,
            shares: 1123,
            createdAt: Date().addingTimeInterval(-86400 * 21),
            isPublished: true,
            isFeatured: true
        ),

        // ── POST 22 ─────────────────────────────────────────────────────────
        FeedPost(
            id: "post_022",
            title: "Burnout: Como Reconhecer Antes de Chegar ao Limite",
            description: "A OMS incluiu burnout no CID-11 em 2019. Sinais de alerta, diferença de depressão e protocolo de recuperação baseado em evidências.",
            content: """
            Em 2019, a Organização Mundial da Saúde incluiu burnout no CID-11 como fenômeno ocupacional. Não é frescura — é uma síndrome com neurobiologia documentada.

            **A definição da OMS:**
            Síndrome resultante de estresse crônico no trabalho não gerenciado, caracterizada por:
            1. Sensação de esgotamento de energia
            2. Aumento de distanciamento mental do trabalho (cinismo)
            3. Redução da eficácia profissional

            **Diferença crucial: Burnout vs. Depressão**
            • Burnout: esgotamento contextualizado ao trabalho; melhora em férias/descanso
            • Depressão: estado persistente independente do contexto; não melhora apenas com descanso

            **Os 12 estágios de Herbert Freudenberger:**
            (O burnout não acontece do dia para a noite)
            1. Compulsão de se provar
            2. Trabalhar mais arduamente
            3. Negligenciar necessidades pessoais
            4. Deslocamento de conflitos
            5. Revisão de valores
            6. Negação de problemas emergentes
            7. Retirada social
            8. Mudanças comportamentais óbvias
            9. Despersonalização
            10. Vazio interno
            11. Depressão
            12. Colapso

            **Protocolo de recuperação:**
            • Fase 1 (1-2 semanas): apenas descanso — sem produtividade
            • Fase 2 (2-4 semanas): reintrodução gradual de atividades prazerosas
            • Fase 3: reestruturação de valores e limites profissionais
            • Fase 4: retorno ao trabalho com novos protocolos
            """,
            contentType: .study,
            categories: ["Trabalho", "Saúde Mental"],
            author: "ALMA",
            authorId: "alma_official",
            authorImage: nil,
            coverImage: nil,
            scientificBasis: ["Medicina Ocupacional", "Psicologia Clínica", "CID-11"],
            sources: ["OMS CID-11 (2019)", "Maslach & Leiter - Burnout (2016)", "Freudenberger - Staff Burn-Out (1974) - Journal of Social Issues"],
            meditationDuration: nil,
            meditationAudio: nil,
            hashtags: ["#Burnout", "#Trabalho", "#SaúdeMental", "#Esgotamento"],
            likes: 3456,
            saves: 3012,
            shares: 1567,
            createdAt: Date().addingTimeInterval(-86400 * 22),
            isPublished: true,
            isFeatured: true
        ),
    ]
}
