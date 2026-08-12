//
//  stubs.swift — APENAS andaimes para o compilador.
//
//  O harness compila o ARQUIVO DE PRODUÇÃO `Shared/Corpo/AIBodyScan.swift`,
//  não uma cópia dele. Esse arquivo importa só Foundation, mas cita três
//  símbolos que moram em arquivos que arrastam UIKit e FirebaseAuth
//  (`AnaliseDeFotoService.swift`) ou SwiftUI (`Models.swift`) — e que o
//  swiftc de linha de comando não tem como carregar.
//
//  Então estes três são substituídos por andaimes. NADA aqui é o código sob
//  teste: `BodyAnalysis`, `BodyAnalysis.gorduraInformada`, o `init(from:)` e o
//  `MockAIPlanService` são os de produção, lidos direto do repo. Se alguém
//  mexer neles, este harness sente.
//
//  A dívida honesta: um andaime que divergisse do original poderia esconder
//  defeito. `Goal` é copiado verbatim dos rawValues de `Models.swift:127-130`
//  (o `MockAIPlanService` compara por rawValue, então é isso que importa), e os
//  outros dois nunca são chamados pelas asserções.
//

import Foundation

/// Verbatim de `Shared/Corpo/Models.swift:127-130` — só os rawValues, que é o
/// que o `MockAIPlanService` compara.
enum Goal: String, CaseIterable, Identifiable {
    case perder = "Perder peso"
    case manter = "Manter a forma"
    case ganhar = "Ganhar massa"

    var id: String { rawValue }
}

/// Andaime: `AIService.endpoint` só encaminha para cá. Nenhuma asserção usa.
enum AnaliseDeFotoService {
    static let endpoint = URL(string: "https://andaime.invalido/nao-chamado")!
}

/// Andaime: `AIService.make(consentimento:)` constrói isto. Nenhuma asserção
/// usa — o caminho sob teste é o SEM foto (`MockAIPlanService`).
struct NuvemAIPlanService: AIPlanService {
    let consentimento: Bool
    func analyze(_ input: ScanInput) async throws -> ScanResult {
        fatalError("andaime: o harness não exercita o caminho com foto")
    }
}
