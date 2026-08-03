#!/bin/bash
# Remove as entradas do CorpoInsightsEngine com UID de 23 chars (invalido) e
# re-registra com UID de 24.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
PROJ="Alma.App.Oficial.xcodeproj/project.pbxproj"

grep -v 'FA900701FA900701FA90071' "$PROJ" | grep -v 'FA900700FA900700FA90070' > /tmp/p.tmp
mv /tmp/p.tmp "$PROJ"
echo "entradas invalidas removidas: $(grep -c 'FA90070' "$PROJ") restantes"

/usr/bin/python3 _scripts/registrar_corpo_pbxproj.py

echo "=== tamanho dos UIDs novos ==="
grep -oE '\bFA9[0-9A-Z]{21}\b' "$PROJ" | head -2 | while read -r u; do
  echo "$u -> ${#u} chars"
done
plutil -lint "$PROJ" | tail -1
