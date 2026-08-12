#!/usr/bin/env python3
"""Verifica que as CHAMADAS críticas existem no código de produção.

[2026-08-04 — resposta à reauditoria]

A revisora aplicou quatro mutações e o harness continuou 40/40. Duas delas
(M2 e M3) foram dentro de uma View — apagar `model.registrarTreinoConcluido()`
do botão, e reintroduzir `if hasPremiumAccess` no botão de água.

Nenhuma asserção em runtime pega isso sem renderizar a tela E simular o toque.
Mover a lógica para o AppModel, como fiz ontem, NÃO resolveu: fez a View e o
harness chamarem o mesmo método, não fez o harness exercitar a chamada da View.
A revisora está certa: o defeito foi movido um nível, não corrigido.

O que pega é isto: um lint que afirma que a chamada existe (ou não existe) no
arquivo certo. É uma "fitness function" de arquitetura — verificação estática,
mas que FICA VERMELHA sob exatamente a mutação que o runtime não vê.

Cada regra abaixo tem um campo `mutacao`: a edição que deve deixá-la vermelha.
É assim que este lint se prova — ver `_scripts/mutacao.sh`.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(sys.argv[1] if len(sys.argv) > 1 else ".")

REGRAS = [
    {
        "id": "W1",
        "desc": "concluir treino GRAVA o dia (bug B3)",
        "arquivo": "Shared/Corpo/WorkoutSessionView.swift",
        "precisa": r"model\.registrarTreinoConcluido\(\)",
        "mutacao": "comentar a chamada em registrarTreinoConcluido() da View",
    },
    {
        "id": "W2",
        "desc": "exclusão de conta chama a limpeza local (bug B9/LGPD)",
        "arquivo": "Shared/AccountDeletionService.swift",
        "precisa": r"Self\.executarLimpezaLocal\(\)",
        "mutacao": "comentar a chamada de limpeza na requestDeletion",
    },
    {
        "id": "W3",
        "desc": "limpeza local realmente apaga (bug B9/LGPD)",
        "arquivo": "Shared/AccountDeletionService.swift",
        "precisa": r"LocalDataCleanupService\.clearAll\(\)",
        "mutacao": "comentar clearAll() dentro de executarLimpezaLocal",
    },
    {
        "id": "W4",
        "desc": "limpeza interrompida é retomada no boot (D-1)",
        "arquivo": "Shared/AlmaApp.swift",
        "precisa": r"retomarLimpezaPendenteSeNecessario\(\)",
        "mutacao": "remover a chamada do .task da RootView",
    },
    {
        "id": "W5",
        "desc": "o perfil em memória é zerado na limpeza (D-2)",
        "arquivo": "Shared/LocalDataCleanupService.swift",
        "precisa": r"UserProfileStore\.resetar\(\)",
        "mutacao": "remover a chamada de clearAll()",
    },
    {
        "id": "W6",
        "desc": "água NÃO tem gate de premium no botão (bug B11)",
        "arquivo": "Shared/Corpo/CorpoHomeView.swift",
        "proibe": r"hasPremiumAccess\s*\{\s*\n?\s*model\.addWater",
        "mutacao": "reintroduzir `if model.hasPremiumAccess` no botão de água",
    },
    {
        "id": "W7",
        "desc": "o didSet de waterMl grava no disco (bug B4)",
        "arquivo": "Shared/Corpo/Models.swift",
        "precisa": r"store\.set\(waterMl,\s*forKey:\s*\"waterMl\"\)",
        "mutacao": "esvaziar o didSet de waterMl",
    },
    {
        "id": "W8",
        "desc": "o token FCM não recria users/{uid} durante a exclusão (D-5)",
        "arquivo": "Shared/AlmaApp.swift",
        "precisa": r"temLimpezaPendente",
        "mutacao": "remover a guarda antes do setData do fcmToken",
    },
    # ── R-W · encaminhamento por toque em notificação (2026-08-05) ──────────
    #
    # Por que estas regras existem sendo estáticas: as asserções N1..N7 do
    # harness provam o MAPA (identificador → destino) em runtime, mas não
    # conseguem provar que a TELA obedece ao destino — isso precisaria de
    # XCUITest, ausente no projeto. Cada regra abaixo cobre um elo que o
    # runtime não enxerga, e fica vermelha sob a mutação declarada.
    {
        "id": "R-W1",
        "desc": "o toque em notificação atravessa a rota (não só o openFeed)",
        "arquivo": "Shared/AlmaApp.swift",
        "precisa": r"RotaDaNotificacao\.destino\(identificador:",
        "mutacao": "voltar o delegate a tratar apenas action == openFeed",
    },
    {
        "id": "R-W2",
        "desc": "a Alma encaminha o destino pendente ao NASCER (app fechado)",
        "arquivo": "Shared/MainTabView.swift",
        "precisa": r"\.onAppear\s*\{\s*encaminharNotificacaoPendente\(\)\s*\}",
        "mutacao": "remover o .onAppear e deixar só o .onChange — quebra a "
                   "partida fria, que é o caminho que ninguém testa",
    },
    {
        "id": "R-W3",
        "desc": "a Alma encaminha o destino que chega com o app vivo",
        "arquivo": "Shared/MainTabView.swift",
        "precisa": r"onChange\(of:\s*roteador\.pendente\)",
        "mutacao": "remover o .onChange — quebra o app em segundo plano",
    },
    {
        "id": "R-W4",
        "desc": "a Início abre Corpo/chat/vícios a partir do destino",
        "arquivo": "Shared/HomeView.swift",
        "precisa": r"case \.conversarComAlma:\s*\n\s*showChat = true",
        "mutacao": "apagar o ramo do chat do encaminhamento da Início",
    },
    {
        "id": "R-W5",
        "desc": "o RootTabView aplica a aba pedida pela notificação",
        "arquivo": "Shared/Corpo/RootTabView.swift",
        "precisa": r"selection = aba\.rawValue",
        "mutacao": "comentar a atribuição — o módulo abre sempre na Início e a "
                   "notificação de almoço deixa de chegar na Dieta",
    },
    {
        "id": "R-W6",
        "desc": "os lembretes do Corpo carimbam o destino ao serem agendados",
        "arquivo": "Shared/Corpo/NotificationManager.swift",
        "precisa": r"content\.userInfo = RotaDaNotificacao\.carimbo\(para: id\)",
        "mutacao": "remover o carimbo — sobra só o roteamento por prefixo",
    },
    {
        "id": "R-W7",
        "desc": "os lembretes da Alma carimbam o destino",
        "arquivo": "Shared/LembretesDaAlma.swift",
        "precisa": r"content\.userInfo = RotaDaNotificacao\.carimbo\(para: id\)",
        "mutacao": "remover o carimbo dos lembretes de meditação",
    },
    {
        "id": "R-W8",
        "desc": "os marcos de vício carimbam o destino",
        "arquivo": "Shared/AddictionFreeView.swift",
        "precisa": r"content\.userInfo = RotaDaNotificacao\.carimbo",
        "mutacao": "remover o carimbo dos marcos",
    },
    # ── C · exibido == registrado (2026-08-05) ─────────────────────────────
    {
        "id": "H-W1",
        "desc": "o scan de comida registra a porção estimada, não 100 g fixo",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "proibe": r"addFood\([^)]*grams:\s*100\b",
        "mutacao": "voltar `grams: 100` no botão de adicionar",
    },
    {
        # [2026-08-06] Atualizada junto com a porção editável. A regra ANTIGA
        # exigia `r.macrosDaPorcao.kcal` nos tiles — o que, com a porção
        # ajustável, passaria a significar "mostre a estimativa da IA e ignore
        # a correção da pessoa", ou seja, o bug novo. A INTENÇÃO é a mesma de
        # 05/08 e não mudou: os tiles mostram os macros da quantidade que vale,
        # nunca os valores por 100 g. O que mudou é qual quantidade vale.
        "id": "H-W2",
        "desc": "os tiles mostram os macros DA QUANTIDADE EM USO",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "precisa": r"macroTile\(\"\\\(macros\.kcal\)\"",
        "mutacao": "voltar os tiles a exibir r.kcalPer100",
    },
    {
        "id": "H-W2b",
        "desc": "os tiles NÃO voltam a exibir valores por 100 g",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "proibe": r"macroTile\(\"\\\(r\.(kcal|protein|carbs|fat)Per100\)\"",
        "mutacao": "pôr r.kcalPer100 de volta num tile",
    },
    {
        "id": "H-W3",
        "desc": "porção e macros saem da mesma função de escala",
        "arquivo": "Shared/Corpo/Models.swift",
        "precisa": r"static func escalarPor100\(_ valorPor100: Int, gramas: Int\)",
        "mutacao": "reescrever a conta dentro do addFood, criando duplicata",
    },
    # ── H-W4 reescrita em 2026-08-12, depois do incidente em produção ────────
    # A versão de 05/08 exigia literalmente
    #     `guard let somatotipo = r.somatotipo.flatMap`
    # e com isso prendia o MECANISMO, não o invariante. O mecanismo estava
    # errado: tratava o RÓTULO (somatotipo) no mesmo nível do que SUSTENTA a
    # análise (gordura e resumo), e derrubava a leitura inteira quando o rótulo
    # não vinha na grafia exata. Aconteceu quatro vezes seguidas com o Assis.
    #
    # O invariante que sempre importou continua inteiro e agora está em DUAS
    # regras, porque são duas afirmações diferentes:
    #   H-W4  — o rótulo sai da string da PRÓPRIA IA (via normalizador), nunca
    #           de heurística local; sem nada reconhecível vira `nil`.
    #   H-W4b — o que sustenta a análise continua obrigatório: resumo vazio
    #           ainda RECUSA. É a metade do invariante que NÃO foi afrouxada, e
    #           sem esta regra alguém relaxaria o resumo junto sem ninguém ver.
    {
        "id": "H-W4",
        "desc": "o rótulo vem da própria IA, normalizado — nunca de cálculo local",
        "arquivo": "Shared/Corpo/AnaliseDeFotoService.swift",
        "precisa": r"let somatotipo = Self\.somatotipoDaIA\(r\.somatotipo\)",
        "mutacao": "derivar o somatotipo do `base` (mock) quando a IA não manda",
    },
    {
        "id": "H-W4b",
        "desc": "resumo vazio ainda derruba a análise (a metade não afrouxada)",
        "arquivo": "Shared/Corpo/AnaliseDeFotoService.swift",
        "precisa": r"guard !resumoLimpo\.isEmpty else",
        "mutacao": "aceitar resumo vazio, deixando a tela sem a leitura da foto",
    },
    # [2026-08-12] A PRIMEIRA VERSÃO DESTA REGRA ERA CEGA, e a revisão provou
    # isso por mutação antes de qualquer commit. Ela era
    #     proibe: somatotipoDaIA\([^)]*\)\s*\?\?\s*\.(ecto|meso|endo)morfo
    # ou seja, olhava só o SÍTIO DE CHAMADA e só na grafia com ponto. Passava
    # verde com o bug dentro em dois casos: `?? Somatotype.mesomorfo` (nome
    # qualificado) e — pior — `return melhor?.tipo ?? .mesomorfo` DENTRO da
    # própria função que promete não chutar, que é o lugar mais natural de
    # introduzir o defeito.
    #
    # É exatamente o modo de falha que a A26d denunciou em 05/08: guarda que fica
    # verde porque não enxerga. Agora a regra varre o ARQUIVO inteiro por
    # qualquer `?? <somatotipo literal>`, com ou sem qualificação.
    {
        "id": "H-W4c",
        "desc": "nada no caminho de IA chuta um somatotipo com `?? .tipo`",
        "arquivo": "Shared/Corpo/AnaliseDeFotoService.swift",
        "proibe": r"\?\?\s*(Somatotype)?\.(ecto|meso|endo)morfo",
        "mutacao": "pôr `?? .mesomorfo` na saída do normalizador OU na chamada",
    },
    {
        "id": "H-W5",
        "desc": "nenhum texto do MockAIPlanService entra no resultado com IA",
        "arquivo": "Shared/Corpo/AnaliseDeFotoService.swift",
        "proibe": r"base\.analysis\.(summary|observations|focusAreas|somatotype)",
        "mutacao": "reintroduzir qualquer `base.analysis.<texto>` como reserva",
    },
    # ── H-W6 · A LINHA QUE CAUSOU O INCIDENTE DE 12/08 ────────────────────────
    # Esta é a regra mais importante do bloco H, porque prende a causa raiz
    # exata em vez de um sintoma.
    #
    # O que aconteceu: `somatotipo` era `{ type: ['string','null'] }` — texto
    # livre, anulável — e a instrução do modelo NUNCA mencionava o campo. O
    # modelo devolvia `null` de forma determinística e o app 2.0.1 descartava a
    # análise inteira. Quatro tentativas do Assis, quatro telas de erro.
    #
    # `enum` fechado + não-anulável não é preferência de estilo: com
    # `strict: true` é o que restringe a decodificação e torna `null`
    # impossível de emitir. Voltar a permitir `null` é reabrir o incidente,
    # e é por isso que existem DUAS regras — uma exige a forma certa, a outra
    # proíbe a forma errada de voltar por outro caminho.
    {
        "id": "H-W6",
        "desc": "somatotipo é enum FECHADO no esquema do servidor",
        "arquivo": "functions/src/analiseDeFoto.ts",
        "precisa": r"somatotipo: \{ type: 'string', enum: SOMATOTIPOS \}",
        "mutacao": "tirar o enum, deixando o campo como string livre",
    },
    {
        "id": "H-W6b",
        "desc": "e somatotipo NÃO volta a ser anulável",
        "arquivo": "functions/src/analiseDeFoto.ts",
        "proibe": r"somatotipo: \{ type: \[('|\")string\1, ('|\")null\2\]",
        "mutacao": "devolver `type: ['string','null']` ao campo — o bug original",
    },
    {
        "id": "H-W6c",
        "desc": "a instrução do modelo PEDE o somatotipo pelo nome",
        "arquivo": "functions/src/analiseDeFoto.ts",
        "precisa": r'- "somatotipo": EXATAMENTE uma destas três palavras',
        "mutacao": "tirar o campo da instrução, como estava antes de 12/08",
    },
    {
        "id": "H-W7",
        "desc": "o rótulo ausente NÃO derruba a análise no servidor",
        "arquivo": "functions/src/analiseDeFoto.ts",
        "proibe": r"faltando\.push\('somatotipo'\);[\s\S]{0,400}?res\.status\(502\)",
        "mutacao": "voltar a responder 502 quando só o rótulo falta",
    },
    # ── E · a porção deixa de ser um decreto (2026-08-06) ──────────────────
    # As asserções E0..E4b provam a ARITMÉTICA em runtime. Estas cinco provam o
    # WIRING dentro da View, que runtime nenhum enxerga sem XCUITest: que existe
    # controle na tela, que ele escreve no estado, e que as três pontas (tiles,
    # rótulo do botão e registro) leem a MESMA variável.
    {
        "id": "E-W1",
        "desc": "o registro usa a quantidade EM USO, não a estimativa da IA",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "precisa": r"model\.addFood\(r\.comoFoodItem, grams: gramas, to: mealType\)",
        "mutacao": "voltar `grams: r.porcaoG`, ignorando o ajuste da pessoa",
    },
    {
        "id": "E-W1b",
        "desc": "e não volta a gravar a estimativa por baixo do ajuste",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "proibe": r"addFood\([^)]*grams:\s*r\.porcaoG",
        "mutacao": "gravar r.porcaoG mesmo com a porção ajustada na tela",
    },
    {
        "id": "E-W2",
        "desc": "UMA quantidade só, lida pelos três consumidores",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "precisa": r"let gramas = porcaoEmUso\(r\)",
        "mutacao": "cada ponta voltar a ler a sua própria fonte de porção",
    },
    {
        "id": "E-W3",
        "desc": "o rótulo do botão sai da função estática que o harness lê",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        "precisa": r"Label\(Self\.rotuloDeConfirmacao\(gramas: gramas, refeicao: mealType\)",
        "mutacao": "voltar a string solta no corpo da View — E2 fica sem o que ler",
    },
    {
        "id": "E-W4",
        "desc": "existe controle de ajuste, e ele escreve no estado",
        "arquivo": "Shared/Corpo/FoodScanView.swift",
        # [revisão 06/08] Tolerante a reformatação: fixar o texto literal
        # inteiro transforma uma quebra de linha em falha falsa. O que precisa
        # existir é a atribuição ao estado a partir do valor do controle.
        "precisa": r"porcaoAjustada\s*=\s*max\(\s*piso\s*,\s*Int\(",
        "mutacao": "tirar o Slider — a porção volta a ser decreto da IA",
    },
    {
        "id": "E-W5",
        "desc": "o CustomFoodForm CONVERTE para 100 g em vez de copiar a porção",
        "arquivo": "Shared/Corpo/AddFoodView.swift",
        "precisa": r"kcalPer100:\s*Self\.converterPara100g\(",
        "mutacao": "voltar `kcalPer100: Int(kcal) ?? 0` — marmita de 600 kcal vira 600/100 g",
    },
    {
        "id": "E-W5b",
        "desc": "e a cópia crua não volta por outro caminho",
        "arquivo": "Shared/Corpo/AddFoodView.swift",
        # [revisão 06/08] `\s+` e não um espaço só: o código usa alinhamento por
        # colunas (`kcalPer100:    Self.converterPara100g(`). Com um espaço
        # fixo, uma reversão escrita no mesmo estilo alinhado passaria batido
        # pelo canário — o furo exato que este `proibe` existe para tapar.
        "proibe": r"kcalPer100:\s+Int\(kcal\)\s*\?\?\s*0",
        "mutacao": "O BUG ORIGINAL: valor da porção gravado no campo por-100-g",
    },
    {
        # Guarda a DECISÃO, não o código: 05/08 decidiu-se NÃO registrar o
        # HabitNotificationManager (~500 linhas que nunca compilaram). Se
        # alguém o acrescentar ao target sem revisar, três prefixos da
        # GradeDeLembretes passam a agendar notificações sem rota — e a
        # asserção N7 já está calibrada para o estado atual. Ver CLAUDE.md.
        "id": "R-W9",
        "desc": "HabitNotificationManager segue FORA do build (dívida declarada)",
        "arquivo": "Alma.App.Oficial.xcodeproj/project.pbxproj",
        "proibe": r"HabitNotificationManager",
        "mutacao": "adicionar HabitNotificationManager.swift ao target",
    },
]


def main() -> int:
    falhas = []
    print("═════ LINT DE WIRING ═════")
    for r in REGRAS:
        caminho = RAIZ / r["arquivo"]
        if not caminho.exists():
            falhas.append(f"{r['id']} arquivo não encontrado: {r['arquivo']}")
            print(f"✗ {r['id']} {r['desc']} — ARQUIVO NÃO ENCONTRADO")
            continue

        texto = caminho.read_text(encoding="utf-8")
        # Linhas comentadas não contam como wiring: comentar a chamada É a mutação.
        vivo = "\n".join(
            l for l in texto.split("\n") if not l.lstrip().startswith("//")
        )

        if "precisa" in r:
            ok = re.search(r["precisa"], vivo) is not None
            obs = "presente" if ok else "AUSENTE"
        else:
            ok = re.search(r["proibe"], vivo, re.MULTILINE) is None
            obs = "ausente (correto)" if ok else "PRESENTE — gate reintroduzido"

        if ok:
            print(f"✓ {r['id']} {r['desc']} — {obs}")
        else:
            falhas.append(f"{r['id']} {r['desc']}")
            print(f"✗ {r['id']} {r['desc']} — {obs}  [{r['arquivo']}]")

    print("═════ RESULTADO ═════")
    print(f"regras: {len(REGRAS)} · falhas: {len(falhas)}")
    for f in falhas:
        print(f"   ✗ {f}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
