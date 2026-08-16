#!/bin/bash
# [2026-08-14] Compila e roda as asserções de fisiologia contra o código de
# PRODUÇÃO de `Shared/RegrasDeSaude.swift`.
#
# Por que o `cp` para `main.swift`: o Swift só aceita expressões no topo do
# arquivo se ele se chamar `main.swift`. O arquivo fica no repositório com nome
# descritivo e é copiado na hora de compilar. Sem gambiarra escondida: é isto,
# e está escrito aqui.
#
# NÃO toca no DerivedData, não abre o Xcode, não compila o app. Segundos.
# É isso que torna a MUTAÇÃO barata o bastante para ser rotina.
#
# Uso:
#   bash _scripts/rodar_teste_fisiologia.sh
# Saída: 0 = verde · 1 = vermelho · 2 = detector cego · 3 = nem compilou

set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

TMP=$(mktemp -d)
cp _scripts/teste_fisiologia.swift "$TMP/main.swift"

echo "── COMPILANDO (produção + asserções) ──"
if ! xcrun swiftc -O Shared/RegrasDeSaude.swift "$TMP/main.swift" -o "$TMP/t" 2>"$TMP/erros"; then
    echo "✗✗ NÃO COMPILOU — nenhuma asserção rodou. Isto NÃO é um teste vermelho,"
    echo "   é a ausência de teste. Erros:"
    sed 's/^/   /' "$TMP/erros" | head -40
    rm -rf "$TMP"
    exit 3
fi
echo "✓ compilou (este é o passo que a mutação precisa confirmar antes de"
echo "  qualquer vermelho contar — mutação que não compila não provou nada)"

echo
"$TMP/t"
CODIGO=$?
rm -rf "$TMP"
exit $CODIGO
