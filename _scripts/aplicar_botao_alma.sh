#!/bin/bash
# Põe .almaBackButton() nas 5 abas do módulo Corpo, logo após o
# .navigationBarTitleDisplayMode(.inline) de cada uma.
set -u
CORPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo"

/usr/bin/python3 - <<'PY'
import pathlib, re

ABAS = ["CorpoHomeView.swift", "SaudeView.swift", "DietaView.swift",
        "TreinoView.swift", "CorpoInsightsView.swift"]
base = pathlib.Path("/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo")

for nome in ABAS:
    p = base / nome
    src = p.read_text()
    if ".almaBackButton()" in src:
        print(f"já tinha: {nome}")
        continue
    # Ancora no primeiro navigationBarTitleDisplayMode da view
    m = re.search(r"(\n(\s*)\.navigationBarTitleDisplayMode\([^)]*\))", src)
    if m:
        src = src[:m.end(1)] + f"\n{m.group(2)}.almaBackButton()" + src[m.end(1):]
        p.write_text(src)
        print(f"aplicado: {nome}")
    else:
        print(f"AVISO: âncora não encontrada em {nome}")
PY

echo "=== conferência ==="
grep -l "almaBackButton()" "$CORPO"/*.swift | xargs -n1 basename | tr '\n' ' '
echo
