#!/bin/bash
# mutacao_unidade.sh — Regra 1 do CLAUDE.md aplicada ao trabalho da unidade.
#
# "Um teste que nunca reprova não é teste — é papel pintado."
#
# Este script apaga, uma de cada vez, as linhas de produção que as asserções de
# `_scripts/testes_unidade.swift` dizem proteger, e EXIGE que o teste fique
# vermelho em cada uma. Ao fim, restaura o arquivo e confere que voltou ao verde.
#
# O que cada mutação simula, e por que ela importa:
#
#   M1 · apaga o `init(from:)` à mão de `StoredFood`, deixando o Swift
#        sintetizar. É EXATAMENTE o código que alguém escreveria sem conhecer a
#        armadilha, e é o que apagaria os alimentos personalizados de todo mundo
#        que já usa o app. Se U1/U5 continuarem verdes com esta mutação viva, o
#        harness não está enxergando a perda de dados.
#
#   M2 · troca `decodeIfPresent` por `decode` dentro de `lerRetrocompativel` —
#        a mesma falha um nível abaixo, para o caso de alguém "simplificar" o
#        helper achando que o `guard let` já cobre.
#
#   M3 · faz `daEmbalagem` adivinhar pelo NOME (a versão rápida que o comentário
#        do `enum Unidade` recusa). Tem de reprovar U8 e U9.
#
# Uso: ./_scripts/mutacao_unidade.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ALVO="Shared/Corpo/UnidadeDeMedida.swift"
TESTES="_scripts/testes_unidade.swift"
BIN="/tmp/testes_unidade_mut"
BKP="/tmp/UnidadeDeMedida.original.$$"
EVID="_validacao_20260812"
mkdir -p "$EVID"

cp "$ALVO" "$BKP"
restaurar() { cp "$BKP" "$ALVO"; }
trap restaurar EXIT

verde=0; vermelho=0

# roda: compila e roda. Ecoa a saída e devolve o código.
roda() {
  local saida
  saida="$(/usr/bin/xcrun swiftc -O "$ALVO" "$TESTES" -o "$BIN" 2>&1)"
  if [ -n "$saida" ]; then echo "$saida"; fi
  "$BIN" 2>&1
}

# ── 0 · linha de base ───────────────────────────────────────────────────────
echo "═════ 0 · LINHA DE BASE (código íntegro) ═════"
BASE="$(roda)"; RC=$?
echo "$BASE" | tee "$EVID/00_base_unidade.txt"
if [ $RC -eq 0 ]; then
  echo "  → BASE VERDE, como esperado"; verde=$((verde+1))
else
  echo "  → ✗✗ BASE JÁ ESTÁ VERMELHA — pare aqui, não há o que mutar"; exit 2
fi

# `espera_vermelho <id> <descricao> <asserções que TÊM de cair...>`
espera_vermelho() {
  local id="$1"; shift
  local desc="$1"; shift
  local saida rc
  saida="$(roda)"; rc=$?
  echo "$saida" > "$EVID/${id}_mutacao_unidade.txt"
  local faltou=""
  for asser in "$@"; do
    echo "$saida" | grep -q "✗ $asser " || faltou="$faltou $asser"
  done
  if [ $rc -ne 0 ] && [ -z "$faltou" ]; then
    echo "  → ✓ $id VERMELHO como exigido ($desc)"
    echo "$saida" | grep '✗' | sed 's/^/      /'
    verde=$((verde+1))
  else
    echo "  → ✗✗ $id NÃO REPROVOU — asserção cega. Faltou reprovar:$faltou"
    echo "$saida" | tail -5 | sed 's/^/      /'
    vermelho=$((vermelho+1))
  fi
  restaurar
}

# ── M1 · sem o init(from:) à mão ────────────────────────────────────────────
echo
echo "═════ M1 · apaga o init(from:) de StoredFood (decoder sintetizado) ═════"
/usr/bin/python3 - "$ALVO" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
i = t.index('    public init(from decoder: Decoder) throws {')
j = t.index('\n    }\n', i) + len('\n    }\n')
novo = t[:i] + '    // [MUTAÇÃO M1] init(from:) removido de propósito.\n' + t[j:]
assert 'init(from decoder' not in novo, 'mutação M1 não removeu o init'
open(p, 'w', encoding='utf-8').write(novo)
print('  mutação M1 aplicada')
PY
espera_vermelho "01" "os alimentos antigos somem" "U1" "U5"

# ── M2 · decodeIfPresent → decode ───────────────────────────────────────────
echo
echo "═════ M2 · lerRetrocompativel passa a exigir a chave (decode) ═════"
/usr/bin/python3 - "$ALVO" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
antes = 'guard let bruto = try container.decodeIfPresent(String.self, forKey: chave) else {'
depois = 'let bruto: String? = try container.decode(String.self, forKey: chave); guard let bruto else {'
assert antes in t, 'mutação M2 não achou a linha alvo'
open(p, 'w', encoding='utf-8').write(t.replace(antes, depois, 1))
print('  mutação M2 aplicada')
PY
espera_vermelho "02" "a chave ausente volta a lançar" "U1" "U5"

# ── M3 · adivinhação por nome ───────────────────────────────────────────────
echo
echo "═════ M3 · daEmbalagem passa a adivinhar pelo NOME ═════"
/usr/bin/python3 - "$ALVO" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
marca = '        guard let texto, !texto.isEmpty else { return nil }'
assert marca in t, 'mutação M3 não achou o começo de daEmbalagem'
injecao = (marca + '\n'
           '        // [MUTAÇÃO M3] a versão rápida que o comentário recusa.\n'
           '        let porNome = texto.lowercased()\n'
           '        for palavra in ["leite", "suco", "agua", "refrigerante", "cha", "cafe"] {\n'
           '            if porNome.contains(palavra) { return .mililitro }\n'
           '        }')
open(p, 'w', encoding='utf-8').write(t.replace(marca, injecao, 1))
print('  mutação M3 aplicada')
PY
espera_vermelho "03" "palpite por nome erra no leite em pó" "U8" "U9"

# ── Fecho ───────────────────────────────────────────────────────────────────
echo
echo "═════ FECHO · o arquivo voltou ao original? ═════"
restaurar
FIM="$(roda)"; RC=$?
echo "$FIM" | tail -3
if [ $RC -eq 0 ]; then
  echo "  → ✓ verde de novo após restaurar"
  if diff -q "$BKP" "$ALVO" >/dev/null; then
    echo "  → ✓ arquivo idêntico ao original (nenhum resíduo de mutação)"
    verde=$((verde+1))
  else
    echo "  → ✗✗ O ARQUIVO NÃO VOLTOU AO ORIGINAL — confira antes de commitar"
    vermelho=$((vermelho+1))
  fi
else
  echo "  → ✗✗ continua vermelho depois de restaurar"
  vermelho=$((vermelho+1))
fi

echo
echo "═════ RESUMO: $verde etapa(s) como esperado · $vermelho problema(s) ═════"
[ $vermelho -eq 0 ] || exit 1
