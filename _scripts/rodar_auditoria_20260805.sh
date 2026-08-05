#!/bin/bash
# Roda a auditoria automática no simulador — 05/08/2026.
#
# Mesmo desenho do `_scripts/rodar_auditoria.sh` (que continua valendo): a saída
# do harness é NSLog, então precisa de `log stream` filtrando "[AUDIT]" — não
# aparece no stdout do `simctl launch`. E o gatilho é `-auditoria 1`.
#
# Diferenças: descobre o simulador e o .app em vez de assumir caminho fixo (o
# ID anotado no CLAUDE.md já não existe, e o DerivedData aqui é o padrão).
# Sem archive e sem upload: a 2.0 está em revisão.
set -u
RAIZ=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main
OUT="$RAIZ/_validacao_20260805"
BUNDLE=com.almaapp.app

DEV=$(xcrun simctl list devices available \
  | grep -E '^\s+iPhone' | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
APP=$(find ~/Library/Developer/Xcode/DerivedData/Alma.App.Oficial-*/Build/Products/Debug-iphonesimulator \
  -maxdepth 1 -name 'Alma.App.Oficial.app' 2>/dev/null | head -1)
[ -n "$DEV" ] && [ -n "$APP" ] || { echo "dev=$DEV app=$APP — faltou algo"; exit 3; }

mkdir -p "$OUT"
rm -f /tmp/auditoria_alma.done

(
  xcrun simctl bootstatus "$DEV" -b > /dev/null 2>&1
  xcrun simctl terminate "$DEV" "$BUNDLE" > /dev/null 2>&1
  xcrun simctl uninstall "$DEV" "$BUNDLE" > /dev/null 2>&1
  xcrun simctl install  "$DEV" "$APP" > /dev/null 2>&1
  xcrun simctl privacy  "$DEV" grant all "$BUNDLE" > /dev/null 2>&1

  xcrun simctl spawn "$DEV" log stream \
    --predicate 'eventMessage CONTAINS "[AUDIT]"' --style compact > /tmp/audit_0805.txt 2>&1 &
  STREAM=$!
  sleep 4

  xcrun simctl launch "$DEV" "$BUNDLE" -auditoria 1 -semPermissoes 1 > /dev/null 2>&1
  sleep 45
  kill $STREAM 2>/dev/null
  xcrun simctl terminate "$DEV" "$BUNDLE" > /dev/null 2>&1
  echo pronto > /tmp/auditoria_alma.done
) > /dev/null 2>&1 &

echo "auditoria iniciada em $DEV"
echo "app: $APP"
