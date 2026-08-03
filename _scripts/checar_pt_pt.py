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
    "léxico europeu": r"\b(ecrã|contacto|facto|acção|óptimo|telemóvel|autocarro|casa de banho)\b",
    "ênclise": r"\b\w+-te\b",
    "até aos": r"\baté aos\b",
}

raiz = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
total = 0

for arquivo in sorted(raiz.rglob("*.swift")):
    if "/build/" in str(arquivo) or "_desativado" in str(arquivo):
        continue
    for n, linha in enumerate(arquivo.read_text(encoding="utf-8").split("\n"), 1):
        if '"' not in linha:
            continue
        for nome, padrao in PADROES.items():
            for m in re.finditer(padrao, linha):
                total += 1
                print(f"{arquivo.name}:{n} [{nome}] …{linha.strip()[max(0, m.start()-30):m.end()+25]}…")

print(f"\n{total} resíduo(s) de PT-PT")
sys.exit(1 if total else 0)
