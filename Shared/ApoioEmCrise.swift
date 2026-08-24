import SwiftUI

/// O apoio em crise, sempre à mão — sem detecção nenhuma.
///
/// ── POR QUE ESTA É A CAMADA MAIS IMPORTANTE ────────────────────────────────
/// O bloco de crise do prompt (`functions/src/apoioEmCrise.ts`) melhora muito a
/// média das respostas, mas é instrução, não garantia: o chat roda com
/// `temperature: 0.85` num modelo pequeno. Esta tela é a única camada que **não
/// depende de o modelo acertar** — e, por não detectar nada, tem falso positivo
/// IMPOSSÍVEL. Não interrompe conversa de ninguém, não julga, não aparece de
/// repente. Fica lá.
///
/// A alternativa que foi considerada e rejeitada: filtro por palavra-chave na
/// mensagem do usuário. Uma lista com "morrer", "sumir", "não aguento mais"
/// dispara em "morri de vergonha", em quem fala do luto do pai e em quem conta
/// o enredo de um filme. Num app de bem-estar, interromper essas conversas
/// ensina a pessoa que o app entra em pânico — e ela para de trazer o assunto
/// difícil. Quem mais precisa vira quem aprende a se calar.
///
/// ── OS NÚMEROS ─────────────────────────────────────────────────────────────
/// Conferidos em 22/08/2026. O 1411 de Portugal é RECENTE — criado em setembro
/// de 2025; qualquer texto anterior a essa data está desatualizado. Se for
/// revisar, confira de novo em vez de confiar neste comentário: linha de apoio
/// muda, e este arquivo é do tipo que envelhece calado.
enum ApoioEmCrise {

    struct Recurso {
        let titulo: String
        let corpo: String
    }

    /// O recurso do país da pessoa.
    ///
    /// Região desconhecida cai no genérico, que é seguro em qualquer lugar.
    /// Nunca mostrar o número do outro país.
    static func recursoDoPais(
        _ regiao: String? = Locale.current.region?.identifier
    ) -> Recurso {
        switch regiao?.uppercased() {
        case "PT":
            return Recurso(
                titulo: "Se você está em sofrimento intenso",
                corpo: """
                A Alma é apoio de bem-estar e não substitui acompanhamento médico, \
                psicológico ou psiquiátrico. Falar com alguém preparado ajuda, e é gratuito.

                1411 — Linha Nacional de Prevenção do Suicídio
                24 horas, todos os dias. Psicólogos e enfermeiros especializados.

                808 24 24 24 — SNS 24, aconselhamento psicológico

                112 — se houver perigo de vida imediato
                """
            )

        case "BR":
            return Recurso(
                titulo: "Se você está em sofrimento intenso",
                corpo: """
                A Alma é apoio de bem-estar e não substitui acompanhamento médico, \
                psicológico ou psiquiátrico. Falar com alguém preparado ajuda, e é gratuito.

                188 — CVV, Centro de Valorização da Vida
                24 horas, todos os dias. Ligação gratuita, sigilosa e anônima.
                Também por chat em cvv.org.br

                192 — se houver perigo de vida imediato
                """
            )

        default:
            return Recurso(
                titulo: "Se você está em sofrimento intenso",
                corpo: """
                A Alma é apoio de bem-estar e não substitui acompanhamento médico, \
                psicológico ou psiquiátrico.

                findahelpline.com encontra a linha de apoio do seu país, de graça.

                Em caso de perigo de vida imediato, ligue para a emergência local.
                """
            )
        }
    }
}

/// A linha discreta do rodapé do chat. Uma frase, sempre visível, sem alarme.
///
/// O texto NÃO menciona crise nem risco de propósito: um rótulo alarmante no
/// rodapé de uma conversa comum é ruído para 99% das pessoas e constrangimento
/// para a que precisa. "Precisa falar com alguém agora?" é convite, não aviso.
struct LinkDeApoio: View {
    let acao: () -> Void

    var body: some View {
        Button(action: acao) {
            Text("Precisa falar com alguém agora?")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Abre as linhas de apoio do seu país")
    }
}

/// Aviso curto + link, para as telas que ainda não têm disclaimer próprio.
///
/// O chat usa só o `LinkDeApoio` (a conversa não é registro clínico). Aqui vão
/// os dois juntos — check-in de humor e Livre de Vícios, que no iOS não tinham
/// aviso nenhum.
///
/// ── POR QUE NÃO É CONDICIONAL ──────────────────────────────────────────────
/// No check-in de humor existe um sinal que o chat não tem: a pessoa ESCOLHE um
/// estado, e daria para mostrar isto só no extremo negativo. Foi considerado e
/// rejeitado, por três motivos:
///
///  1. o link vira sinal. A pessoa aprende que marcar "muito mal" faz o app
///     reagir — e passa a marcar menos mal do que está, para não ser tratada
///     como caso. Aí some justamente o registro honesto, que é o motivo de a
///     tela existir;
///  2. é um detector com os mesmos falsos positivos de sempre, só que mudados
///     de texto para toque: um dia ruim de trabalho vira tela de crise;
///  3. contraria o argumento inteiro que fez esta camada valer a pena. Ela
///     funciona PORQUE não detecta nada.
struct AvisoDeApoio: View {
    let acao: () -> Void

    init(acao: @escaping () -> Void) { self.acao = acao }

    var body: some View {
        VStack(spacing: 0) {
            Text("A Alma é apoio de bem-estar, não atendimento de saúde.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            LinkDeApoio(acao: acao)
        }
    }
}

/// A tela do recurso, aberta pelo `LinkDeApoio`.
struct ApoioEmCriseView: View {
    @Environment(\.dismiss) private var dismiss
    var recurso = ApoioEmCrise.recursoDoPais()

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(recurso.corpo)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(recurso.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
