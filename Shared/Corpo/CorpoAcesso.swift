// CorpoAcesso.swift
// Alma — Corpo · onde termina o grátis e começa o pago
//
// [2026-08-02] O freemium herdado do Corpo & Alma era severo demais: registrar
// uma refeição exigia assinatura. Até MARCAR uma refeição como feita abria o
// paywall. Na prática a aba Dieta inteira era uma parede para quem não pagava —
// e ninguém assina o que nunca conseguiu experimentar.
//
// A linha que este arquivo desenha é a mesma que o Assis já adotou no chat:
//
//   • O QUE CUSTA DINHEIRO OU PENSA POR VOCÊ → pago.
//     Escaneamento de alimento por IA (chamada paga a cada foto), plano
//     alimentar gerado, análises da Alma.
//
//   • O QUE É SÓ O SEU DIÁRIO → grátis.
//     Anotar o que comeu, marcar água, registrar peso, tomar suplemento.
//     Cobrar da pessoa para ela escrever no próprio caderno é hostil, mata a
//     retenção e ainda deixa a Alma cega: sem registro não há contexto, e sem
//     contexto o app não cumpre o que promete.
//
// Ponto único de decisão de propósito: quando a régua mudar, muda aqui — não em
// dezoito `if` espalhados pelas telas.

import Foundation

enum CorpoAcesso {

    /// Registro manual: sempre liberado. É o diário da pessoa.
    static let registroManualLiberado = true

    /// Recursos que consomem IA paga por uso.
    static func podeUsarIA(_ model: AppModel) -> Bool {
        model.hasPremiumAccess
    }

    /// Análises e planos gerados — valor agregado, não registro.
    static func podeVerAnalisesAvancadas(_ model: AppModel) -> Bool {
        model.hasPremiumAccess
    }

    /// Texto do convite quando um recurso pago é tocado. Explica o limite sem
    /// culpar a pessoa por não ter assinado.
    static let convitePremium = "Este recurso usa inteligência artificial e faz parte do plano completo."
}
