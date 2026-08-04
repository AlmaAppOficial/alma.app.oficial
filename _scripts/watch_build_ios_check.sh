#!/bin/bash
# Conferência de compilação do scheme iOS (inclui Shared/WatchBridge + embed do
# Watch). NÃO assina, NÃO arquiva, NÃO envia — só compila para validar código.
# [2026-08-04 — frente Apple Watch]
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
rm -f /tmp/ios_build.log
nohup /usr/bin/xcodebuild \
  -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Debug \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  build > /tmp/ios_build.log 2>&1 &
echo "DISPARADO"
