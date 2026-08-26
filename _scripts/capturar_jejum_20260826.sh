#!/bin/bash
# Conferência visual do módulo de jejum — 26/08/2026
#
# Modelado no `capturar_telas.sh` de 04/08: o PNG vem do próprio harness que
# monta a view num `UIWindow` real, e não de screenshot do simulador. O motivo
# está escrito no cabeçalho de `SmokeTestTelas.conferenciaDeAparencia`: o
# `fullScreenCover` do módulo Corpo não apresenta a partir de `-corpoAba N`, e
# nas três tentativas de 04/08 o print saiu da Home do Alma.
set -u
PROJ=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main
BUNDLE=com.almaapp.app
OUT="$PROJ/_validacao_20260826_jejum"

DEV=$(cat /tmp/jejum_sim_id 2>/dev/null)
if [ -z "${DEV:-}" ]; then
  DEV=$(xcrun simctl list devices available | grep -E '^\s+iPhone' | head -1 \
        | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
fi
[ -n "$DEV" ] || { echo "sem simulador"; exit 3; }

# `Index.noindex` é o build do INDEXADOR do Xcode: ele existe, tem o nome
# certo e NÃO tem bundle ID — instalar dá "Missing bundle ID". Custou uma
# rodada em 26/08. O build de verdade fica sob `/Build/Products/`.
APP=$(find ~/Library/Developer/Xcode/DerivedData -type d \
      -path '*/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app' \
      -not -path '*Index.noindex*' 2>/dev/null \
      | xargs -I{} stat -f '%m {}' {} 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$APP" ] || { echo "app compilado não encontrado"; exit 4; }
echo "simulador: $DEV"
echo "app: $APP"

rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl boot "$DEV" 2>/dev/null
sleep 3
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

# `-semLogin 1` é obrigatório: os harnesses rodam no `.task` da `HomeView`, que
# fica ATRÁS do portão de autenticação (ver `RootView.pularLoginParaHarness`).
# Sem ele o app para na tela de login e sai zero captura — custou uma rodada.
xcrun simctl launch "$DEV" "$BUNDLE" \
  -semLogin 1 -conferenciaAparencia 1 -capturarTelas 1 -soVisual 1 \
  -semearPerfil 1 -semearSaude 1 -semPermissoes 1 > /dev/null 2>&1
sleep 45

CONTAINER=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null)
[ -n "$CONTAINER" ] || { echo "container não encontrado"; exit 5; }
cp "$CONTAINER/Documents/capturas/"*.png "$OUT/" 2>/dev/null

TOTAL=$(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
JEJUM=$(ls -1 "$OUT"/*J[0-9]*.png 2>/dev/null | wc -l | tr -d ' ')
echo "capturas: $TOTAL (do jejum: $JEJUM)"
ls -1 "$OUT" | sed 's/^/  /'
