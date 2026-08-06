#!/bin/bash
# COMMIT DA PORÇÃO EDITÁVEL — para rodar NO MAC (06/08/2026)
#
# POR QUE ISTO EXISTE, e não um commit já feito: o ambiente onde o trabalho foi
# escrito monta o repositório por FUSE e não consegue remover `.git/index.lock`.
# Nenhuma operação de escrita do git completa lá. O código está pronto e provado
# até onde dava; o commit é a única etapa que ficou para esta máquina.
#
# SÃO DOIS COMMITS, de propósito, e nesta ordem:
#   1. o REPARO do que o commit 4944881 (de hoje) quebrou — build Debug parado;
#   2. a porção editável + a unidade do alimento personalizado.
# Separados porque o reparo vale sozinho: se o commit 2 tiver erro de
# compilação, dá para revertê-lo e o build continua de pé.
#
# NÃO FAZ PUSH. NÃO FAZ ARCHIVE. NÃO SOBE NADA. Gate do Felipe, como sempre.
set -eu

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

echo "═════ 0 · limpeza do lixo que o sandbox deixou no .git ═════"
# Arquivos de 0 byte que o ambiente FUSE criou e não conseguiu apagar. O
# index.lock trava QUALQUER git nesta máquina até ser removido.
rm -f .git/index.lock .git/_teste_escrita
echo "  .git/index.lock e .git/_teste_escrita removidos (se existiam) ✓"
echo

echo "═════ 1 · confere que estamos no lugar certo ═════"
BRANCH="$(git branch --show-current)"
[ "$BRANCH" = "feat/build84-chat-e-ciclos" ] || {
  echo "ABORTADO: branch é '$BRANCH', esperava feat/build84-chat-e-ciclos"; exit 1; }
echo "  branch: $BRANCH ✓"
echo

echo "═════ 2 · COMMIT 1 — reparo do 4944881 (build Debug de volta) ═════"
# Guarda a versão completa (reparo + bloco E) e reconstrói a versão só-reparo
# a partir do HEAD, para o commit 1 conter SÓ o reparo.
cp Shared/AuditoriaBloqueadores.swift /tmp/harness_completo_$$.swift
git checkout -- Shared/AuditoriaBloqueadores.swift
git apply --check _validacao_20260806/reparo_4944881.patch
git apply _validacao_20260806/reparo_4944881.patch
echo "  patch do reparo aplicado ✓"

git add Shared/AuditoriaBloqueadores.swift
git commit -F - <<'MSG'
Harness volta a compilar: nome repetido e id repetido, os dois de hoje

O commit 4944881 ("treino: o botao pago que engolia o toque") acrescentou um
bloco de asserções ao AuditoriaBloqueadores e trouxe dois defeitos junto. O
primeiro para o build; o segundo estraga o log justamente onde ele é lido com
mais atenção.

(a) `Invalid redeclaration of 'semPremium'` — O ALVO DEBUG NÃO COMPILAVA

`semPremium` já existia desde a B11b (linha 252) como o AppModel sem assinatura.
O bloco novo declarou `let semPremium` de novo, no MESMO escopo — corpo direto
de `executar()`. Swift não permite, e AuditoriaBloqueadores.swift está em
Sources do target: nenhum build Debug passava desde as 13:09 de hoje.

Renomeados para `acaoSemPremium`/`acaoComPremium`, que também dizem melhor o que
são — a AÇÃO decidida por CorpoAcesso, não o modelo. O `semPremium` da B11b fica
intacto.

(b) A27a/A27b/A27c EXISTIAM EM DOIS LUGARES

O bloco novo reusou os ids A27a/b/c, que são do HealthKit desde 05/08 (linhas
~1196-1208). Este arquivo escreve a regra que isso viola, umas 800 linhas
abaixo: "Duas asserções com o mesmo id tornam o log ambíguo — quando uma
reprova, não dá para saber qual." Foi por isso que o bloco de honestidade virou
`H` e não `C`.

Agrava que o cabeçalho do bloco de HealthKit declara A27g como VERMELHA de
propósito — ou seja, o A27 é exatamente o trecho do log que alguém vai ler com
atenção, agora com três ids ambíguos no meio.

Renomeados para P1a/P1b/P1c (P de pago). O canário continua sendo o P1c.

PROVA
· Análise de escopo por indentação sobre o arquivo inteiro: 161 declarações no
  escopo direto de executar(), nenhuma duplicada; 129 ids de asserção, nenhum
  duplicado. Evidência em _validacao_20260806/03_integridade_do_harness.txt.
· NÃO PROVADO POR COMPILAÇÃO: o ambiente onde isto foi escrito não tem Xcode.
  A afirmação "o build volta" é análise de escopo, não build verde. Rodar
  _scripts/build_e_auditar_20260805.sh nesta máquina fecha essa lacuna.

Sem push.
MSG
echo "  commit 1 feito ✓"
echo

echo "═════ 3 · COMMIT 2 — porção editável + unidade do alimento personalizado ═════"
cp /tmp/harness_completo_$$.swift Shared/AuditoriaBloqueadores.swift
rm -f /tmp/harness_completo_$$.swift

# Stage por caminho explícito, um a um. Nunca -a, nunca add . (CLAUDE.md).
git add Shared/Corpo/FoodScanView.swift
git add Shared/Corpo/AddFoodView.swift
git add Shared/Corpo/MealDetailView.swift
git add Shared/AuditoriaBloqueadores.swift
git add _scripts/lint_wiring.py
git add _scripts/mutacao_porcao_editavel.sh
git add _scripts/commitar_porcao_editavel.sh
git add CLAUDE.md
git add _validacao_20260806/00_plano_porcao_editavel.md
git add _validacao_20260806/01_mutacao_porcao_editavel.txt
git add _validacao_20260806/02_aritmetica_das_assercoes.txt
git add _validacao_20260806/03_integridade_do_harness.txt
git add _validacao_20260806/04_entrega_e_o_que_falta_para_o_build.md
git add _validacao_20260806/reparo_4944881.patch

git commit -F - <<'MSG'
A porção deixa de ser um decreto da IA, e o alimento personalizado para de trocar de unidade

Dois bugs da mesma família, os dois pedidos pelo Assis depois de escanear um
prato real: número errado entrando no diário, que é o dado que dá sentido a esta
parte do app.

(a) A PESSOA NÃO PODIA CORRIGIR A QUANTIDADE

O conserto de 05/08 (366c1ac) fez a tela e o diário contarem o mesmo número. Não
fez esse número poder estar certo. `porcaoG` vinha da IA, era `let`, e não havia
controle nenhum na tela: ou a pessoa aceitava a estimativa ou não registrava. A
queixa foi exatamente essa — "as proporções estão exatas mas a quantidade não era
a mesma que tinha no prato".

Agora existe ajuste, com a estimativa da IA já preenchida como ponto de partida.
Quem concorda com ela não toca em nada. Quem olhou o prato e sabe que era mais,
arrasta — e vê os quatro números mudarem acima, antes de confirmar.

A estimativa NÃO é sobrescrita: `porcaoAjustada` é estado à parte, e a tela
continua dizendo quanto a máquina tinha lido, com um toque para voltar. Apagar
a estimativa apagaria a diferença entre o que a máquina viu e o que a pessoa
corrigiu — que é justamente o que ensina quanto confiar na leitura.

Desenho que impede a regressão: UM `let gramas` no topo de `resultSection`, lido
pelos tiles, pelo rótulo do botão e pelo `addFood`. Divergir exigiria criar uma
segunda variável. E os dois textos que carregam a quantidade viraram funções
estáticas (`rotuloDaPorcao`, `rotuloDeConfirmacao`), porque enquanto viviam
soltos no corpo da View nenhuma asserção conseguia ler o que o botão promete.

O Slider ficou SEM `step:`. Com passo de 5 a grade ancorava no piso (10, 15,
20…) e a estimativa da IA é inteiro qualquer: um prato de 247 g pulava para 245
ao primeiro toque, e os botões −/+ andavam por uma grade que nunca encontrava a
do slider. Dois controles discordando sobre quais números existem é a mesma
família de bug. O piso também acompanha estimativas pequenas — com piso fixo em
10, uma estimativa de 5 g deixaria o rótulo dizendo 5 e o slider parado em 10.

(b) O CustomFoodForm GRAVAVA VALOR DE PORÇÃO NO CAMPO POR 100 G

O formulário pergunta "Macros (por porção)" e o StoredFood guarda por 100 g. Os
mesmos números iam para os dois. Uma marmita de 600 kcal virava 600 kcal POR
100 G, e a leitura seguinte do código de barras a 350 g devolvia 2 100 kcal.
Mesmo gênero do bug do scan: número mudando de unidade em silêncio.

Entra o campo "Peso da porção (g)", pré-preenchido com 100 — em 100 a conversão
é a identidade, então quem ignorar o campo recebe exatamente o comportamento
antigo. Uma correção não pode criar erro novo para quem não olhou.

O Meal recebe o número digitado INTACTO; o arredondamento fica só no item de
catálogo. E a porção passa a aparecer no nome: este era o único caminho de
registro que não dizia de quanto falava, nem no texto nem em campo nenhum.

PROVA
· 7 mutações no lint, 7 vermelhas, 0 furos (_scripts/mutacao_porcao_editavel.sh).
  A M-E7 nasceu de um furo achado na revisão: o `proibe` do E-W5b exigia UM
  espaço e o arquivo usa alinhamento por colunas, então uma reversão no estilo
  da casa passava batido pelo canário.
· Lint de wiring: 30 regras, 0 falhas. E-W1..E-W5b provam o que runtime nenhum
  vê sem XCUITest — que existe controle na tela, que ele escreve no estado, e
  que as três pontas leem a mesma variável.
· Aritmética das asserções conferida fora do Swift, replicando escalarPor100:
  936/122/18/41 para 450 g, 171 kcal/100 g para 600 em 350 g
  (_validacao_20260806/02_aritmetica_das_assercoes.txt).
· E0 é o canário do comparador; E2b é o canário do extrator do E2.

NÃO PROVADO, e declarado como dívida, não como verde:
· O harness E0..E4b NÃO FOI EXECUTADO. Não há Xcode no ambiente onde isto foi
  escrito. As asserções estão escritas e a aritmética delas foi conferida à mão;
  que elas passem, e que o alvo compile, exige rodar
  _scripts/build_e_auditar_20260805.sh nesta máquina.
· Ninguém viu a tela. Nada aqui prova que arrastar o Slider redesenha os quatro
  números — E-W4 prova que ele escreve no estado e E-W2 que os tiles leem a
  mesma variável do registro; o elo "e o pixel mudou" segue sem prova, como
  desde 05/08.

CORREÇÕES VINDAS DA REVISÃO (a primeira versão tinha três asserções fracas):
· E3 era eco — assertava porcaoG == 250 dez linhas depois de passar 250 ao
  construtor, e o comentário prometia pegar `let`→`var`, o que não pegava.
  Agora trava o elo que a refatoração criou: macrosDaPorcao continua sendo
  macros(para: porcaoG), senão H2/H2b/H2d passam a falar de outra coisa.
· E2 fazia .contains do literal que ela mesma passou. Agora EXTRAI o número das
  duas frases — produzidas por funções diferentes — e compara.
· E1 declarava um alvo de mutação que não cobre (o botão). O comentário agora
  diz o que ela cobre e manda o resto para o lint.

DÍVIDA REGISTRADA: MealDetailView existe, está no target, NÃO é alcançável por
nenhuma navegação e NÃO edita nada. Anotado no topo do próprio arquivo e no
CLAUDE.md, para quem pegar a 2.1 não achar que há meio caminho andado. O
obstáculo da 2.1 é de modelo: Meal não guarda gramas nem base por 100 g.

Sem push. Sem archive e sem upload.
MSG
echo "  commit 2 feito ✓"
echo

echo "═════ 4 · resultado ═════"
git log --oneline -3
echo
echo "NADA foi enviado. Para virar build, ver o relatório do dia."
