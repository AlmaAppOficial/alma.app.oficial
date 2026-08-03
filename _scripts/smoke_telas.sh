#!/bin/bash
# Varredura de crash em todas as telas do app fundido (SmokeTestTelas.swift).
# Instalação limpa, sem dados de ninguém, com o log capturado do unified log.
set -u
DEV=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260803

mkdir -p "$OUT"

xcrun simctl terminate "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl uninstall "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all com.almaapp.app 2>/dev/null

ANTES=$(ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci alma || echo 0)

xcrun simctl spawn "$DEV" log stream \
  --predicate 'eventMessage CONTAINS "[SMOKE]"' --style compact > /tmp/smoke.txt 2>&1 &
STREAM=$!
sleep 3

xcrun simctl launch "$DEV" com.almaapp.app -smokeTelas 1 -semPermissoes 1 > /dev/null 2>&1
sleep 35

if xcrun simctl spawn "$DEV" launchctl list 2>/dev/null | grep -q "com.almaapp.app"; then
  echo "APP VIVO no fim da varredura (não crashou)"
else
  echo "APP MORREU durante a varredura — ver última linha do log"
fi

DEPOIS=$(ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci alma || echo 0)
echo "crash reports novos: $((DEPOIS - ANTES))"

kill $STREAM 2>/dev/null
grep -a 'SMOKE' /tmp/smoke.txt | sed 's/.*\[SMOKE\] //' > "$OUT/08_smoke_telas.txt"
echo "linhas de log: $(wc -l < "$OUT/08_smoke_telas.txt")"
tail -4 "$OUT/08_smoke_telas.txt"
