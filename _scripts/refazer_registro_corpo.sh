#!/bin/bash
# Restaura o pbxproj limpo e refaz o registro do módulo Corpo com UIDs únicos.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
PROJ="Alma.App.Oficial.xcodeproj/project.pbxproj"

cp /tmp/pbxproj.backup "$PROJ"
echo "pbxproj restaurado"

/usr/bin/python3 _scripts/registrar_corpo_pbxproj.py

echo "=== UIDs colidem com algo pré-existente? ==="
DUP=$(grep -oE '^\s+[A-F0-9a-z]{24} ' "$PROJ" | tr -d ' ' | sort | uniq -d | head -5)
if [ -z "$DUP" ]; then echo "nenhuma colisão"; else echo "COLISÃO: $DUP"; fi

echo "=== integridade ==="
plutil -lint "$PROJ" | tail -1
echo -n "arquivos na fase Sources do iOS: "
awk '/9ECED0A52F588F21009412A7 \/\* Sources \*\//,/runOnlyForDeploymentPostprocessing/' "$PROJ" | grep -c 'in Sources'
echo -n "PraticasView continua registrado: "
grep -c 'PraticasView.swift in Sources' "$PROJ"
