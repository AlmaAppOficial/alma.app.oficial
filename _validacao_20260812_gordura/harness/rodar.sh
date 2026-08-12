#!/bin/bash
# Compila o harness contra o código de PRODUÇÃO e roda.
#
# Uso: bash rodar.sh <arquivo-de-saida.txt> "<rótulo>"
#
# A ordem importa e é o ponto da lição de hoje: se a compilação falhar, o
# script PARA e diz isso. Ele nunca roda um binário velho por cima de um build
# quebrado, e nunca manda erro de compilação para /dev/null — foi exatamente
# assim que uma mutação passou verde medindo a biblioteca antiga.

set -u
REPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main"
DEST="$REPO/_validacao_20260812_gordura/$1"
ROTULO="${2:-sem rótulo}"
BIN="/tmp/gordura_harness_$$"

cd "$REPO" || exit 9

{
  echo "═════ $ROTULO"
  echo "data: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "swiftc: $(swiftc --version 2>&1 | head -1)"
  echo "arquivos compilados (produção + andaimes + asserções):"
  echo "  Shared/Corpo/AIBodyScan.swift  (PRODUÇÃO — sha1 $(shasum Shared/Corpo/AIBodyScan.swift | cut -c1-12))"
  echo "  Shared/Corpo/ScanResultView.swift  (lido como texto — sha1 $(shasum Shared/Corpo/ScanResultView.swift | cut -c1-12))"
  echo "  _validacao_20260812_gordura/harness/{stubs,main}.swift"
  echo "─── COMPILAÇÃO ───"
} > "$DEST"

rm -f "$BIN"
COMPILA=$(swiftc -o "$BIN" \
    Shared/Corpo/AIBodyScan.swift \
    _validacao_20260812_gordura/harness/stubs.swift \
    _validacao_20260812_gordura/harness/main.swift 2>&1)
STATUS_COMPILA=$?

echo "$COMPILA" >> "$DEST"
echo "exit code do swiftc: $STATUS_COMPILA" >> "$DEST"

if [ $STATUS_COMPILA -ne 0 ] || [ ! -x "$BIN" ]; then
  {
    echo ""
    echo "✗✗ NÃO COMPILOU — nenhum resultado abaixo pode ser acreditado."
    echo "   (binário existe? $([ -x "$BIN" ] && echo sim || echo não))"
  } >> "$DEST"
  cat "$DEST"
  exit 1
fi

{
  echo "✓ COMPILOU (binário novo: $(date -r "$BIN" '+%H:%M:%S'))"
  echo "─── EXECUÇÃO ───"
} >> "$DEST"

SAIDA=$("$BIN" "$REPO" 2>&1)
STATUS_RODA=$?
{
  echo "$SAIDA"
  echo "exit code do harness: $STATUS_RODA  (0 = tudo verde, 1 = houve falha, 2 = abortou)"
} >> "$DEST"

rm -f "$BIN"
cat "$DEST"
exit $STATUS_RODA
