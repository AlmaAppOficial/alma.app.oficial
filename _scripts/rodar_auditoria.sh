#!/bin/bash
# Roda a auditoria automática dos bloqueadores no app real, instalação limpa.
set -u
DEV=64B214AD-5854-4F5A-ADCA-A1A936358170
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260803

mkdir -p "$OUT"
xcrun simctl terminate "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl uninstall "$DEV" com.almaapp.app 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all com.almaapp.app 2>/dev/null

xcrun simctl spawn "$DEV" log stream \
  --predicate 'eventMessage CONTAINS "[AUDIT]"' --style compact > /tmp/audit.txt 2>&1 &
STREAM=$!
sleep 3

xcrun simctl launch "$DEV" com.almaapp.app -auditoria 1 -semPermissoes 1 > /dev/null 2>&1
sleep 20
kill $STREAM 2>/dev/null

# Uma passada só (o .task da Home reexecuta)
python3 - <<'PY'
import re
d = open('/tmp/audit.txt', encoding='utf-8', errors='ignore').read().split('\n')
ini = [i for i, l in enumerate(d) if 'AUDITORIA DOS BLOQUEADORES' in l]
if not ini:
    print('nenhuma passada capturada'); raise SystemExit(1)
fim = ini[1] if len(ini) > 1 else len(d)
passada = [l.split('[AUDIT] ')[-1] for l in d[ini[0]:fim] if '[AUDIT]' in l]
out = '/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260803/09_auditoria_bloqueadores.txt'
open(out, 'w', encoding='utf-8').write('\n'.join(passada))
for l in passada:
    print(l)
PY
