#!/bin/bash
# Evidência visual do padrão do exercício — 03/09/2026.
#
# As capturas vêm do `ImageRenderer` que já varre as telas (`SmokeTestTelas`),
# pelo mesmo motivo declarado em `capturar_telas.sh`: não dependem de navegação,
# toque nem diálogo do sistema. O app RODA no simulador; o que se vê é a View de
# produção desenhada com o `AppModel` de produção.
#
# As telas novas são quatro:
#   · "Meu padrão (vazio)"      — placeholders do catálogo, nada definido;
#   · "Meu padrão (definido)"   — 3 × 8 × 60 kg já salvos e relidos do store;
#   · "Detalhe do exercício"    — antes, ainda com a sugestão do catálogo;
#   · "Detalhe do exercício (com padrão)" — depois, com o volume da pessoa.
set -u
DEV=C9FE7224-677D-4B38-9F94-9C7BCE331053
APP=/tmp/alma_padrao_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
BUNDLE=com.almaapp.app
OUT="$(cd "$(dirname "$0")/.." && pwd)/_validacao_20260903_padrao/telas"
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl boot "$DEV" 2>/dev/null
xcrun simctl bootstatus "$DEV" -b >/dev/null 2>&1
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

xcrun simctl launch "$DEV" "$BUNDLE" \
  -smokeTelas 1 -capturarTelas 1 -semearPerfil 1 -semearSaude 1 -semPermissoes 1 > /dev/null 2>&1
sleep 45

CONTAINER=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null)
if [ -z "$CONTAINER" ]; then echo "✗ container não encontrado"; exit 1; fi
cp "$CONTAINER/Documents/capturas/"*.png "$OUT/" 2>/dev/null

echo "capturas totais: $(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')"
echo "── as do padrão ──"
ls -1 "$OUT" | grep -i "padr" || echo "  ✗ NENHUMA — a tela nova não foi renderizada"
