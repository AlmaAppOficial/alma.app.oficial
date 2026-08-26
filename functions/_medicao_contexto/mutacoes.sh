#!/usr/bin/env bash
# Regra 1 do CLAUDE.md — teste de mutação.
#
# Apaga, uma de cada vez, a linha de produção que uma asserção protege,
# recompila, roda os testes e confere que a asserção FICA VERMELHA. Depois
# restaura. Asserção que continua verde sem a linha é asserção cega e não conta.
#
# Uso: bash mutacoes.sh
set -uo pipefail
cd "$(dirname "$0")/.."

FONTE="src/contextoDoUsuario.ts"
BACKUP="/tmp/contextoDoUsuario.original.ts"
cp "$FONTE" "$BACKUP"
restaurar() { cp "$BACKUP" "$FONTE"; ./node_modules/.bin/tsc >/dev/null 2>&1; }
trap restaurar EXIT

falhas=0

mutar() {
  local id="$1" descricao="$2" de="$3" para="$4" asercao="$5"
  cp "$BACKUP" "$FONTE"
  python3 - "$FONTE" "$de" "$para" <<'PY'
import sys
caminho, de, para = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(caminho, encoding='utf8').read()
if de not in s:
    print('ALVO NAO ENCONTRADO'); sys.exit(3)
open(caminho, 'w', encoding='utf8').write(s.replace(de, para, 1))
PY
  if [ $? -ne 0 ]; then echo "  $id: ALVO NÃO ENCONTRADO — mutação inválida"; falhas=$((falhas+1)); return; fi

  ./node_modules/.bin/tsc >/dev/null 2>&1
  saida=$(node _medicao_contexto/testes.mjs 2>&1)

  if echo "$saida" | grep -q "✗✗ $asercao"; then
    echo "  ✓ $id ($descricao) → \"$asercao\" ficou VERMELHA"
  else
    echo "  ✗✗ $id ($descricao) → \"$asercao\" continuou verde. ASSERÇÃO CEGA."
    falhas=$((falhas+1))
  fi
}

echo
echo "── TESTE DE MUTAÇÃO ──────────────────────────────────────────────────"

mutar "M1" "sem conjunto fechado de valores" \
  'if (v && VALORES_ACEITOS[campo].has(v)) out[campo] = v;' \
  'if (v) out[campo] = v;' \
  'recusa slug inventado'

mutar "M2" "sem barreira de quebra de linha no nome" \
  'if (nome && nome.length <= MAX_CHARS_NOME && !/[\r\n]/.test(nome)) out.name = nome;' \
  'if (nome) out.name = nome;' \
  'recusa nome com quebra de linha (injeção no prompt)'

mutar "M3" "precedência invertida entre os dois endereços" \
  'const valor = daSub ?? doMapa;' \
  'const valor = doMapa ?? daSub;' \
  'subcoleção vence no conflito'

mutar "M4" "sem janela do Ano-Novo Lunar" \
  'if (d.mes === 1 || (d.mes === 2 && d.dia <= 20)) return null;' \
  '' \
  'chinês: 05/02/1988 devolve null (janela do Ano-Novo Lunar)'

mutar "M5" "sem teto total do histórico" \
  'while (total > maxTotalChars && i < cortadas.length) {' \
  'while (false && total > maxTotalChars && i < cortadas.length) {' \
  'respeita o teto total'

echo
restaurar
saida=$(node _medicao_contexto/testes.mjs 2>&1 | tail -1)
echo "restaurado: $saida"
echo
if [ "$falhas" -eq 0 ]; then
  echo "✓ 5 mutações, 5 vermelhas. As asserções enxergam."
else
  echo "✗✗ $falhas mutação(ões) não acusaram."
fi
exit "$falhas"
