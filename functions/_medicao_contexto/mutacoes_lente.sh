#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# TESTE DE MUTAÇÃO da leitura de lente — Regra 1 do CLAUDE.md.
#
# Apaga, uma de cada vez, a linha de PRODUÇÃO que cada asserção protege, roda o
# harness e exige que ele fique VERMELHO. Uma asserção que continua verde sem a
# linha que ela protege é cega, e não conta como verificação.
#
# ── POR QUE `perl -0pe ORIG > ALVO` E NUNCA `perl -0pi` ────────────────────
# `perl -i` (e `cp`, e `sed -i`) editam TROCANDO O INODE: escrevem um
# temporário e renomeiam por cima. Num diretório montado por FUSE — que é como
# o sandbox dos agentes enxerga o Desktop — cada troca dessas deixa para trás
# um arquivo `.fuse_hidden…`. Este script rodou com `-i` em 29/08 e semeou 51
# desses dentro de `functions/src/`, todos cópias mortas do arquivo mutado, e
# eles aparecem no `git status` como se fossem trabalho de alguém.
#
# `perl -0pe ORIG > ALVO` LÊ do original e TRUNCA o alvo no lugar: mesmo
# resultado, inode preservado, zero resíduo. Vale para qualquer script deste
# projeto que edite arquivo do repositório em lote.
#
# Se for interrompido no meio, o `trap` devolve o original.
#
# Uso: bash _medicao_contexto/mutacoes_lente.sh
# ═══════════════════════════════════════════════════════════════════════════
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ALVO=src/leituraDeLente.ts
ORIG=/tmp/leituraDeLente.original.ts
cat "$ALVO" > "$ORIG" || exit 1
restaura () { cat "$ORIG" > "$ALVO"; }
trap 'restaura; npx tsc >/dev/null 2>&1' EXIT

falhas=0

# mutacao <nome> <asserção que TEM de reprovar> <expressão perl>
mutacao () {
  local nome="$1" esperada="$2" expr="$3"
  perl -0pe "$expr" "$ORIG" > "$ALVO"
  # Guarda contra mutação morta: uma expressão que não casa nada faria a
  # asserção continuar verde e este script cantaria "asserção cega" sobre uma
  # asserção inocente. Sem esta checagem, o próprio harness de mutação mente.
  #
  # ⚠️ Ela pega mutação que não ALTEROU O TEXTO — não pega mutação que alterou o
  # texto sem alterar o COMPORTAMENTO. Aconteceu com a M2 em 29/08: escrevi
  # `return "" || temHoraExata(...)`, que em JS devolve `temHoraExata(...)`
  # porque `""` é falsy. Texto diferente, semântica idêntica, mutação inútil.
  # O que salvou foi a M2 aparecer como "asserção cega" — a leitura certa
  # daquele vermelho era "a mutação está errada", não "a asserção está cega".
  if diff -q "$ORIG" "$ALVO" >/dev/null; then
    echo "   ✗✗ $nome → a MUTAÇÃO NÃO PEGOU (arquivo idêntico). Expressão morta."
    falhas=$((falhas+1)); restaura; return
  fi
  npx tsc >/dev/null 2>&1
  local saida; saida=$(node _medicao_contexto/provar_lente.mjs 2>&1)
  if echo "$saida" | grep -qF "FALHOU — $esperada"; then
    echo "   ✓ $nome → a asserção ficou VERMELHA (enxerga)"
  else
    echo "   ✗✗ $nome → a asserção CONTINUOU VERDE. ASSERÇÃO CEGA."
    echo "      esperava reprovar: \"$esperada\""
    falhas=$((falhas+1))
  fi
  restaura
}

echo
echo "══ MUTAÇÃO — cada asserção sem a linha que ela protege ════════════════"
echo

# M1 — o ciclo pessoal deixa de virar no aniversário e passa a virar em 1º/jan
#      (é exatamente o que o GuidanceEngine.swift do iOS faz)
mutacao "M1  ciclo vira em 1º/jan, não no aniversário" \
  "ciclo pessoal vira no aniversário (ano 8, não 9)" \
  's/const anoDoCiclo = jaFezAniversario \? anoHoje : anoHoje - 1;/const anoDoCiclo = anoHoje;/'

# M2 — a resolução some: o buraco do ascendente fica sem declaração
mutacao "M2  resolucaoDaLeitura devolve string vazia" \
  "hora aproximada → diz que NÃO existe ascendente" \
  's/  return temHoraExata\(identidade\)/  return true ? "" : temHoraExata(identidade)/'

# M3 — a instrução deixa de ser condicional: quem não tem data passa a pagar
mutacao "M3  instrução deixa de ser condicional" \
  "sem data de nascimento → instrução vazia" \
  's/return lerDataDeNascimento\(birthDate, hoje\) \? INSTRUCAO_DE_LENTE : .+;/return INSTRUCAO_DE_LENTE;/'

# M4 — o nome da tradição vaza para dentro do bloco (corregedoria)
mutacao "M4  nome da tradição vaza para o bloco" \
  'não vaza o nome da tradição: "Cabala"' \
  "s/'dissolver a borda/'na Cabala, dissolver a borda/"

# M5 — some a proibição de ler saúde/morte/gravidez/dinheiro
mutacao "M5  some a proibição de prever saúde/morte/dinheiro" \
  "instrução proíbe leitura de saúde/doença/morte/gravidez/dinheiro" \
  's/NUNCA leia saúde, doença, corpo, morte, gravidez, dinheiro, sorte, nem nada que\nainda vai acontecer — nem em pergunta\.\n//'

# M6 — some a cedência ao §0 (crise)
mutacao "M6  some a cedência ao §0 (crise)" \
  "instrução cede ao §0 (crise)" \
  's/Se o §0 se aplicar, esta seção sai de cena\.//'

# M7 — a instrução vira veredito: some o "propor e perguntar"
mutacao "M7  instrução manda AFIRMAR em vez de propor" \
  "instrução: propor e perguntar" \
  's/PROPOR E PERGUNTAR/AFIRMAR COM CONVICÇÃO/'

# M8 — a devolução da palavra volta a ser PERMITIDA em vez de obrigatória.
#      É a mutação mais importante da lista: foi exatamente esta versão que o
#      modelo real desobedeceu em 29/08 (a Alma aceitava o "não faz sentido" e
#      parava, sem devolver a palavra). A asserção precisa enxergar a diferença
#      entre "pode" e "deve" — que é a diferença entre a regra pegar ou não.
mutacao "M8  devolver a palavra vira permissão, não obrigação" \
  'instrução: OBRIGA a devolver a palavra depois do "não"' \
  's/PEÇA que ela conte/Devolva a palavra/; s/Esse pedido é obrigatório e pode ser a última frase\./Aqui terminar convidando é permitido./'

echo
echo "══════════════════════════════════════════════════════════════════════"
if [ "$falhas" -gt 0 ]; then
  echo "✗ $falhas asserção(ões) CEGA(S). O resultado do harness não vale."
  exit 1
fi
echo "✓ as 8 mutações ficaram vermelhas. As asserções enxergam o que dizem ver."
echo "  (o arquivo foi restaurado ao original e recompilado)"
