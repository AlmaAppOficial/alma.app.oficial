//
//  MealDetailView.swift
//  Corpo & Alma
//
//  Detalhe de uma refeição — macros, status e remoção.
//
// ═══════════════════════════════════════════════════════════════════════════
// ✅ DÍVIDA PAGA [2026-08-12] — esta tela É alcançável e EDITA.
//
// A dívida abaixo, escrita em 06/08, ficou aqui de propósito: ela descreve o
// obstáculo real (era de MODELO, não de tela) e prescreve a ordem (a) campos →
// (b) gravar → (c) formulário → (d) navegação. Os quatro passos foram feitos
// nessa ordem, e onde eles estão:
//
//   (a) `Refeicao.swift` — `ComponenteDaRefeicao` e `Meal.componentes`, com
//       quantidade E base por 100, que eram os dois números que faltavam.
//   (b) `AppModel.addFood` e `AppModel.registrarPrato` — todo registro nasce
//       com componentes, inclusive o que vem da busca.
//   (c) `editorDeComponentes`, aqui embaixo.
//   (d) `DietaView` — o toque no nome do item abre esta tela.
//
// O aviso de 06/08 estava certo no ponto mais importante: ligar a navegação
// primeiro teria entregue dois botões repetidos e nenhuma edição. Foi por isso
// que (d) veio por último.
//
// O que continua verdade: refeição registrada ANTES de 12/08 não tem
// `componentes` (é `nil`), e para ela esta tela mostra os totais e as duas
// ações de sempre, sem editor. Não há como inventar a decomposição de um
// registro que só guardou o total — e inventar seria o B8.
//
// ── texto original de 06/08, preservado ────────────────────────────────────
// ⚠️ DÍVIDA DECLARADA [2026-08-06] — ESTA TELA NÃO É ALCANÇÁVEL, E NÃO EDITA.
//
// Quem for fazer a refeição editável (2.1) vai encontrar este arquivo e supor
// que há meio caminho andado. Não há. Duas coisas, as duas verificadas:
//
// 1. NINGUÉM CHEGA AQUI. O arquivo está no target (project.pbxproj), compila e
//    entra no binário, mas não existe NavigationLink, sheet, fullScreenCover
//    nem navigationDestination apontando para ele em lugar nenhum do projeto.
//    A única referência viva é `SmokeTestTelas.swift:376`, que está dentro de
//    `#if DEBUG` e atrás da flag `smokeTelas` — em release ela nem existe.
//    Na interface real, a lista de itens é montada em `DietaView.swift:226-262`
//    e cada linha tem exatamente dois botões: marcar consumido e remover.
//
// 2. ELA NÃO EDITA NADA. As duas ações abaixo são `toggleMeal` e `removeMeal`,
//    as mesmas que a linha da DietaView já oferece. Não há campo, slider nem
//    formulário. Alcançar esta tela como está apenas duplicaria dois botões.
//
// E o obstáculo real da 2.1 não é de tela, é de modelo: `Meal`
// (`Models.swift:45-54`) não guarda gramas nem base por 100 g. O `addFood`
// (`Models.swift:748`) escreve a porção DENTRO da string do nome
// ("Frango · 250 g") e descarta o número. Sem gramas e sem base gravadas, não
// há o que reescalar — editar exigiria fazer parsing do nome.
//
// Ou seja: a 2.1 é (a) acrescentar campos opcionais de porção e base ao `Meal`,
// (b) gravá-los no `addFood`, (c) então dar a esta tela um formulário de
// quantidade — o do `AddFoodView.swift:224-298` serve — e (d) só aí ligar a
// navegação. Nessa ordem. Ligar a navegação primeiro entrega dois botões
// repetidos e nenhuma edição.
//
// Precedente da casa, para quem quiser copiar um padrão que já funciona:
// suplemento TEM editor — `SupplementsView.swift:55`.
// ═══════════════════════════════════════════════════════════════════════════

import SwiftUI

struct MealDetailView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let meal: Meal

    /// [2026-08-12] Os componentes em edição.
    ///
    /// Cópia local, e não escrita direta em `model.meals`: enquanto a pessoa
    /// arrasta o arroz de 150 para 220 g, o diário do dia não muda. Só o botão
    /// Salvar aplica. Sem isso, cada quadro do arrasto viraria uma gravação em
    /// `UserDefaults` (o `didSet` de `meals` persiste a cada mudança) e a
    /// contagem do dia dançaria embaixo da tela da Dieta.
    @State private var emEdicao: [ComponenteDaRefeicao] = []

    /// Os números que a tela mostra AGORA — a soma do que está em edição.
    ///
    /// A refeição de referência é montada por `Meal.comComponentes`, que é o
    /// mesmo caminho do registro. Assim o que esta tela exibe antes de salvar é,
    /// literalmente, a refeição que será salva: não há uma fórmula "de
    /// visualização" que possa divergir da fórmula "de gravação". Era esse par
    /// divergente o bug de 05/08.
    private var previa: Meal {
        emEdicao.isEmpty ? meal : meal.trocandoComponentes(emEdicao)
    }

    private var houveMudanca: Bool {
        meal.componentes.map { $0 != emEdicao } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Cabeçalho
                VStack(spacing: 10) {
                    Image(systemName: meal.type.systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.coral)
                        .frame(width: 88, height: 88)
                        .background(Theme.coral.opacity(0.14))
                        .clipShape(Circle())
                    Text(meal.type.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                    Text(meal.name)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Calorias — da PRÉVIA, não do `meal` gravado: enquanto a pessoa
                // ajusta, o número grande acompanha.
                VStack(spacing: 4) {
                    Text("\(previa.kcal)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(Theme.coral)
                    Text("kcal")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .cardStyle()

                // Macros
                HStack(spacing: 12) {
                    macroBox("Proteína", previa.protein, Theme.primary)
                    macroBox("Carbo", previa.carbs, Theme.gold)
                    macroBox("Gordura", previa.fat, Theme.azure)
                }

                // [2026-08-12] O EDITOR — o passo (c) da dívida declarada no
                // topo deste arquivo. Só aparece quando há componentes: uma
                // refeição registrada antes desta versão não tem o que editar,
                // e mostrar controles inertes seria pior que não mostrar.
                if !emEdicao.isEmpty { editorDeComponentes }

                // Ações
                VStack(spacing: 12) {
                    if houveMudanca {
                        Button {
                            model.atualizarRefeicao(previa)
                            dismiss()
                        } label: {
                            Label("Salvar alterações", systemImage: "checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall,
                                                            style: .continuous))
                        }
                        Button {
                            emEdicao = meal.componentes ?? []
                        } label: {
                            Label("Descartar alterações", systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        model.toggleMeal(meal)
                        dismiss()
                    } label: {
                        Label(meal.done ? "Marcar como não consumida" : "Marcar como consumida",
                              systemImage: meal.done ? "circle" : "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary.opacity(0.12))
                            .foregroundStyle(Theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                    Button(role: .destructive) {
                        model.removeMeal(meal)
                        dismiss()
                    } label: {
                        Label("Remover refeição", systemImage: "trash")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.coral.opacity(0.12))
                            .foregroundStyle(Theme.coral)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Refeição")
        .navigationBarTitleDisplayMode(.inline)
        // A cópia local nasce aqui, do dado gravado.
        .onAppear { if emEdicao.isEmpty { emEdicao = meal.componentes ?? [] } }
    }

    /// A lista editável. Mesmo desenho do editor do `FoodScanView`: rótulo, −/+,
    /// slider contínuo, e os macros do componente logo abaixo.
    private var editorDeComponentes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Componentes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)

            ForEach(Array(emEdicao.enumerated()), id: \.element.id) { i, c in
                VStack(spacing: 6) {
                    HStack {
                        Text(c.nome)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(textoDaQuantidade(c.quantidade, c.unidade))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(Theme.primary)
                    }
                    HStack(spacing: 12) {
                        Button {
                            emEdicao[i] = c.com(quantidade: max(0, c.quantidade - 10))
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(c.quantidade > 0
                                                 ? Theme.primary : Theme.inkSoft.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .disabled(c.quantidade == 0)

                        Slider(
                            value: Binding<Double>(
                                get: { Double(emEdicao[i].quantidade) },
                                set: { emEdicao[i] = c.com(quantidade: Int($0.rounded())) }
                            ),
                            in: 0...Double(max(500, c.quantidade * 3))
                        )
                        .tint(Theme.primary)

                        Button {
                            emEdicao[i] = c.com(quantidade: c.quantidade + 10)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Text("\(c.kcal) kcal · P\(c.proteina) C\(c.carbo) G\(c.gordura)")
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
                if i < emEdicao.count - 1 { Divider() }
            }

            Text("Arraste até 0 o que você não comeu. As calorias acima acompanham.")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }

    private func macroBox(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value) g").font(.title3.bold()).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

#Preview {
    NavigationStack {
        MealDetailView(meal: AppModel().meals[0]).environmentObject(AppModel())
    }
}
