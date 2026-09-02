// RegistroDeSeries.swift
// Alma — Corpo · repetições e carga por série, como a pessoa digitou.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE (2026-09-02)
//
// Até hoje o app só PRESCREVIA: `Exercise` tem `sets` e `reps`, e "Completar
// série" incrementava um contador. Nada do que a pessoa fez ficava em lugar
// nenhum — nem quantas repetições, nem com quanto peso. O Assis aprovou o
// registro ("gostei da ideia dos pesos"), e este arquivo é onde ele mora.
//
// ── DECISÕES JÁ TOMADAS — não reabrir ─────────────────────────────────────
//
//   · Sempre em kg. Guarda-se em kg para que libra, um dia, seja só conversão
//     de exibição.
//   · Registrar é GRÁTIS (é o diário da pessoa — régua do `CorpoAcesso`). O
//     gráfico de evolução, quando vier, é Insights, pago. O armazenamento entra
//     agora mesmo sem a tela de evolução: dado não gravado não se recupera.
//   · Nada é obrigatório. Em branco, "Completar série" funciona como sempre e
//     NADA é gravado (`montar` devolve nil) — nunca se grava valor que a pessoa
//     não viu.
//   · "Última vez: 12 reps × 60 kg" é REGISTRO e pode aparecer. "Tente 65 kg"
//     é PRESCRIÇÃO e é proibido (regra 3.2 do CLAUDE.md). Nenhuma função aqui
//     sabe sugerir nada; a única aritmética é formatar o que foi digitado.
//
// ── COLEÇÃO PRÓPRIA, SEPARADA DE `customWorkouts` ─────────────────────────
//
// O óbvio seria pôr `cargaKg` dentro de `Exercise`. É a armadilha: o
// `AppModel.init` decodifica `customWorkouts` com `try?`, e um campo novo
// não-opcional faria o decode falhar e apagar, em silêncio, todo treino que a
// pessoa montou. Além disso prescrição (o plano) e execução (o que aconteceu
// numa data) são coisas diferentes — uma série de 60 kg feita em 2 de setembro
// não muda o plano, é um fato sobre aquele dia. Por isso: uma linha por série,
// numa lista à parte, na chave `registroDeSeries` do `UserDefaults`.
//
// ── IDENTIDADE DO EXERCÍCIO ───────────────────────────────────────────────
//
// O `Exercise` gravado num treino NÃO tem id estável (`asLegacyExercise`
// descarta o slug). Por isso o slug é calculado e gravado NA ESCRITA, a partir
// do nome (`slugDeExercicio`), e é por ele que se pergunta "quando foi a última
// vez que fiz supino?". O nome também vai junto, para exibir sem depender do
// catálogo.
//
// ── SÓ FOUNDATION ─────────────────────────────────────────────────────────
//
// `_scripts/testes_series.swift` compila este arquivo com `swiftc` e prova, com
// mutação, que: o que foi digitado é o que foi gravado; em branco não grava;
// um registro corrompido não derruba os outros; e o `customWorkouts` antigo
// continua legível. Se alguém acrescentar `import SwiftUI` aqui, o harness
// para de compilar — e é essa a intenção.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

// MARK: - O que uma série mede

/// Um exercício de força conta repetições; um por tempo ("30 s", "20 min")
/// conta segundos. A tela troca o rótulo do campo conforme isto.
enum MedidaDaSerie: Equatable {
    case repeticoes
    case segundos
}

// MARK: - Uma série registrada

/// Uma série executada, exatamente como a pessoa digitou. Uma linha por série.
struct SerieRegistrada: Codable, Equatable, Identifiable {
    var id: UUID
    /// Agrupa as séries de uma mesma sessão de treino (uma abertura da tela).
    var sessao: UUID
    /// Instante em que "Completar série" foi tocado.
    var quando: Date
    /// Nome do treino ("Full Body — Força", "Meu treino").
    var treino: String
    /// Identidade estável do exercício — ver o cabeçalho.
    var exercicioSlug: String
    /// Nome exibido na hora, para mostrar sem depender do catálogo.
    var exercicio: String
    /// Série 1, 2, 3… dentro do exercício.
    var numero: Int
    /// `nil` = não informado. Só um dos dois (reps/segundos) costuma vir.
    var repeticoes: Int?
    var segundos: Int?
    /// Em kg, sempre. `nil` = não informado (peso corporal sem extra, ou em branco).
    var cargaKg: Double?

    init(id: UUID = UUID(), sessao: UUID, quando: Date, treino: String,
         exercicioSlug: String, exercicio: String, numero: Int,
         repeticoes: Int?, segundos: Int?, cargaKg: Double?) {
        self.id = id
        self.sessao = sessao
        self.quando = quando
        self.treino = treino
        self.exercicioSlug = exercicioSlug
        self.exercicio = exercicio
        self.numero = numero
        self.repeticoes = repeticoes
        self.segundos = segundos
        self.cargaKg = cargaKg
    }

    private enum CodingKeys: String, CodingKey {
        case id, sessao, quando, treino, exercicioSlug, exercicio, numero
        case repeticoes, segundos, cargaKg
    }

    /// Decode TOLERANTE, escrito à mão de propósito.
    ///
    /// O sintetizado exige toda chave não-opcional. Aqui, o que falta ganha um
    /// valor razoável em vez de derrubar a linha — e um build antigo lendo um
    /// registro gravado por um build mais novo (com campo a mais) simplesmente
    /// ignora o que não conhece. As únicas coisas sem as quais a linha não faz
    /// sentido são o instante e alguma identidade de exercício.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sessao = try c.decodeIfPresent(UUID.self, forKey: .sessao) ?? UUID()
        quando = try c.decode(Date.self, forKey: .quando)
        treino = try c.decodeIfPresent(String.self, forKey: .treino) ?? ""
        let nome = try c.decodeIfPresent(String.self, forKey: .exercicio)
        let slug = try c.decodeIfPresent(String.self, forKey: .exercicioSlug)
        guard nome != nil || slug != nil else {
            throw DecodingError.keyNotFound(
                CodingKeys.exercicioSlug,
                .init(codingPath: c.codingPath, debugDescription: "série sem exercício"))
        }
        exercicioSlug = slug ?? slugDeExercicio(nome ?? "")
        exercicio = nome ?? slug ?? ""
        numero = try c.decodeIfPresent(Int.self, forKey: .numero) ?? 1
        repeticoes = try c.decodeIfPresent(Int.self, forKey: .repeticoes)
        segundos = try c.decodeIfPresent(Int.self, forKey: .segundos)
        cargaKg = try c.decodeIfPresent(Double.self, forKey: .cargaKg)
    }
}

// MARK: - As regras (puras)

enum RegrasDeSeries {

    /// Tetos de sanidade para o que vem de um campo de texto. Não são limites
    /// fisiológicos — são o que separa "digitou errado" de "quis dizer isso".
    static let repeticoesMaximas = 999
    static let segundosMaximos = 24 * 60 * 60
    static let cargaMaximaKg = 1500.0

    /// Repetições ou segundos? Lido do que o catálogo prescreve: "30 s",
    /// "45 s cada", "60 seg", "20 min", "20 s on / 10 s off" contam tempo;
    /// "12 reps", "8-12", "10 cada", "max reps", "5 ciclos" contam repetições.
    ///
    /// Distância ("20 m") cai em repetições — não há campo de metros, e
    /// inventar um agora seria inventar um dado que nenhum dos 1.095 pede com
    /// frequência (7 exercícios).
    static func medida(paraReps reps: String) -> MedidaDaSerie {
        // dígitos, espaço opcional, unidade de tempo, fim de palavra
        let padrao = #"(?i)(^|[^0-9a-z])[0-9]+\s*(s|seg|segundos?|min|minutos?)([^a-z]|$)"#
        return reps.range(of: padrao, options: .regularExpression) != nil ? .segundos : .repeticoes
    }

    /// Peso corporal: o campo de carga nasce recolhido, com "+ peso extra" para
    /// colete, anilha ou halter. Nunca some de vez — 435 dos 1.095 exercícios
    /// são assim, e muita gente põe carga neles.
    static func ehPesoCorporal(_ equipamento: Equipment) -> Bool {
        equipamento == .corporal
    }

    /// Um inteiro não-negativo digitado, ou `nil` se em branco ou sem sentido.
    /// Aceita "12", " 12 ", "12 reps" (dígitos iniciais). Recusa negativo e o
    /// que passa do teto.
    static func inteiro(de texto: String, teto: Int = repeticoesMaximas) -> Int? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { return nil }
        let digitos = limpo.prefix { $0.isNumber }
        guard !digitos.isEmpty, let n = Int(digitos), n >= 0, n <= teto else { return nil }
        return n
    }

    /// Carga em kg digitada, ou `nil` se em branco ou sem sentido. Aceita
    /// vírgula ("12,5") e ponto ("12.5"); recusa negativo, NaN e o que passa
    /// do teto. Guarda com no máximo duas casas — meia anilha é 1,25 kg.
    static func carga(de texto: String) -> Double? {
        let limpo = texto
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !limpo.isEmpty else { return nil }
        // Só dígitos e no máximo um ponto — é ESTA linha que barra o negativo
        // (não há "-" permitido), a notação científica (`Double("1e3")`) e o
        // infinito (`Double("inf")`). Um `valor >= 0` depois dela seria
        // inalcançável — e a mutação M10 provou isso: apagá-lo não mudava nada.
        let permitido = limpo.allSatisfy { $0.isNumber || $0 == "." }
        guard permitido, limpo.filter({ $0 == "." }).count <= 1,
              let valor = Double(limpo), valor.isFinite, valor <= cargaMaximaKg
        else { return nil }
        return (valor * 100).rounded() / 100
    }

    /// Monta o registro a partir do que a tela tem. `nil` quando está tudo em
    /// branco — e aí NÃO se grava nada: "Completar série" segue como sempre.
    ///
    /// Recebe os valores já interpretados (não os textos) para que a decisão
    /// "há algo a gravar?" seja uma só, aqui, e não em cada tela.
    static func montar(sessao: UUID, quando: Date, treino: String,
                       exercicio nome: String, numero: Int,
                       repeticoes: Int?, segundos: Int?, cargaKg: Double?) -> SerieRegistrada? {
        guard repeticoes != nil || segundos != nil || cargaKg != nil else { return nil }
        return SerieRegistrada(sessao: sessao, quando: quando, treino: treino,
                               exercicioSlug: slugDeExercicio(nome), exercicio: nome,
                               numero: max(1, numero), repeticoes: repeticoes,
                               segundos: segundos, cargaKg: cargaKg)
    }

    /// "60", "12,5", "1,25" — vírgula decimal (PT-BR), sem zeros à direita.
    static func textoDaCarga(_ kg: Double) -> String {
        let arredondado = (kg * 100).rounded() / 100
        var s = String(format: "%.2f", arredondado)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",")
    }

    /// "12 reps × 60 kg" · "30 s × 10 kg" · "12 reps" · "60 kg". Só o que foi
    /// informado; nunca inventa a parte que falta.
    static func resumo(_ s: SerieRegistrada) -> String {
        var partes: [String] = []
        if let r = s.repeticoes { partes.append("\(r) reps") }
        if let t = s.segundos { partes.append("\(t) s") }
        if let kg = s.cargaKg { partes.append("\(textoDaCarga(kg)) kg") }
        return partes.joined(separator: " × ")
    }

    /// A linha que a tela mostra debaixo dos campos.
    ///
    /// Na MESMA sessão: "Série anterior: 12 reps × 60 kg". De outra sessão:
    /// "Última vez (28/08): 12 reps × 60 kg". É registro do que a pessoa fez —
    /// nunca uma sugestão do que fazer.
    static func linhaDeUltimaVez(_ ultima: SerieRegistrada, sessaoAtual: UUID,
                                 calendario: Calendar = .current) -> String {
        if ultima.sessao == sessaoAtual {
            return "Série anterior: \(resumo(ultima))"
        }
        let f = DateFormatter()
        f.calendar = calendario
        f.timeZone = calendario.timeZone
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return "Última vez (\(f.string(from: ultima.quando))): \(resumo(ultima))"
    }

    /// A série mais recente de um exercício, pelo instante — não pela posição
    /// na lista, para que uma reordenação no disco não troque a resposta.
    static func ultima(em lista: [SerieRegistrada], exercicioSlug: String) -> SerieRegistrada? {
        lista.filter { $0.exercicioSlug == exercicioSlug }.max { $0.quando < $1.quando }
    }
}

// MARK: - Onde fica

/// A coleção no disco. `UserDefaults`, chave `registroDeSeries`, JSON.
///
/// Guarda no máximo `maximo` séries — as mais antigas saem primeiro. A ~150
/// bytes por série, 4.000 são ~600 KB: um ano de quem treina quatro vezes por
/// semana com 25 séries por treino. `UserDefaults` não é lugar de megabytes.
///
/// ⚠️ A chave está na lista `limparDadosDoCorpo` do `LocalDataCleanupService`.
/// Sem isso, "apagar meus dados" deixaria o histórico de treino para trás — é
/// dado da pessoa como qualquer outro (asserção B9e da auditoria).
final class RegistroDeSeries {

    static let chave = "registroDeSeries"
    static let maximo = 4000

    private let store: UserDefaults
    private var cache: [SerieRegistrada]?

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    /// Todas as séries gravadas, na ordem em que foram gravadas.
    func todas() -> [SerieRegistrada] {
        if let cache { return cache }
        let lidas = store.data(forKey: Self.chave).map(Self.decodificar) ?? []
        cache = lidas
        return lidas
    }

    /// Grava uma série. É a ÚNICA porta de escrita.
    func registrar(_ serie: SerieRegistrada) {
        var lista = todas()
        lista.append(serie)
        if lista.count > Self.maximo { lista.removeFirst(lista.count - Self.maximo) }
        cache = lista
        if let d = try? Self.codificar(lista) { store.set(d, forKey: Self.chave) }
    }

    func ultima(exercicioSlug: String) -> SerieRegistrada? {
        RegrasDeSeries.ultima(em: todas(), exercicioSlug: exercicioSlug)
    }

    func daSessao(_ sessao: UUID) -> [SerieRegistrada] {
        todas().filter { $0.sessao == sessao }
    }

    // MARK: Codificação

    /// Datas como segundos desde 1970 — unívoco e sem fuso. (O Android grava
    /// milissegundos; um importador que um dia leia o outro lado converte.)
    static func codificar(_ lista: [SerieRegistrada]) throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return try e.encode(lista)
    }

    /// Um registro ilegível NÃO derruba os outros. `Tolerante` engole o erro
    /// de cada elemento; o que sobra é o que dava para ler. Se a lista inteira
    /// não for JSON, devolve vazio — e a próxima escrita recomeça do zero.
    static func decodificar(_ data: Data) -> [SerieRegistrada] {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        let itens = (try? d.decode([Tolerante<SerieRegistrada>].self, from: data)) ?? []
        return itens.compactMap(\.valor)
    }

    private struct Tolerante<T: Decodable>: Decodable {
        let valor: T?
        init(from decoder: Decoder) {
            valor = try? T(from: decoder)
        }
    }
}
