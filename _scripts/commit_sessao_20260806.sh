#!/bin/bash
# Commit da documentação e das evidências da sessão de 06/08/2026.
# Stage por caminho explícito. Sem push.
set -eu
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git add _validacao_20260806/05_destrave_do_git.txt
git add _validacao_20260806/06_commits.txt
git add _validacao_20260806/07_bump.txt
git add _validacao_20260806/08_build.txt
git add _validacao_20260806/09_simuladores.txt
git add _validacao_20260806/10_destinos.txt
git add _validacao_20260806/11_toolchain.txt
git add _validacao_20260806/12_textos_da_2_0_1.md
git add _validacao_20260806/13_ofertas_intro_asc.txt
git add _validacao_20260806/14_produtos_asc.txt
git add _validacao_20260806/15_build_erros.txt
git add _validacao_20260806/16_auditoria.txt
git add _validacao_20260806/17_resultado_harness.txt
git add _validacao_20260806/18_commit_reparo.txt
git add _validacao_20260806/19_archive_upload_94.txt
git add _validacao_20260806/20_relatorio_da_sessao.md
git add _scripts/bump_2_0_1_build94.sh
git add _scripts/tf_archive_94.sh
git add _scripts/commit_reparo_e618d9b.sh
git add _scripts/commit_sessao_20260806.sh
git add functions/asc_ofertas_intro.mjs
git add functions/asc_build94.mjs

git commit -F - <<'MSG'
2.0.1 (94) no TestFlight, VALID — e o porque de tres quebra-builds num dia so

A CAUSA RAIZ DO DIA, que vale mais que qualquer conserto isolado: o Xcode foi
atualizado para 26.6 ontem as 18:44 e as plataformas iOS 26.5 e watchOS 26.5
nunca foram baixadas. `xcodebuild -showdestinations` nao listava NENHUM destino
elegivel — nem simulador, nem device. A maquina passou o dia sem conseguir
compilar, e os seis commits de entitlement/paywall de hoje entraram sem uma
unica compilacao. Foi assim que tres defeitos triviais sobreviveram:
`semPremium` declarado duas vezes, um `path` dobrado no pbxproj e
`jwsRepresentation` pedido ao tipo errado.

Baixadas iOS 26.5 (8,52 GB) e watchOS 26.5 (3,96 GB). Se o build voltar a
"nenhum destino elegivel", e isto: `xcodebuild -downloadPlatform iOS`.

RESULTADO
· Build de simulador: SUCCEEDED (exit 0), Debug, SDK 26.5.
· Harness em runtime: 135 aprovados, 2 reprovados — A26d e A27g, as duas
  vermelhas de proposito desde 05/08. Nenhuma reprovacao nova.
· As 8 assercoes da porcao editavel (E0..E4b) passaram com os numeros previstos
  a mao antes de existir compilador: 936 exibidos == 936 registrados,
  botao=450 == diario=450, 600 kcal em 350 g -> 171/100 g.
· Archive: iPhone e Watch, ambos 2.0.1 (94). Export: IPA de 348 MB.
· altool --validate-app: VERIFY SUCCEEDED with no errors.
· altool --upload-app: UPLOAD SUCCEEDED. Delivery 0c662fca-5ae9-4238-a234-8fd9272598e4.
· App Store Connect: build 94, processingState=VALID.

NADA FOI ENVIADO PARA REVISAO. Decisao do Felipe, por duas razoes boas: ninguem
tocou na tela nova (a porcao editavel e interface que nenhuma assercao alcanca)
e os screenshots da 2.0.1 estao sendo refeitos noutra sessao — os atuais tem
banner de trial que nao vale mais.

CORRECAO DE UMA AFIRMACAO MINHA, no mesmo dia. Escrevi nas notas do revisor que
o teste gratis nao existe mais. Errado. Li a assercao A22a como se cobrisse o
paywall inteiro; ela cobre so os textos ESTATICOS. Ha dois "trials": a oferta
introdutoria do StoreKit no ASC, que EXISTE (FREE_TRIAL, uma semana, um ciclo,
desde 03/04, exibida so a quem e elegivel), e o trial local no app, que nao
existe e e contra quem a A22a foi escrita. Reconferido na API hoje.
Divergencia nao resolvida e declarada: de manha contaram 30 territorios, eu
contei 175.

ACHADO ADJACENTE: o ASC tem UM unico produto de assinatura, o mensal. O
premium_annual que as notas de abril listam nao existe — o proprio
StoreKitManager.swift:6 ja dizia isso em comentario. Proposta de notas novas em
_validacao_20260806/12_textos_da_2_0_1.md, nada gravado no ASC.

O QUE CONTINUA SEM PROVA: ninguem viu a tela; o fluxo de compra nao foi
exercitado em sandbox; a ergonomia do ajuste de porcao nao foi usada por
ninguem. Aritmetica provada, pixel nao.

Sem push.
MSG

git log --oneline -6
