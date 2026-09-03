//
//  AIBodyScan.swift
//  Corpo & Alma
//
//  Scan corporal com IA: modelos + serviço.
//
//  IMPORTANTE (segurança): a chamada ao modelo de IA (Claude com visão) deve
//  acontecer num BACKEND (ex.: Firebase Function), nunca no app — para não expor
//  chaves. O app só envia medidas + fotos e recebe o resultado já pronto.
//  Enquanto o backend não existe, `MockAIPlanService` gera um plano real offline.
//

import Foundation

// MARK: - Modelos de resultado

enum Somatotype: String, Codable {
    case ectomorfo = "Ectomorfo"
    case mesomorfo = "Mesomorfo"
    case endomorfo = "Endomorfo"

    var descricao: String {
        switch self {
        case .ectomorfo: return "Estrutura mais magra, ganha massa com mais dificuldade."
        case .mesomorfo: return "Estrutura atlética, responde bem a treino e dieta."
        case .endomorfo: return "Tende a acumular gordura, foco em déficit e constância."
        }
    }
}

struct BodyAnalysis: Codable {
    /// OPCIONAL desde 12/08/2026, e a opcionalidade é o conserto — não um detalhe.
    ///
    /// O somatotipo é um RÓTULO. A análise é a gordura estimada, o resumo, as
    /// observações e os focos. Até 12/08 o app descartava tudo isso quando o
    /// rótulo não vinha na grafia esperada: a pessoa perdia a análise inteira
    /// por causa de uma palavra. Aconteceu em produção, quatro vezes seguidas.
    ///
    /// Agora ausência de rótulo esconde o rótulo (`ScanResultView`), e nada mais.
    /// O que continua PROIBIDO é preencher este campo com heurística local e
    /// exibir como se a foto tivesse sido lida — isso é o B8, e é o motivo de
    /// aqui ser `nil` em vez de um valor de reserva.
    let somatotype: Somatotype?

    /// OPCIONAL desde 12/08/2026, pelo mesmo motivo do `somatotype` acima e com
    /// uma diferença que pesa mais: aqui a ausência vinha **disfarçada de
    /// medida**.
    ///
    /// No caminho sem foto, quem nunca informou a gordura tem `bodyFat == 0` no
    /// `AppModel` — o zero é o valor de carga (`store.object(...) as? Double ?? 0`,
    /// `Models.swift`), não algo que alguém tenha digitado. Esse zero atravessava
    /// o `ScanInput` inteiro e a tela imprimia **"Gordura estimada: 0%"**: um
    /// número que ninguém mediu, exibido como resultado, num app de saúde.
    ///
    /// Zero não é medida — é ausência de medida. A regra já valia em
    /// `SaudeView.medida(_:casas:)`, em `EditAssessmentView.measureRow` e em
    /// `AppModel.hasBodyProfile`; o que faltava era ela chegar aqui. Sendo
    /// opcional, o compilador não deixa mais ninguém imprimir este campo sem
    /// antes decidir o que fazer quando ele não existe — a mesma trava que
    /// `imcSeguro` ganhou depois do "nan · Obesidade".
    ///
    /// Ausência esconde a linha (`ScanResultView`), e nada mais. Continua
    /// PROIBIDO preencher com estimativa local e exibir como se fosse leitura —
    /// é o B8, e é o motivo de ser `nil` em vez de um valor de reserva.
    let estimatedBodyFat: Double?
    let summary: String
    let observations: [String]
    let focusAreas: [String]

    /// A REGRA, num lugar só: gordura só é dado quando é número finito e maior
    /// que zero.
    ///
    /// Está aqui, e não na tela, porque o resultado é **persistido**
    /// (`AppModel.scanResult`, JSON no store) e reaberto pelo "Ver meu plano
    /// atual" da `SaudeView`. Quem já gerou um scan sem informar a gordura tem
    /// um `0` gravado no aparelho; normalizar só na hora de desenhar deixaria
    /// esse arquivo mentindo para sempre. Por isso a regra roda também no
    /// `init(from:)` — o dado velho é corrigido na leitura.
    ///
    /// `> 0` e não `>= 5` (o mínimo do slider): o limite do controle é assunto
    /// da tela de edição. Aqui a pergunta é só se existe medida.
    static func gorduraInformada(_ bruto: Double?) -> Double? {
        guard let bruto, bruto.isFinite, bruto > 0 else { return nil }
        return bruto
    }

    /// A REGRA DE CIMA, uma camada acima da anterior: **sem gordura, sem
    /// rótulo.**
    ///
    /// Consertar a linha de gordura (12/08, `012b40f`) deixou o defeito de pé um
    /// nível abaixo. A heurística do `MockAIPlanService` testa `bodyFat <= 12`, e
    /// o zero da ausência **passa nesse teste**: mesmo corpo, IMC 17,96, quem
    /// nunca informou nada recebia "Ectomorfo" com a mesma confiança de quem
    /// informou 10% (sonda `05_achado_somatotipo.txt`). A linha já não mentia; a
    /// conta ainda usava o vazio.
    ///
    /// Rótulo tirado de dado que ninguém forneceu é pior que rótulo ausente —
    /// mais ainda num app de saúde, onde "Ectomorfo" soa como leitura do corpo
    /// da pessoa. E esconder não é invenção nova: é o que a tela **já** faz com
    /// somatotipo ausente desde o incidente da IA (`ScanResultView`), quando o
    /// modelo devolve `null` no rótulo.
    ///
    /// FOI RECUSADA, por decisão do Assis, a alternativa de recalcular o rótulo
    /// só por IMC quando falta a gordura: isso seria inventar um método de
    /// classificação corporal, o que é afirmação de saúde, não decisão de
    /// engenharia.
    ///
    /// ── O CUSTO, dito em voz alta ───────────────────────────────────────────
    /// No caminho COM foto o rótulo vem da imagem, não da gordura — lá ele não é
    /// calculado com a ausência. Mesmo assim esta regra o alcança, porque
    /// `BodyAnalysis` não guarda a procedência (quem guarda é
    /// `ScanResult.isAIGenerated`, um nível acima). Na prática isso só morde se a
    /// IA devolver gordura ≤ 0 junto de um rótulo válido: o servidor não valida
    /// faixa (`analiseDeFoto.ts` só normaliza `somatotipo` e exige `resumo`) e o
    /// cliente só desembrulha o opcional, então é alcançável, ainda que exija
    /// resposta malformada — 0% de gordura é fisiologicamente impossível. Nesse
    /// caso perde-se o rótulo; resumo, observações e focos continuam. Preferido
    /// a espalhar a regra por dois tipos e deixar o Android com um invariante
    /// que não porta.
    static func somatotipoSustentado(_ bruto: Somatotype?, gordura: Double?) -> Somatotype? {
        guard gorduraInformada(gordura) != nil else { return nil }
        return bruto
    }

    /// A lista de entradas que a estimativa REALMENTE usou, para o texto que a
    /// declara. Terceira aplicação da mesma regra, agora na frase.
    ///
    /// Duas frases dizem essa lista, e **as duas aparecem juntas na mesma tela**
    /// do caminho sem foto: o resumo (`MockAIPlanService`) e o banner
    /// "Estimativa por medidas — sem IA" (`ScanResultView`, sob
    /// `isAIGenerated == false`). Ambas afirmavam "peso, altura, idade e % de
    /// gordura informados" mesmo quando ninguém informou gordura nenhuma.
    ///
    /// Isso é a mesma família dos dois consertos anteriores — ausência
    /// apresentada como informação —, e depois deles ficou pior, não melhor:
    /// sem a linha de gordura e sem o rótulo, a gordura passou a alimentar
    /// **exatamente nada** na tela, enquanto duas frases diziam que ela entrou
    /// na conta. Vale notar que ela nunca entrou nos números do plano: o
    /// Mifflin-St Jeor abaixo usa peso, altura e idade, e a proteína sai do
    /// peso. A gordura só alimentava o rótulo e a própria linha dela.
    ///
    /// Por que UMA função e não dois `if`: consertar uma frase e não a outra
    /// deixaria a tela se contradizendo sobre o mesmo scan, a um dedo de
    /// distância. Saindo as duas daqui, divergir deixa de ser possível — e o
    /// caso "informou" continua com a redação de hoje, palavra por palavra.
    static func medidasUsadas(gordura: Double?) -> String {
        gorduraInformada(gordura) != nil
            ? "peso, altura, idade e % de gordura informados"
            : "peso, altura e idade"
    }

    init(somatotype: Somatotype?,
         estimatedBodyFat: Double?,
         summary: String,
         observations: [String],
         focusAreas: [String]) {
        let gordura = Self.gorduraInformada(estimatedBodyFat)
        self.somatotype = Self.somatotipoSustentado(somatotype, gordura: gordura)
        self.estimatedBodyFat = gordura
        self.summary = summary
        self.observations = observations
        self.focusAreas = focusAreas
    }

    enum CodingKeys: String, CodingKey {
        case somatotype, estimatedBodyFat, summary, observations, focusAreas
    }

    /// Escrito à mão para que o zero gravado por versões anteriores vire
    /// ausência na leitura, em vez de voltar à tela como medida.
    ///
    /// O rótulo segue junto pelo mesmo motivo, e ele é o caso MAIS grave dos
    /// dois: quem gerou um scan sem informar a gordura tem no aparelho um
    /// `{"somatotype":"Ectomorfo","estimatedBodyFat":0}`. Normalizar só a
    /// gordura deixaria a tela abrindo "Perfil: Ectomorfo" sem linha de gordura
    /// nenhuma — o rótulo inventado sobrevivendo ao conserto, vindo do disco,
    /// para sempre e justamente para quem tomou o defeito.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let gordura = Self.gorduraInformada(
            try c.decodeIfPresent(Double.self, forKey: .estimatedBodyFat))
        somatotype       = Self.somatotipoSustentado(
            try c.decodeIfPresent(Somatotype.self, forKey: .somatotype), gordura: gordura)
        estimatedBodyFat = gordura
        summary          = try c.decode(String.self, forKey: .summary)
        observations     = try c.decode([String].self, forKey: .observations)
        focusAreas       = try c.decode([String].self, forKey: .focusAreas)
    }
}

struct PlannedMeal: Codable, Identifiable {
    var id: String { type + title }
    let type: String
    let title: String
    let kcal: Int
    let items: [String]
}

struct PlannedDay: Codable, Identifiable {
    var id: String { day }
    let day: String
    let focus: String
    let exercises: [String]
}

struct GeneratedPlan: Codable {
    let dailyKcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let meals: [PlannedMeal]
    let week: [PlannedDay]
    let notes: String
}

struct ScanResult: Codable {
    let analysis: BodyAnalysis
    let plan: GeneratedPlan
    /// [F1] true = veio de IA real (Gemini/backend); false = estimativa local por medidas.
    /// Optional para decodificar resultados salvos antes deste campo existir.
    var isAIGenerated: Bool? = nil
}

struct ScanInput {
    let weightKg: Double
    let heightCm: Double
    let ageYears: Int
    let bodyFat: Double
    let goal: String
    let frontPhoto: Data?
    let sidePhoto: Data?
}

// MARK: - Serviço

protocol AIPlanService {
    func analyze(_ input: ScanInput) async throws -> ScanResult
}

/// Fábrica do serviço de análise.
///
/// [2026-08-05] A IA do scan LIGOU, por decisão do Assis, e por um caminho
/// diferente do antigo: Cloud Function `analisarFoto` (a chave mora no Secret
/// Manager, nunca no bundle). Ver `AnaliseDeFotoService`.
///
/// O que mudou nesta fábrica:
///   • `GeminiConfig` saiu de cena — não há mais chave embarcada para consultar;
///   • `isRealAI` agora é uma verdade DO BUILD, não de um plist: esta versão
///     do app tem análise por foto, ponto. Falha de rede, sessão expirada ou
///     foto ilegível são erros em tempo de execução, tratados com mensagem
///     honesta — não fazem o app voltar a fingir que nunca teve IA;
///   • o caminho sem foto continua existindo e continua rotulado como
///     estimativa por medidas (`MockAIPlanService`), porque a pessoa pode
///     escolher não enviar foto nenhuma.
enum AIService {
    /// Endpoint real, para quem procurar por ele aqui.
    static var endpoint: URL { AnaliseDeFotoService.endpoint }

    /// [F1] true = este build analisa foto de verdade. As asserções B8b/B8c
    /// exigem que a copy diga isso — e só diga enquanto for verdade.
    static var isRealAI: Bool { true }

    /// - Parameter consentimento: autorização DAQUELE envio, dada na tela.
    ///   Sem ela o serviço recusa antes de tocar na rede.
    static func make(consentimento: Bool) -> AIPlanService {
        NuvemAIPlanService(consentimento: consentimento)
    }

    /// Caminho explícito de quem optou por não enviar foto.
    static func semFoto() -> AIPlanService { MockAIPlanService() }
}

// MARK: - Gemini AI Plan Service

/// Chama o Gemini Vision diretamente para análise corporal real por foto.
// [2026-08-05] `GeminiAIPlanService` REMOVIDO. Ele chamava
// `GeminiService.analyzeBody`, que mandava as fotos direto para o provedor com
// a chave tirada do bundle. Quem faz esse trabalho agora é `NuvemAIPlanService`
// (Shared/Corpo/AnaliseDeFotoService.swift), passando pela Cloud Function.
//
// O arquivo `GeminiService.swift` continua no repo mas não é mais chamado por
// ninguém — mantido só como referência do formato de prompt até a limpeza.

// MARK: - Backend real (produção)

struct RemoteAIPlanService: AIPlanService {
    let endpoint: URL

    func analyze(_ input: ScanInput) async throws -> ScanResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "weightKg": input.weightKg,
            "heightCm": input.heightCm,
            "ageYears": input.ageYears,
            "bodyFat": input.bodyFat,
            "goal": input.goal,
            "frontPhotoBase64": input.frontPhoto?.base64EncodedString() ?? "",
            "sidePhotoBase64": input.sidePhoto?.base64EncodedString() ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ScanResult.self, from: data)
    }
}

// MARK: - Gerador offline (mock inteligente — funciona sem backend)

struct MockAIPlanService: AIPlanService {
    func analyze(_ input: ScanInput) async throws -> ScanResult {
        // [2026-08-03 — B8] Havia aqui um `Task.sleep(1,3s)` comentado como
        // "simula o tempo de processamento da IA". Era teatro: uma espera
        // artificial para o cálculo local parecer trabalho de IA, embaixo de um
        // overlay que dizia "Analisando seu corpo com IA…". Removido — o
        // cálculo é instantâneo e o app não finge o contrário.

        let h = input.heightCm / 100
        let bmi = input.weightKg / (h * h)

        // Somatotipo (heurística por IMC + % gordura)
        //
        // [2026-08-12] A heurística SÓ RODA quando a gordura existe. Antes ela
        // rodava sempre, e o `0` da ausência passava no teste `<= 12` — a pessoa
        // que não informou nada saía "Ectomorfo", que é o vazio virando rótulo.
        //
        // Note que a primeira condição (`bmi >= 27`) classificaria sozinha, sem
        // olhar a gordura. Não é saída: usar só o IMC quando falta a gordura é
        // um método de classificação corporal DIFERENTE deste, inventado aqui e
        // exibido com a mesma cara. Ou a heurística tem as duas entradas que ela
        // pede, ou não há rótulo.
        let soma: Somatotype?
        if let gordura = BodyAnalysis.gorduraInformada(input.bodyFat) {
            if gordura >= 25 || bmi >= 27 { soma = .endomorfo }
            else if gordura <= 12 && bmi < 21 { soma = .ectomorfo }
            else { soma = .mesomorfo }
        } else {
            soma = nil
        }

        // Sem rótulo, a frase que o descreve também sai — senão ele apenas troca
        // de lugar, do cabeçalho para o meio do resumo, e continua sendo dito.
        let perfilNoResumo = soma.map {
            " Seu perfil estimado é predominantemente \($0.rawValue.lowercased()). \($0.descricao)"
        } ?? ""

        // Gasto energético (Mifflin-St Jeor, fator de atividade moderado)
        let bmr = 10 * input.weightKg + 6.25 * input.heightCm - 5 * Double(input.ageYears) + 5
        let tdee = bmr * 1.45
        let adjust: Double
        switch input.goal {
        case Goal.perder.rawValue: adjust = -450
        case Goal.ganhar.rawValue: adjust = 300
        default: adjust = 0
        }
        let kcal = max(Int((tdee + adjust).rounded()), 1300)
        let protein = Int((1.8 * input.weightKg).rounded())
        let fat = Int(((Double(kcal) * 0.25) / 9).rounded())
        let carbs = max(Int((Double(kcal - protein * 4 - fat * 9) / 4).rounded()), 0)

        // [F1] Honestidade: este gerador NÃO usa fotos nem IA — o texto não pode
        // sugerir o contrário. O resultado sai rotulado como estimativa por medidas.
        let analysis = BodyAnalysis(
            somatotype: soma,
            estimatedBodyFat: input.bodyFat,
            summary: "Estimativa calculada apenas com suas medidas (\(BodyAnalysis.medidasUsadas(gordura: input.bodyFat))) — sem análise de fotos.\(perfilNoResumo) O plano abaixo foi calibrado para seu objetivo de \(input.goal.lowercased()).",
            observations: observations(for: input, bmi: bmi),
            focusAreas: focusAreas(for: input.goal)
        )

        let plan = GeneratedPlan(
            dailyKcal: kcal,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            meals: meals(kcal: kcal, goal: input.goal),
            week: week(for: input.goal),
            notes: "Estimativa por medidas — gerada sem IA. Ajuste porções conforme fome e energia, e priorize comida de verdade. Reavalie a cada 2–4 semanas."
        )

        return ScanResult(analysis: analysis, plan: plan, isAIGenerated: false)
    }

    private func observations(for input: ScanInput, bmi: Double) -> [String] {
        var out: [String] = []
        out.append(String(format: "IMC atual: %.1f (%@)", bmi, imcClass(bmi)))
        if input.frontPhoto == nil || input.sidePhoto == nil {
            out.append("Para uma análise mais precisa, adicione foto de frente e de lado.")
        }
        switch input.goal {
        case Goal.perder.rawValue:
            out.append("Déficit calórico moderado para perda de gordura preservando massa magra.")
            out.append("Inclua caminhadas diárias além dos treinos.")
        case Goal.ganhar.rawValue:
            out.append("Leve superávit calórico com proteína alta para ganho de massa.")
            out.append("Foque em progressão de carga nos treinos.")
        default:
            out.append("Manutenção com foco em composição corporal e constância.")
        }
        return out
    }

    private func focusAreas(for goal: String) -> [String] {
        switch goal {
        case Goal.perder.rawValue: return ["Gordura abdominal", "Condicionamento", "Core"]
        case Goal.ganhar.rawValue: return ["Peito e costas", "Pernas", "Ombros"]
        default: return ["Postura", "Mobilidade", "Resistência"]
        }
    }

    private func imcClass(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "abaixo do peso"
        case 18.5..<25: return "saudável"
        case 25..<30: return "sobrepeso"
        default: return "obesidade"
        }
    }

    private func meals(kcal: Int, goal: String) -> [PlannedMeal] {
        let cafe = Int(Double(kcal) * 0.25)
        let almoco = Int(Double(kcal) * 0.35)
        let lanche = Int(Double(kcal) * 0.15)
        let jantar = Int(Double(kcal) * 0.25)

        let ganho = goal == Goal.ganhar.rawValue
        return [
            PlannedMeal(type: "Café da manhã", title: "Energia da manhã", kcal: cafe,
                        items: ganho ? ["Ovos mexidos (3)", "Aveia com banana", "Pão integral", "Café"]
                                     : ["Ovos mexidos (2)", "Aveia com fruta", "Café sem açúcar"]),
            PlannedMeal(type: "Almoço", title: "Prato principal", kcal: almoco,
                        items: ["Frango/peixe grelhado", "Arroz integral", "Feijão", "Salada à vontade"]),
            PlannedMeal(type: "Lanche", title: "Pré ou pós-treino", kcal: lanche,
                        items: ganho ? ["Whey + banana", "Pasta de amendoim", "Castanhas"]
                                     : ["Iogurte natural", "Fruta", "Punhado de castanhas"]),
            PlannedMeal(type: "Jantar", title: "Refeição leve", kcal: jantar,
                        items: ["Proteína magra", "Batata-doce ou legumes", "Vegetais"])
        ]
    }

    private func week(for goal: String) -> [PlannedDay] {
        if goal == Goal.perder.rawValue {
            return [
                PlannedDay(day: "Segunda", focus: "Full Body + HIIT", exercises: ["Agachamento", "Supino halteres", "Remada", "Burpees 4x30s"]),
                PlannedDay(day: "Terça", focus: "Cardio + Core", exercises: ["Caminhada 40min", "Prancha", "Abdominais"]),
                PlannedDay(day: "Quarta", focus: "Full Body", exercises: ["Levantamento terra", "Desenvolvimento", "Afundo", "Mountain climbers"]),
                PlannedDay(day: "Quinta", focus: "Descanso ativo", exercises: ["Mobilidade", "Alongamento", "Caminhada leve"]),
                PlannedDay(day: "Sexta", focus: "HIIT", exercises: ["Polichinelos", "Agachamento com salto", "Burpees", "Corrida intervalada"]),
                PlannedDay(day: "Sábado", focus: "Full Body", exercises: ["Agachamento", "Remada", "Flexão", "Prancha"]),
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Caminhada leve", "Respiração"])
                // Todos os nomes acima estão em `NomesDePlano.tabela`.
            ]
        } else if goal == Goal.ganhar.rawValue {
            return [
                PlannedDay(day: "Segunda", focus: "Peito e tríceps", exercises: ["Supino reto", "Supino inclinado", "Crucifixo", "Tríceps corda"]),
                PlannedDay(day: "Terça", focus: "Costas e bíceps", exercises: ["Barra fixa", "Remada curvada", "Puxada", "Rosca direta"]),
                PlannedDay(day: "Quarta", focus: "Pernas", exercises: ["Agachamento", "Leg press", "Cadeira extensora", "Panturrilha"]),
                PlannedDay(day: "Quinta", focus: "Ombros e core", exercises: ["Desenvolvimento", "Elevação lateral", "Encolhimento", "Prancha"]),
                PlannedDay(day: "Sexta", focus: "Full Body força", exercises: ["Levantamento terra", "Supino", "Agachamento", "Remada"]),
                PlannedDay(day: "Sábado", focus: "Descanso ativo", exercises: ["Mobilidade", "Caminhada"]),
                // [2026-09-03] Era ["Recuperação total"] — que não é exercício
                // nenhum, não existe no catálogo, e por isso virava um card
                // fabricado ("Peso corporal · 3 séries · 10-12 reps") num dia
                // de descanso. Trocado por duas coisas que a pessoa de fato faz.
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Caminhada leve", "Respiração"])
            ]
        } else {
            return [
                PlannedDay(day: "Segunda", focus: "Superior", exercises: ["Supino halteres", "Remada", "Desenvolvimento", "Rosca"]),
                PlannedDay(day: "Terça", focus: "Cardio", exercises: ["Corrida leve 30min", "Core"]),
                PlannedDay(day: "Quarta", focus: "Inferior", exercises: ["Agachamento", "Afundo", "Stiff", "Panturrilha"]),
                PlannedDay(day: "Quinta", focus: "Mobilidade", exercises: ["Alongamento", "Yoga", "Respiração"]),
                PlannedDay(day: "Sexta", focus: "Full Body", exercises: ["Agachamento", "Flexão", "Remada", "Prancha"]),
                // [2026-09-03] "Esporte" e "Recuperação" saíram pelo mesmo
                // motivo de "Recuperação total": rótulo, não exercício.
                PlannedDay(day: "Sábado", focus: "Atividade livre", exercises: ["Caminhada", "Pedalada"]),
                PlannedDay(day: "Domingo", focus: "Descanso", exercises: ["Alongamento", "Respiração"])
            ]
        }
    }
}
