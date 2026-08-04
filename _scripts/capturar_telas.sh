#!/bin/bash
# Conferência visual — 04/08/2026, terceira tentativa (as duas por screenshot
# do simulador falharam; ver o cabeçalho de SmokeTestTelas.salvarPNGs).
#
# Aqui o PNG vem do próprio ImageRenderer que já varre as 43 telas: não depende
# de navegação, toque ou diálogo do sistema. Instalação limpa + perfil semeado
# para as telas terem conteúdo.
set -u
DEV=FB0A3E45-AE25-4F33-A506-5DCBAB0853E7
APP=/tmp/alma_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
BUNDLE=com.almaapp.app
OUT=/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/_validacao_20260804/telas
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

xcrun simctl launch "$DEV" "$BUNDLE" \
  -smokeTelas 1 -capturarTelas 1 -semearPerfil 1 -semearSaude 1 -semPermissoes 1 > /dev/null 2>&1
sleep 35

CONTAINER=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null)
if [ -z "$CONTAINER" ]; then echo "✗ container não encontrado"; exit 1; fi
cp "$CONTAINER/Documents/capturas/"*.png "$OUT/" 2>/dev/null

TOTAL=$(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
echo "capturas salvas: $TOTAL"
echo
echo "───── são telas distintas? ─────"
python3 - "$OUT" <<'PY'
import hashlib, sys, pathlib, collections
out = pathlib.Path(sys.argv[1])
por_hash = collections.defaultdict(list)
for p in sorted(out.glob("*.png")):
    por_hash[hashlib.md5(p.read_bytes()).hexdigest()].append(p.stem)
iguais = {h: v for h, v in por_hash.items() if len(v) > 1}
print(f"  {len(list(out.glob('*.png')))} arquivos · {len(por_hash)} imagens distintas")
if iguais:
    print("\n  ⚠ telas que renderizaram IDÊNTICAS (checar se é esperado):")
    for grupo in iguais.values():
        print("     " + " == ".join(grupo))
else:
    print("  ✓ nenhuma duplicata")
PY
