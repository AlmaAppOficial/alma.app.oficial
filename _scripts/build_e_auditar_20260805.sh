#!/bin/bash
# Build de simulador + auditoria — 05/08/2026
#
# SEM archive e SEM upload de propósito: a 2.0 (build 93) está em revisão da
# Apple e o próximo build pertence a uma versão futura. Este script só compila
# e roda o harness de DEBUG no simulador.
#
# Ele se destaca sozinho (subshell em background) porque a sessão que o chama
# tem timeout curto: quem chama volta na hora e depois lê /tmp/build_alma.done.
set -u
PROJ=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main
# [05/08] Os IDs anotados no CLAUDE.md (iPhone 17 / iPad Air M4) não existem
# mais nesta máquina — o Xcode trocou os simuladores. Descobrir na hora evita
# que este script apodreça de novo.
IPHONE=$(xcrun simctl list devices available \
  | grep -E '^\s+iPhone' | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$IPHONE" ] || { echo "sem simulador de iPhone disponível"; exit 3; }
echo "simulador: $IPHONE"

rm -f /tmp/build_alma.log /tmp/build_alma.done

(
  cd "$PROJ" || exit 1
  xcodebuild -scheme "Alma.App.Oficial (iOS)" \
    -destination "platform=iOS Simulator,id=$IPHONE" \
    -configuration Debug \
    DEVELOPMENT_TEAM=CV2V6HLTS2 \
    build > /tmp/build_alma.log 2>&1
  echo $? > /tmp/build_alma.done
) > /dev/null 2>&1 &

echo "build iniciado — acompanhe /tmp/build_alma.log, fim em /tmp/build_alma.done"
