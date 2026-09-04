//
//  EditorDePadraoView.swift
//  Corpo & Alma
//
//  Onde a pessoa define o padrão dela para um exercício: N séries × M
//  repetições × carga. É a tela que faltava — até 03/09/2026 séries e reps eram
//  `Text`, vindos do catálogo, e nenhum controle no app os mudava.
//
//  Regras de produto:
//    · nada é obrigatório. Campo em branco = "use o do catálogo", e o
//      placeholder mostra qual é esse valor, para a pessoa saber do que está
//      abrindo mão;
//    · os três em branco REMOVEM o padrão — é o desfazer, sem botão de apagar;
//    · sempre kg, teclado numérico, alvo de toque grande, como no registro;
//    · a OFERTA ("você registrou 65 kg nas últimas 3 séries") aparece AQUI e só
//      aqui. No meio do treino, sugerir carga é proibido (regra 3.2): ali o app
//      só mostra o que aconteceu, nunca o que fazer. Aqui a pessoa veio de
//      propósito mexer no próprio padrão, e ainda assim quem decide é ela — o
//      botão preenche o campo, não salva.
//
import SwiftUI

struct EditorDePadraoView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// O exercício como o CATÁLOGO o define — é dele que saem os placeholders.
    let exercicioDoCatalogo: Exercise
    var tint: Color = Theme.primary

    @State private var textoSeries = ""
    @State private var textoReps   = ""
    @State private var textoCarga  = ""
    @State private var carregou    = false
    @FocusState private var campoFocado: Campo?

    enum Campo: Hashable { case series, reps, carga }

    private var sugestao: Double? { model.sugestaoDePadrao(para: exercicioDoCatalogo) }

    /// Como ficará o cartão do exercício depois de salvar — a pessoa vê o
    /// resultado antes de confirmar.
    private var previa: String {
        let p = RegrasDePadrao.montar(exercicio: exercicioDoCatalogo.name,
                                      series: RegrasDePadrao.series(de: textoSeries),
                                      reps: RegrasDePadrao.reps(de: textoReps),
                                      cargaKg: RegrasDePadrao.carga(de: textoCarga))
        let ex = RegrasDePadrao.aplicar(p, em: exercicioDoCatalogo)
        var partes = ["\(ex.sets) séries", ex.reps]
        if let kg = p?.cargaKg { partes.append("\(RegrasDeSeries.textoDaCarga(kg)) kg") }
        return partes.joined(separator: " · ")
    }

    private var vaiRemover: Bool {
        RegrasDePadrao.series(de: textoSeries) == nil
        && RegrasDePadrao.reps(de: textoReps) == nil
        && RegrasDePadrao.carga(de: textoCarga) == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Quanto você faz neste exercício. Fica salvo e vem preenchido na próxima vez.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 12) {
                        campo(texto: $textoSeries, rotulo: "séries",
                              exemplo: "\(exercicioDoCatalogo.sets)",
                              teclado: .numberPad, alvo: .series)
                            .accessibilityLabel("Quantidade de séries")
                        campo(texto: $textoReps, rotulo: "repetições",
                              exemplo: exercicioDoCatalogo.reps,
                              teclado: .default, alvo: .reps)
                            .accessibilityLabel("Repetições por série")
                        campo(texto: $textoCarga, rotulo: "kg",
                              exemplo: "–", teclado: .decimalPad, alvo: .carga)
                            .accessibilityLabel("Carga em quilos")
                    }

                    if let kg = sugestao {
                        ofertaDeAtualizacao(kg)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vaiRemover ? "Sem padrão definido" : "Vai ficar assim")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                        Text(previa)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        if vaiRemover {
                            Text("Deixando os três campos em branco, o exercício volta ao que o catálogo sugere.")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    Text("O que você anotar durante o treino não muda isto — um dia mais leve não estraga o seu padrão.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Meu padrão")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.inkSoft)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { salvar() }
                        .font(.headline)
                        .tint(tint)
                }
                // Teclado numérico não tem "return": este OK é a saída.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { campoFocado = nil }
                        .font(.headline)
                }
            }
            .onAppear(perform: carregarDoDisco)
        }
    }

    // MARK: - Peças

    /// A oferta. Preenche o campo — NUNCA salva. Quem confirma é o "Salvar".
    private func ofertaDeAtualizacao(_ kg: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Você anotou \(RegrasDeSeries.textoDaCarga(kg)) kg nas últimas \(RegrasDePadrao.seriesParaOferecer) séries deste exercício.")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                textoCarga = RegrasDeSeries.textoDaCarga(kg)
            } label: {
                Label("Usar \(RegrasDeSeries.textoDaCarga(kg)) kg como padrão",
                      systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Campo de 48 pt (o mínimo humano é 44), rótulo à direita, como o card de
    /// anotar série — é o mesmo gesto, na mesma mão.
    private func campo(texto: Binding<String>, rotulo: String, exemplo: String,
                       teclado: UIKeyboardType, alvo: Campo) -> some View {
        HStack(spacing: 6) {
            TextField(exemplo, text: texto)
                .keyboardType(teclado)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .focused($campoFocado, equals: alvo)
                .autocorrectionDisabled()
            Text(rotulo)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(Theme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(campoFocado == alvo ? tint : Theme.inkSoft.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { campoFocado = alvo }
    }

    // MARK: - Disco

    /// Abre com o que a pessoa já definiu — e VAZIO onde ela não definiu nada,
    /// para que o placeholder do catálogo continue à vista. `carregou` impede
    /// que um redesenho apague o que ela acabou de digitar.
    private func carregarDoDisco() {
        guard !carregou else { return }
        carregou = true
        let p = model.padrao(de: exercicioDoCatalogo)
        textoSeries = p?.series.map(String.init) ?? ""
        textoReps   = p?.reps ?? ""
        textoCarga  = p?.cargaKg.map(RegrasDeSeries.textoDaCarga) ?? ""
    }

    private func salvar() {
        campoFocado = nil
        model.definirPadrao(exercicio: exercicioDoCatalogo.name,
                            series: RegrasDePadrao.series(de: textoSeries),
                            reps: RegrasDePadrao.reps(de: textoReps),
                            cargaKg: RegrasDePadrao.carga(de: textoCarga))
        dismiss()
    }
}

#Preview {
    EditorDePadraoView(exercicioDoCatalogo: AppModel().workouts[0].exercises[0])
        .environmentObject(AppModel())
}
