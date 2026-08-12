#!/usr/bin/env python3
"""Tira `MealType` e `Meal` de `Models.swift` — eles agora vivem em `Refeicao.swift`.

Arquivo em vez de heredoc pelo mesmo motivo do `estender_testes_scan.py`: o
conteúdo tem acento e chaves que não sobrevivem a duas camadas de shell.

Idempotente. Aborta sem escrever se qualquer bloco esperado não bater — melhor
não mexer do que cortar no lugar errado.
"""
import sys

P = 'Shared/Corpo/Models.swift'
t = open(P, encoding='utf-8').read()

if 'MUDARAM DE ARQUIVO — agora vivem em `Refeicao.swift`' in t:
    print('já aplicado — nada a fazer')
    sys.exit(0)

BLOCO_ENUM = '''enum MealType: String, CaseIterable, Identifiable, Codable {
    case cafe = "Café da manhã"
    case almoco = "Almoço"
    case lanche = "Lanche"
    case jantar = "Jantar"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cafe:   return "sunrise.fill"
        case .almoco: return "sun.max.fill"
        case .lanche: return "cup.and.saucer.fill"
        case .jantar: return "moon.stars.fill"
        }
    }
}

// [2026-07-29] Codable para persistir as refeições do dia (antes o array `meals`
// vivia só em memória e tudo que o usuário adicionava sumia ao fechar o app).
struct Meal: Identifiable, Codable {
    var id = UUID()
    let type: MealType
    let name: String
    let kcal: Int
    let protein: Int   // g
    let carbs: Int     // g
    let fat: Int       // g
    var done: Bool
}'''

NOTA = '''// [2026-08-12] `MealType` e `Meal` MUDARAM DE ARQUIVO — agora vivem em
// `Refeicao.swift`, junto do `ComponenteDaRefeicao` que a refeição passou a
// poder carregar.
//
// Mesmo motivo da mudança de `FoodItem`/`StoredFood`: os três tipos só
// dependem de Foundation, e `Meal` ganhou um campo persistido — que é
// exatamente o tipo de mudança que precisa de teste de decodificação contra o
// dado antigo, e que este arquivo (SwiftUI + UserDefaults + meia dúzia de
// dependências) torna impossível exercitar fora do simulador.
//
// ⚠️ Os `rawValue` de `MealType` estão gravados no disco de quem usa o app.
// Ver o aviso no topo do enum em `Refeicao.swift` antes de tocar neles.'''

if BLOCO_ENUM not in t:
    print('ABORTADO: bloco MealType/Meal não bateu exatamente. Nada foi escrito.')
    sys.exit(2)

t = t.replace(BLOCO_ENUM, NOTA, 1)

# `escalarPor100` passa a delegar para a função pura de `Refeicao.swift`.
VELHA = '''    static func escalarPor100(_ valorPor100: Int, gramas: Int) -> Int {
        Int((Double(valorPor100) * Double(gramas) / 100.0).rounded())
    }'''
NOVA = '''    /// [2026-08-12] A conta mudou de casa (`Refeicao.swift`, função pura) para
    /// poder ser exercitada sem simulador. Este método CONTINUA sendo a porta
    /// de entrada de todo mundo — inclusive da asserção H2d, provada em 06/08,
    /// que fala deste nome. Delegar em vez de repetir a fórmula é o que impede
    /// as duas de divergirem, que seria o bug que o bloco H fechou.
    /// (A chamada abaixo é a função LIVRE de `Refeicao.swift`, não recursão:
    /// os rótulos diferem — `quantidade:` lá, `gramas:` aqui — e é isso que
    /// desempata a resolução.)
    static func escalarPor100(_ valorPor100: Int, gramas: Int) -> Int {
        escalarPor100(valorPor100, quantidade: gramas)
    }'''
if VELHA not in t:
    print('ABORTADO: escalarPor100 não bateu. Nada foi escrito.')
    sys.exit(3)
t = t.replace(VELHA, NOVA, 1)

open(P, 'w', encoding='utf-8').write(t)
print('Models.swift: MealType/Meal removidos, escalarPor100 delega')
