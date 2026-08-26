// AnaliseDeFotoService.swift
// Cliente da Cloud Function `analisarFoto` — análise de corpo e de comida.
//
// ═══════════════════════════════════════════════════════════════════════════
// DUAS DECISÕES DE DESENHO QUE VALE LER ANTES DE MEXER
//
// 1. A CHAVE NÃO ESTÁ AQUI. Este arquivo fala com a nossa Cloud Function, que
//    fala com a OpenAI. A implementação antiga (`GeminiService`) chamava o
//    provedor direto, com a chave no `GoogleService-Info.plist` — qualquer
//    pessoa descompactava o IPA e usava a cota. Mesmo caminho do chat:
//    URLRequest + `Bearer <Firebase ID token>`.
//
// 2. A IA LÊ A FOTO. A MATEMÁTICA DO PLANO CONTINUA NO APARELHO.
//    A versão antiga pedia ao modelo o plano inteiro — calorias, macros,
//    refeições e a semana de treino. Isso é PRESCRIÇÃO, e a regra 3.2 do
//    CLAUDE.md proíbe: a Alma acolhe e encaminha, não prescreve exercício,
//    alimento nem dieta. Além disso, número vindo de modelo de linguagem varia
//    entre chamadas — a mesma pessoa receberia metas diferentes a cada scan.
//
//    Agora a divisão é: a IA faz o que só ela faz (olhar a foto e estimar
//    composição corporal); Mifflin-St Jeor, determinístico e já testado, faz o
//    que já sabia fazer. O scan fica mais barato, mais estável e dentro da regra.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation
import UIKit
import FirebaseAuth

// MARK: - Erros honestos

/// Toda falha vira UMA DESTAS e chega à tela como frase. Nenhuma delas pode
/// virar número — foi exatamente esse o bug B8 (o app caía no cálculo local e
/// mostrava o resultado como se a IA tivesse analisado a foto).
enum ErroDaAnalise: LocalizedError, Equatable {
    case semSessao
    case semConsentimento
    case fotoIlegivel(String)
    case limiteDiario(String)
    case indisponivel(String)

    var errorDescription: String? {
        switch self {
        case .semSessao:
            return "Entre na sua conta para usar a análise por foto."
        case .semConsentimento:
            return "A análise só acontece depois que você autoriza o envio."
        case .fotoIlegivel(let m), .limiteDiario(let m), .indisponivel(let m):
            return m
        }
    }
}

// MARK: - Respostas do servidor

private struct RespostaCorpo: Decodable {
    let legivel: Bool
    let motivo: String?
    let somatotipo: String?
    let gorduraEstimada: Double?
    let resumo: String?
    let observacoes: [String]
    let focos: [String]
}

/// [2026-08-12] Um alimento dentro do prato, como a IA o viu.
struct ComponenteDoPrato: Decodable, Equatable {
    let nome: String
    let porcaoG: Double
    let kcalPor100: Double
    let proteinaPor100: Double
    let carboPor100: Double
    let gorduraPor100: Double

    /// O componente do jeito que o diário guarda.
    ///
    /// Sempre `.grama`: a IA estima peso a partir de uma foto, e a resposta do
    /// servidor fala em gramas (`porcaoG`) nos dois níveis. Um copo de suco na
    /// foto sai daqui em grama, e isso é uma limitação REAL desta versão —
    /// dita aqui em vez de disfarçada com um palpite pelo nome do componente,
    /// que é a adivinhação que `Unidade` recusa por escrito.
    var comoComponenteDaRefeicao: ComponenteDaRefeicao {
        ComponenteDaRefeicao(
            nome: nome,
            quantidade: max(1, Int(porcaoG.rounded())),
            unidade: .grama,
            kcalPor100: Int(kcalPor100.rounded()),
            proteinaPor100: Int(proteinaPor100.rounded()),
            carboPor100: Int(carboPor100.rounded()),
            gorduraPor100: Int(gorduraPor100.rounded()))
    }
}

struct AnaliseDePrato: Decodable, Equatable {
    let nome: String
    let porcaoG: Double
    let kcalPor100: Double
    let proteinaPor100: Double
    let carboPor100: Double
    let gorduraPor100: Double
    /// `nil` = o servidor não mandou decomposição, ou mandou e ela não passou na
    /// conferência dele. O prato inteiro continua valendo — ver `analisarPrato`.
    var componentes: [ComponenteDoPrato]? = nil
}

private struct RespostaPrato: Decodable {
    let legivel: Bool
    let motivo: String?
    let nome: String?
    let porcaoG: Double?
    let kcalPor100: Double?
    let proteinaPor100: Double?
    let carboPor100: Double?
    let gorduraPor100: Double?
    /// Campo novo do servidor. Opcional aqui de propósito: uma função mais
    /// velha que ainda não devolva a chave continua sendo decodificada.
    let componentes: [ComponenteDoPrato]?
}

private struct EnvelopeFalha: Decodable {
    let ok: Bool
    let motivo: String?
    let mensagem: String?
}

// MARK: - Serviço

enum AnaliseDeFotoService {

    static let endpoint = URL(string:
        "https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/analisarFoto")!

    /// Redimensiona antes de enviar: menos dado saindo do aparelho, menos custo,
    /// menos tempo. 1280 px no maior lado é suficiente para o modelo.
    static let ladoMaximo: CGFloat = 1280

    // MARK: Corpo

    static func analisarCorpo(input: ScanInput, consentimento: Bool) async throws -> ScanResult {
        guard consentimento else { throw ErroDaAnalise.semConsentimento }

        // Redimensiona e reencoda ANTES de virar base64 — ver `jpegParaEnvio`.
        var fotos: [String] = []
        for original in [input.frontPhoto, input.sidePhoto].compactMap({ $0 }) {
            guard let pronta = Self.jpegParaEnvio(original) else {
                throw ErroDaAnalise.fotoIlegivel(
                    "Não consegui preparar essa foto. Tente escolher outra imagem.")
            }
            fotos.append(pronta.base64EncodedString())
        }
        guard !fotos.isEmpty else {
            throw ErroDaAnalise.fotoIlegivel("Adicione ao menos uma foto para a análise.")
        }

        let medidas: [String: Any] = [
            "pesoKg": input.weightKg,
            "alturaCm": input.heightCm,
            "idade": input.ageYears,
            "objetivo": input.goal
        ]

        let dados = try await chamar(tipo: "corpo", fotos: fotos,
                                     medidas: medidas, consentimento: consentimento)
        let r = try decodificar(RespostaCorpo.self, de: dados)

        // ═══════════════════════════════════════════════════════════════════
        // [2026-08-05] A GUARDA EXIGE A LEITURA DA FOTO INTEIRA, não só a gordura.
        //
        // Antes exigia `legivel` + `gorduraEstimada`, e os outros campos caíam
        // para o `MockAIPlanService` quando vinham vazios. O somatotipo e o
        // resumo SÃO a leitura da foto — é o que só a IA faz. Se ela não os
        // entrega, a análise por foto não aconteceu, e devolver um resultado
        // completo com esses campos preenchidos por heurística local é
        // apresentar cálculo de medidas como se fosse leitura de imagem.
        //
        // Isto é o mesmo erro do B8, um nível abaixo: lá o app inteiro caía no
        // cálculo local; aqui caíam três campos, em silêncio e sem banner,
        // porque `isAIGenerated` continuava `true`.
        //
        // ── EMENDA [2026-08-12] — O QUE ESTAVA CERTO E O QUE CUSTOU CARO ────
        //
        // O princípio acima continua valendo e não foi afrouxado: NADA vindo do
        // `MockAIPlanService` entra num resultado rotulado como análise por foto.
        //
        // O erro foi de EXECUÇÃO, e ele quebrou o recurso em produção. A guarda
        // tratou `somatotipo` — um RÓTULO — como se fosse a leitura da foto, no
        // mesmo nível da gordura e do resumo. E o esquema do servidor permitia
        // `null` naquele campo enquanto a instrução nunca o pedia, então o
        // modelo devolvia `null` sempre. Resultado: `Somatotype.init(rawValue:)`
        // dava `nil`, e a pessoa perdia gordura, resumo, observações e focos —
        // tudo que a IA tinha entregue de verdade — por causa de uma palavra.
        // Quatro tentativas do Assis em 12/08, quatro telas de erro, quatro
        // scans queimados do limite diário.
        //
        // A distinção que faltava, e que agora é explícita aqui:
        //   • `gorduraEstimada` e `resumo` SUSTENTAM a análise → sem eles não
        //     houve leitura, e recusar é honesto.
        //   • `somatotipo` DESCREVE a análise → sem ele a leitura aconteceu do
        //     mesmo jeito, e derrubá-la é perder informação boa por nada.
        //
        // Ausência de rótulo agora esconde o rótulo (`BodyAnalysis.somatotype`
        // é opcional e `ScanResultView` omite a linha). O que continua proibido
        // — e é o coração do B8 — é PREENCHER o rótulo com heurística local e
        // exibi-lo como se a foto tivesse sido lida. Por isso `nil`, nunca um
        // valor de reserva. O lint H-W4 mudou junto, de propósito: ele passou a
        // prender este invariante em vez da linha antiga.
        // ═══════════════════════════════════════════════════════════════════
        guard r.legivel, let gordura = r.gorduraEstimada else {
            throw ErroDaAnalise.fotoIlegivel(
                r.motivo ?? "Não consegui ler essa foto o suficiente para estimar.")
        }
        let resumoLimpo = r.resumo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resumoLimpo.isEmpty else {
            throw ErroDaAnalise.indisponivel(
                "A análise da foto voltou incompleta. Tente de novo em alguns minutos.")
        }
        let resumo = resumoLimpo
        // Vem da IA ou não vem. `nil` é resposta válida e some da tela.
        let somatotipo = Self.somatotipoDaIA(r.somatotipo)

        // A IA entrega a leitura da foto. O plano NUMÉRICO sai do cálculo
        // local, alimentado pela gordura que a IA estimou em vez da informada —
        // e a tela diz isso, no `notes` logo abaixo.
        //
        // [2026-08-26] Até hoje esta frase era falsa. O `notes` era escrito aqui
        // e NENHUMA view o renderizava — a auditoria pegou o comentário
        // descrevendo comportamento inexistente. Quem renderiza agora:
        // `ScanResultView.rodapeDeHonestidade`. Se alguém remover aquele
        // rodapé, esta frase volta a mentir.
        //
        // O `base` serve SÓ para os números do plano. Nenhum texto dele
        // atravessa para cá: o `MockAIPlanService` escreve para a tela do
        // caminho SEM IA ("sem análise de fotos", "adicione foto de frente e de
        // lado") e essas frases, numa tela de resultado com foto analisada,
        // mandam a pessoa fazer o que ela acabou de fazer.
        let comGorduraDaIA = ScanInput(
            weightKg: input.weightKg, heightCm: input.heightCm,
            ageYears: input.ageYears, bodyFat: gordura,
            goal: input.goal, frontPhoto: nil, sidePhoto: nil)
        let base = try await MockAIPlanService().analyze(comGorduraDaIA)

        let analise = BodyAnalysis(
            somatotype: somatotipo,
            estimatedBodyFat: gordura,
            summary: resumo,
            observations: r.observacoes.isEmpty ? Self.observacoesPadraoDaIA : r.observacoes,
            focusAreas: r.focos.isEmpty ? Self.focosPadraoDaIA : r.focos
        )

        let plano = GeneratedPlan(
            dailyKcal: base.plan.dailyKcal, proteinG: base.plan.proteinG,
            carbsG: base.plan.carbsG, fatG: base.plan.fatG,
            meals: base.plan.meals, week: base.plan.week,
            notes: "As metas de calorias e macros são calculadas no seu aparelho "
                 + "a partir das suas medidas e da estimativa da análise. "
                 + "Ajuste conforme fome e energia, e reavalie a cada 2–4 semanas."
        )

        return ScanResult(analysis: analise, plan: plano, isAIGenerated: true)
    }

    /// Textos de reserva DO CAMINHO DE IA. Existem para que nenhum campo vazio
    /// da resposta puxe frase do `MockAIPlanService`, que fala para a outra
    /// tela. São verdadeiros nos dois casos: a foto foi analisada e o plano é
    /// estimativa.
    ///
    /// Asserção C1 exige que nenhuma delas cite foto ausente — é a frase que
    /// vazava e que mandava a pessoa anexar a foto que ela já tinha anexado.
    static let observacoesPadraoDaIA = [
        "Estimativa a partir da foto e das suas medidas.",
        "Reavalie a cada 2–4 semanas, com a mesma luz e o mesmo enquadramento."
    ]

    static let focosPadraoDaIA = ["Constância", "Composição corporal"]

    /// Traz o rótulo para a grafia que o app conhece, ou devolve `nil`.
    ///
    /// O servidor já normaliza e o esquema já fecha o `enum` — isto aqui é a
    /// terceira camada, para o caso de um servidor mais velho, um modelo trocado
    /// ou alguém afrouxando o esquema. Reconhecer "mesomorfo" em minúscula e
    /// mostrar o rótulo é melhor que escondê-lo por causa de uma letra.
    ///
    /// NÃO INVENTA: sem radical reconhecível, devolve `nil` e a tela omite a
    /// linha. Chutar um tipo aqui seria o B8 de novo, agora com três camadas
    /// de código dando cobertura ao chute.
    static func somatotipoDaIA(_ bruto: String?) -> Somatotype? {
        guard let bruto else { return nil }
        let limpo = bruto.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                  locale: Locale(identifier: "pt_BR"))
        // Composto: vale o PRIMEIRO citado. Regra arbitrária e casada com a do
        // servidor (`normalizarSomatotipo`) de propósito — as duas mudam juntas
        // ou nenhuma muda. Ver a nota lá sobre por que não é a convenção clássica.
        var melhor: (tipo: Somatotype, posicao: String.Index)?
        for tipo in [Somatotype.ectomorfo, .mesomorfo, .endomorfo] {
            let radical = String(tipo.rawValue.prefix(4))
                .folding(options: [.diacriticInsensitive, .caseInsensitive],
                         locale: Locale(identifier: "pt_BR"))
            if let faixa = limpo.range(of: radical),
               melhor == nil || faixa.lowerBound < melhor!.posicao {
                melhor = (tipo, faixa.lowerBound)
            }
        }
        return melhor?.tipo
    }

    /// Reduz a foto para `ladoMaximo` no maior lado e devolve JPEG.
    ///
    /// ═══════════════════════════════════════════════════════════════════════
    /// [2026-08-12] ISTO NÃO EXISTIA. `ladoMaximo` estava declarado desde 05/08
    /// e NUNCA era usado — o comentário do topo prometia "redimensiona antes de
    /// enviar" e nada redimensionava. Dois efeitos reais:
    ///
    ///   1. Foto da galeria sai do `PhotosPicker` no formato original. No iPhone
    ///      isso costuma ser HEIC, e o servidor rotula tudo como
    ///      `data:image/jpeg;base64,` sem olhar os bytes. Reencodar aqui elimina
    ///      a divergência entre o rótulo e o conteúdo, em vez de contar com o
    ///      provedor farejar o formato.
    ///   2. Uma foto de 12 MP passa fácil de 3 MB e infla mais um terço em
    ///      base64 — perto do teto de 4 MB por foto do servidor, que responde
    ///      "Foto muito grande" quando estoura.
    ///
    /// E não custa qualidade: com `detail: "high"` a OpenAI reduz a imagem para
    /// caber em 2048×2048 e depois põe o lado MENOR em 768 px. Uma foto de
    /// 3024×4032 e uma de 960×1280 chegam ao modelo como a mesma imagem de
    /// 768×1024. O que se corta aqui é upload, latência e custo — não detalhe.
    /// ═══════════════════════════════════════════════════════════════════════
    static func jpegParaEnvio(_ dados: Data) -> Data? {
        guard let imagem = UIImage(data: dados) else { return nil }
        let lado = max(imagem.size.width, imagem.size.height)
        // Já pequena: só reencoda para garantir que é JPEG de verdade.
        let escala = lado > ladoMaximo ? ladoMaximo / lado : 1
        let tamanho = CGSize(width: (imagem.size.width * escala).rounded(),
                             height: (imagem.size.height * escala).rounded())
        // `UIGraphicsImageRendererFormat()` e não `.default()`: o `.default()`
        // está depreciado desde o iOS 11 E lê os traits da tela principal, o que
        // dispara o Main Thread Checker — esta função roda fora da main thread,
        // dentro do `Task` da view.
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1                      // pontos = pixels, sem 2x/3x surpresa
        formato.opaque = true
        return UIGraphicsImageRenderer(size: tamanho, format: formato)
            .image { _ in imagem.draw(in: CGRect(origin: .zero, size: tamanho)) }
            .jpegData(compressionQuality: 0.85)
    }

    // MARK: Comida

    /// [2026-08-12] `descricao` é o texto opcional que a pessoa escreve antes de
    /// analisar — "mix de frutas com iogurte, mel e aveia".
    ///
    /// Ele viaja como DADO e o servidor o trata como dado (bloco delimitado,
    /// instrução `system` dizendo que ali não há ordens, esquema estrito na
    /// volta). Ver o bloco longo em `functions/src/analiseDeFoto.ts`. Aqui só
    /// passa pela limpeza de interface do `TextoDaPessoa`, que existe para o
    /// que a tela mostra ser o que de fato é enviado — não como defesa.
    static func analisarPrato(foto: Data, descricao: String = "",
                              consentimento: Bool) async throws -> AnaliseDePrato {
        guard consentimento else { throw ErroDaAnalise.semConsentimento }

        guard let pronta = Self.jpegParaEnvio(foto) else {
            throw ErroDaAnalise.fotoIlegivel(
                "Não consegui preparar essa foto. Tente escolher outra imagem.")
        }
        let dados = try await chamar(tipo: "comida", fotos: [pronta.base64EncodedString()],
                                     medidas: nil,
                                     contexto: TextoDaPessoa.descricaoParaEnvio(descricao),
                                     consentimento: consentimento)
        let r = try decodificar(RespostaPrato.self, de: dados)

        guard r.legivel,
              let nome = r.nome, let kcal = r.kcalPor100,
              let p = r.proteinaPor100, let c = r.carboPor100, let g = r.gorduraPor100 else {
            throw ErroDaAnalise.fotoIlegivel(
                r.motivo ?? "Não consegui identificar a comida nessa foto.")
        }

        // Menos de dois componentes não é decomposição: é o prato inteiro com
        // outro nome. O servidor já filtra assim (`sanitizarComponentes`); a
        // mesma regra aqui evita depender de uma função mais velha ter feito.
        let componentes = (r.componentes?.count ?? 0) >= 2 ? r.componentes : nil

        return AnaliseDePrato(nome: nome, porcaoG: r.porcaoG ?? 100,
                              kcalPor100: kcal, proteinaPor100: p,
                              carboPor100: c, gorduraPor100: g,
                              componentes: componentes)
    }

    // MARK: Transporte

    private static func chamar(tipo: String, fotos: [String],
                               medidas: [String: Any]?, contexto: String? = nil,
                               consentimento: Bool) async throws -> Data {
        guard let user = Auth.auth().currentUser else { throw ErroDaAnalise.semSessao }
        let token: String
        do { token = try await user.getIDToken() }
        catch { throw ErroDaAnalise.semSessao }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Visão é mais lenta que texto: o chat usa 30 s, aqui 90 s.
        req.timeoutInterval = 90

        var corpo: [String: Any] = ["tipo": tipo, "fotos": fotos,
                                    "consentimento": consentimento]
        if let medidas { corpo["medidas"] = medidas }
        // Sem descrição, a chave não existe — e o servidor monta o pedido de
        // sempre. Ver `TextoDaPessoa.descricaoParaEnvio` sobre por que `nil` e
        // não string vazia.
        if let contexto { corpo["contexto"] = contexto }
        req.httpBody = try JSONSerialization.data(withJSONObject: corpo)

        let (data, resposta): (Data, URLResponse)
        do { (data, resposta) = try await URLSession.shared.data(for: req) }
        catch {
            throw ErroDaAnalise.indisponivel(
                "Não consegui falar com a análise agora. Verifique sua conexão e tente de novo.")
        }

        let codigo = (resposta as? HTTPURLResponse)?.statusCode ?? 0
        let envelope = try? JSONDecoder().decode(EnvelopeFalha.self, from: data)

        if envelope?.ok == false || !(200..<300).contains(codigo) {
            let msg = envelope?.mensagem
                ?? "Não consegui analisar sua foto agora. Tente de novo em alguns minutos."
            switch envelope?.motivo {
            case "foto_ilegivel", "foto_nao_e_do_tipo": throw ErroDaAnalise.fotoIlegivel(msg)
            case "limite_diario":                        throw ErroDaAnalise.limiteDiario(msg)
            default:                                     throw ErroDaAnalise.indisponivel(msg)
            }
        }
        return data
    }

    private static func decodificar<T: Decodable>(_ tipo: T.Type, de dados: Data) throws -> T {
        do {
            return try JSONDecoder().decode(EnvelopeOK<T>.self, from: dados).resultado
        } catch {
            throw ErroDaAnalise.indisponivel("A análise voltou incompleta. Tente de novo.")
        }
    }
}

/// `{ "ok": true, "resultado": { … } }` — o formato que a função devolve.
/// Fora do `enum` porque Swift não aceita tipo genérico aninhado em função.
private struct EnvelopeOK<U: Decodable>: Decodable {
    let ok: Bool
    let resultado: U
}

// MARK: - Ponte com o protocolo existente

/// Substitui `GeminiAIPlanService`. Guarda o consentimento daquele envio —
/// sem ele o serviço recusa antes de tocar na rede, e o servidor recusa de novo.
struct NuvemAIPlanService: AIPlanService {
    let consentimento: Bool

    func analyze(_ input: ScanInput) async throws -> ScanResult {
        try await AnaliseDeFotoService.analisarCorpo(input: input,
                                                     consentimento: consentimento)
    }
}
