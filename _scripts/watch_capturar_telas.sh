#!/bin/bash
# Captura as telas do app do Watch no simulador (harness de verdade visual).
# Usa o argumento -paginaInicial para abrir cada página. [2026-08-04]
set -u
UD=2E7F59B6-72EE-44F0-BC4B-91210EA3B409
APP='/tmp/almawatch_simsym/Debug-watchsimulator/Alma Watch App.app'
DEST='/Users/almaappoficial/Desktop/ALMA/evidencias_watch_20260804'

cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

/usr/bin/xcodebuild -project Alma.App.Oficial.xcodeproj \
  -target 'Alma Watch App' -configuration Debug -sdk watchsimulator \
  CODE_SIGNING_ALLOWED=NO SYMROOT=/tmp/almawatch_simsym build > /tmp/watch_sim_build3.log 2>&1
grep -E 'BUILD (SUCCEEDED|FAILED)' /tmp/watch_sim_build3.log

/usr/bin/xcrun simctl install "$UD" "$APP" || exit 1
mkdir -p "$DEST" /tmp/watch_prints

for p in agua humor respirar treino meditacoes; do
  /usr/bin/xcrun simctl terminate "$UD" com.almaapp.app.watchkitapp 2>/dev/null
  sleep 1
  /usr/bin/xcrun simctl launch "$UD" com.almaapp.app.watchkitapp -paginaInicial "$p" > /dev/null
  sleep 4
  /usr/bin/xcrun simctl io "$UD" screenshot "/tmp/watch_prints/$p.png" 2>/dev/null && echo "print_$p"
done

cp /tmp/watch_prints/*.png "$DEST/" && echo COPIADO
