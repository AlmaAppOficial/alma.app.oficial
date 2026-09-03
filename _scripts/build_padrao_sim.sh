#!/bin/bash
# Build de simulador desta WORKTREE (não do checkout principal — a lição do
# versionCode 7 do Android: buildar da árvore errada esconde o que se acabou de
# escrever). Roda da raiz em que este script está.
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ" || exit 1
LOG="${1:-/tmp/alma_padrao_build.log}"
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -destination "platform=iOS Simulator,id=C9FE7224-677D-4B38-9F94-9C7BCE331053" \
  -derivedDataPath /tmp/alma_padrao_dd \
  build > "$LOG" 2>&1
echo "BUILD_EXIT:$?" >> "$LOG"
grep -m1 "BUILD SUCCEEDED\|BUILD FAILED" "$LOG" >> "$LOG"
