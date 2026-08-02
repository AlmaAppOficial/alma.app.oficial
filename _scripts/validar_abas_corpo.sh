#!/bin/bash
# Valida as 5 abas do módulo Corpo sem automação de toque:
# abre o app direto em cada aba, confirma que o processo sobrevive e captura tela.
set -u
D=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
EVID=/Users/almaappoficial/Desktop/ALMA/evidencias_fusao
NOMES=("inicio" "saude" "dieta" "treino" "insights")

xcrun simctl install "$D" "$APP" || exit 1
mkdir -p "$EVID"

FALHAS=0
for i in 0 1 2 3 4; do
  NOME="${NOMES[$i]}"
  xcrun simctl terminate "$D" com.almaapp.app 2>/dev/null
  sleep 1
  PID=$(xcrun simctl launch "$D" com.almaapp.app -abrirCorpo 1 -corpoAba "$i" | sed 's/.*: //')
  sleep 9
  if ps -p "$PID" > /dev/null 2>&1; then
    STATUS="VIVO"
  else
    STATUS="CRASH"
    FALHAS=$((FALHAS+1))
  fi
  xcrun simctl io "$D" screenshot "$EVID/0$((i+5))_corpo_aba_${NOME}.png" 2>/dev/null
  printf 'aba %d (%-9s) -> %s\n' "$i" "$NOME" "$STATUS"
done

echo
echo "abas com crash: $FALHAS"
[ "$FALHAS" -eq 0 ] && echo "TODAS AS 5 ABAS OK" || echo "REPROVADO"
