#!/bin/bash
# Evidência visual do padrão do exercício — 03/09/2026.
#
# As capturas vêm do `ImageRenderer` que já varre as telas (`SmokeTestTelas`),
# pelo mesmo motivo declarado em `capturar_telas.sh`: não dependem de navegação,
# toque nem diálogo do sistema. O app RODA no simulador; o que se vê é a View de
# produção desenhada com o `AppModel` de produção.
#
# As telas novas são quatro:
#   · "Meu padrão (vazio)"      — placeholders do catálogo, nada definido;
#   · "Meu padrão (definido)"   — 3 × 8 × 60 kg já salvos e relidos do store;
#   · "Detalhe do exercício"    — antes, ainda com a sugestão do catálogo;
#   · "Detalhe do exercício (com padrão)" — depois, com o volume da pessoa.
set -u
DEV=C9FE7224-677D-4B38-9F94-9C7BCE331053
APP=/tmp/alma_padrao_dd/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app
BUNDLE=com.almaapp.app
OUT="$(cd "$(dirname "$0")/.." && pwd)/_validacao_20260903_padrao/telas"
rm -rf "$OUT"; mkdir -p "$OUT"

xcrun simctl boot "$DEV" 2>/dev/null
xcrun simctl bootstatus "$DEV" -b >/dev/null 2>&1
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null
xcrun simctl install "$DEV" "$APP" || exit 1
xcrun simctl privacy "$DEV" grant all "$BUNDLE" 2>/dev/null

# `-onboardingComplete 1` NÃO é opcional: o smoke roda no `.task` da `HomeView`,
# e sem isto o app para na primeira tela do onboarding e o harness nunca começa
# (foi assim que a primeira tentativa saiu com zero capturas).
#
# A desinstalação acima também não é opcional, e é a causa raiz da rodada
# inválida: `UserDefaults.standard` sobrevive ao relançamento, então um app não
# desinstalado começa com o padrão que a execução anterior deixou — e a captura
# rotulada "vazio" sai com 3×8×60. Instalação limpa a cada rodada.
xcrun simctl launch "$DEV" "$BUNDLE" \
  -smokeTelas 1 -capturarTelas 1 -semearPerfil 1 -semearSaude 1 -semPermissoes 1 \
  -onboardingComplete 1 > /dev/null 2>&1
sleep 50

CONTAINER=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null)
if [ -z "$CONTAINER" ]; then echo "✗ container não encontrado"; exit 1; fi
cp "$CONTAINER/Documents/capturas/"*.png "$OUT/" 2>/dev/null

echo "capturas totais: $(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')"
echo
echo "── as do padrão, com md5 ──"
ls -1 "$OUT" | grep -i "padr" || { echo "  ✗ NENHUMA — a tela nova não foi renderizada"; exit 1; }
echo
md5 "$OUT"/*padr*.png 2>/dev/null | sed 's|.*/||'

# ── O CANÁRIO, do lado de fora ────────────────────────────────────────────
# O harness já compara os bytes por dentro (`exigirDiferentes`). Isto aqui é a
# segunda tranca, e existe porque a primeira rodada entregou "(vazio)" e
# "(definido)" com o MESMO md5 e ninguém percebeu até o Assis conferir à mão.
# Duas capturas iguais com nomes diferentes não são evidência — são um rótulo.
echo
echo "── são imagens DISTINTAS? ──"
python3 - "$OUT" <<'PY'
import hashlib, sys, pathlib, collections
out = pathlib.Path(sys.argv[1])
alvos = [p for p in sorted(out.glob("*.png"))
         if "padr" in p.stem.lower() or "exerc" in p.stem.lower()]
por_hash = collections.defaultdict(list)
for p in alvos:
    por_hash[hashlib.md5(p.read_bytes()).hexdigest()].append(p.stem)
iguais = {h: v for h, v in por_hash.items() if len(v) > 1}
print(f"  {len(alvos)} arquivos · {len(por_hash)} imagens distintas")
if iguais:
    print("  ✗✗ DUPLICATAS — a prova está morta:")
    for h, nomes in iguais.items():
        print(f"     {h}  {' == '.join(nomes)}")
    raise SystemExit(1)
print("  ✓ nenhuma duplicata: cada rótulo tem imagem própria")
PY
