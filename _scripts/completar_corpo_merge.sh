#!/bin/bash
# Completa a base de integração do C&A: soma a branch da nutrição.
set -u
cd /Users/almaappoficial/Desktop/ALMA/CorpoAlma_com_Watch || exit 1

git branch --show-current
git merge fix/apis-calorias-scans --no-edit > /tmp/ca_merge2.log 2>&1
echo "MERGE_NUTRICAO_EXIT:$?"
tail -3 /tmp/ca_merge2.log

echo
echo "=== CONFERÊNCIA DA BASE ==="
echo -n "arquivos .swift: "; ls CorpoEAlma/*.swift | wc -l
echo -n "exercícios no catálogo V2: "
grep -o 'ExerciseV2(' CorpoEAlma/ExerciseLibraryV2.swift 2>/dev/null | wc -l
echo -n "linhas do ExerciseLibraryV2: "; wc -l < CorpoEAlma/ExerciseLibraryV2.swift 2>/dev/null || echo 0
echo -n "persistência do diário (loadMealsForToday): "; grep -c 'loadMealsForToday' CorpoEAlma/Models.swift
echo -n "NutritionEngine: "; ls CorpoEAlma/NutritionEngine.swift 2>/dev/null || grep -rl 'Mifflin' CorpoEAlma/*.swift 2>/dev/null | head -2
echo -n "Open Food Facts: "; grep -rl 'openfoodfacts' CorpoEAlma/*.swift 2>/dev/null | head -2
echo -n "Suplementos: "; grep -rl 'Supplement\|suplemento' CorpoEAlma/*.swift 2>/dev/null | head -2
echo -n "MuscleMapView: "; ls CorpoEAlma/MuscleMapView.swift 2>/dev/null && echo OK
