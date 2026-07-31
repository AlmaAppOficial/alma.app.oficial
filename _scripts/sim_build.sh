#!/bin/bash
# Build de simulador do Alma iOS (uso local, para validação rápida).
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
LOG="${1:-/tmp/alma_sim_build.log}"
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -destination "platform=iOS Simulator,id=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7" \
  -derivedDataPath /tmp/alma_dd \
  build > "$LOG" 2>&1
echo "BUILD_EXIT:$?"
grep -m1 "BUILD SUCCEEDED\|BUILD FAILED" "$LOG"
