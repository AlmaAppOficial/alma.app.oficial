#!/bin/bash
# Commits de 04/08 — stage por CAMINHO EXPLICITO (regra anti-commit-cruzado).
# Sem push: os gates do Assis continuam valendo.
set -e
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main

git add Shared/UserProfileStore.swift \
        Shared/HomeView.swift \
        Shared/Corpo/Models.swift \
        Shared/Corpo/CorpoContextFormat.swift \
        Shared/HealthContextBuilder.swift \
        Shared/AlmaApp.swift \
        Shared/AuditoriaBloqueadores.swift \
        ios/AlmaTests/ContextoIATests.swift
git commit -q -F _scripts/msg1.txt

git add Shared/SmokeTestTelas.swift \
        Shared/DebugContextDump.swift \
        Shared/HealthKitManager.swift \
        Shared/ProfileView.swift \
        Shared/Corpo/GeminiService.swift \
        _scripts/validar_20260804.sh \
        _scripts/capturar_telas.sh \
        _scripts/conferencia_visual_abas.sh \
        _scripts/rodar_tudo_0804.sh \
        _scripts/commit_0804.sh \
        docs/GATE_SCAN_IA_20260804.md \
        _validacao_20260804/01_testes_contexto.txt \
        _validacao_20260804/02_testes_ciclo.txt \
        _validacao_20260804/03_auditoria_bloqueadores.txt \
        _validacao_20260804/04_dump_12_dados.txt
git commit -q -F _scripts/msg2.txt

echo "───── ultimos commits ─────"
git log --oneline -4
echo "───── working tree ─────"
git status --short
echo "───── upstream (deve estar vazio = nada pushado) ─────"
git status -sb | head -1
