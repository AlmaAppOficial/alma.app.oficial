// QuebraDeJejumView.swift
// Alma — Corpo · a tela da refeição que quebra o jejum.
//
// ═══════════════════════════════════════════════════════════════════════════
// O QUE ESTA TELA FAZ QUE AS OUTRAS NÃO FAZEM
//
// Ela é o ponto em que o módulo de jejum encontra a Dieta que já existia: a
// sugestão daqui vira `Meal` de verdade, pela mesma porta que o scan de comida
// usa (`AppModel.registrarPrato`), com os mesmos `ComponenteDaRefeicao`
// editáveis depois pela `MealDetailView`. Não há diário paralelo, não há
// caloria que só o jejum conhece.
//
// ═══════════════════════════════════════════════════════════════════════════
// TRÊS COISAS QUE ESTA TELA É OBRIGADA A DIZER
//
// 1. **De onde veio o orçamento calórico.** Se veio da meta da pessoa, diz. Se
//    veio de um padrão porque não há medidas, diz isso também, com todas as
//    letras. É a mesma régua do `metaEhEstimada`: número sem origem declarada é
//    número que finge ser cálculo pessoal.
//
// 2. **O que ficou de fora por restrição alimentar.** Para a pessoa poder
//    conferir que o app entendeu.
//
// 3. **O que o app NÃO conseguiu interpretar da restrição.** Esta é a mais
//    importante das três e a mais fácil de esquecer. Um filtro que engole em
//    silêncio o que não entendeu é pior do que não ter filtro: a pessoa
//    declarou a alergia, viu o prato, e confiou.
//
// ═══════════════════════════════════════════════════════════════════════════
// O NÚMERO NA TELA É O TOTAL REAL, NUNCA O ALVO
//
// `QuebraDeJejum.ajustarPara` limita o fator de escala, então a sugestão às
// vezes fica abaixo do orçamento. A tela mostra `kcalTotal` — a soma dos
// componentes — e não `orcamentoKcal`. Mostrar o alvo seria a tela dizendo um
// número e o diário gravando outro, que é exatamente o bug da porção fixa de
// 05/08 renascido numa tela nova.

import SwiftUI

struct QuebraDeJejumView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var jejum = JejumStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Quanto durou o jejum. Vem de quem apresentou a tela.
    let duracao: TimeInterval

    @State private var registrado = false

    private var sugestao: SugestaoDeQuebra {
        QuebraDeJejum.montar(
            duracao: duracao,
            horasDeJanela: jejum.emCurso?.protocolo.horasDeJanela
                ?? jejum.protocoloPreferido.horasDeJanela,
            kcalGoal: model.kcalGoal,
            kcalConsumidas: model.kcalConsumed,
            proteinaConsumida: model.proteinConsumed,
            proteinaGoal: model.proteinGoal,
            objetivo: Self.objetivo(de: model.goal),
            restricoesTextoLivre: model.dietaryRestrictions,
            nomesJaRegistradosHoje: JejumStore.nomesRegistrados(em: model.meals),
            catalogo: foodDatabase
        )
    }

    /// A tradução de uma linha prometida no cabeçalho do `QuebraDeJejum`.
    static func objetivo(de goal: Goal) -> ObjetivoDaQuebra {
        switch goal {
        case .perder: return .perder
        case .manter: return .manter
        case .ganhar: return .ganhar
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cabecalho
                    if sugestao.temPrimeiroPrato {
                        prato(titulo: "Comece pela proteína",
                              legenda: "Pouca comida, e proteína. É o que cai melhor depois de horas sem comer.",
                              itens: sugestao.primeiroPrato,
                              tint: Theme.violet,
                              numerar: false)
                        intervalo
                        prato(titulo: "Depois, o prato principal",
                              legenda: "Coma nesta ordem. O carboidrato por último.",
                              itens: sugestao.pratoPrincipal,
                              tint: Theme.primary,
                              numerar: true)
                    } else {
                        prato(titulo: "Sua refeição",
                              legenda: "Coma nesta ordem. O carboidrato por último.",
                              itens: sugestao.pratoPrincipal,
                              tint: Theme.primary,
                              numerar: true)
                    }

                    orcamentoCard
                    restricoesCard
                    acoes
                    porQueAssim
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Quebrar o jejum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    // MARK: Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(textoDaDuracao(duracao))
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                Text("de jejum")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("\(sugestao.kcalTotal) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.primary)
            }
            Text(sugestao.gentileza.explicacao)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: Prato

    /// `numerar` liga os números 1, 2, 3 ao lado dos itens.
    ///
    /// Só o prato principal é numerado, e não é enfeite: a ordem vem calculada
    /// do motor (`PapelNoPrato.ordemDeComer`, carboidrato por último) e o número
    /// é como ela chega à pessoa. Um prato de um item só não é numerado —
    /// "1." sozinho não informa nada.
    private func prato(titulo: String, legenda: String,
                       itens: [ItemDaQuebra], tint: Color, numerar: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(itens.reduce(0) { $0 + $1.componente.kcal }) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(legenda)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)

            ForEach(Array(itens.enumerated()), id: \.element.id) { posicao, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if numerar && itens.count > 1 {
                        Text("\(posicao + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                            .frame(width: 18, height: 18)
                            .background(tint.opacity(0.14))
                            .clipShape(Circle())
                    } else {
                        Circle().fill(tint.opacity(0.5)).frame(width: 6, height: 6)
                    }
                    Text(item.componente.descricao)
                        .font(.caption)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                    Text("\(item.componente.kcal) kcal")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
            }

            let comps = itens.map(\.componente)
            let p = comps.reduce(0) { $0 + $1.proteina }
            let c = comps.reduce(0) { $0 + $1.carbo }
            let g = comps.reduce(0) { $0 + $1.gordura }
            Text("Proteína \(p) g · Carboidrato \(c) g · Gordura \(g) g")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var intervalo: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.footnote)
                .foregroundStyle(Theme.gold)
            Text("Espere uns \(sugestao.intervaloEmMinutos) minutos antes do prato principal.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    // MARK: Orçamento

    private var orcamentoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sugestao.orcamentoVeioDaMeta ? "Calibrado pela sua meta" : "Porção padrão")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            if sugestao.orcamentoVeioDaMeta, let meta = model.kcalGoal {
                Text("Hoje você já registrou \(model.kcalConsumed) kcal de \(meta). Esta sugestão usa parte do que sobrou, dividido pelas refeições que ainda cabem na sua janela.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Honestidade: sem medidas não há meta, e o app não inventa uma.
                Text("Você ainda não tem meta de calorias. Sem peso, altura e idade não dá para calcular. Usei uma porção padrão. Preencha suas medidas na aba Saúde e a sugestão passa a ser sua.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: Restrições

    @ViewBuilder
    private var restricoesCard: some View {
        if !sugestao.gruposEvitados.isEmpty || !sugestao.restricoesNaoLidas.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !sugestao.gruposEvitados.isEmpty {
                    Label("Deixei de fora: \(sugestao.gruposEvitados.map(\.rawValue).joined(separator: ", "))",
                          systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(Theme.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !sugestao.restricoesNaoLidas.isEmpty {
                    // A confissão. Ver o item 3 do cabeçalho.
                    Label("Você escreveu \"\(sugestao.restricoesNaoLidas.joined(separator: ", "))\" nas suas restrições e eu não entendi. Confira a sugestão antes de registrar.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    // MARK: Ações

    private var acoes: some View {
        VStack(spacing: 10) {
            Button { registrar(encerrandoJejum: true) } label: {
                Label(registrado ? "Registrado" : "Registrar no diário e encerrar o jejum",
                      systemImage: registrado ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(registrado ? Theme.primary.opacity(0.15) : Theme.primary)
                    .foregroundStyle(registrado ? Theme.primary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(registrado)

            Button { registrar(encerrandoJejum: false) } label: {
                Text("Registrar sem encerrar o jejum")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.azure)
            }
            .buttonStyle(.plain)
            .disabled(registrado)

            Text("Depois de registrar, dá para mudar a quantidade de cada item na aba Dieta.")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Registra os dois pratos como refeições separadas — e é assim de
    /// propósito. Juntar tudo numa `Meal` só faria a porção leve e o prato
    /// principal virarem uma linha, e a pessoa perderia a capacidade de marcar
    /// só a primeira como consumida enquanto espera os 20 minutos.
    private func registrar(encerrandoJejum: Bool) {
        let tipo = Self.refeicaoDaHora()
        let s = sugestao
        if !s.primeiroPrato.isEmpty {
            model.registrarPrato(nome: "Quebra do jejum · proteína",
                                 componentes: s.primeiroPrato.map(\.componente), to: tipo)
        }
        if !s.pratoPrincipal.isEmpty {
            model.registrarPrato(nome: s.temPrimeiroPrato ? "Quebra do jejum · prato principal"
                                                          : "Quebra do jejum",
                                 componentes: s.pratoPrincipal.map(\.componente), to: tipo)
        }
        if encerrandoJejum { jejum.encerrar() }
        registrado = true
    }

    /// Em que refeição do dia isto entra. Pela hora, porque a quebra do jejum
    /// pode cair em qualquer uma delas — quem faz OMAD às 19 h não está tomando
    /// café da manhã.
    static func refeicaoDaHora(_ agora: Date = Date(),
                               calendario: Calendar = .current) -> MealType {
        switch calendario.component(.hour, from: agora) {
        case 0..<10:  return .cafe
        case 10..<15: return .almoco
        case 15..<18: return .lanche
        default:      return .jantar
        }
    }

    // MARK: Por que assim

    private var porQueAssim: some View {
        AfirmacaoCard(afirmacao: JejumConteudo.sobreAQuebra)
    }
}

#Preview {
    QuebraDeJejumView(duracao: 19 * 3600).environmentObject(AppModel())
}
