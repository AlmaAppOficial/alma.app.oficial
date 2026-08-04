#!/bin/bash
# Build RELEASE de verdade desta branch.
#
# [2026-08-04] A reauditoria mostrou que o único binário Release existente era
# de 03/08 20:50 — anterior a 5 dos 6 commits da frente. A prova "strings no
# Release" estava sendo feita no binário errado. Com o disco livre, refazemos.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
LOG=/tmp/release_0804.log
rm -rf /tmp/alma_rel_novo

xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath /tmp/alma_rel_novo \
  CODE_SIGNING_ALLOWED=NO \
  build > "$LOG" 2>&1
echo "RELEASE_EXIT:$?"
grep -m1 "BUILD SUCCEEDED\|BUILD FAILED" "$LOG"

BIN=$(find /tmp/alma_rel_novo/Build/Products -name "Alma.App.Oficial" -type f 2>/dev/null | head -1)
echo "binário: ${BIN:-NÃO ENCONTRADO}"
[ -z "${BIN:-}" ] && exit 1

echo
echo "───── HEAD deste binário ─────"
git rev-parse --short HEAD
echo "───── build/versão compilados ─────"
PLIST=$(dirname "$BIN")/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST" 2>/dev/null

echo
echo "───── flags de DEBUG no Release (esperado: 0 em todas) ─────"
for s in semearPerfil semearSaude dumpContexto auditoria smokeTelas capturarTelas semPermissoes abrirCorpo corpoAba testePersistencia; do
  n=$(strings "$BIN" | grep -c "^$s$")
  printf '  %-20s %s\n' "$s" "$n"
done

echo
echo "───── produtos do app descontinuado (esperado: 0) ─────"
strings "$BIN" | grep -c "corpoealma.premium" || true
echo "───── produtos do Alma (esperado: >0) ─────"
strings "$BIN" | grep -c "com.almaapp.app.premium" || true

echo
echo "───── promessa de IA no binário Release ─────"
strings "$BIN" | grep -c "Scan corporal com IA" || true
strings "$BIN" | grep -c "scan com IA" || true
