#!/bin/bash
# Junta as duas branches do C&A (biblioteca 1.095 + nutrição nova) numa base
# única, para o port entrar completo no Alma.
set -u
cd /Users/almaappoficial/Desktop/ALMA/CorpoAlma_com_Watch || exit 1

git checkout fix/apis-calorias-scans 2>&1 | tail -1
git checkout -B integracao/fusao-alma 2>&1 | tail -1
git merge feat/biblioteca-exercicios --no-edit > /tmp/ca_merge.log 2>&1
echo "MERGE_EXIT:$?"
tail -3 /tmp/ca_merge.log

echo "=== conferência ==="
echo -n "exercícios no catálogo V2: "
grep -c 'id:' CorpoEAlma/ExerciseLibraryV2.swift 2>/dev/null || echo "(arquivo não encontrado)"
echo -n "arquivos .swift no módulo: "
ls CorpoEAlma/*.swift | wc -l
echo -n "persistência do diário alimentar presente: "
grep -c 'loadMealsForToday' CorpoEAlma/Models.swift
echo -n "NutritionEngine (Mifflin-St Jeor): "
grep -rc 'Mifflin\|NutritionEngine' CorpoEAlma/*.swift 2>/dev/null | grep -v ':0' | head -2
