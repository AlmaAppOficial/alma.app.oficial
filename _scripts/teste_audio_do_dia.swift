// [2026-08-31] Asserções do Áudio do dia contra o código de PRODUÇÃO de
// `Shared/AudioDoDiaRegras.swift`. Compilado e executado por
// `_scripts/rodar_teste_audio_do_dia.sh` (copia para main.swift — mesmo
// desenho do teste_fisiologia.swift, e pelo mesmo motivo).
//
// Regra 1.1 do CLAUDE.md: nenhum valor de teste coincide com o padrão de
// fallback — título "Mensagem de 29/08" (o padrão é "Áudio do dia"),
// duração 312 (o padrão é 0), dias que nenhum fallback gera.
//
// Saída: 0 = verde · 1 = vermelho · 2 = DETECTOR CEGO (canário passou).

import Foundation

var passaram = 0
var falhas: [String] = []

func checa(_ id: String, _ descricao: String, _ cond: Bool) {
    if cond {
        passaram += 1
        print("  ✓ \(id) \(descricao)")
    } else {
        falhas.append(id)
        print("  ✗ \(id) \(descricao)")
    }
}

// ── A. PrefsDeNotificacaoRegras.ligado — "ausente = ligado" ─────────────────
print("── A. ausente = ligado (semântica do servidor) ──")
checa("A1", "campo AUSENTE (nil) = ligado", PrefsDeNotificacaoRegras.ligado(nil) == true)
checa("A2", "false desliga", PrefsDeNotificacaoRegras.ligado(false) == false)
checa("A3", "true liga", PrefsDeNotificacaoRegras.ligado(true) == true)

// ── B. elegivelHoje — o dia editorial (contrato da fase 2) ──────────────────
print("── B. dia editorial ──")
checa("B1", "sem publicarEmDia (doc antigo) = elegível",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: nil, hojeLocalISO: "2026-08-31"))
checa("B2", "publicarEmDia vazio = elegível",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "", hojeLocalISO: "2026-08-31"))
checa("B3", "dia passado = elegível",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "2026-08-30", hojeLocalISO: "2026-08-31"))
checa("B4", "o próprio dia = elegível",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "2026-08-31", hojeLocalISO: "2026-08-31"))
checa("B5", "dia FUTURO segura a caixa (fase 2)",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "2026-09-01", hojeLocalISO: "2026-08-31") == false)
checa("B6", "virada de ano ordena certo (2027-01-01 > 2026-12-31)",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "2027-01-01", hojeLocalISO: "2026-12-31") == false)

// ── C. dataLocalISO — o "hoje" depende do FUSO, não do relógio UTC ──────────
print("── C. data local por fuso ──")
let iso = ISO8601DateFormatter()
// 02:30 UTC de 31/08: Lisboa (UTC+1 no verão) já está no dia 31;
// São Paulo (UTC−3) ainda está no dia 30. Mesmo instante, dias diferentes —
// é exatamente a diferença que o agendador das 6h locais explora.
let instante = iso.date(from: "2026-08-31T02:30:00Z")!
checa("C1", "Lisboa, 02:30Z → 2026-08-31",
      AudioDoDiaRegras.dataLocalISO(instante, fuso: TimeZone(identifier: "Europe/Lisbon")!) == "2026-08-31")
checa("C2", "São Paulo, MESMO instante → 2026-08-30",
      AudioDoDiaRegras.dataLocalISO(instante, fuso: TimeZone(identifier: "America/Sao_Paulo")!) == "2026-08-30")
// Kathmandu (+5:45, o fuso de :45): 18:20Z de 31/08 já é 00:05 de 01/09 lá.
let tarde = iso.date(from: "2026-08-31T18:20:00Z")!
checa("C3", "Kathmandu (+5:45), 18:20Z → 2026-09-01",
      AudioDoDiaRegras.dataLocalISO(tarde, fuso: TimeZone(identifier: "Asia/Kathmandu")!) == "2026-09-01")
let janeiro = iso.date(from: "2026-01-05T12:00:00Z")!
checa("C4", "zeros à esquerda (2026-01-05, não 2026-1-5)",
      AudioDoDiaRegras.dataLocalISO(janeiro, fuso: TimeZone(identifier: "UTC")!) == "2026-01-05")

// ── D. decodificar — lixo não vira tela ─────────────────────────────────────
print("── D. decodificação do ponteiro ──")
checa("D1", "doc ausente (nil) → caixa não desenhada",
      AudioDoDiaRegras.decodificar(nil) == nil)
checa("D2", "sem downloadUrl → nil",
      AudioDoDiaRegras.decodificar(["titulo": "x"]) == nil)
checa("D3", "downloadUrl vazia → nil",
      AudioDoDiaRegras.decodificar(["downloadUrl": ""]) == nil)
checa("D4", "esquema não-http (ftp) → nil",
      AudioDoDiaRegras.decodificar(["downloadUrl": "ftp://h/a.m4a"]) == nil)

let docCompleto: [String: Any] = [
    "downloadUrl": "https://firebasestorage.googleapis.com/v0/b/x/o/a.m4a?alt=media&token=t",
    "titulo": "Mensagem de 29/08",
    "duracaoSeg": 312,          // Int de propósito: prova o caminho NSNumber
    "publicarEmDia": "2026-08-29",
]
let d5 = AudioDoDiaRegras.decodificar(docCompleto)
checa("D5a", "doc completo decodifica", d5 != nil)
checa("D5b", "título editorial preservado (≠ padrão)", d5?.titulo == "Mensagem de 29/08")
checa("D5c", "duracaoSeg INTEIRO vira 312.0 (NSNumber, não `as? Double`)",
      d5?.duracaoSeg == 312.0)
checa("D5d", "publicarEmDia preservado como STRING", d5?.publicarEmDia == "2026-08-29")

checa("D6", "sem título → padrão \"Áudio do dia\"",
      AudioDoDiaRegras.decodificar(["downloadUrl": "https://h/a.m4a"])?.titulo == "Áudio do dia")
checa("D7", "título vazio → padrão",
      AudioDoDiaRegras.decodificar(["downloadUrl": "https://h/a.m4a", "titulo": ""])?.titulo == "Áudio do dia")
checa("D8", "duração NEGATIVA clampa em 0",
      AudioDoDiaRegras.decodificar(["downloadUrl": "https://h/a.m4a", "duracaoSeg": -5])?.duracaoSeg == 0)
checa("D9", "duração fracionária preservada (12.5)",
      AudioDoDiaRegras.decodificar(["downloadUrl": "https://h/a.m4a", "duracaoSeg": 12.5])?.duracaoSeg == 12.5)
checa("D10", "http simples é aceito (emulador serve por http)",
      AudioDoDiaRegras.decodificar(["downloadUrl": "http://127.0.0.1:9199/v0/b/x/o/a.m4a"]) != nil)

// ── E. mmss — o rótulo de duração ───────────────────────────────────────────
print("── E. mm:ss ──")
checa("E1", "312 s → 5:12", AudioDoDiaRegras.mmss(312) == "5:12")
checa("E2", "0 → 0:00", AudioDoDiaRegras.mmss(0) == "0:00")
checa("E3", "59.6 arredonda para 1:00", AudioDoDiaRegras.mmss(59.6) == "1:00")
checa("E4", "negativo clampa em 0:00", AudioDoDiaRegras.mmss(-3) == "0:00")
checa("E5", "3599 → 59:59 (segundo com 2 dígitos)", AudioDoDiaRegras.mmss(3599) == "59:59")

// ── Canário: o detector enxerga? ────────────────────────────────────────────
// Asserção DELIBERADAMENTE falsa passada pela MESMA máquina `checa`. Se ela
// não reprovar, o harness está cego e o resultado inteiro é descartado.
let falhasAntesDoCanario = falhas.count
checa("CANARIO", "dia 2099 elegível em 2026 (TEM de reprovar)",
      AudioDoDiaRegras.elegivelHoje(publicarEmDia: "2099-01-01", hojeLocalISO: "2026-08-31"))
if falhas.count == falhasAntesDoCanario + 1 {
    falhas.removeLast()
    passaram -= 0 // o canário não conta como asserção verde
    print("✓ detector vivo (o canário reprovou como devia)")
} else {
    print("✗✗ DETECTOR CEGO — o canário passou. Resultado inteiro DESCARTADO.")
    exit(2)
}

print("")
if falhas.isEmpty {
    print("VERDE — \(passaram) asserções passaram, canário vivo.")
    exit(0)
} else {
    print("VERMELHO — falharam: \(falhas.joined(separator: ", "))")
    exit(1)
}
