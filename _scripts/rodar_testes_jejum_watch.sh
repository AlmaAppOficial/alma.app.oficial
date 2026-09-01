#!/bin/bash
# Compila o contrato do jejum do pulso (arquivo REAL de produção) junto com as
# asserções e roda. Sai com o exit do binário de testes (0 verde, 1 vermelho,
# 2 detector cego).
#
# Uso: ./rodar_testes_jejum_watch.sh [raiz-do-repo]
set -euo pipefail
RAIZ="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# O arquivo de asserções tem código de nível de topo — o swiftc exige que ele
# se chame main.swift.
cp "$RAIZ/_scripts/testes_jejum_watch.swift" "$TMP/main.swift"

swiftc -o "$TMP/testes" \
    "$RAIZ/AlmaWatch/JejumNoPulso.swift" \
    "$TMP/main.swift"

"$TMP/testes"
