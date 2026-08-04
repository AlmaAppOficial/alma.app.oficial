#!/bin/bash
# Validação de 04/08/2026 — auditoria dos bloqueadores + dump dos 12 dados.
#
# Duas execuções separadas, cada uma em instalação LIMPA, para que uma evidência
# não contamine a outra:
#   1) -auditoria      → asserções (inclui C1–C3, o bug do card "Complete seu perfil")
#   2) -dumpContexto   → o texto real que sai do aparelho rumo à IA, fonte por fonte
#
# `-semearSaude` preenche as 5 fontes que o simulador não produz (HealthKit e
# sequência de prática) — o dump marca cada uma com [semeado]. Ver o cabeçalho
# de SementeDeSaude em DebugContextDump.swift para o que isso prova e o que não.
set -u
DEV=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
BUNDLE=com.almaapp.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260804
mkdir -p "$OUT"

rodar() {
  local marcador="$1" destino="$2"; shift 2
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
  xcrun simctl install "$DEV" "$APP" || return 1
  xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

  xcrun simctl spawn "$DEV" log stream \
    --predicate "eventMessage CONTAINS \"[$marcador]\"" --style compact > /tmp/stream_$marcador.txt 2>&1 &
  local pid=$!
  sleep 3
  xcrun simctl launch "$DEV" "$BUNDLE" "$@" > /dev/null 2>&1
  sleep 22
  kill $pid 2>/dev/null

  # Uma passada só: o .task da Home reexecuta a cada aparição da tela.
  python3 - "$marcador" "$destino" <<'PY'
import sys
marcador, destino = sys.argv[1], sys.argv[2]
linhas = open(f'/tmp/stream_{marcador}.txt', encoding='utf-8', errors='ignore').read().split('\n')
uteis = [l.split(f'[{marcador}] ')[-1].rstrip() for l in linhas if f'[{marcador}] ' in l]
# corta na segunda passada, se houver
if uteis:
    primeira = uteis[0]
    repete = [i for i, l in enumerate(uteis) if l == primeira]
    if len(repete) > 1:
        uteis = uteis[:repete[1]]
open(destino, 'w', encoding='utf-8').write('\n'.join(uteis) + '\n')
print('\n'.join(uteis))
PY
}

echo "=== instalação limpa · auditoria ==="
rodar AUDIT "$OUT/03_auditoria_bloqueadores.txt" -auditoria 1 -semPermissoes 1

echo
echo "=== instalação limpa · dump dos 12 dados ==="
rodar CONTEXTO "$OUT/04_dump_12_dados.txt" \
  -dumpContexto 1 -semearPerfil 1 -semearSaude 1 -semPermissoes 1
