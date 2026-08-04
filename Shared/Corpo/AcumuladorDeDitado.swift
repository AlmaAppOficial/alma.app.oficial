// AcumuladorDeDitado.swift
// Alma — junta o que a pessoa fala em várias rodadas de ditado
//
// [2026-08-04] Terceira tentativa de matar este bug, e a primeira com a causa
// certa. Vale escrever a história inteira, porque errei duas vezes por não
// olhar o caminho real.
//
// O SINTOMA, narrado pelo próprio Assis enquanto gravava a tela:
//   "Se ficou algum segundo sem falar... a mensagem apagada."
// Cinco prints em sequência, o indicador de "ouvindo" aceso em TODOS — ele
// nunca tocou no botão. Cada frase nova substituía a anterior no campo.
//
// AS DUAS EXPLICAÇÕES ERRADAS QUE EU DEI ANTES:
//   1ª — "o código faz `transcript = ...` em vez de acumular". Verdade, mas
//        pus a acumulação dentro de `start()`, que só roda quando a pessoa
//        TOCA no microfone. Ela não tocou. A correção nunca foi executada.
//   2ª — "o `teardown()` no `isFinal` mata a gravação e a fala se perde".
//        Se matasse, não chegariam resultados novos. Chegam, um por frase.
//        Logo, `isFinal` não dispara nesse cenário.
//
// A CAUSA REAL: com `requiresOnDeviceRecognition = true`, o SFSpeechRecognizer
// segmenta por ENUNCIADO. Depois de uma pausa ele abre um enunciado novo, e o
// `bestTranscription.formattedString` passa a trazer só a fala nova — não o
// acumulado da sessão. Quem tem de juntar os enunciados é o app.
//
// A FRONTEIRA: enquanto o enunciado cresce, cada string nova ESTENDE a anterior
// ("Vou" → "Vou falar"). Quando o reconhecedor recomeça, a string nova não tem
// mais relação com a anterior ("Vou falar" → "Mas"). É esse salto que fecha o
// enunciado e o dobra no acumulado.
//
// Cuidado com a revisão: o reconhecedor corrige o final do que já disse
// ("Vou fala" → "Vou falar"), e isso NÃO é enunciado novo. Por isso a
// comparação é por prefixo COMUM proporcional, não por `hasPrefix` puro —
// uma revisão preserva quase todo o começo; um enunciado novo, não.

import Foundation

struct AcumuladorDeDitado {

    /// Enunciados já fechados, na ordem em que foram ditos.
    private(set) var acumulado = ""
    /// O último texto que o reconhecedor entregou para o enunciado em curso.
    private(set) var enunciadoAtual = ""

    /// Fração do texto anterior que precisa sobreviver no novo para que ainda
    /// seja considerado o MESMO enunciado (revisão) e não um começo do zero.
    static let limiarDeContinuidade = 0.6

    /// Recebe um `bestTranscription.formattedString` e devolve o texto completo
    /// que deve aparecer no campo.
    mutating func receber(_ novo: String) -> String {
        let anterior = enunciadoAtual

        if !anterior.isEmpty && !continua(novo: novo, anterior: anterior) {
            // O reconhecedor recomeçou: fecha o enunciado anterior.
            acumulado = juntar(acumulado, anterior)
        }
        enunciadoAtual = novo
        return juntar(acumulado, novo)
    }

    /// Fecha o que estiver em curso — usado quando a gravação para de vez.
    mutating func encerrar() -> String {
        acumulado = juntar(acumulado, enunciadoAtual)
        enunciadoAtual = ""
        return acumulado
    }

    /// Recomeça do zero (mensagem enviada, campo limpo).
    mutating func zerar() {
        acumulado = ""
        enunciadoAtual = ""
    }

    /// Semeia com o que já estava escrito no campo antes de ligar o microfone.
    mutating func semear(textoExistente: String) {
        acumulado = textoExistente.trimmingCharacters(in: .whitespacesAndNewlines)
        enunciadoAtual = ""
    }

    // MARK: - Regra

    /// `novo` é continuação/revisão de `anterior`?
    static func continua(novo: String, anterior: String) -> Bool {
        if anterior.isEmpty { return true }
        if novo.hasPrefix(anterior) { return true }          // cresceu
        let comum = tamanhoDoPrefixoComum(novo, anterior)
        return Double(comum) / Double(anterior.count) >= limiarDeContinuidade
    }

    private func continua(novo: String, anterior: String) -> Bool {
        Self.continua(novo: novo, anterior: anterior)
    }

    static func tamanhoDoPrefixoComum(_ a: String, _ b: String) -> Int {
        var n = 0
        var ia = a.startIndex, ib = b.startIndex
        while ia < a.endIndex, ib < b.endIndex, a[ia] == b[ib] {
            n += 1; ia = a.index(after: ia); ib = b.index(after: ib)
        }
        return n
    }

    private func juntar(_ a: String, _ b: String) -> String {
        let ea = a.trimmingCharacters(in: .whitespaces)
        let eb = b.trimmingCharacters(in: .whitespaces)
        if ea.isEmpty { return eb }
        if eb.isEmpty { return ea }
        return ea + " " + eb
    }
}
