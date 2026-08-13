//
//  SupplementsView.swift
//  Corpo & Alma
//
//  [F5] Espaço para suplementos — registro pessoal do usuário, 100% local.
//  O app NÃO recomenda suplemento nem dose. Suplementos com calorias
//  relevantes (whey, hipercalórico) somam na Dieta ao serem marcados.
//

import SwiftUI

// MARK: - Seção de suplementos (embutida na Dieta)

struct SupplementsSection: View {
    @EnvironmentObject var model: AppModel
    @State private var showForm = false
    @State private var editing: Supplement?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Suplementos")
                Spacer()
                Button { showForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                }
            }

            if model.supplements.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "pills")
                        .font(.title2)
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    Text("Registre os suplementos que você já usa")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .cardStyle()
            } else {
                ForEach(model.supplements) { s in
                    supplementRow(s)
                }
            }

            // Corregedoria: registro pessoal, sem recomendação, sem alegação de saúde.
            Text("Registro pessoal — o app não recomenda suplementos nem doses. Não substitui orientação de médico ou nutricionista.")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
        .sheet(isPresented: $showForm) { SupplementForm() }
        .sheet(item: $editing) { SupplementForm(existing: $0) }
    }

    private func supplementRow(_ s: Supplement) -> some View {
        let taken = model.supplementTakenToday(s)
        return HStack(spacing: 12) {
            Button { model.toggleSupplementToday(s) } label: {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(taken ? Theme.primary : Theme.inkSoft)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text([s.brand, s.dose, s.timeLabel].compactMap { $0?.isEmpty == false ? $0 : nil }
                        .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                HStack(spacing: 8) {
                    Text("\(model.supplementAdherence7d(s))/7 dias na semana")
                        .font(.caption2)
                        .foregroundStyle(Theme.azure)
                    if s.kcalPerDose > 0 {
                        Text("+\(s.kcalPerDose) kcal na Dieta")
                            .font(.caption2)
                            .foregroundStyle(Theme.coral)
                    }
                }
            }
            Spacer()
            Button { editing = s } label: {
                Image(systemName: "pencil")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(12)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
    }
}

// MARK: - Formulário (novo / editar)

struct SupplementForm: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var existing: Supplement?

    @State private var name = ""
    @State private var brand = ""
    @State private var dose = ""
    @State private var timeLabel = "Manhã"
    @State private var notes = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var barcode = ""
    @State private var lookingUp = false
    @State private var lookupMessage: String?
    @State private var showError = false

    private let timeOptions = ["Manhã", "Almoço", "Pré-treino", "Pós-treino", "Noite", "Antes de dormir"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // [F3→F5] Buscar por código de barras (opcional)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Código de barras (opcional)").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                        HStack(spacing: 8) {
                            TextField("EAN do rótulo", text: $barcode)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                            Button {
                                lookupBarcode()
                            } label: {
                                if lookingUp { ProgressView() } else { Text("Buscar") }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.primary)
                            .disabled(barcode.count < 8 || lookingUp)
                        }
                        if let msg = lookupMessage {
                            Text(msg).font(.caption2).foregroundStyle(Theme.inkSoft)
                        }
                    }

                    field("Nome *", text: $name, placeholder: "Ex.: Whey protein, Creatina…")
                    field("Marca / fabricante", text: $brand, placeholder: "Ex.: Growth, Max Titanium…")
                    field("Dose", text: $dose, placeholder: "Ex.: 30 g, 1 cápsula")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Horário / frequência").font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
                        Picker("Horário", selection: $timeLabel) {
                            ForEach(timeOptions, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.primary)
                    }

                    HStack(spacing: 10) {
                        field("kcal por dose", text: $kcal, placeholder: "0", numeric: true)
                        field("Proteína (g) por dose", text: $protein, placeholder: "0", numeric: true)
                    }
                    Text("Preencha as kcal se o suplemento for calórico (whey, hipercalórico) — ao marcar como tomado, ele soma na Dieta do dia.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)

                    field("Observação", text: $notes, placeholder: "Ex.: tomar com água")

                    if showError {
                        Text("Informe pelo menos o nome do suplemento.")
                            .font(.caption)
                            .foregroundStyle(Theme.coral)
                    }

                    Button { save() } label: {
                        Label(existing == nil ? "Adicionar suplemento" : "Salvar alterações", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    }

                    if let existing {
                        Button(role: .destructive) {
                            model.removeSupplement(existing)
                            dismiss()
                        } label: {
                            Label("Excluir suplemento", systemImage: "trash")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(Theme.coral)
                    }

                    Text("Registro pessoal — o app não recomenda suplementos nem doses. Não substitui orientação de médico ou nutricionista.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(existing == nil ? "Novo suplemento" : "Editar suplemento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
            .onAppear {
                if let s = existing {
                    name = s.name
                    brand = s.brand ?? ""
                    dose = s.dose
                    timeLabel = s.timeLabel
                    notes = s.notes ?? ""
                    kcal = s.kcalPerDose > 0 ? "\(s.kcalPerDose)" : ""
                    protein = s.proteinPerDose > 0 ? "\(s.proteinPerDose)" : ""
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, numeric: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.inkSoft)
            TextField(placeholder, text: text)
                .keyboardType(numeric ? .numberPad : .default)
                .padding(10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        }
    }

    // [F3] Reuso do lookup: preenche nome/marca/kcal a partir do código.
    private func lookupBarcode() {
        lookingUp = true
        lookupMessage = nil
        Task {
            defer { lookingUp = false }
            do {
                let p = try await OpenFoodFactsService.lookup(barcode.trimmingCharacters(in: .whitespaces))
                name = p.name
                if let b = p.brand { brand = b }
                // [2026-08-13] Era `p.kcalPer100 > 0`. Funcionava por acidente:
                // o parse colapsava "ausente" em 0, então `> 0` acertava a
                // mensagem pelo motivo errado. Agora a ausência é do tipo, e o
                // suplemento sem kcal na base continua sendo um fluxo legítimo
                // — aqui a pessoa informa a kcal da dose dela de qualquer jeito.
                if let kcal = p.kcalPer100 { lookupMessage = "Encontrado: \(kcal) kcal/100 g — ajuste a kcal pela SUA dose." }
                else { lookupMessage = "Produto encontrado (sem dados de kcal na base)." }
            } catch let e as ProductLookupError {
                lookupMessage = e.errorDescription
            } catch {
                lookupMessage = ProductLookupError.badResponse.errorDescription
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { showError = true; return }
        let cleanBrand = brand.trimmingCharacters(in: .whitespaces)
        let s = Supplement(
            id: existing?.id ?? UUID(),
            name: cleanName,
            brand: cleanBrand.isEmpty ? nil : cleanBrand,
            dose: dose.trimmingCharacters(in: .whitespaces),
            timeLabel: timeLabel,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes,
            kcalPerDose: Int(kcal) ?? 0,
            proteinPerDose: Int(protein) ?? 0,
            takenDates: existing?.takenDates ?? []
        )
        if let idx = model.supplements.firstIndex(where: { $0.id == s.id }) {
            model.supplements[idx] = s
        } else {
            model.supplements.append(s)
        }
        dismiss()
    }
}

#Preview {
    ScrollView { SupplementsSection().environmentObject(AppModel()).padding() }
}
