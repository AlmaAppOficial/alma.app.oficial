#!/bin/bash
# Compila o domínio do jejum com swiftc e roda as asserções — sem simulador.
#
# Só entram aqui arquivos que importam apenas Foundation. Se alguém acrescentar
# `import SwiftUI` a qualquer um deles, este script para de compilar — e é essa
# a intenção: é o que mantém o domínio exercitável.
#
# [28/08] `JejumAoVivo.swift` entrou na lista. Ele TEM um `import ActivityKit`,
# mas dentro de `#if canImport(ActivityKit) && os(iOS)` — no Mac esse bloco não
# existe, e o que sobra é a função pura `estadoAoVivo`, que é justamente a
# decisão que o cronômetro da tela bloqueada precisa acertar. O encanamento com
# o ActivityKit fica fora do alcance daqui, e isso está declarado no rodapé do
# `mutacao_jejum.sh`.
#
# Por que o `cp` para `main.swift`: o Swift só aceita expressões no topo do
# arquivo se ele se chamar `main.swift`. O arquivo fica no repositório com nome
# descritivo e é copiado na hora — mesma solução do `rodar_teste_fisiologia.sh`,
# e escrita aqui pelo mesmo motivo: sem gambiarra escondida.
#
# Saída: 0 = verde · 1 = vermelho · 3 = nem compilou
set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

TMP=$(mktemp -d)
cp _scripts/testes_jejum.swift "$TMP/main.swift"

echo "── COMPILANDO (produção + asserções) ──"
if ! xcrun swiftc -O \
      Shared/Corpo/UnidadeDeMedida.swift \
      Shared/Corpo/Refeicao.swift \
      Shared/Corpo/Jejum.swift \
      Shared/Corpo/JejumConteudo.swift \
      Shared/Corpo/QuebraDeJejum.swift \
      Shared/Corpo/JejumAoVivo.swift \
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
