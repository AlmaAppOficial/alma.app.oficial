#!/bin/bash
# Analisa o merge das duas branches do C&A que precisam ir juntas no port.
set -u
cd /Users/almaappoficial/Desktop/ALMA/CorpoAlma_com_Watch || exit 1

echo "=== arquivos tocados pelas DUAS branches (fonte de conflito) ==="
comm -12 \
  <(git diff --name-only main..feat/biblioteca-exercicios | sort) \
  <(git diff --name-only main..fix/apis-calorias-scans | sort)

echo
echo "=== conflitos reais no merge ==="
BASE=$(git merge-base feat/biblioteca-exercicios fix/apis-calorias-scans)
CONFLITOS=$(git merge-tree "$BASE" feat/biblioteca-exercicios fix/apis-calorias-scans 2>/dev/null | grep -c '<<<<<<<')
echo "marcadores de conflito: $CONFLITOS"

echo
echo "=== onde vivem os 1095 exercicios ==="
git show 160feb1 --stat 2>/dev/null | tail -12

echo
echo "=== arquivos .swift novos na branch da biblioteca ==="
git diff --name-only main..feat/biblioteca-exercicios | grep '\.swift$'
