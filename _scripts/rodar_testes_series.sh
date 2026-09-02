#!/bin/bash
# Compila o registro de séries com swiftc e roda as asserções — sem simulador.
#
# Só entram aqui arquivos que importam apenas Foundation. Se alguém acrescentar
# `import SwiftUI` a qualquer um deles, este script para de compilar — e é essa
# a intenção: é o que mantém o domínio exercitável.
#
# `Exercicio.swift` está na lista porque a asserção L1 decodifica um
# `customWorkouts` gravado antes de 02/09/2026 com os structs de HOJE.
#
# Saída: 0 = verde · 1 = vermelho · 3 = nem compilou
set -u
cd "$HOME/Desktop/alma/alma.app.oficial-main" || exit 3

TMP=$(mktemp -d)
cp _scripts/testes_series.swift "$TMP/main.swift"

echo "── COMPILANDO (produção + asserções) ──"
if ! xcrun swiftc -O \
      Shared/Corpo/Exercicio.swift \
      Shared/Corpo/RegistroDeSeries.swift \
      "$TMP/main.swift" -o "$TMP/t" 2>"$TMP/erros"; then
    echo "✗✗ NÃO COMPILOU — nenhuma asserção rodou. Isto NÃO é um teste"
    echo "   vermelho, é a AUSÊNCIA de teste. Erros:"
    sed 's/^/   /' "$TMP/erros" | grep 'error:' | head -30
    rm -rf "$TMP"
    exit 3
fi

"$TMP/t"
CODIGO=$?
rm -rf "$TMP"
exit $CODIGO
