#!/bin/bash
# [2026-08-31] Compila e roda as asserções do Áudio do dia contra o código de
# PRODUÇÃO de `Shared/AudioDoDiaRegras.swift`. Mesmo desenho (e mesmo motivo)
# do rodar_teste_fisiologia.sh: main.swift é exigência do swiftc para
# expressões de topo, então o arquivo descritivo é copiado na hora.
#
# NÃO toca no DerivedData, não abre o Xcode, não compila o app. Segundos —
# é o que torna a MUTAÇÃO barata o bastante para ser rotina.
#
# Uso:  bash _scripts/rodar_teste_audio_do_dia.sh
# Saída: 0 = verde · 1 = vermelho · 2 = detector cego · 3 = nem compilou

set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

TMP=$(mktemp -d)
cp _scripts/teste_audio_do_dia.swift "$TMP/main.swift"

echo "── COMPILANDO (produção + asserções) ──"
if ! xcrun swiftc -O Shared/AudioDoDiaRegras.swift "$TMP/main.swift" -o "$TMP/t" 2>"$TMP/erros"; then
    echo "✗✗ NÃO COMPILOU — nenhuma asserção rodou. Isto NÃO é um teste vermelho,"
    echo "   é a ausência de teste. Erros:"
    sed 's/^/   /' "$TMP/erros" | head -40
    rm -rf "$TMP"
    exit 3
fi
echo "✓ compilou (o passo que a mutação confirma antes de qualquer vermelho contar)"

echo
"$TMP/t"
CODIGO=$?
rm -rf "$TMP"
exit $CODIGO
