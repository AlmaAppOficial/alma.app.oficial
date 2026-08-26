// JejumView.swift
// Alma — Corpo · o jejum na tela, dentro da Dieta.
//
// ═══════════════════════════════════════════════════════════════════════════
// AS DECISÕES DE DESENHO QUE NÃO SÃO ESTÉTICAS
//
// Este arquivo tem quatro regras que existem por segurança, não por gosto, e
// que qualquer redesenho precisa preservar. Estão listadas aqui em cima porque
// é onde alguém que vai mexer na tela vai olhar.
//
// 1. **NÃO EXISTE BOTÃO DE ESTENDER.** Em nenhum estado, em nenhuma tela. Com a
//    meta atingida, a ação principal é "Quebrar o jejum". Quem quiser seguir
//    simplesmente não toca em nada — o cronômetro continua, sem que o app tenha
//    sugerido isso. A diferença entre não impedir e sugerir é o módulo inteiro.
//
// 2. **NADA CELEBRA DURAÇÃO.** A sequência conta dias (ver `Sequencia`). O
//    jejum mais longo aparece no histórico como número seco, sem "recorde!",
//    sem cor de destaque, sem animação. Ver é diferente de comemorar.
//
// 3. **`AvisoDeApoio` FICA NO RODAPÉ, SEMPRE.** É o mesmo componente do chat, do
//    humor e do Livre de Vícios (`Shared/ApoioEmCrise.swift`), com a mesma tela
//    regionalizada — 1411 em Portugal, 188 no Brasil. Não foi criada outra, e
//    não pode ser: número de apoio duplicado é número de apoio que envelhece em
//    dois lugares. E não é condicional, pelo argumento escrito naquele arquivo:
//    a camada funciona PORQUE não detecta nada.
//
// 4. **ENCERRAR É UM TOQUE.** Sem "tem certeza?", sem tela de confirmação, sem
//    aviso de que a sequência vai quebrar. Um app que dificulta parar de jejuar
//    é um app que empurra para continuar jejuando.
//
// ═══════════════════════════════════════════════════════════════════════════
// O CRONÔMETRO NÃO É UM `Timer`
//
// `TimelineView(.periodic(by: 1))` redesenha sozinho e para quando a tela sai
// de cena. Um `Timer.publish` guardado em `@State` continua vivo em segundo
// plano, gasta bateria e — pior — não é a FONTE do número: a fonte é
// `JejumEmCurso.decorrido(agora:)`, que lê o relógio de parede. O que a tela
// faz é redesenhar; o que o modelo faz é contar. Com `Timer`, o número dependia
// de a tela ter ficado aberta, e é assim que se escreve um cronômetro que
// "atrasa" depois de o app ficar em segundo plano.

import SwiftUI

// MARK: - Card dentro da Dieta

/// O jejum na aba Dieta. É por aqui que o módulo é alcançado — ele mora DENTRO
/// da Dieta, não ao lado dela, porque a janela alimentar e o que se come na
/// janela são a mesma decisão.
struct JejumCard: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var jejum = JejumStore.shared
    @State private var abrirModulo = false

    var body: some View {
        Button { abrirModulo = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .foregroundStyle(Theme.violet)
                        .frame(width: 46, height: 46)
                        .background(Theme.violet.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Jejum intermitente")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(subtitulo)
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Spacer(minLength: 8)

                    if let atual = jejum.emCurso {
                        // TimelineView aqui também: o card fica visível enquanto
                        // a pessoa mexe na Dieta, e um número parado ao lado de
                        // um cronômetro que corre é pior que nenhum número.
                        TimelineView(.periodic(from: .now, by: 1)) { contexto in
                            ProgressRing(progress: min(1, atual.progresso(agora: contexto.date)),
                                         tint: Theme.violet, lineWidth: 7, icon: nil)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.inkSoft.opacity(0.6))
                    }
                }

                if let atual = jejum.emCurso {
                    TimelineView(.periodic(from: .now, by: 1)) { contexto in
                        let decorrido = atual.decorrido(agora: contexto.date)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(textoDaDuracao(decorrido, comSegundos: true))
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(Theme.ink)
                            Text("de \(textoDaDuracao(atual.protocolo.duracaoDoJejum))")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                            Spacer()
                            if atual.estaPausado {
                                Pill(text: "Pausado", tint: Theme.gold)
                            } else if atual.metaAtingida(agora: contexto.date) {
                                Pill(text: "Meta atingida", tint: Theme.primary)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .cardStyle()
        .fullScreenCover(isPresented: $abrirModulo) {
            JejumView().environmentObject(model)
        }
    }

    private var subtitulo: String {
        guard let atual = jejum.emCurso else {
            let seq = jejum.sequenciaEmDias
            if seq > 0 { return "Janela alimentar · \(seq) \(seq == 1 ? "dia" : "dias") de sequência" }
            return "Toque para escolher um protocolo"
        }
        return atual.estaPausado
            ? "\(atual.protocolo.rotulo) · pausado"
            : "\(atual.protocolo.rotulo) · em curso"
    }
}

// MARK: - Tela do módulo

struct JejumView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var jejum = JejumStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var aba: AbaDoJejum
    @State private var mostrarApoio = false
    @State private var mostrarAvisoDeSaude = false
    @State private var mostrarQuebra = false
    @State private var protocoloEscolhido: ProtocoloDeJejum = .dezesseisPorOito

    enum AbaDoJejum: String, CaseIterable, Identifiable {
        case cronometro = "Jejum"
        case saber = "Saber mais"
        case historico = "Histórico"
        var id: String { rawValue }
    }

    /// `abaInicial` existe para a conferência visual conseguir capturar as três
    /// seções — `@State` privado não é alcançável de fora, e sem isto duas das
    /// telas do módulo nunca apareceriam num print. Uso normal não passa nada.
    init(abaInicial: AbaDoJejum = .cronometro) {
        _aba = State(initialValue: abaInicial)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenHeader(title: "Jejum", subtitle: "Cronômetro e registro da sua janela")

                    Picker("Seção", selection: $aba) {
                        ForEach(AbaDoJejum.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch aba {
                    case .cronometro: secaoCronometro
                    case .saber:      secaoSaberMais
                    case .historico:  secaoHistorico
                    }

                    rodape
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            // O aviso de saúde aparece UMA vez, no primeiro acesso. Depois vive
            // na aba "Saber mais" — informar uma vez é diferente de esconder.
            .onAppear {
                protocoloEscolhido = jejum.protocoloPreferido
                if !jejum.avisoDeSaudeVisto { mostrarAvisoDeSaude = true }
            }
            .sheet(isPresented: $mostrarApoio) { ApoioEmCriseView() }
            .sheet(isPresented: $mostrarAvisoDeSaude) {
                AvisoDeSaudeDoJejum { jejum.marcarAvisoDeSaudeComoVisto() }
                    .environmentObject(model)
            }
            .sheet(isPresented: $mostrarQuebra) {
                QuebraDeJejumView(duracao: duracaoParaQuebra).environmentObject(model)
            }
        }
    }

    /// A duração que a sugestão de quebra deve considerar. Vem do jejum em
    /// curso; se não houver, do último encerrado — porque a pessoa pode abrir a
    /// quebra logo depois de encerrar.
    private var duracaoParaQuebra: TimeInterval {
        if let atual = jejum.emCurso { return atual.decorrido() }
        return jejum.historico.first?.duracao ?? 0
    }

    // MARK: Cronômetro

    @ViewBuilder
    private var secaoCronometro: some View {
        if let atual = jejum.emCurso {
            cronometroAtivo(atual)
        } else {
            escolhaDeProtocolo
        }
        sequenciaCard
    }

    private func cronometroAtivo(_ atual: JejumEmCurso) -> some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 1)) { contexto in
                let agora = contexto.date
                let decorrido = atual.decorrido(agora: agora)
                let atingiu = atual.metaAtingida(agora: agora)

                VStack(spacing: 14) {
                    ZStack {
                        ProgressRing(progress: min(1, atual.progresso(agora: agora)),
                                     tint: atingiu ? Theme.primary : Theme.violet,
                                     lineWidth: 14, icon: nil)
                            .frame(width: 210, height: 210)
                        VStack(spacing: 4) {
                            Text(textoDaDuracao(decorrido, comSegundos: true))
                                .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Theme.ink)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text(atual.protocolo.rotulo)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // O texto de estado. Repare no que ele NÃO diz quando a
                    // meta é atingida: não parabeniza pela duração e não
                    // convida a seguir. Diz que chegou e oferece quebrar.
                    if atual.estaPausado {
                        Text("Pausado em \(textoDaDuracao(decorrido)). Retome quando quiser.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    } else if atingiu {
                        Text("Você chegou à meta de \(textoDaDuracao(atual.protocolo.duracaoDoJejum)).")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primary)
                            .multilineTextAlignment(.center)
                    } else if let previsao = atual.previsaoDeTermino(agora: agora) {
                        Text("Faltam \(textoDaDuracao(atual.restante(agora: agora))) · termina às \(horaCurta(previsao))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }

                    // ── A ÚNICA LINHA CONDICIONAL DO MÓDULO ────────────────
                    //
                    // Acima de 24 h, uma linha discreta, uma vez, sem alarme e
                    // sem bloquear nada. Não é detecção de risco — é o mesmo
                    // convite do rodapé, aparecendo onde faz mais sentido. O
                    // rodapé continua lá independentemente disso.
                    if decorrido >= 24 * 3600 {
                        Text("Passou de 24 horas. Jejum longo costuma pedir acompanhamento médico. Se quiser falar com alguém, tem um caminho no rodapé desta tela.")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
            }

            // ── Ações ──────────────────────────────────────────────────────
            //
            // Duas, e nunca três. A terceira que não existe é "estender".
            HStack(spacing: 12) {
                Button {
                    atual.estaPausado ? jejum.retomar() : jejum.pausar()
                } label: {
                    Label(atual.estaPausado ? "Retomar" : "Pausar",
                          systemImage: atual.estaPausado ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surfaceAlt)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    mostrarQuebra = true
                } label: {
                    Label("Quebrar o jejum", systemImage: "fork.knife")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button("Comecei por engano — descartar") { jejum.descartar() }
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
        }
        .cardStyle()
    }

    private var escolhaDeProtocolo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Escolha um protocolo")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            ForEach(ProtocoloDeJejum.allCases) { proto in
                Button { protocoloEscolhido = proto } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: protocoloEscolhido == proto
                              ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundStyle(protocoloEscolhido == proto ? Theme.violet : Theme.inkSoft.opacity(0.5))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(proto.rotulo)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                if let janela = proto.horasDeJanela {
                                    Text("janela de \(Int(janela)) h")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            Text(proto.detalhe)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button {
                jejum.iniciar(protocoloEscolhido)
            } label: {
                Label("Começar agora", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.violet)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Toggle(isOn: $jejum.notificacoesLigadas) {
                Text("Avisar quando a janela abrir e fechar")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
            }
            .tint(Theme.violet)
        }
        .cardStyle()
    }

    private var sequenciaCard: some View {
        let seq = jejum.sequenciaEmDias
        let stats = jejum.estatisticas
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sua constância")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if seq > 0 {
                    Pill(text: "\(seq) \(seq == 1 ? "dia" : "dias")", tint: Theme.primary)
                }
            }
            // O texto explica a régua de propósito: quem lê entende que não há
            // ponto extra por jejuar mais tempo, e por isso não tenta.
            Text(seq > 0
                 ? "Dias seguidos em que você fechou a janela. Um 16/8 vale o mesmo que um OMAD: aqui a conta é de constância, não de duração."
                 : "A sequência conta os dias em que você fechou a janela. Um 16/8 vale o mesmo que um OMAD.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if stats.total > 0 {
                Divider().padding(.vertical, 2)
                HStack(spacing: 18) {
                    resumo("Registros", "\(stats.total)")
                    resumo("Na meta", "\(stats.cumpriramAMeta)")
                    if let media = stats.mediaDosUltimos7 {
                        resumo("Média 7 dias", textoDaDuracao(media))
                    }
                }
            }
        }
        .cardStyle()
    }

    private func resumo(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valor)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(titulo)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: Saber mais

    private var secaoSaberMais: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Dicas práticas primeiro: é o que a pessoa veio buscar.
            VStack(alignment: .leading, spacing: 14) {
                Text("Dicas").font(.headline).foregroundStyle(Theme.ink)
                ForEach(JejumConteudo.dicas) { dica in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: dica.simbolo)
                            .font(.footnote)
                            .foregroundStyle(Theme.violet)
                            .frame(width: 26, height: 26)
                            .background(Theme.violet.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dica.titulo)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(dica.corpo)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("O que os estudos mostram")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("O que foi medido em pesquisa. Não é previsão sobre você. O rótulo de cada card diz o quanto dá para afirmar.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(JejumConteudo.oQueALiteraturaObserva) { afirmacao in
                AfirmacaoCard(afirmacao: afirmacao)
            }

            AfirmacaoCard(afirmacao: JejumConteudo.sobreAQuebra)

            Text("Fontes conferidas em \(jejumFontesConferidasEm).")
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)

            Button { mostrarAvisoDeSaude = true } label: {
                HStack {
                    Label("Quando não jejuar", systemImage: "exclamationmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .cardStyle()
        }
    }

    // MARK: Histórico

    private var secaoHistorico: some View {
        VStack(alignment: .leading, spacing: 14) {
            if jejum.historico.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nada registrado ainda")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Todo jejum que você encerra entra aqui, com o tempo que durou. Inclusive os que pararam antes da meta.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            } else {
                // O "mais longo" mora AQUI, no histórico, como número seco.
                // Sem selo, sem cor de conquista, sem "recorde". Ver a regra 2
                // no cabeçalho.
                let stats = jejum.estatisticas
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jejum mais longo registrado: \(textoDaDuracao(stats.maisLongo))")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(jejum.historico) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.protocolo.simbolo)
                            .font(.footnote)
                            .foregroundStyle(item.cumpriuAMeta ? Theme.primary : Theme.inkSoft)
                            .frame(width: 34, height: 34)
                            .background((item.cumpriuAMeta ? Theme.primary : Theme.inkSoft).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(textoDaDuracao(item.duracao))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text("\(item.protocolo.rotulo) · \(dataCurta(item.terminouEm))")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 0)
                        if item.cumpriuAMeta {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.primary.opacity(0.8))
                        }
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button("Apagar histórico do jejum") { jejum.apagarHistorico() }
                    .font(.caption)
                    .foregroundStyle(Theme.coral)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Rodapé

    private var rodape: some View {
        VStack(spacing: 10) {
            Text(JejumConteudo.disclaimer)
                .font(.caption2)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // Reutilizado, não reescrito. Ver a regra 3 no cabeçalho.
            AvisoDeApoio { mostrarApoio = true }
        }
        .padding(.top, 6)
    }

    // MARK: Formatação de data

    private func horaCurta(_ data: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f.string(from: data)
    }

    private func dataCurta(_ data: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d 'de' MMM, HH:mm"
        return f.string(from: data)
    }
}

// MARK: - Card de afirmação

/// Uma afirmação com o rótulo de força e a fonte. O rótulo NÃO é decoração: é o
/// que separa "ensaio randomizado" de "estudo em camundongo", e sem ele as duas
/// coisas viram "estudos mostram".
struct AfirmacaoCard: View {
    let afirmacao: AfirmacaoComFonte

    private var corDaForca: Color {
        switch afirmacao.forca {
        case .consolidado: return Theme.primary
        case .misto:       return Theme.gold
        case .preliminar:  return Theme.inkSoft
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(afirmacao.titulo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Pill(text: afirmacao.forca.rotulo, tint: corDaForca)
            }

            Text(afirmacao.forca.explicacao)
                .font(.caption2)
                .foregroundStyle(corDaForca)

            Text(afirmacao.corpo)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(afirmacao.fonte)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = URL(string: afirmacao.url) {
                    Link(destination: url) {
                        Label("Ver a fonte", systemImage: "arrow.up.right.square")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.azure)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Aviso de saúde (contraindicações)

/// "Informe de forma clara e sem drama, uma vez, e siga."
///
/// Não pergunta nada. O app já sabe sexo, gravidez, peso e altura — e
/// `destaques` usa isso só para ORDENAR, subindo a linha que se aplica. Nenhum
/// dado sai daqui, nada é gravado, e nada é bloqueado: quem quiser jejuar,
/// jejua. A tela informa; a decisão continua sendo de quem lê.
struct AvisoDeSaudeDoJejum: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var aoConfirmar: () -> Void = {}

    /// As chaves que se aplicam ao que o app já sabe. Sobem para o topo.
    private var destaques: Set<JejumConteudo.ChaveDeContraindicacao> {
        var s: Set<JejumConteudo.ChaveDeContraindicacao> = []
        // Gravidez: o próprio app tem o Modo Gravidez, no Keychain.
        if FeminineHealthSecureStore.pregnancyMode { s.insert(.gravidezEAmamentacao) }
        // Peso muito baixo: IMC < 18,5, e só quando há as duas medidas. Sem
        // medida não há IMC, e um IMC inventado destacaria a linha errada.
        if model.weightKg > 0, model.heightCm > 0 {
            let m = model.heightCm / 100
            if model.weightKg / (m * m) < 18.5 { s.insert(.pesoMuitoBaixo) }
        }
        return s
    }

    private var ordenadas: [JejumConteudo.ChaveDeContraindicacao] {
        let d = destaques
        return JejumConteudo.contraindicacoesEmOrdem.sorted { a, b in
            d.contains(a) && !d.contains(b)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Jejuar não serve para todo mundo. Em algumas situações não é seguro. Leia uma vez e siga.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(ordenadas, id: \.self) { chave in
                        if let item = JejumConteudo.contraindicacoes[chave] {
                            let destacado = destaques.contains(chave)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.titulo)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                    Spacer(minLength: 4)
                                    if destacado {
                                        Pill(text: "pode ser o seu caso", tint: Theme.gold)
                                    }
                                }
                                Text(item.corpo)
                                    .font(.caption)
                                    .foregroundStyle(Theme.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(destacado ? Theme.gold.opacity(0.10) : Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Text(JejumConteudo.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Quando não jejuar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entendi") {
                        aoConfirmar()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    JejumView().environmentObject(AppModel())
}
