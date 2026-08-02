#!/bin/bash
# Resolve colisões de TIPO entre o Alma e o módulo Corpo, prefixando os do Corpo.
#   HealthMetric  — Alma tem uma View com esse nome (MainTabView.swift);
#                   o Corpo tem um model. Vira CorpoHealthMetric.
#   Color.init(hex:) — os dois declaram a mesma extensão. A do Corpo é removida
#                   e o módulo passa a usar a do Alma (mesma assinatura).
set -u
CORPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo"
cd "$CORPO" || exit 1

perl -pi -e 's/\bHealthMetric\b/CorpoHealthMetric/g' *.swift
echo "renomeado: HealthMetric -> CorpoHealthMetric"

# Remove a extensão duplicada de Color(hex:) do CorpoTheme (a do Alma fica).
/usr/bin/python3 - <<'PY'
import re, pathlib
p = pathlib.Path("/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo/CorpoTheme.swift")
src = p.read_text()
# Localiza "extension Color {" ... "}" que contenha init(hex:)
m = re.search(r"\nextension Color \{.*?\n\}\n", src, re.S)
if m and "init(hex" in m.group(0):
    src = src[:m.start()] + "\n// [Fusão] extension Color.init(hex:) removida — o Alma já declara a mesma\n// em Shared/Theme.swift; duas declarações davam 'invalid redeclaration'.\n" + src[m.end():]
    p.write_text(src)
    print("removida: extension Color.init(hex:) do CorpoTheme")
else:
    print("AVISO: extension Color não encontrada no formato esperado")
PY

echo "=== conferência ==="
echo -n "HealthMetric remanescente no Corpo: "; grep -c '\bHealthMetric\b' *.swift | grep -v ':0' | head -3 || echo "nenhum"
echo -n "init(hex: no Corpo: "; grep -rc 'init(hex' *.swift | grep -v ':0' | head -3 || echo "nenhum"
