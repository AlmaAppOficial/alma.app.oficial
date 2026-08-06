#!/bin/bash
# Commit do reparo dos dois quebra-builds do commit e618d9b (06/08/2026).
# Stage por caminho explícito. Sem push.
set -eu
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git add Alma.App.Oficial.xcodeproj/project.pbxproj
git add Shared/AlmaEntitlementBridge.swift

git commit -F - <<'MSG'
A ponte do entitlement finalmente compila: caminho dobrado e JWS do envelope

Dois defeitos do commit e618d9b, de hoje. Nenhum dos dois sobrevive a uma
compilacao — e nenhuma houve. O Xcode foi atualizado para 26.6 ontem as 18:44 e
as plataformas iOS/watchOS 26.5 nunca foram baixadas: a maquina passou o dia
inteiro sem conseguir compilar nada, nem simulador nem device. Foi por isso que
tres quebra-builds entraram um atras do outro hoje (o `semPremium` repetido do
4944881 e estes dois).

(a) Shared/Shared/AlmaEntitlementBridge.swift — CAMINHO DOBRADO

O PBXFileReference declarava path = "Shared/AlmaEntitlementBridge.swift" dentro
de um grupo que ja e `Shared`, e o xcodebuild foi procurar em `Shared/Shared/`.
Erro: "Build input file cannot be found".

E literalmente o mesmo defeito que o commit 366c1ac consertou em 05/08 no
RotaDaNotificacao.swift, com a mesma correcao: tirar o prefixo do path. Varri o
pbxproj — era a unica ocorrencia restante do padrao.

(b) transacao.jwsRepresentation NAO EXISTE

jwsRepresentation e do VerificationResult, nao da Transaction. Nao e detalhe de
API: o JWS e o ENVELOPE ASSINADO, e Transaction e o que sobra depois de abrir o
envelope. Um payload ja aberto nao teria como provar coisa alguma ao servidor —
que verifica a assinatura, pelo mesmo caminho do appleNotifications. Passa a
enviar resultado.jwsRepresentation.

PROVA
· Build de simulador VERDE (exit 0), Debug, iPhone 17 Pro Max, SDK 26.5.
· Auditoria em runtime: 135 aprovados, 2 reprovados — A26d e A27g, as mesmas
  duas vermelhas de proposito declaradas desde 05/08. Nenhuma reprovacao nova.
· As oito assercoes E (porcao editavel) passaram com os numeros previstos:
  E1 exibido=936kcal == registrado=936kcal; E2 botao=450 == diario=450;
  E4 600 kcal em 350 g -> 171/100 g. Evidencia em
  _validacao_20260806/16_auditoria.txt e 17_resultado_harness.txt.
· P1a/P1b/P1c passam.

O QUE CONTINUA SEM PROVA: ninguem viu a tela. O harness prova aritmetica e
fiacao estatica, nao pixel.

Sem push.
MSG

git log --oneline -1
