#!/usr/bin/env python3
"""Varre o repo por resíduos de PT-PT no conteúdo de strings.

Existe para que a correção de A12 seja verificável e não volte em silêncio.
O grep do macOS trata \\b de forma inconsistente e dá falso positivo em "pés" e
"raízes"; aqui o motor é o `re` do Python.
"""
import re
import sys
from pathlib import Path

PADROES = {
    "tuteamento": r"\b(teu|tua|teus|tuas|ti|tu|contigo)\b",
    "conjugação 2ª pessoa": r"\b(estás|és|tens|podes|queres|sabes|precisas|vais|vens|fazes|dizes|vês|mereces|consegues)\b",
    # "actual" fica de fora: em código é a palavra inglesa (actual_duration).
    #
    # [2026-08-04] A lista era curta demais e deixou passar "Monitorização de
    # saúde avançada" — no PAYWALL, uma das telas mais vistas do app, por dois
    # pentes finos seguidos. Achei olhando o print, não rodando o checador.
    # A lição: uma allowlist de palavras só encontra o que já se sabe. Por isso
    # entrou também a família -ização/-izar, que é o padrão morfológico onde o
    # PT-PT mais aparece em software (monitorização, otimização com uma só
    # consoante, etc.).
    "léxico europeu": (r"\b(ecrã|contacto|contactos|facto|acção|acções|óptimo|óptima|"
                       r"telemóvel|autocarro|casa de banho|utilizador|utilizadores|"
                       r"monitorização|monitorizar|monitoriza|ficheiro|ficheiros|"
                       r"ecrãs|equipa|autocolante|comboio|"
                       r"registo|registos|projecto|projectos|directo|directa|"
                       r"eléctrico|actividade|actividades|colectivo|exacto|exacta)\b"),
    "ênclise": r"\b\w+-te\b",
    "até aos": r"\baté aos\b",
}

raiz = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
total = 0

for arquivo in sorted(raiz.rglob("*.swift")):
    if "/build/" in str(arquivo) or "_desativado" in str(arquivo):
        continue
    # O auditor guarda a própria lista de termos PT-PT num array de strings —
    # o checador o denunciava por citar as palavras que existem para procurar.
    if arquivo.name == "AuditoriaBloqueadores.swift":
        continue
    for n, linha in enumerate(arquivo.read_text(encoding="utf-8").split("\n"), 1):
        if '"' not in linha:
            continue
        # [2026-08-04] Depois de ampliar a lista de termos, o checador passou a
        # acusar 15 "resíduos" — TODOS em comentários, inclusive o dicionário de
        # termos PT-PT do próprio auditor se auto-denunciando. Um checador que
        # grita à toa é um checador que ninguém lê: foi exatamente assim que
        # "Monitorização" sobreviveu no paywall por dois pentes finos.
        # Aqui só interessa texto que o usuário VÊ, e comentário ninguém vê.
        if linha.lstrip().startswith(("//", "///", "*", "/*")):
            continue
        for nome, padrao in PADROES.items():
            for m in re.finditer(padrao, linha):
                total += 1
                print(f"{arquivo.name}:{n} [{nome}] …{linha.strip()[max(0, m.start()-30):m.end()+25]}…")

print(f"\n{total} resíduo(s) de PT-PT")
sys.exit(1 if total else 0)
