// TesteAudio.swift
// Alma — harness de reprodução de áudio
//
// [2026-08-04] Existe porque o build 89 subiu para o TestFlight e o Assis
// relatou "nenhuma das meditações ou sons ou músicas estão tocando". Build
// verde não prova som. Nenhuma verificação do projeto tocava um único byte de
// áudio — e áudio é a função central do produto.
//
// O QUE ESTE HARNESS PROVA
//   ✅ que o arquivo existe no bundle do build que está rodando;
//   ✅ que a AVAudioSession aceita ser configurada e ativada;
//   ✅ que o AVAudioPlayer inicia E QUE O TEMPO ANDA (currentTime > 0) —
//      `isPlaying == true` sozinho é fraco: ele fica true mesmo quando o
//      áudio está travado em 0,000s. Só o relógio andando prova reprodução.
//
// O QUE ELE NÃO PROVA
//   ❌ que sai som pelo alto-falante (volume, interruptor de silencioso,
//      rota de saída). Isso só o ouvido do Assis confirma.
//
// Roda com `-testeAudio 1`, só em DEBUG.

#if DEBUG
import Foundation
import AVFoundation

@MainActor
enum TesteAudio {

    static var ligado: Bool { UserDefaults.standard.bool(forKey: "testeAudio") }

    private static var aprovados = 0
    private static var reprovados: [String] = []

    private static func log(_ t: String) { NSLog("%@", "[AUDIO] " + t) }

    private static func checa(_ id: String, _ desc: String, _ ok: Bool, _ observado: String) {
        if ok {
            aprovados += 1
            log("✓ \(id) \(desc) — \(observado)")
        } else {
            reprovados.append("\(id) \(desc)")
            log("✗ \(id) \(desc) — OBSERVADO: \(observado)")
        }
    }

    /// Toca de verdade e mede se o relógio do player andou.
    private static func tocaDeVerdade(_ url: URL) async -> (iniciou: Bool, andou: Double, erro: String?) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 1.0
            p.prepareToPlay()
            let iniciou = p.play()
            try? await Task.sleep(nanoseconds: 900_000_000)   // 0,9 s
            let andou = p.currentTime
            p.stop()
            return (iniciou, andou, nil)
        } catch {
            return (false, 0, String(describing: error))
        }
    }

    static func executar() async {
        guard ligado else { return }
        aprovados = 0
        reprovados = []

        log("═════ TESTE DE ÁUDIO ═════")

        // ── estado da sessão, como o app a deixou ────────────────────────────
        let s = AVAudioSession.sharedInstance()
        log("sessão ANTES: categoria=\(s.category.rawValue) modo=\(s.mode.rawValue) " +
            "outroÁudio=\(s.isOtherAudioPlaying) saída=\(s.currentRoute.outputs.map(\.portType.rawValue))")

        // ── os arquivos estão no bundle DESTE build? ─────────────────────────
        let medURL = Bundle.main.url(forResource: "meditation_01", withExtension: "m4a")
        checa("AU1", "meditation_01.m4a existe no bundle",
              medURL != nil, medURL?.lastPathComponent ?? "NÃO ENCONTRADO")

        let musURL = Bundle.main.url(forResource: "mozart_k467", withExtension: "mp3")
        checa("AU2", "mozart_k467.mp3 existe no bundle",
              musURL != nil, musURL?.lastPathComponent ?? "NÃO ENCONTRADO")

        let sonURL = Bundle.main.url(forResource: "sleep_water", withExtension: "mp3")
        checa("AU3", "sleep_water.mp3 existe no bundle",
              sonURL != nil, sonURL?.lastPathComponent ?? "NÃO ENCONTRADO")

        // ── a sessão aceita ser ativada para tocar? ──────────────────────────
        var sessaoOK = false
        var sessaoErro = "—"
        do {
            try s.setCategory(.playback, mode: .spokenAudio, options: [])
            try s.setActive(true, options: .notifyOthersOnDeactivation)
            sessaoOK = true
        } catch {
            sessaoErro = String(describing: error)
        }
        checa("AU4", "AVAudioSession ativa em .playback", sessaoOK,
              sessaoOK ? "categoria=\(s.category.rawValue) modo=\(s.mode.rawValue)" : sessaoErro)

        // ── TOCA DE VERDADE ──────────────────────────────────────────────────
        // `isPlaying` sozinho mente: fica true com o tempo parado em 0,000.
        // A prova é o relógio andar.
        if let medURL {
            let r = await tocaDeVerdade(medURL)
            checa("AU5", "meditação toca E o tempo anda",
                  r.iniciou && r.andou > 0.1,
                  "play()=\(r.iniciou) avançou=\(String(format: "%.3f", r.andou))s" +
                  (r.erro.map { " erro=\($0)" } ?? ""))
        }

        if let musURL {
            let r = await tocaDeVerdade(musURL)
            checa("AU6", "música toca E o tempo anda",
                  r.iniciou && r.andou > 0.1,
                  "play()=\(r.iniciou) avançou=\(String(format: "%.3f", r.andou))s" +
                  (r.erro.map { " erro=\($0)" } ?? ""))
        }

        if let sonURL {
            let r = await tocaDeVerdade(sonURL)
            checa("AU7", "som ambiente toca E o tempo anda",
                  r.iniciou && r.andou > 0.1,
                  "play()=\(r.iniciou) avançou=\(String(format: "%.3f", r.andou))s" +
                  (r.erro.map { " erro=\($0)" } ?? ""))
        }

        // ── AU9/AU10 · O BUG DO BUILD 89 ─────────────────────────────────────
        //
        // Este é o teste que faltava. Todas as verificações acima configuram a
        // sessão antes de tocar — por isso passavam enquanto o aparelho do
        // Assis estava mudo. O bug real era de ESTADO DEIXADO PARA TRÁS: o
        // ditado punha a sessão em `.record` e não devolvia.
        //
        // Aqui exercitamos o caminho DE VERDADE: `VoiceInputController.stop()`,
        // o mesmo que o botão do microfone chama. Se alguém remover a restauração
        // de lá, AU9 e AU10 ficam vermelhas.
        let voz = VoiceInputController()
        try? s.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? s.setActive(true, options: .notifyOthersOnDeactivation)
        let durante = s.category.rawValue
        voz.stop()
        let depois = s.category.rawValue
        checa("AU9", "depois do ditado a sessão volta para .playback",
              s.category == .playback,
              "durante=\(durante) → depois=\(depois)")

        // A prova do usuário: gravou, parou, agora toca uma meditação.
        //
        // ⚠️ LIMITE MEDIDO DESTA ASSERÇÃO (mutação de 04/08): com a restauração
        // removida, AU9 ficou VERMELHA mas AU10 continuou VERDE — o simulador
        // deixa o player avançar mesmo com a sessão em `.record`. No APARELHO
        // isso é silêncio. Ou seja: quem pega este bug é o AU9 (a categoria),
        // não o AU10. O AU10 fica porque cobre outras falhas do caminho de
        // reprodução, mas NÃO se pode confiar nele para este defeito.
        if let medURL {
            let r = await tocaDeVerdade(medURL)
            checa("AU10", "meditação toca DEPOIS de um ciclo de ditado",
                  r.iniciou && r.andou > 0.1,
                  "categoria=\(s.category.rawValue) play()=\(r.iniciou) " +
                  "avançou=\(String(format: "%.3f", r.andou))s")
        }

        // ── CANÁRIO ──────────────────────────────────────────────────────────
        // Um arquivo que não existe TEM de ser acusado. Se este passar, o
        // detector está cego e nada acima vale.
        let fantasma = Bundle.main.url(forResource: "arquivo_que_nao_existe_de_proposito",
                                       withExtension: "m4a")
        let canarioAcusou = fantasma == nil
        checa("AU8", "canário — arquivo inexistente é detectado como ausente",
              canarioAcusou, canarioAcusou ? "acusou" : "DETECTOR CEGO")

        log("═════ RESULTADO ═════")
        log("aprovados: \(aprovados)")
        if reprovados.isEmpty {
            log("reprovados: NENHUM — o áudio INICIA e AVANÇA neste build")
            log("(isto não prova que sai som no alto-falante: volume, silencioso e rota ficam fora)")
        } else {
            log("REPROVADOS (\(reprovados.count)):")
            reprovados.forEach { log("   ✗ \($0)") }
        }
    }
}
#endif
