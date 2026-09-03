// PadraoDoExercicio.swift
// Alma — Corpo · o padrão da pessoa para um exercício: N séries × M reps × carga.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE ESTE ARQUIVO EXISTE (2026-09-03)
//
// O Assis: "quero poder definir a quantidade de séries; eu faço três séries de
// oito repetições de uma determinada quantidade de carga". Até hoje o app só
// sabia duas coisas, e nenhuma delas era essa:
//
//   · o CATÁLOGO prescreve ("4 séries · 8 reps"), e era imutável — `sets` e
//     `reps` são `let` num `Exercise` que nenhuma tela editava;
//   · o REGISTRO guarda o que aconteceu num dia (`RegistroDeSeries.swift`),
//     série a série, e de propósito não mexe no plano.
//
// Faltava a terceira: o ALVO DA PESSOA. "Meu supino é 3×8 com 60 kg" não é um
// fato sobre 3 de setembro nem uma sugestão do catálogo — é a preferência dela,
// persistente, que vem preenchida na próxima vez. É o que mora aqui.
//
// ── AS TRÊS CAMADAS, E POR QUE NÃO SE MISTURAM ────────────────────────────
//
//   catálogo  →  padrão da pessoa  →  registro do dia
//   (fixo)       (este arquivo)       (RegistroDeSeries)
//
// O padrão VENCE o catálogo na exibição e no pré-preenchimento. O registro NÃO
// altera o padrão: fugir do padrão num dia ruim é normal e não pode estragar o
// que a pessoa configurou. A única ponte é `sugestaoDeAtualizacao`, que OFERECE
// (na tela de edição, nunca no meio do treino) e jamais decide sozinha.
//
// ── COLEÇÃO PRÓPRIA, SEPARADA DE `customWorkouts` ─────────────────────────
//
// O óbvio seria pôr `seriesAlvo`/`cargaAlvoKg` dentro de `Exercise`. É a mesma
// armadilha que o `RegistroDeSeries` desviou e que o cabeçalho de
// `Exercicio.swift` documenta: `AppModel.init` decodifica `customWorkouts` com
// `try?`, e campo novo não-opcional apaga em silêncio todo treino montado. Não
// se acrescentou campo nenhum a `Exercise` — nem opcional. A asserção L1 de
// `testes_padrao.swift` decodifica um `customWorkouts` gravado ANTES desta
// mudança e prova que ele abre igual, com o canário L0 mostrando que o
// detector enxerga.
//
// Há um segundo motivo, de produto: o plano do scan é REGENERADO
// (`applyPlan` faz `customWorkouts.removeAll { $0.name.hasPrefix("Plano · ") }`).
// Padrão guardado dentro do treino morreria no próximo scan. Guardado por
// SLUG DE EXERCÍCIO, sobrevive — e vale para o supino em qualquer treino em que
// ele apareça, que é exatamente o que "meu padrão de supino" quer dizer.
//
// ── SÓ FOUNDATION ─────────────────────────────────────────────────────────
//
// `_scripts/testes_padrao.swift` compila este arquivo com `swiftc`. Um
// `import SwiftUI` aqui quebra o harness — e é essa a intenção.
// ═══════════════════════════════════════════════════════════════════════════

import Foundation

// MARK: - O padrão de um exercício

/// O que a pessoa definiu para um exercício. Cada campo é OPCIONAL e `nil`
/// significa "não defini isto — use o do catálogo". Um padrão em que os três
/// são `nil` não existe: é o mesmo que não ter padrão, e `montar` devolve `nil`.
struct PadraoDoExercicio: Codable, Equatable, Identifiable {
    /// Identidade estável — `slugDeExercicio(nome)`. É a chave da coleção.
    var exercicioSlug: String
    /// Nome exibido na hora em que foi definido, para listar sem o catálogo.
    var exercicio: String
    /// Quantas séries. `nil` = usa o do catálogo.
    var series: Int?
    /// Como o catálogo, texto livre: "8", "10-12", "30 s". `nil` = usa o do
    /// catálogo. É String porque `Exercise.reps` é String — trocar por Int aqui
    /// obrigaria a inventar uma conversão para "20 s on / 10 s off".
    var reps: String?
    /// Em kg, sempre — como no registro, para que libra seja só exibição.
    /// `nil` = sem carga-alvo (peso corporal, ou a pessoa não quis fixar).
    var cargaKg: Double?
    /// Quando foi definido pela última vez. Só para desempate e diagnóstico.
    var atualizadoEm: Date

    var id: String { exercicioSlug }

    init(exercicioSlug: String, exercicio: String, series: Int?, reps: String?,
         cargaKg: Double?, atualizadoEm: Date) {
        self.exercicioSlug = exercicioSlug
        self.exercicio = exercicio
        self.series = series
        self.reps = reps
        self.cargaKg = cargaKg
        self.atualizadoEm = atualizadoEm
    }

    private enum CodingKeys: String, CodingKey {
        case exercicioSlug, exercicio, series, reps, cargaKg, atualizadoEm
    }

    /// Decode TOLERANTE, pela mesma razão do `SerieRegistrada`: o que falta
    /// ganha um valor razoável em vez de derrubar a linha, e um build antigo
    /// lendo um campo que ainda não conhece simplesmente o ignora. A única
    /// coisa sem a qual a linha não significa nada é a identidade do exercício.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nome = try c.decodeIfPresent(String.self, forKey: .exercicio)
        let slug = try c.decodeIfPresent(String.self, forKey: .exercicioSlug)
        guard nome != nil || slug != nil else {
            throw DecodingError.keyNotFound(
                CodingKeys.exercicioSlug,
                .init(codingPath: c.codingPath, debugDescription: "padrão sem exercício"))
        }
        exercicioSlug = slug ?? slugDeExercicio(nome ?? "")
        exercicio = nome ?? slug ?? ""
        series = try c.decodeIfPresent(Int.self, forKey: .series)
        reps = try c.decodeIfPresent(String.self, forKey: .reps)
        cargaKg = try c.decodeIfPresent(Double.self, forKey: .cargaKg)
        atualizadoEm = try c.decodeIfPresent(Date.self, forKey: .atualizadoEm) ?? Date(timeIntervalSince1970: 0)
    }
}

// MARK: - As regras (puras)

enum RegrasDePadrao {

    /// Tetos de sanidade, não fisiologia. 50 séries do mesmo exercício não é
    /// treino, é dedo escorregando no teclado numérico.
    static let seriesMaximas = 50
    static let repsMaximoDeCaracteres = 24

    /// Quantas séries iguais seguidas com a mesma carga bastam para o app
    /// OFERECER a atualização do padrão. Três é o menor número que não é
    /// coincidência e não é ainda um hábito perdido.
    static let seriesParaOferecer = 3

    /// Interpreta o campo "séries". `nil` em branco ou sem sentido. Reaproveita
    /// o parser do registro — uma regra, nunca duas implementações.
    static func series(de texto: String) -> Int? {
        guard let n = RegrasDeSeries.inteiro(de: texto, teto: seriesMaximas), n >= 1 else { return nil }
        return n
    }

    /// Interpreta o campo "reps". Texto livre, como o catálogo, mas aparado e
    /// com teto de tamanho — o campo é para "8" ou "10-12", não para um bilhete.
    static func reps(de texto: String) -> String? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty, limpo.count <= repsMaximoDeCaracteres else { return nil }
        return limpo
    }

    /// Carga em kg — o mesmo parser do registro (vírgula, ponto, tetos).
    static func carga(de texto: String) -> Double? {
        RegrasDeSeries.carga(de: texto)
    }

    /// Monta o padrão a partir do que a tela tem. `nil` quando os três campos
    /// estão vazios — e aí o padrão é REMOVIDO: a pessoa voltou ao catálogo.
    static func montar(exercicio nome: String, series: Int?, reps: String?,
                       cargaKg: Double?, em data: Date = Date()) -> PadraoDoExercicio? {
        guard series != nil || reps != nil || cargaKg != nil else { return nil }
        return PadraoDoExercicio(exercicioSlug: slugDeExercicio(nome), exercicio: nome,
                                 series: series, reps: reps, cargaKg: cargaKg,
                                 atualizadoEm: data)
    }

    /// O exercício como a pessoa quer vê-lo: catálogo por baixo, padrão por
    /// cima, campo a campo. O `id` é preservado — trocá-lo faria cada `ForEach`
    /// achar que é outro exercício e reanimar a lista a cada render.
    ///
    /// `equipment`, `muscle`, `symbol` e `instructions` NUNCA vêm do padrão:
    /// aquilo é o exercício, isto é a preferência de volume.
    static func aplicar(_ padrao: PadraoDoExercicio?, em ex: Exercise) -> Exercise {
        guard let padrao else { return ex }
        let series = padrao.series.map { max(1, $0) } ?? ex.sets
        let reps = padrao.reps ?? ex.reps
        guard series != ex.sets || reps != ex.reps else { return ex }
        return Exercise(id: ex.id, name: ex.name, sets: series, reps: reps,
                        equipment: ex.equipment, muscle: ex.muscle,
                        symbol: ex.symbol, instructions: ex.instructions)
    }

    /// "3 séries · 8 reps · 60 kg" — só o que foi definido, nunca a parte que
    /// falta. Devolve `nil` quando não há padrão nenhum.
    static func resumo(_ padrao: PadraoDoExercicio?) -> String? {
        guard let padrao else { return nil }
        var partes: [String] = []
        if let s = padrao.series { partes.append(s == 1 ? "1 série" : "\(s) séries") }
        if let r = padrao.reps { partes.append(r) }
        if let kg = padrao.cargaKg { partes.append("\(RegrasDeSeries.textoDaCarga(kg)) kg") }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// O texto que já vem no campo de carga quando a sessão abre o exercício.
    /// Vazio quando não há carga-alvo — nunca se pré-preenche um número que a
    /// pessoa não escolheu.
    static func cargaPrePreenchida(_ padrao: PadraoDoExercicio?) -> String {
        guard let kg = padrao?.cargaKg else { return "" }
        return RegrasDeSeries.textoDaCarga(kg)
    }

    /// O texto que já vem no campo de reps. Só quando o alvo é um número limpo
    /// ("8"), nunca quando é faixa ("10-12") ou frase ("max reps"): o campo
    /// grava um inteiro, e pré-preencher "10" a partir de "10-12" seria o app
    /// escolhendo por ela dentro da faixa.
    static func repsPrePreenchidas(_ padrao: PadraoDoExercicio?) -> String {
        guard let r = padrao?.reps?.trimmingCharacters(in: .whitespacesAndNewlines),
              !r.isEmpty, r.allSatisfy({ $0.isNumber }) else { return "" }
        return r
    }

    /// A OFERTA — sugestão de produto do Assis, e o único ponto em que o
    /// registro toca o padrão.
    ///
    /// Devolve a carga a oferecer quando as últimas `seriesParaOferecer` séries
    /// registradas do exercício tiveram TODAS a mesma carga, e essa carga é
    /// diferente do padrão vigente. Devolve `nil` em qualquer outro caso —
    /// inclusive quando falta série, quando alguma veio sem carga, ou quando já
    /// bate com o padrão.
    ///
    /// É função PURA e devolve um número que a pessoa mesma registrou. Quem
    /// decide é ela, na tela de edição: nada aqui escreve, e nada disto aparece
    /// no meio do treino — "tente 65 kg" continua proibido (regra 3.2).
    static func sugestaoDeAtualizacao(registros: [SerieRegistrada],
                                      exercicioSlug: String,
                                      padrao: PadraoDoExercicio?) -> Double? {
        let doExercicio = registros
            .filter { $0.exercicioSlug == exercicioSlug }
            .sorted { $0.quando < $1.quando }
        guard doExercicio.count >= seriesParaOferecer else { return nil }
        let ultimas = doExercicio.suffix(seriesParaOferecer)
        let cargas = ultimas.compactMap(\.cargaKg)
        guard cargas.count == seriesParaOferecer else { return nil }
        guard let primeira = cargas.first, cargas.allSatisfy({ $0 == primeira }) else { return nil }
        guard primeira != padrao?.cargaKg else { return nil }
        return primeira
    }
}

// MARK: - Onde fica

/// A coleção no disco. `UserDefaults`, chave `padroesDeExercicio`, JSON — uma
/// lista, um padrão por slug.
///
/// ⚠️ A chave está na lista `limparDadosDoCorpo` do `LocalDataCleanupService`.
/// Sem isso, "apagar meus dados" deixaria as preferências de treino para trás.
final class PadroesDeExercicio {

    static let chave = "padroesDeExercicio"
    /// Teto de sanidade: o catálogo tem 1.095 exercícios: ninguém define padrão
    /// para mais do que existe.
    static let maximo = 1200

    private let store: UserDefaults
    private var cache: [String: PadraoDoExercicio]?

    init(store: UserDefaults = .standard) {
        self.store = store
    }

    /// Todos os padrões, indexados por slug.
    func todos() -> [String: PadraoDoExercicio] {
        if let cache { return cache }
        let lidos = store.data(forKey: Self.chave).map(Self.decodificar) ?? [:]
        cache = lidos
        return lidos
    }

    func padrao(slug: String) -> PadraoDoExercicio? {
        todos()[slug]
    }

    func padrao(paraExercicio nome: String) -> PadraoDoExercicio? {
        padrao(slug: slugDeExercicio(nome))
    }

    /// Grava (ou substitui) um padrão. É a ÚNICA porta de escrita.
    func definir(_ padrao: PadraoDoExercicio) {
        var mapa = todos()
        // Cheio: sai o mais antigo, que é o que a pessoa menos mexeu.
        if mapa[padrao.exercicioSlug] == nil, mapa.count >= Self.maximo,
           let maisAntigo = mapa.values.min(by: { $0.atualizadoEm < $1.atualizadoEm }) {
            mapa[maisAntigo.exercicioSlug] = nil
        }
        mapa[padrao.exercicioSlug] = padrao
        persistir(mapa)
    }

    /// Apaga o padrão — a pessoa voltou ao que o catálogo prescreve.
    func remover(slug: String) {
        var mapa = todos()
        guard mapa.removeValue(forKey: slug) != nil else { return }
        persistir(mapa)
    }

    private func persistir(_ mapa: [String: PadraoDoExercicio]) {
        cache = mapa
        if let d = try? Self.codificar(mapa) { store.set(d, forKey: Self.chave) }
    }

    // MARK: Codificação

    /// Lista, não dicionário: um slug ilegível como CHAVE de dicionário
    /// derrubaria o objeto inteiro. Como lista, cada linha cai sozinha.
    /// Datas em segundos desde 1970 — unívoco e sem fuso, como no registro.
    static func codificar(_ mapa: [String: PadraoDoExercicio]) throws -> Data {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return try e.encode(mapa.values.sorted { $0.exercicioSlug < $1.exercicioSlug })
    }

    /// Um padrão ilegível NÃO derruba os outros — mesma `Tolerante` do
    /// registro. Se a lista inteira não for JSON, devolve vazio, e a próxima
    /// escrita recomeça: perder uma preferência é ruim, abrir o app sem os
    /// treinos é inaceitável, e é por isso que isto vive fora do `Exercise`.
    static func decodificar(_ data: Data) -> [String: PadraoDoExercicio] {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        let itens = (try? d.decode([Tolerante<PadraoDoExercicio>].self, from: data)) ?? []
        var mapa: [String: PadraoDoExercicio] = [:]
        for p in itens.compactMap(\.valor) { mapa[p.exercicioSlug] = p }
        return mapa
    }

    private struct Tolerante<T: Decodable>: Decodable {
        let valor: T?
        init(from decoder: Decoder) {
            valor = try? T(from: decoder)
        }
    }
}
