#!/bin/bash
# Instala o app iOS no simulador em segundo plano e registra o resultado.
set -u
P=C6E2BF1F-9ECF-4D63-B8B2-9BEC56F4405F
WT="$(cd "$(dirname "$0")/.." && pwd)"
DD_BASE="$HOME/Library/Developer/Xcode/DerivedData"
DD="$DD_BASE/$(basename "$WT")_watch_dd"
LOG="$WT/_validacao_20260829_watch/install_ios.log"
nohup bash -c "xcrun simctl install $P '$DD/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app' && echo INSTALADO || echo FALHOU" > "$LOG" 2>&1 &
echo "lancado — log em $LOG"
