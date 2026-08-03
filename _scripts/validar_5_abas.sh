#!/bin/bash
# Validação real das 5 abas do módulo Corpo, em instalação LIMPA e SEM o seed de
# DEBUG (-semearPerfil). A revisão independente apontou que a validação anterior
# foi contaminada pelo seed: os dados que eu vi na tela existiam só porque o
# próprio harness os tinha criado.
set -u
DEV=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260803

mkdir -p "$OUT"
NOMES=("Inicio" "Saude" "Dieta" "Treino" "Insights")

xcrun simctl terminate "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl uninstall "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1; xcrun simctl privacy "$DEV" grant all com.almaapp.app 2>/dev/null
echo "instalação limpa: ok (sem dados de nenhum usuário anterior)"

ANTES=$(ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci alma || echo 0)

for i in 0 1 2 3 4; do
  xcrun simctl terminate "$DEV" com.almaapp.app 2>/dev/null
  sleep 1
  xcrun simctl launch "$DEV" com.almaapp.app -abrirCorpo 1 -semPermissoes 1 -corpoAba "$i" > /dev/null 2>&1
  sleep 6
  xcrun simctl io "$DEV" screenshot "$OUT/aba${i}_${NOMES[$i]}.png" > /dev/null 2>&1
  # App vivo = não crashou
  if xcrun simctl spawn "$DEV" launchctl list 2>/dev/null | grep -q "com.almaapp.app"; then
    echo "aba $i (${NOMES[$i]}): VIVA"
  else
    echo "aba $i (${NOMES[$i]}): MORREU"
  fi
done

DEPOIS=$(ls ~/Library/Logs/DiagnosticReports/ 2>/dev/null | grep -ci alma || echo 0)
echo "crash reports novos: $((DEPOIS - ANTES))"
