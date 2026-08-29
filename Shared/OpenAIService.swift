import Foundation
import FirebaseAuth

// MARK: - Limites do chat
// [Build 84 — 2026-07-28] Espelha o limite da Cloud Function `chat`
// (functions/src/index.ts, MAX_MESSAGE_CHARS). Se mudar lá, mudar aqui.
enum ChatLimits {
    /// Máximo de caracteres por mensagem aceito pelo servidor.
    static let maxMessageLength = 4000
    /// A partir de quantos caracteres o contador aparece no input.
    static let counterVisibleFrom = 3400
}

// MARK: - Identidade de nascimento (efêmera)
//
// [2026-08-28] Hora e local de nascimento, do aparelho para a IA, sem parar no
// banco.
//
// ── O DEFEITO QUE ISTO FECHA ────────────────────────────────────────────────
// O onboarding (`OnboardingBiometricsView`) pergunta o período do dia e a
// cidade de nascimento, e o `UserMemoryManager` grava os dois em UserDefaults
// (`alma_user_birthTimeSlot`, `alma_user_birthCity`). E acabava ali: nenhum
// caminho levava esses campos até a Alma. Em produção ela dizia, corretamente,
// que os dados "não chegaram para mim neste contexto".
//
// ── POR QUE EFÊMERO, E NÃO NO FIRESTORE ────────────────────────────────────
// Decisão do Assis: mesmo cano do `healthContext`. Sobe dentro da requisição,
// é usado para montar o prompt e morre com ela. Cidade + hora exata
// identificam muito mais que uma data solta, e a declaração de "efêmero" já
// feita no formulário do Google Play só continua verdadeira enquanto isto não
// for persistido.
//
// ── POR QUE MANDA CAMPO, E NÃO FRASE PRONTA ────────────────────────────────
// O `healthContext` sobe como texto porque é montado de sensor. A cidade é
// digitada pela pessoa num `TextField` — mesma superfície de injeção de prompt
// que o `mainChallenge`. Então o aparelho manda os CAMPOS e quem escreve a
// frase é o servidor, que valida o período contra conjunto fechado e higieniza
// a cidade (`blocoIdentidadeDeNascimento`, em contextoDoUsuario.ts).
//
// ── POR QUE AQUI DENTRO, E NÃO EM ARQUIVO PRÓPRIO ──────────────────────────
// `Shared/` não é um `PBXFileSystemSynchronizedRootGroup` neste projeto — só
// `AlmaComplication` é. Arquivo novo em `Shared/` NÃO entra no alvo sozinho:
// precisa ser registrado no `project.pbxproj`, e um arquivo que não compila
// falha em silêncio (o app builda, a função simplesmente não existe). Mora
// junto de quem o consome até alguém decidir mexer no projeto.
enum BirthIdentityContext {

    /// Valor que o onboarding grava quando a pessoa não sabe o período.
    /// Não sobe: ausência de linha já diz isso, e de graça.
    static let slotDesconhecido = "Não sei"

    /// Tem de bater com `PERIODOS_DE_NASCIMENTO` no servidor — o que não bater
    /// é descartado lá, em silêncio.
    static let slotsValidos: Set<String> = [
        "Madrugada (0h-6h)",
        "Manhã (6h-12h)",
        "Tarde (12h-18h)",
        "Noite (18h-24h)",
    ]

    static let maxCharsCidade = 60

    /// Monta o dicionário que vai no corpo da requisição. `nil` quando não há
    /// nada de útil — e aí nada é enviado, e o servidor se comporta como nas
    /// versões antigas do app.
    static func build(memoria: UserMemoryManager = .shared) -> [String: String]? {
        var campos: [String: String] = [:]

        // Hora exata: só existe se algum dia a pessoa disser na conversa e
        // alguém gravar. Hoje NINGUÉM grava esta chave — ela é lida assim mesmo
        // para que o dia em que passar a existir não precise de mudança aqui.
        let horaExata = UserDefaults.standard.string(forKey: "alma_user_birthTimeExact") ?? ""
        if Self.horaValida(horaExata) {
            campos["birthTime"] = horaExata
        } else {
            let slot = memoria.birthTimeSlot.trimmingCharacters(in: .whitespacesAndNewlines)
            if slotsValidos.contains(slot) {
                campos["birthTimeSlot"] = slot
            }
        }

        let cidade = Self.limpar(memoria.birthCity)
        if !cidade.isEmpty {
            campos["birthCity"] = cidade
            let pais = Self.limpar(memoria.birthCountry)
            if !pais.isEmpty { campos["birthCountry"] = pais }
        }

        return campos.isEmpty ? nil : campos
    }

    /// `"14:30"` — 24h, zero à esquerda. Qualquer outra coisa é tratada como
    /// ausência: hora meio-válida vira precisão inventada lá na frente.
    static func horaValida(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count == 5 else { return false }
        return t.range(of: "^([01][0-9]|2[0-3]):[0-5][0-9]$", options: .regularExpression) != nil
    }

    /// Tira quebra de linha e aparas, e aplica o teto. A higiene contra injeção
    /// é do servidor — esta é só a boa vizinhança de não mandar lixo.
    static func limpar(_ s: String) -> String {
        let semQuebra = s
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(semQuebra.prefix(maxCharsCidade))
    }
}

// MARK: - AlmaError
enum AlmaError: LocalizedError {
    case noUser
    case tokenFailed
    case serverError(Int)
    /// [Build 84] Erro HTTP com mensagem amigável vinda do corpo JSON do
    /// servidor (`{"error": "..."}`) — ex.: validação de mensagem muito longa.
    case serverRejected(Int, String)
    /// [2026-08-28] O servidor recusou por ASSINATURA (403 + `motivo:
    /// "premium_obrigatorio"`). Variante própria, e não `serverRejected`,
    /// porque a UI **não deve mostrar este texto**: deve abrir o paywall.
    ///
    /// Antes disto, o texto do servidor virava balão da Alma e se repetia a
    /// cada mensagem enviada — ver `LAUDO_CHAT_403_PREMIUM_20260828.md`. O
    /// texto viaja junto só para log e para o `switch` ser exaustivo; quem
    /// escreve a frase que a pessoa lê é o CLIENTE.
    case premiumRequired(String)
    case rateLimited
    case parseFailed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noUser:            return "Nenhum usuário autenticado."
        case .tokenFailed:       return "Falha ao obter token de autenticacao."
        case .serverError(let c): return "Erro do servidor (\(c))."
        case .serverRejected(_, let m): return m
        case .premiumRequired(let m): return m
        case .rateLimited:       return "Limite de mensagens atingido. Tente novamente amanhã."
        case .parseFailed:       return "Resposta inesperada do servidor."
        case .networkError(let m): return "Erro de rede: \(m)"
        }
    }
}

// MARK: - OpenAIService (Singleton)
class OpenAIService {

    static let shared = OpenAIService()

    // Endpoint principal — Firebase Cloud Function
    private let cloudFunctionURL = URL(string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat")!

    // ⚠️ DESATIVADO por motivos de segurança.
    //
    // O fallback original chamava OpenAI directamente a partir do cliente, usando
    // uma chave lida do Info.plist. Em producao, essa chave estaria empacotada no
    // bundle e qualquer pessoa com o IPA conseguia extrai-la — risco de abuso e
    // custo runaway. TODA a comunicacao com a OpenAI passa pela Cloud Function
    // autenticada (verifyIdToken + rate-limit em `rate_limits/{uid}`).
    //
    // Se um dia precisares de resiliencia extra, implementa retry exponencial
    // contra a Cloud Function — NUNCA embutas a chave OpenAI no cliente.

    private init() {}

    /// Envia uma mensagem para a Cloud Function Alma e devolve a resposta.
    /// Sem fallback directo: se a Cloud Function falhar, o erro e propagado.
    /// - Parameter healthContext: resumo do dia montado NO APARELHO
    ///   (HealthContextBuilder). Vai no prompt daquela chamada e o servidor NÃO
    ///   o grava no histórico. `nil` quando o usuário não deu consentimento.
    func sendMessage(_ message: String, healthContext: String? = nil) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AlmaError.noUser
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw AlmaError.tokenFailed
        }

        return try await callCloudFunction(message: message, token: token, healthContext: healthContext)
    }

    // MARK: - Cloud Function
    private func callCloudFunction(message: String, token: String, healthContext: String? = nil) async throws -> String {
        var request = URLRequest(url: cloudFunctionURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body: [String: Any] = ["message": message]
        // [Build 85 / 2.0] Contexto de saúde: só vai quando existe consentimento
        // e dado real. Efêmero — o servidor injeta no prompt e não persiste.
        if let healthContext, !healthContext.isEmpty {
            body["healthContext"] = healthContext
        }
        // [2026-08-28] Hora e local de nascimento (`BirthIdentityContext`).
        //
        // Cano deliberadamente SEPARADO do `healthContext`: aquele é gated por
        // consentimento de saúde e tem teto de 600 caracteres compartilhado.
        // Pendurar nascimento ali faria a identidade da pessoa depender de ela
        // ter ligado o HealthKit — e competir por espaço com alergia e humor.
        // Nascimento não é dado de saúde e não deve disputar aquele orçamento.
        //
        // ⚠️ Efêmero, como o `healthContext` e a `regiao`: o servidor injeta no
        // prompt e NÃO grava. Vai estruturado de propósito — a cidade é
        // digitada pela pessoa, então quem escreve a frase é o servidor.
        if let nascimento = BirthIdentityContext.build(), !nascimento.isEmpty {
            body["identidadeDeNascimento"] = nascimento
        }
        // [2026-08-22] Região do aparelho, e SÓ para o servidor escolher qual
        // linha de apoio em crise oferecer (`functions/src/apoioEmCrise.ts`).
        // Dar o número do país errado é pior do que não dar número: a pessoa
        // liga e não atende.
        //
        // O `Locale` foi escolhido por ser o caminho MENOS invasivo que funciona
        // — já está no aparelho, não pede permissão, não é dado sensível.
        // Geolocalização por IP no servidor seria pior (erra com VPN e cria
        // tratamento de dado que hoje não existe).
        //
        // ⚠️ NÃO É RASTREAMENTO. Vai no corpo desta requisição e acaba aí: não
        // é gravado, não vira evento de analytics, não vai para a Meta (ver
        // `MetaEventsManager`) e não entra em log.
        if let regiao = Locale.current.region?.identifier,
           regiao.count == 2 {
            body["regiao"] = regiao.uppercased()
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao serializar body do chat: \(error)")
            #endif
            throw AlmaError.networkError(error.localizedDescription)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AlmaError.networkError(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw AlmaError.rateLimited }
            if http.statusCode >= 400 {
                // [Build 84] A Cloud Function devolve {"error": "<texto em PT-BR>"}.
                // Propaga esse texto para a UI mostrar algo útil em vez de
                // "Algo deu errado (erro 400)". 401 continua como serverError
                // para preservar o fluxo de retry de token no ChatView.
                if http.statusCode != 401,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverText = json["error"] as? String,
                   !serverText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // [2026-08-28] O campo `motivo` é o que separa "assinatura"
                    // de qualquer outra recusa. Sem ele, o 403 de premium e o
                    // 400 de mensagem longa chegam à UI como o MESMO caso — e
                    // o de premium virava balão de conversa, repetido.
                    //
                    // A condição é estreita de propósito: exige status 403 E o
                    // motivo exato. Qualquer outro erro com corpo JSON continua
                    // saindo como `serverRejected` e continua sendo MOSTRADO à
                    // pessoa, que é o comportamento certo para erro de verdade.
                    if http.statusCode == 403,
                       (json["motivo"] as? String) == "premium_obrigatorio" {
                        throw AlmaError.premiumRequired(serverText)
                    }
                    throw AlmaError.serverRejected(http.statusCode, serverText)
                }
                throw AlmaError.serverError(http.statusCode)
            }
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao decodificar resposta do chat: \(error)")
            #endif
            throw AlmaError.parseFailed
        }

        guard let json = jsonObject as? [String: Any],
              let reply = json["reply"] as? String else {
            #if DEBUG
            print("OpenAIService: resposta do chat sem campo 'reply' esperado")
            #endif
            throw AlmaError.parseFailed
        }

        return reply
    }

    // MARK: - OpenAI Direct (REMOVIDO)
    // Função removida por motivos de seguranca — ver comentario no topo do ficheiro.
    // Toda a comunicacao com OpenAI passa pela Cloud Function autenticada.

    // MARK: - Text-to-Speech (via Firebase Cloud Function)

    /// Generates natural speech audio via the Alma TTS Cloud Function.
    /// Uses OpenAI's "nova" voice on the server side — no API key needed in the app.
    /// Returns raw MP3 data suitable for AVAudioPlayer.
    func generateSpeech(
        text: String,
        voice: String = "nova",
        speed: Double = 0.88
    ) async throws -> Data {
        guard let user = Auth.auth().currentUser else {
            throw AlmaError.noUser
        }

        let token: String
        do {
            token = try await user.getIDToken()
        } catch {
            throw AlmaError.tokenFailed
        }

        let ttsURL = URL(string: "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/tts")!
        var request = URLRequest(url: ttsURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "voice": voice,
            "speed": speed
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            #if DEBUG
            print("OpenAIService: falha ao serializar body do TTS: \(error)")
            #endif
            throw AlmaError.networkError(error.localizedDescription)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AlmaError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AlmaError.serverError(code)
        }

        return data
    }
}
