#!/bin/bash
# Build de simulador do módulo de jejum — 26/08/2026
#
# Modelado no `build_e_auditar_20260805.sh`: descobre o simulador em tempo de
# execução (o CLAUDE.md explica por que UUID anotado apodrece), compila em
# Debug com o team local, e se destaca em background porque a sessão que chama
# tem timeout curto.
#
# SEM archive e SEM upload, como o de 05/08. Isto é build de teste.
set -u
PROJ=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main

IPHONE=$(xcrun simctl list devices available \
  | grep -E '^\s+iPhone' | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$IPHONE" ] || { echo "sem simulador de iPhone disponível"; exit 3; }
echo "simulador: $IPHONE"
echo "$IPHONE" > /tmp/jejum_sim_id

rm -f /tmp/build_jejum.log /tmp/build_jejum.done

(
  cd "$PROJ" || exit 1
  xcodebuild -scheme "Alma.App.Oficial (iOS)" \
    -destination "platform=iOS Simulator,id=$IPHONE" \
    -configuration Debug \
    DEVELOPMENT_TEAM=CV2V6HLTS2 \
    build > /tmp/build_jejum.log 2>&1
  echo $? > /tmp/build_jejum.done
) > /dev/null 2>&1 &

echo "build iniciado — /tmp/build_jejum.log, fim em /tmp/build_jejum.done"
