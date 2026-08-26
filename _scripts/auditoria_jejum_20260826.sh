#!/bin/bash
# Roda o `AuditoriaBloqueadores` no simulador e filtra o que interessa ao
# jejum — as asserções J* (novas) e as N3/R7/R7b (que o dono de lembrete novo
# tocou).
#
# Diferente do `capturar_jejum_20260826.sh`: aqui NÃO passa `-soVisual 1`,
# porque é justamente o auditor que precisa rodar.
set -u
BUNDLE=com.almaapp.app
DEV=$(cat /tmp/jejum_sim_id 2>/dev/null)
[ -n "${DEV:-}" ] || DEV=$(xcrun simctl list devices available \
  | grep -E '^\s+iPhone' | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')

APP=$(find ~/Library/Developer/Xcode/DerivedData -type d \
      -path '*/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app' \
      -not -path '*Index.noindex*' 2>/dev/null \
      | xargs -I{} stat -f '%m {}' {} 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$APP" ] || { echo "app não encontrado"; exit 4; }

xcrun simctl boot "$DEV" 2>/dev/null; sleep 3
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

rm -f /tmp/auditoria_jejum.txt
xcrun simctl spawn "$DEV" log stream --predicate 'eventMessage CONTAINS "[AUDIT]"' \
  --style compact > /tmp/auditoria_jejum.txt 2>/dev/null &
LOGPID=$!
sleep 2

xcrun simctl launch "$DEV" "$BUNDLE" \
  -semLogin 1 -auditoria 1 -semearPerfil 1 -semearSaude 1 -semPermissoes 1 \
  > /dev/null 2>&1
sleep 40
kill $LOGPID 2>/dev/null

echo "───── J* (jejum) ─────"
grep -oE '\[AUDIT\] [✓✗] (J[0-9][a-z]?) .*' /tmp/auditoria_jejum.txt | sed 's/\[AUDIT\] //' | sort -u
echo
echo "───── N3 / R7 / R7b (lembretes — dono novo) ─────"
grep -oE '\[AUDIT\] [✓✗] (N3|R7b?) .*' /tmp/auditoria_jejum.txt | sed 's/\[AUDIT\] //' | sort -u
echo
echo "───── placar geral ─────"
grep -oE '\[AUDIT\] .*(APROVAD|REPROVAD|placar|total).*' /tmp/auditoria_jejum.txt | sed 's/\[AUDIT\] //' | tail -5
REPROVADAS=$(grep -c '✗' /tmp/auditoria_jejum.txt || true)
echo "linhas com ✗ no log inteiro: $REPROVADAS"
