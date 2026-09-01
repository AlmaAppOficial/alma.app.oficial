import Foundation

// MARK: - Áudio do dia — regras PURAS (2026-08-31)
//
// Sem I/O e sem import além de Foundation, DE PROPÓSITO: é o que permite ao
// harness (`_scripts/teste_audio_do_dia.swift`) compilar este arquivo de
// produção com `swiftc` em segundos e exercitar cada regra por mutação —
// mesmo desenho do `RegrasDeSaude.swift` (fisiologia, 14/08).
//
// Quem consome: a caixa da Início (`HomeView.swift` — modelo e view) e a
// seção de Preferências do Perfil (`ProfileView.swift` — NotificationPrefs).
// O lado do servidor destas mesmas regras vive em
// `audio-do-dia/functions/src/fuso.ts` e `notificacaoDiaria.ts`, provado no
// emulador em 29/08 (51 asserções, 12/12 mutações).

/// O ponteiro `audio_do_dia/atual` decodificado. Só nasce válido: quem monta
/// é `AudioDoDiaRegras.decodificar`, que recusa URL vazia ou não-http(s).
struct AudioDoDia: Equatable {
    let downloadUrl: String
    let titulo: String
    let duracaoSeg: Double
    /// Contrato da fase 2 (fila de ~20): STRING "YYYY-MM-DD", não Timestamp.
    /// `nil` em doc anterior ao campo — tratado como elegível.
    let publicarEmDia: String?
}

enum AudioDoDiaRegras {

    /// O título que o servidor grava quando o Assis não põe um editorial.
    /// A caixa usa isto para não desenhar a mesma linha duas vezes.
    static let tituloPadrao = "Áudio do dia"

    /// Data local "YYYY-MM-DD" no fuso dado — espelho do `dataLocalISO` do
    /// servidor (fuso.ts). `Calendar` em vez de `DateFormatter` de propósito:
    /// imune a locale de 12h e a truques de formatação regional.
    static func dataLocalISO(_ data: Date = Date(), fuso: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fuso
        let c = cal.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// O dia editorial já chegou no relógio DESTA pessoa? Espelho do
    /// `inicioEditorial` do servidor (fuso.ts): áudio de dia futuro não
    /// aparece nem é anunciado antes do dia. Comparação de string funciona
    /// porque ISO ordena lexicograficamente. Campo ausente (doc anterior à
    /// fase 2) = elegível — mesma leitura tolerante do servidor
    /// (notificacaoDiaria.ts trata doc antigo como "dia do envio").
    static func elegivelHoje(publicarEmDia: String?, hojeLocalISO: String) -> Bool {
        guard let dia = publicarEmDia, !dia.isEmpty else { return true }
        return dia <= hojeLocalISO
    }

    /// Decodifica o doc do Firestore. Devolve `nil` (caixa não desenhada) se
    /// não houver `downloadUrl` http(s) válida — um ponteiro sem URL tocável
    /// não é um áudio, é lixo, e lixo não vira tela.
    static func decodificar(_ dados: [String: Any]?) -> AudioDoDia? {
        guard let dados,
              let url = dados["downloadUrl"] as? String,
              let parsed = URL(string: url),
              parsed.scheme == "https" || parsed.scheme == "http"
        else { return nil }
        let titulo = (dados["titulo"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? tituloPadrao
        // Números do Firestore chegam como NSNumber (Int64 OU Double) — o
        // cast direto `as? Double` falharia para inteiros.
        let duracao = (dados["duracaoSeg"] as? NSNumber)?.doubleValue ?? 0
        return AudioDoDia(
            downloadUrl: url,
            titulo: titulo,
            duracaoSeg: max(0, duracao),
            publicarEmDia: dados["publicarEmDia"] as? String
        )
    }

    /// "5:12" a partir de segundos — rótulo de duração da caixa.
    static func mmss(_ segundos: Double) -> String {
        let s = max(0, Int(segundos.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Semântica dos botões de aviso (feed E Áudio do dia), idêntica à do
/// servidor (`notifyNewFeedPost` e o agendador `audioDoDiaNotificacao`):
/// campo AUSENTE no doc = ligado; só `false` desliga.
enum PrefsDeNotificacaoRegras {
    static func ligado(_ valorNoDoc: Bool?) -> Bool {
        valorNoDoc != false
    }
}
