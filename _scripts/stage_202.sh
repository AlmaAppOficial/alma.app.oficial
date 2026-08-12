#!/bin/bash
# stage_202.sh — põe no índice SÓ o trabalho da fila da 2.0.2.
#
# Nunca `git add -A`, nunca `git add .`, nunca `git commit -a` (CLAUDE.md).
#
# Três arquivos precisam de tratamento por HUNK porque carregam, ao mesmo tempo,
# o trabalho desta sessão e um WIP não commitado que já estava na árvore quando
# ela começou (07/08: virada do dia no Corpo, pontuação de sono). Os índices dos
# hunks abaixo foram escolhidos DEPOIS de ler o conteúdo de cada um — ver o
# cabeçalho de `staged_por_hunk.py` sobre por que a classificação automática por
# palavra-chave foi descartada.
#
# FICA DE FORA, de propósito (trabalho de outra sessão, não revisado por mim):
#   Shared/Corpo/HealthManager.swift      Shared/HealthKitManager.swift
#   Shared/Corpo/PontuacaoDeSono.swift    Shared/RootView.swift
#   Shared/Corpo/TestePersistencia.swift  Shared/CorpoModuleView.swift
#   Models.swift hunks 2,3,4 (dadoDiarioAindaVale / reavaliarDiaAtual)
#   AuditoriaBloqueadores.swift hunk 1 (A18f, rodapé do sono)
#   project.pbxproj: o bump CURRENT_PROJECT_VERSION 94→95
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

echo "── arquivos inteiramente desta sessão ──"
git add Shared/Corpo/UnidadeDeMedida.swift
git add Shared/Corpo/TextoDaPessoa.swift
git add Shared/Corpo/Refeicao.swift
git add Shared/Corpo/AddFoodView.swift
git add Shared/Corpo/AnaliseDeFotoService.swift
git add Shared/Corpo/DietaView.swift
git add Shared/Corpo/FoodScanView.swift
git add Shared/Corpo/MealDetailView.swift
git add Shared/Corpo/OpenFoodFacts.swift
git add functions/src/analiseDeFoto.ts
git add functions/testes_scan.mjs

echo "── harness, mutações e utilitários ──"
git add _scripts/testes_unidade.swift
git add _scripts/testes_texto.swift
git add _scripts/testes_refeicao.swift
git add _scripts/mutacao_unidade.sh
git add _scripts/mutacao_texto.sh
git add _scripts/mutacao_refeicao.sh
git add _scripts/build202_fundo.sh
git add _scripts/rodar_mutacao_texto_fundo.sh
git add _scripts/estender_testes_scan.py
git add _scripts/mover_meal_para_refeicao.py
git add _scripts/hunks_de_quem.py
git add _scripts/staged_por_hunk.py
git add _scripts/stage_202.sh

echo "── arquivos compartilhados: só os meus hunks ──"
python3 _scripts/staged_por_hunk.py Shared/Corpo/Models.swift 1,5,6,7,8,9,10,11,12,13
python3 _scripts/staged_por_hunk.py Shared/AuditoriaBloqueadores.swift 2,3
python3 _scripts/staged_por_hunk.py Alma.App.Oficial.xcodeproj/project.pbxproj 1,2,3,4

echo
echo "── ÍNDICE ──"
git diff --cached --stat
echo
echo "── SOBROU FORA DO ÍNDICE (tem de ser só o WIP alheio) ──"
git diff --stat
