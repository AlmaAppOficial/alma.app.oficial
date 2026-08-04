#!/bin/bash
# Conferência visual das 5 abas do módulo Corpo — 04/08/2026.
#
# Pendência herdada da revisão independente: "os diálogos do sistema cobrem os
# screenshots e a automação de toque ficou indisponível".
#
# A tentativa de 03/08 gerou 5 PNGs do MESMO tamanho em bytes — sinal de que as
# cinco capturas eram a mesma tela e a evidência não valia nada. Por isso este
# script termina comparando os md5: se duas capturas forem idênticas, ele DIZ
# que a conferência falhou, em vez de deixar 5 arquivos parecendo prova.
#
# `-semPermissoes 1` suprime os diálogos de HealthKit/notificações (só DEBUG).
# `-abrirCorpo 1 -corpoAba N` abre direto na aba N sem depender de toque.
set -u
DEV=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
BUNDLE=com.almaapp.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260804
mkdir -p "$OUT"
NOMES=(Inicio Saude Dieta Treino Insights)

xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

for i in 0 1 2 3 4; do
  xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
  sleep 1
  xcrun simctl launch "$DEV" "$BUNDLE" \
    -abrirCorpo 1 -corpoAba "$i" -semearPerfil 1 -semPermissoes 1 > /dev/null 2>&1
  sleep 9
  xcrun simctl io "$DEV" screenshot "$OUT/aba${i}_${NOMES[$i]}.png" > /dev/null 2>&1
  echo "capturada aba $i (${NOMES[$i]})"
done

echo
echo "───── as 5 capturas são diferentes entre si? ─────"
python3 - "$OUT" <<'PY'
import hashlib, sys, pathlib
out = pathlib.Path(sys.argv[1])
nomes = ["Inicio", "Saude", "Dieta", "Treino", "Insights"]
hashes = {}
for i, nome in enumerate(nomes):
    p = out / f"aba{i}_{nome}.png"
    if not p.exists():
        print(f"  FALTOU  aba{i} {nome}"); continue
    h = hashlib.md5(p.read_bytes()).hexdigest()
    hashes.setdefault(h, []).append(f"aba{i} {nome}")
    print(f"  aba{i} {nome:<9} {h[:12]}  {p.stat().st_size} bytes")

repetidas = [v for v in hashes.values() if len(v) > 1]
if repetidas:
    print("\n  ✗ CONFERÊNCIA INVÁLIDA — capturas idênticas:")
    for grupo in repetidas:
        print("     " + " == ".join(grupo))
    print("  A flag -corpoAba não trocou de aba. Não usar estes PNGs como prova.")
    raise SystemExit(1)
print(f"\n  ✓ {len(hashes)} capturas distintas — cada aba renderizou uma tela diferente")
PY
