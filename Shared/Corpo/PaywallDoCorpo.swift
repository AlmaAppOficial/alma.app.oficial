// PaywallDoCorpo.swift
// Alma — Corpo · a única porta de compra do módulo
//
// [2026-08-03 — BUG B10 da revisão independente]
//
// O módulo Corpo mostrava o `CorpoPaywallView`, herdado do app Corpo & Alma.
// Ele pedia ao StoreKit os produtos:
//
//     com.almaapp.corpoealma.premium.annual
//     com.almaapp.corpoealma.premium.monthly
//
// …de dentro do binário do Alma, que vende `com.almaapp.app.premium_*`. O app
// Corpo & Alma foi descontinuado. Os dois desfechos possíveis eram ruins:
//
//   • se os IDs não existem no App Store Connect do Alma, `products` volta
//     vazio e a tela fica presa em "Tentar novamente" — exibindo preços em R$
//     chumbados no código. Beco sem saída de compra, e Guidelines 2.1 e 3.1.2.
//   • se existissem, seria uma SEGUNDA assinatura dentro do mesmo app, contra
//     a decisão de assinatura única que o Assis tomou em julho.
//
// Aqui o Corpo passa a usar a mesma porta de compra do resto do app: um
// produto, um preço, um lugar para gerenciar. Os cinco pontos que abriam
// paywall no Corpo (Início, Dieta, Treino, Saúde e Ajustes) apontam para cá.

import SwiftUI

struct PaywallDoCorpo: View {
    @EnvironmentObject private var access: AccessManager
    @EnvironmentObject private var storeAlma: StoreKitManager

    var body: some View {
        PremiumWallView()
            .environmentObject(access)
            .environmentObject(storeAlma)
    }
}
