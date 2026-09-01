#!/bin/bash
# Lança o build do Alma Watch App para o simulador em SEGUNDO PLANO, com log em
# arquivo — o chamador (osascript) volta na hora e acompanha pelo log.
# Uso: ./lancar_build_watch.sh [destino]  (padrão: Series 11 46mm)
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESTINO="${1:-platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)}"
LOG="$RAIZ/_validacao_20260829_watch/build_watch.log"
mkdir -p "$RAIZ/_validacao_20260829_watch"
cd "$RAIZ"
nohup xcodebuild \
    -project Alma.App.Oficial.xcodeproj \
    -scheme "Alma Watch App" \
    -configuration Debug \
    -destination "$DESTINO" \
    -derivedDataPath build_watch_dd \
    build > "$LOG" 2>&1 &
echo "PID $! — log em $LOG"
