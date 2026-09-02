// FotoDoExercicio.swift
// Alma — Corpo · a figura do exercício, recortada, sobre o card do tema.
//
// ═══════════════════════════════════════════════════════════════════════════
// LICENÇA — LEIA ANTES DE MEXER NESTAS IMAGENS
// ═══════════════════════════════════════════════════════════════════════════
// As fotos vêm do **RepDB** (https://repdb.co), free tier, pacote
// `@repdb/exercises`. O que a licença permite e proíbe, em texto:
//
//  • termo 2 — ATRIBUIÇÃO OBRIGATÓRIA, como link visível. Está na tela de
//    Ajustes (`SettingsView.swift`), ao lado de "Termos de uso", com a string
//    exata que a licença exige: "Exercise data by RepDB (repdb.co)". Em inglês
//    de propósito — traduzir deixa de ser o texto exigido.
//
//  • termo 3 — PROIBIDO republicar o acervo como dataset, repositório ou API.
//    É por isso que estes arquivos moram NO BUNDLE e não numa URL pública,
//    como o catálogo faz hoje com `raw.githubusercontent.com`. Servir imagem
//    individual ao usuário do app é permitido; deixar o acervo baixável em
//    bloco não é. **Nada de hotlink, nada de subir a pasta num repo público.**
//
//  • termo 4 — redimensionar, cortar, recolorir e REMOVER O FUNDO é permitido,
//    e a remoção de fundo está citada por escrito. As imagens daqui já vêm
//    chaveadas (fundo azul removido, alfa) e reenquadradas na figura.
//
//  • termo 5 — ⛔ **PROIBIDO usar estas imagens como entrada de modelo
//    generativo.** Sem img2img, sem upscaler neural, sem remoção de fundo por
//    IA, sem "melhorar com IA". A chave de fundo usada na preparação é
//    aritmética pura sobre o pixel; nenhum modelo entra no caminho. Violar o
//    termo 5 contamina o resultado como dataset derivado sob o termo 3 — ou
//    seja, um upscale distraído transforma a pasta inteira em infração.
//
// ═══════════════════════════════════════════════════════════════════════════
// POR QUE FIGURA RECORTADA E NÃO O QUADRO ORIGINAL
// ═══════════════════════════════════════════════════════════════════════════
// O RepDB entrega a figura sobre fundo azul, num quadro de 512². Duas medidas
// decidiram o desenho:
//
//  1. **O azul quebra no modo escuro** — e o app tem modo escuro. "Azul
//     melhorado" exigiria a mesma máscara que o recorte exige, então não
//     economiza etapa nenhuma.
//  2. **A figura ocupava de 7,7% a 51% da área do quadro** (mediana 21%): a
//     flexão de braço tinha 254 px de vazio em cima. Reenquadrar na caixa do
//     conteúdo levou a mediana a 36,9% — a figura aparece ~1,6× maior no mesmo
//     espaço de tela, de graça.
//
// O recorte ANCORA na borda em que o cenário sangra (parede do wall sit, chão).
// Sem isso, um corte centrado transformaria a parede numa laje solta no meio da
// imagem. 73 das 1.056 precisaram de âncora.
//
// ═══════════════════════════════════════════════════════════════════════════
// COBERTURA — 514 dos 1.095 têm foto, e isso NÃO é regressão
// ═══════════════════════════════════════════════════════════════════════════
// Só as faixas A_EXATO e B_EQUIVALENTE do `MAPA_SEMANTICO.csv` receberam
// imagem. As 320 de C_REVISAR esperam olho humano; as 261 órfãs não têm
// correspondente no RepDB e ficam exatamente como estavam. Quem não tem foto
// continua desenhando `ExerciseMuscleThumb`, o corpo anatômico — que é o que
// TODOS desenhavam até aqui. O piso é zero: nada regride.

import SwiftUI

// MARK: - Acervo (cache em memória)

/// Carrega e guarda as fotos do bundle. `NSCache` porque ele solta sozinho sob
/// pressão de memória — a lista tem 1.095 linhas e o usuário rola tudo.
final class AcervoDeFotosDeExercicio {

    static let compartilhado = AcervoDeFotosDeExercicio()

    /// Nome da pasta dentro do bundle. É uma **referência de pasta** no Xcode
    /// (folder reference / pasta azul), não um grupo: os 594 arquivos entram
    /// com uma linha no `project.pbxproj` em vez de 594.
    static let pasta = "ExerciciosFotos"

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // ~594 arquivos, ~9,8 MB em disco. Descomprimidos cabem muito mais que
        // isso na RAM, então o teto é por contagem e não por bytes.
        cache.countLimit = 120
    }

    /// Só o que já está em memória — usado para desenhar sem piscar quando a
    /// pessoa volta para uma tela que já viu.
    func emCache(_ nome: String) -> UIImage? {
        cache.object(forKey: nome as NSString)
    }

    /// Decodifica fora da main thread. Devolve `nil` quando o arquivo não está
    /// no bundle — o chamador cai no corpo anatômico, nunca num quadro vazio.
    func carregar(_ nome: String) async -> UIImage? {
        if let pronta = emCache(nome) { return pronta }
        let imagem = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let url = Self.urlNoBundle(nome),
                  let dados = try? Data(contentsOf: url),
                  let img = UIImage(data: dados) else { return nil }
            return img
        }.value
        if let imagem { cache.setObject(imagem, forKey: nome as NSString) }
        return imagem
    }

    /// `nome` chega com extensão ("flexao-start.webp"); `url(forResource:)`
    /// quer as duas partes separadas.
    static func urlNoBundle(_ nome: String) -> URL? {
        let base = (nome as NSString).deletingPathExtension
        let ext = (nome as NSString).pathExtension
        return Bundle.main.url(forResource: base,
                               withExtension: ext.isEmpty ? nil : ext,
                               subdirectory: pasta)
    }

    /// Usado pelo smoke test e pela auditoria: quantos arquivos do catálogo
    /// realmente existem no bundle. Um catálogo que aponta para arquivo
    /// inexistente desenha o corpo anatômico e não avisa ninguém.
    static func conferirBundle(_ catalogo: [ExerciseV2]) -> (esperados: Int, presentes: Int, faltando: [String]) {
        let nomes = catalogo.compactMap(\.fotos).flatMap { $0 }
        let unicos = Array(Set(nomes)).sorted()
        let faltando = unicos.filter { urlNoBundle($0) == nil }
        return (unicos.count, unicos.count - faltando.count, faltando)
    }
}

// MARK: - Qual foto usar

extension ExerciseV2 {
    /// A foto que representa o exercício numa miniatura só. As fotos vêm em
    /// ordem cronológica (início, pico); o **pico** é a posição que identifica
    /// o movimento — "início" de metade dos exercícios é gente em pé.
    var fotoDeCapa: String? { fotos?.last }

    /// As duas pontas do movimento, quando existem as duas.
    var fotoDeInicioEPico: (inicio: String, pico: String)? {
        guard let f = fotos, f.count >= 2 else { return nil }
        return (f[0], f[f.count - 1])
    }

    var temFoto: Bool { !(fotos ?? []).isEmpty }
}

// MARK: - Views

/// Desenha uma foto do acervo. Enquanto decodifica (ou se o arquivo não
/// existir), mostra `reserva` — nunca um retângulo vazio.
struct FotoDoExercicioView<Reserva: View>: View {
    let nome: String
    @ViewBuilder var reserva: () -> Reserva

    @State private var imagem: UIImage?
    @State private var tentou = false

    init(nome: String, @ViewBuilder reserva: @escaping () -> Reserva) {
        self.nome = nome
        self.reserva = reserva
        // Cache quente = desenha no primeiro frame, sem piscar a reserva.
        _imagem = State(initialValue: AcervoDeFotosDeExercicio.compartilhado.emCache(nome))
    }

    var body: some View {
        Group {
            if let imagem {
                Image(uiImage: imagem)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .accessibilityHidden(true)   // o nome do exercício já é lido ao lado
            } else {
                reserva()
            }
        }
        .task(id: nome) {
            guard imagem == nil, !tentou else { return }
            tentou = true
            imagem = await AcervoDeFotosDeExercicio.compartilhado.carregar(nome)
        }
    }
}

/// O slot visual de um exercício: foto quando existe, corpo anatômico quando
/// não. É o **único** ponto de decisão — as três superfícies que mostram
/// exercício (linha da lista, herói do detalhe, construtor de treino) chamam
/// isto e não repetem o `if`.
struct FiguraDoExercicio: View {
    let exercise: ExerciseV2

    var body: some View {
        if let nome = exercise.fotoDeCapa {
            FotoDoExercicioView(nome: nome) { ExerciseMuscleThumb(exercise: exercise) }
        } else {
            ExerciseMuscleThumb(exercise: exercise)
        }
    }
}

/// A figura de um exercício LEGADO (`Exercise`, o de 7 campos — formato
/// persistido dos treinos salvos e dos programas prontos).
///
/// **O vínculo é calculado, nunca gravado.** O `Exercise` não carrega id, e
/// acrescentar campo a ele é o defeito que já apagou treino de gente neste
/// projeto: `AppModel.init` decodifica `customWorkouts` com `try?`, então um
/// campo novo não-opcional vira `keyNotFound` engolido e "Meus treinos" abre
/// vazio, sem mensagem. Por isso a foto é resolvida pelo slug do nome, em tempo
/// de desenho, contra o catálogo do bundle — nada muda de formato no disco.
///
/// Quando o nome não casa com nenhum dos 1.095, ou casa com um dos 581 sem
/// foto, desenha o SF Symbol de sempre. O piso é o que já existia.
struct FiguraDeExercicioLegado: View {
    let exercise: Exercise
    var tint: Color = Theme.primary
    var tamanhoDoSimbolo: CGFloat = 24

    private var fotoDeCapa: String? {
        ExerciseCatalog.resolve(legacy: exercise).fotoDeCapa
    }

    var body: some View {
        if let nome = fotoDeCapa {
            FotoDoExercicioView(nome: nome) { simbolo }
        } else {
            simbolo
        }
    }

    private var simbolo: some View {
        Image(systemName: exercise.symbol)
            .font(.system(size: tamanhoDoSimbolo))
            .foregroundStyle(tint)
    }
}

/// As duas pontas do movimento, lado a lado, no detalhe. Estático de propósito:
/// nada de timer nem de cross-fade — o que a captura de tela mostra é o que a
/// pessoa vê, e uma prova visual de algo que pisca não prova nada.
struct InicioEPicoView: View {
    let exercise: ExerciseV2

    var body: some View {
        if let par = exercise.fotoDeInicioEPico {
            VStack(alignment: .leading, spacing: 10) {
                Text("O movimento")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    quadro(par.inicio, legenda: "Início")
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.inkSoft)
                    quadro(par.pico, legenda: "Pico")
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func quadro(_ nome: String, legenda: String) -> some View {
        VStack(spacing: 6) {
            FotoDoExercicioView(nome: nome) { Color.clear }
                .frame(height: 132)
                .frame(maxWidth: .infinity)
                .background(Theme.inkSoft.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(legenda)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
        }
    }
}
