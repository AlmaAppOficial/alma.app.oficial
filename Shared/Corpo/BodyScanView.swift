//
//  BodyScanView.swift
//  Corpo & Alma
//
//  Scan corporal com IA — coleta fotos (frente/lado) + medidas e gera o plano.
//

import SwiftUI
import PhotosUI

struct BodyScanView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var frontData: Data?
    @State private var sideData: Data?
    @State private var analyzing = false
    @State private var result: ScanResult?
    @State private var showResult = false
    @State private var errorMessage: String?
    @State private var showCameraFront  = false
    @State private var showCameraSide   = false
    @State private var showGalleryFront = false
    @State private var showGallerySide  = false
    /// [2026-08-05] Consentimento por envio — ver `analyze()`.
    @State private var mostrarConsentimento = false
    /// [2026-08-26] Saída do gate de perfil — ver `canAnalyze`.
    @State private var mostrarEdicaoDePerfil = false

    // [2026-08-26] Fotos semeadas — SÓ para a conferência visual, e só em DEBUG.
    //
    // Existe pelo mesmo motivo de `JejumStore.semearParaCapturas`: sem estado
    // semeado a captura não mostra o que precisa ser conferido. Aqui o problema
    // é mais duro que "print vazio" — é print MENTIROSO.
    //
    // `AIService.isRealAI` é `true` fixo (AIBodyScan:261), então sem foto
    // `canAnalyze` já é falso pelo gate de FOTO. A tela sai idêntica com e sem
    // o `guard model.hasBodyProfile`, e a mutação passa nos dois mundos — foi
    // exatamente o que aconteceu na primeira rodada de 26/08: os dois PNGs
    // deram o mesmo md5. Um teste que fica verde nos dois mundos é cego, e a
    // única maneira de enxergar o gate de perfil é satisfazer o de foto.
    private let fotosSemeadas: Bool

    init(fotosSemeadas: Bool = false) {
        self.fotosSemeadas = fotosSemeadas
        if fotosSemeadas {
            let png = Self.pngDeConferencia()
            _frontData = State(initialValue: png)
            _sideData  = State(initialValue: png)
        }
    }

    /// Imagem chapada, só para ocupar os dois slots na conferência.
    private static func pngDeConferencia() -> Data {
        let lado = CGSize(width: 40, height: 40)
        let r = UIGraphicsImageRenderer(size: lado)
        let img = r.image { ctx in
            UIColor(white: 0.72, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: lado))
        }
        return img.pngData() ?? Data()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                photosSection
                measuresSection
                analyzeButton
                privacyNote
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Scan corporal")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) {
            if let result { ScanResultView(result: result) }
        }
        .onChange(of: frontItem) { item in load(item) { frontData = $0 } }
        .onChange(of: sideItem) { item in load(item) { sideData = $0 } }
        .overlay { if analyzing { analyzingOverlay } }
        .alert("Não foi possível analisar", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: $mostrarEdicaoDePerfil) { EditAssessmentView() }
        .sheet(isPresented: $showCameraFront) {
            CameraPickerView { image in
                frontData = image.jpegData(compressionQuality: 0.8)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCameraSide) {
            CameraPickerView { image in
                sideData = image.jpegData(compressionQuality: 0.8)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showGalleryFront, selection: $frontItem, matching: .images)
        .photosPicker(isPresented: $showGallerySide,  selection: $sideItem,  matching: .images)
        // [2026-08-05] Consentimento A CADA envio, com a alternativa sem foto
        // sempre visível no mesmo lugar — não escondida atrás de um "não".
        .confirmationDialog("Enviar fotos para análise?",
                            isPresented: $mostrarConsentimento,
                            titleVisibility: .visible) {
            Button("Enviar fotos para análise") { enviarComFotos() }
            Button("Gerar só com minhas medidas") { gerarSemFotos() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(Self.pedidoDeConsentimento)
        }
    }

    // MARK: Seções

    /// [2026-08-04] Estáticos para o harness assertar o MESMO texto exibido.
    static var tituloDaTela: String {
        AIService.isRealAI ? "Análise corporal com IA"
                                      : "Estimativa corporal por medidas"
    }

    static var chamadaDaTela: String {
        AIService.isRealAI
        ? "Adicione 2 fotos e confirme suas medidas. A IA estima seu perfil corporal a partir das fotos; as metas de calorias e macros são calculadas no seu aparelho."
        : "Confirme suas medidas e o app calcula uma estimativa do seu perfil, com um plano de alimentação e treino. Nesta versão não há análise por IA e as fotos não são usadas."
    }

    /// [2026-08-05] Texto reescrito quando a IA ligou. Duas coisas mudaram e as
    /// duas importam:
    ///
    /// 1. A versão anterior dizia "não são compartilhadas". Com a análise na
    ///    nuvem isso deixaria de ser verdade — a foto vai para o provedor de IA.
    /// 2. O texto proposto no doc do gate dizia "apagadas logo depois, nada é
    ///    guardado". Também seria falso: a OpenAI retém entradas da API por até
    ///    30 dias para monitoramento de abuso, e Zero Data Retention exige
    ///    acordo comercial que não temos. Prometer "nada é guardado" seria
    ///    exatamente a classe de promessa que o projeto proíbe.
    ///
    /// O que é verdade e está escrito: o ALMA não guarda a foto (a função
    /// processa em memória e não persiste nada — ver `analiseDeFoto.ts`), o
    /// provedor pode reter por até 30 dias por segurança, e não treina com ela.
    static var notaDePrivacidade: String {
        AIService.isRealAI
        ? "A foto é analisada e não fica guardada no Alma. O provedor de IA pode mantê-la por até 30 dias apenas por segurança, e não a usa para treinar modelos. Esta avaliação é uma estimativa informativa e não substitui um profissional de saúde."
        : "Nesta versão nenhuma foto é enviada nem analisada — o resultado vem só das suas medidas. Esta avaliação é informativa e não substitui um profissional de saúde."
    }

    /// Texto do pedido de consentimento, mostrado A CADA envio.
    static var pedidoDeConsentimento: String {
        "Enviar suas fotos para análise?\n\n"
        + "A foto é analisada e não fica guardada no Alma. O provedor de IA pode "
        + "mantê-la por até 30 dias apenas por segurança, e não a usa para treinar modelos.\n\n"
        + "Você pode gerar o resultado só com as suas medidas, sem enviar foto."
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "figure.arms.open")
                .font(.system(size: 40))
                .foregroundStyle(Theme.primary)
            // [2026-08-04 — B8 REABERTO na varredura visual] Esta tela dizia
            // "Análise corporal com IA" e "A IA estima seu perfil" no topo, e
            // no rodapé "A análise por IA não está disponível nesta versão".
            // As duas frases, na mesma tela, ao mesmo tempo. O título vence a
            // ressalva: quem lê de cima para baixo já decidiu que tem IA.
            Text(Self.tituloDaTela)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
            Text(Self.chamadaDaTela)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var photosSection: some View {
        HStack(alignment: .top, spacing: 14) {
            photoSlot(
                title: "Frente",
                data: frontData,
                item: $frontItem,
                onCamera: { showCameraFront = true },
                onGallery: { showGalleryFront = true }
            )
            photoSlot(
                title: "Lado",
                data: sideData,
                item: $sideItem,
                onCamera: { showCameraSide = true },
                onGallery: { showGallerySide = true }
            )
        }
    }

    private func photoSlot(
        title: String,
        data: Data?,
        item: Binding<PhotosPickerItem?>,
        onCamera: @escaping () -> Void,
        onGallery: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 8) {
            // Área de preview
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surfaceAlt)
                if let data, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.title2).foregroundStyle(Theme.primary)
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("toque para adicionar").font(.caption2).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)

            // Botões: Galeria e Câmera
            HStack(spacing: 6) {
                Button { onGallery() } label: {
                    Label("Galeria", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .foregroundStyle(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { onCamera() } label: {
                    Label("Câmera", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Theme.coral)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var measuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suas medidas").font(.headline).foregroundStyle(Theme.ink)
            HStack(spacing: 12) {
                measure("\(Int(model.weightKg)) kg", "Peso")
                measure("\(Int(model.heightCm)) cm", "Altura")
                measure("\(model.ageYears)", "Idade")
                measure(model.goal.rawValue, "Objetivo")
            }
        }
        .cardStyle()
    }

    private func measure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // [F1] Com IA real: as DUAS fotos são obrigatórias — sem elas o botão não libera.
    // Sem IA disponível: o botão diz a verdade ("estimativa por medidas, sem IA").
    private var missingPhotos: [String] {
        var missing: [String] = []
        if frontData == nil { missing.append("foto de frente") }
        if sideData == nil { missing.append("foto de lado") }
        return missing
    }

    // [2026-08-26] O perfil entrou no gate junto com as fotos.
    //
    // Sem peso/altura/idade o plano local calcula com ZERO, e aí o piso de
    // segurança `max(…, 1300)` do AIBodyScan:361 vira fabricador de meta: quem
    // nunca informou nada lia "Meta diária 1300 kcal" e "Proteína 0 g" em
    // .largeTitle. Restrição calórica severa entregue justamente a quem o app
    // não conhece.
    //
    // É o mesmo esqueleto do somatotipo "Ectomorfo": ausência de medida virando
    // número. O app já sabe fazer isto certo — `suggestedKcalGoal` devolve nil
    // sem perfil (Models.swift:471). O scan era o único caminho da casa que
    // contornava a regra.
    private var canAnalyze: Bool {
        guard model.hasBodyProfile else { return false }
        return AIService.isRealAI ? missingPhotos.isEmpty : true
    }

    private var analyzeButton: some View {
        VStack(spacing: 8) {
            Button { analyze() } label: {
                Label(AIService.isRealAI ? "Analisar com IA" : "Gerar estimativa por medidas (sem IA)",
                      systemImage: AIService.isRealAI ? "sparkles" : "ruler")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [Theme.primary, Theme.primaryDeep], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                    .opacity(canAnalyze ? 1 : 0.45)
            }
            .disabled(analyzing || !canAnalyze)

            // [2026-08-26] O aviso do perfil vem ANTES do aviso das fotos: sem
            // medida não existe plano, com ou sem foto. E ele diz o que falta
            // pelo nome e abre onde se preenche — travar o botão sem dar a
            // saída é só um beco.
            if !model.hasBodyProfile {
                VStack(spacing: 8) {
                    Label("Falta informar: \(model.missingProfileFields.joined(separator: ", ")).",
                          systemImage: "exclamationmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.coral)

                    Text("Sem isso não dá para calcular sua meta — e um número inventado é pior que nenhum.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)

                    Button { mostrarEdicaoDePerfil = true } label: {
                        Label("Completar minhas medidas", systemImage: "square.and.pencil")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if AIService.isRealAI && !missingPhotos.isEmpty {
                Label("Falta: \(missingPhotos.joined(separator: " e "))",
                      systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if !AIService.isRealAI {
                Text("A análise por IA não está disponível nesta versão. O resultado será uma estimativa calculada só com suas medidas — sem uso de fotos.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var privacyNote: some View {
        // [2026-08-04] Dizia "Suas fotos são usadas apenas para gerar sua
        // análise" numa versão em que foto nenhuma é usada. Descrever um uso
        // que não existe é tão errado quanto esconder um que existe.
        Text(Self.notaDePrivacidade)
            .font(.caption2)
            .foregroundStyle(Theme.inkSoft)
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(.white)
                // [2026-08-03 — B8] Era "Analisando seu corpo com IA…" sobre um
                // cálculo local por medidas. Sem IA no build, o texto mente.
                Text(AIService.isRealAI
                     ? "Analisando suas fotos…"
                     : "Calculando a partir das suas medidas…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    // MARK: Ações

    private func load(_ item: PhotosPickerItem?, completion: @escaping (Data) -> Void) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    completion(data)
                } else {
                    errorMessage = "Não foi possível carregar a foto. Tente escolher outra imagem."
                }
            } catch {
                #if DEBUG
                print("[BodyScan] Falha ao carregar foto: \(error)")
                #endif
                errorMessage = "Não foi possível carregar a foto. Tente escolher outra imagem."
            }
        }
    }

    /// [2026-08-05] O botão NÃO envia mais direto. Ele abre o pedido de
    /// consentimento; o envio só acontece se a pessoa tocar em "Enviar fotos".
    /// O consentimento é por ENVIO — não fica gravado, não vira toggle que a
    /// pessoa esquece que ligou.
    private func analyze() { mostrarConsentimento = true }

    /// Caminho com foto — exige o consentimento daquele envio.
    private func enviarComFotos() {
        executar(servico: AIService.make(consentimento: true))
    }

    /// Caminho sem foto — a alternativa que fica sempre visível no pedido.
    /// Nenhuma imagem sai do aparelho por aqui.
    private func gerarSemFotos() {
        executar(servico: AIService.semFoto(), usarFotos: false)
    }

    private func executar(servico: AIPlanService, usarFotos: Bool = true) {
        analyzing = true
        Task {
            defer { analyzing = false }
            let input = ScanInput(
                weightKg: model.weightKg,
                heightCm: model.heightCm,
                ageYears: model.ageYears,
                bodyFat: model.bodyFat,
                goal: model.goal.rawValue,
                frontPhoto: usarFotos ? frontData : nil,
                sidePhoto:  usarFotos ? sideData  : nil
            )
            do {
                let r = try await servico.analyze(input)
                result = r
                showResult = true
            } catch {
                // [B8] Falha NUNCA vira número. Não há fallback silencioso para
                // o cálculo local aqui: se a análise por foto falhou, a pessoa
                // lê o motivo e decide se tenta de novo ou segue sem foto.
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        BodyScanView().environmentObject(AppModel())
    }
}
