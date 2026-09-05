// testes_jejum_watch.swift
// Asserções sobre o contrato do jejum no pulso (AlmaWatch/JejumNoPulso.swift).
//
// Compilado como main.swift junto com o arquivo de produção — ver
// `rodar_testes_jejum_watch.sh`. Nenhuma asserção encosta em UserDefaults
// (Regra 4 do CLAUDE.md): só as funções puras entram aqui.
//
// O canário do fim é obrigatório (Regra 2): uma checagem que TEM de reprovar,
// verificada na própria execução. Se ela passar, o detector está cego e o
// resultado inteiro é descartado com exit 2.

import Foundation

var falhas = 0
func checa(_ nome: String, _ ok: Bool) {
    if ok { print("✓ \(nome)") } else { falhas += 1; print("✗ \(nome)") }
}

// MARK: A — validade do par (base, meta)
// Valores nada redondos de propósito; nenhum coincide com fallback algum
// (Regra 1.1: valor de teste igual ao padrão é asserção cega por construção).

checa("V1 base 0 é inválida", !JejumNoPulso.valido(base: 0, meta: 1_756_400_000))
checa("V2 meta igual à base é inválida", !JejumNoPulso.valido(base: 1_756_400_000, meta: 1_756_400_000))
checa("V3 meta antes da base é inválida", !JejumNoPulso.valido(base: 1_756_400_000, meta: 1_756_399_999))
checa("V4 par são é válido", JejumNoPulso.valido(base: 1_756_400_000, meta: 1_756_457_600))
checa("V5 base negativa é inválida", !JejumNoPulso.valido(base: -7, meta: 11))

// MARK: B — fração congelada na pausa

let b = Date(timeIntervalSince1970: 1_756_400_000)
let m = b.addingTimeInterval(16 * 3600)   // meta de 16 h

checa("F1 metade do caminho = 0,5",
      JejumNoPulso.fracaoCongelada(base: b, meta: m, pausadoEm: b.addingTimeInterval(8 * 3600)) == 0.5)
checa("F2 além da meta trava em 1",
      JejumNoPulso.fracaoCongelada(base: b, meta: m, pausadoEm: b.addingTimeInterval(20 * 3600)) == 1)
checa("F3 pausa antes da base trava em 0",
      JejumNoPulso.fracaoCongelada(base: b, meta: m, pausadoEm: b.addingTimeInterval(-3600)) == 0)
checa("F4 meta igual à base não divide por zero",
      JejumNoPulso.fracaoCongelada(base: b, meta: b, pausadoEm: b.addingTimeInterval(60)) == 0)

// MARK: C — Estado: decorrido e meta

let corrida = JejumNoPulso.Estado(base: b, meta: m, pausadoEm: nil, rotulo: "16/8")
checa("E1 decorrido correndo = agora − base",
      corrida.decorrido(agora: b.addingTimeInterval(5_437)) == 5_437)
checa("E2 relógio acertado para trás não fica negativo",
      corrida.decorrido(agora: b.addingTimeInterval(-600)) == 0)
checa("E3 na meta exata, atingiu",
      corrida.atingiuAMeta(agora: m))
checa("E4 um segundo antes da meta, não atingiu",
      !corrida.atingiuAMeta(agora: m.addingTimeInterval(-1)))

let pausada = JejumNoPulso.Estado(base: b, meta: m,
                                  pausadoEm: b.addingTimeInterval(2 * 3600), rotulo: "16/8")
checa("E5 pausado congela o decorrido em pausadoEm − base",
      pausada.decorrido(agora: b.addingTimeInterval(10 * 3600)) == 2 * 3600)
checa("E6 pausado não atinge meta pelo relógio andando",
      !pausada.atingiuAMeta(agora: b.addingTimeInterval(30 * 3600)))

// MARK: D — textos (mesmo formato do textoDaDuracao do iPhone)

checa("T1 16 h", JejumNoPulso.textoDeDuracao(16 * 3600) == "16 h")
checa("T2 1 h 5 min", JejumNoPulso.textoDeDuracao(3_900) == "1 h 5 min")
checa("T3 45 min", JejumNoPulso.textoDeDuracao(45 * 60) == "45 min")
checa("T4 compacto em horas", JejumNoPulso.textoCompacto(12 * 3600 + 1_800) == "12h")
checa("T5 compacto em minutos", JejumNoPulso.textoCompacto(35 * 60) == "35m")
checa("T6 compacto negativo vira 0m", JejumNoPulso.textoCompacto(-42) == "0m")
checa("T7 cronômetro congelado 5:12:00", JejumNoPulso.cronometro(18_720) == "5:12:00")
checa("T8 cronômetro abaixo de 1 min", JejumNoPulso.cronometro(59) == "0:00:59")
checa("T9 cronômetro negativo vira 0:00:00", JejumNoPulso.cronometro(-5) == "0:00:00")

// MARK: Canário — TEM de reprovar. Se passar, o detector está cego.

let falhasAntesDoCanario = falhas
checa("CANÁRIO (este ✗ é esperado)", JejumNoPulso.valido(base: 0, meta: 0))
if falhas == falhasAntesDoCanario {
    print("✗✗ DETECTOR CEGO — o canário passou; resultado inteiro descartado")
    exit(2)
}
print("✓ detector vivo (o canário reprovou como devia)")
falhas = falhasAntesDoCanario   // o canário não conta como falha real

// MARK: Veredito

if falhas == 0 {
    print("VERDE: todas as asserções reais passaram")
    exit(0)
} else {
    print("VERMELHO: \(falhas) asserção(ões) reprovada(s)")
    exit(1)
}
