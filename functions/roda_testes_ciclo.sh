#!/usr/bin/env bash
# Sobe o emulador do Firestore, roda o teste de ciclo do entitlement, derruba.
#
#   cd functions && ./roda_testes_ciclo.sh
#
# Projeto `demo-alma`: o prefixo `demo-` faz o firebase-tools trabalhar 100%
# offline e recusar qualquer conexão com projeto real. Nenhum dado de produção
# é tocado por este script — nem por acidente.
#
# FIREBASE_BIN permite apontar para uma instalação específica do firebase-tools.
# (O emulador exige Java; versões novas do firebase-tools exigem JDK 21+.)
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREBASE_BIN="${FIREBASE_BIN:-firebase}"

cd "$RAIZ/functions"
npm run build

cd "$RAIZ"
exec "$FIREBASE_BIN" emulators:exec \
  --only firestore \
  --project demo-alma \
  "node functions/testes_entitlement_ciclo.mjs"
