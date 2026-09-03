//
//  ExerciseDetailView.swift
//  Corpo & Alma
//
//  Detalhe de um exercício — ilustração do movimento (SF Symbol),
//  equipamento, músculo trabalhado e passo a passo.
//

import SwiftUI

struct ExerciseDetailView: View {
    @EnvironmentObject var model: AppModel
    let exercise: Exercise
    var tint: Color = Theme.primary

    @State private var animate = false
    @State private var editandoPadrao = false

    /// [2026-09-03] Os dois blocos de volume eram `Text` — o app prescrevia
    /// "4 séries · 8 reps" e não havia controle nenhum para mudar isso. Agora
    /// são um botão que abre o `EditorDePadraoView`.
    ///
    /// O padrão é resolvido EM TEMPO DE DESENHO, pelo slug do nome, como a foto
    /// de capa logo acima: nada é gravado dentro do `Exercise`, nada muda de
    /// formato, e um treino salvo antes desta mudança abre igual. `padroesVersao`
    /// é lido de propósito — é ele que faz esta tela redesenhar quando o editor
    /// salva, já que a coleção de padrões não é `@Published`.
    private var padrao: PadraoDoExercicio? {
        _ = model.padroesVersao
        return model.padrao(de: exercise)
    }
    private var exibido: Exercise {
        RegrasDePadrao.aplicar(padrao, em: exercise)
    }

    /// [2026-09-02] O `Exercise` legado (formato PERSISTIDO, 7 campos) não tem
    /// e não vai ter campo de foto — acrescentar campo lá quebra o decode de
    /// `customWorkouts` e apaga o treino da pessoa em silêncio (ver o cabeçalho
    /// de `Exercicio.swift`). A foto é resolvida **em tempo de desenho**, pelo
    /// slug do nome, contra o catálogo do bundle. Nada é gravado, nada muda de
    /// formato, e um treino salvo antes desta mudança abre igual.
    private var fotoDeCapa: String? {
        ExerciseCatalog.resolve(legacy: exercise).fotoDeCapa
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Ilustração do movimento — foto do exercício quando o catálogo
                // tem uma para este nome; o SF Symbol animado quando não tem.
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(tint.opacity(0.12))
                    if let nome = fotoDeCapa {
                        FotoDoExercicioView(nome: nome) { simboloAnimado }
                            .padding(12)
                    } else {
                        simboloAnimado
                    }
                }
                .frame(height: 240)
                .frame(maxWidth: .infinity)

                // Tags
                HStack(spacing: 10) {
                    Label(exercise.equipment.rawValue, systemImage: exercise.equipment.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(tint.opacity(0.14))
                        .clipShape(Capsule())
                    Label(exercise.muscle, systemImage: "figure.arms.open")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.surfaceAlt)
                        .clipShape(Capsule())
                }

                // Volume — agora editável. Toque abre "Meu padrão".
                VStack(alignment: .leading, spacing: 10) {
                    Button { editandoPadrao = true } label: {
                        HStack(spacing: 12) {
                            volumeBox("\(exibido.sets)", "séries")
                            volumeBox(exibido.reps, "por série")
                            if let kg = padrao?.cargaKg {
                                volumeBox(RegrasDeSeries.textoDaCarga(kg), "kg")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Editar o meu padrão deste exercício")

                    HStack(spacing: 6) {
                        Image(systemName: padrao == nil ? "slider.horizontal.3" : "checkmark.circle.fill")
                            .font(.caption)
                        Text(padrao == nil
                             ? "Sugestão do catálogo — toque para definir o seu"
                             : "Seu padrão")
                            .font(.caption)
                    }
                    .foregroundStyle(padrao == nil ? Theme.inkSoft : tint)
                }

                // Passo a passo
                VStack(alignment: .leading, spacing: 14) {
                    Text("Como fazer")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(tint)
                                .clipShape(Circle())
                            Text(step)
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSoft)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { animate = true }
        .sheet(isPresented: $editandoPadrao) {
            EditorDePadraoView(exercicioDoCatalogo: exercise, tint: tint)
                .environmentObject(model)
        }
    }

    /// O desenho de sempre — SF Symbol pulsando. Continua sendo o que aparece
    /// para os 581 exercícios sem foto, e é também a reserva enquanto a foto
    /// decodifica. Não mudou uma linha; só ganhou nome.
    private var simboloAnimado: some View {
        Image(systemName: exercise.symbol)
            .font(.system(size: 120))
            .foregroundStyle(tint)
            .scaleEffect(animate ? 1.04 : 0.96)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animate)
    }

    private func volumeBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(label).font(.caption).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 14)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: AppModel().workouts[0].exercises[0])
            .environmentObject(AppModel())
    }
}
