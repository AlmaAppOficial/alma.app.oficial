#!/bin/bash
# Compila o padrão do exercício com swiftc e roda as asserções — sem simulador.
#
# Só entram aqui arquivos que importam apenas Foundation. Se alguém acrescentar
# `import SwiftUI` a qualquer um deles, este script para de compilar — e é essa
# a intenção: é o que mantém o domínio exercitável.
#
# `Exercicio.swift` está na lista porque as asserções L0–L3 decodificam um
# `customWorkouts` gravado ANTES do padrão com os structs de HOJE. É a prova de
# que este trabalho não acrescentou campo a `Exercise` — o campo novo que
# apagaria, em silêncio, todo treino que a pessoa montou.
#
# Roda da worktree em que ESTE script está — não de um caminho fixo.
#
# Saída: 0 = verde · 1 = vermelho · 3 = nem compilou
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ" || exit 3

TMP=$(mktemp -d)
cp _scripts/testes_padrao.swift "$TMP/main.swift"

echo "── COMPILANDO (produção + asserções) ──"
echo "   raiz: $RAIZ"
if ! xcrun swiftc -O \
      Shared/Corpo/Exercicio.swift \
      Shared/Corpo/RegistroDeSeries.swift \
      Shared/Corpo/PadraoDoExercicio.swift \
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
