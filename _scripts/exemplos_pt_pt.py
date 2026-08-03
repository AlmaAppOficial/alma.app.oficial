#!/usr/bin/env python3
"""Lista ocorrências de PT-PT no texto ORIGINAL, com arquivo:linha e contexto.

Para o Assis julgar caso a caso. Marca também os candidatos a falso positivo:
palavras que existem igualmente em PT-BR ("tu" em citação, "sente" que também é
imperativo de "sentar", etc.).
"""
import re
import sys

# Padrões que são inequivocamente PT-PT (não existem em PT-BR nesse uso).
INEQUIVOCOS = {
    "ecrã": "ecrã (PT-BR: tela)",
    "contacto": "contacto (PT-BR: contato)",
    "acção": "acção (PT-BR: ação)",
    "telemóvel": "telemóvel (PT-BR: celular)",
    "estás": "estás (2ª pessoa; PT-BR usa 'está')",
    "és ": "és (2ª pessoa; PT-BR usa 'é')",
    "tens ": "tens (2ª pessoa; PT-BR usa 'tem')",
    "podes ": "podes",
    "sabes ": "sabes",
    "queres ": "queres",
    "vais ": "vais",
    "mereces": "mereces",
    "consegues": "consegues",
}

# Ambíguos: aparecem em PT-BR também, dependendo do contexto.
AMBIGUOS = {
    "teu": "possessivo de 2ª pessoa — existe em PT-BR literário/poético",
    "tua": "idem",
    "ti": "pronome — existe em PT-BR ('para ti')",
    "tu": "pronome — usado em PT-BR no Sul e no Nordeste",
}

arquivo = sys.argv[1]
rotulo = sys.argv[2] if len(sys.argv) > 2 else arquivo

linhas = open(arquivo, encoding="utf-8").read().split("\n")

print(f"\n{'='*72}\n{rotulo}\n{'='*72}")

achados_ineq, achados_amb = [], []

for n, linha in enumerate(linhas, 1):
    if '"' not in linha:
        continue
    # só o conteúdo entre aspas
    for trecho in re.findall(r'"([^"]*)"', linha):
        for chave, expl in INEQUIVOCOS.items():
            # [correção 2026-08-03] Antes era `chave in trecho`, substring pura:
            # "és " casava dentro de "atravÉS ", e "acção" dentro de "acções".
            # Falso positivo meu — a contagem anterior estava inflada.
            if re.search(r"\b" + re.escape(chave.strip()) + r"\b", trecho):
                achados_ineq.append((n, chave.strip(), expl, trecho))
                break
        else:
            for chave, expl in AMBIGUOS.items():
                if re.search(r"\b" + chave + r"\b", trecho):
                    achados_amb.append((n, chave, expl, trecho))
                    break

print(f"\nINEQUÍVOCOS (não existem em PT-BR): {len(achados_ineq)}")
for n, chave, expl, trecho in achados_ineq[:10]:
    print(f"\n  linha {n} — «{chave}» → {expl}")
    print(f'    "{trecho[:150]}"')

print(f"\n\nAMBÍGUOS (também válidos em PT-BR): {len(achados_amb)}")
for n, chave, expl, trecho in achados_amb[:5]:
    print(f"\n  linha {n} — «{chave}» → {expl}")
    print(f'    "{trecho[:150]}"')
