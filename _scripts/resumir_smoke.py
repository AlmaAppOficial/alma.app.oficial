#!/usr/bin/env python3
"""Extrai uma passada limpa do log da varredura de telas.

O `.task` da Home reexecuta a cada recomposição, então a varredura roda várias
vezes. Repetir é bom (mais confiança), mas para o relatório interessa uma
passada completa — e a contagem de quantas passadas terminaram sem crash.
"""
import re
import sys

bruto = open(sys.argv[1], encoding="utf-8").read()

# O log stream compact junta tudo; separa nos marcadores conhecidos.
bruto = bruto.replace("Filtering the log data", "\nFiltering the log data")
for marca in ["═════", "→ ", "  ok   ", "  VAZIA ", "  — "]:
    bruto = bruto.replace(marca, "\n" + marca)

linhas = [l.rstrip() for l in bruto.split("\n") if l.strip()]

passadas = [i for i, l in enumerate(linhas) if "═════ ALMA ═════" in l]
print(f"passadas completas iniciadas: {len(passadas)}")

if not passadas:
    print("nenhuma passada encontrada")
    sys.exit(1)

# Primeira passada inteira
fim = passadas[1] if len(passadas) > 1 else len(linhas)
passada = linhas[passadas[0]:fim]

iniciadas = [l.replace("→", "").strip() for l in passada if l.strip().startswith("→")]
oks = [l.replace("ok", "", 1).strip() for l in passada if l.strip().startswith("ok")]
vazias = [l for l in passada if "VAZIA" in l]
naotestaveis = [l.strip() for l in passada if l.strip().startswith("—")]

sem_ok = [t for t in iniciadas if t not in oks]

print(f"\ntelas renderizadas nesta passada: {len(oks)}")
print(f"telas iniciadas: {len(iniciadas)}")
print(f"renderizaram vazio: {len(vazias)}")
print(f"não testáveis (declaradas): {len(naotestaveis)}")

if sem_ok:
    print("\n⚠ INICIARAM E NÃO TERMINARAM (candidatas a crash):")
    for t in sem_ok:
        print("   " + t)
else:
    print("\n✓ toda tela que começou terminou de renderizar")

for l in naotestaveis:
    print("   não testável: " + l)

print("\n─── telas desta passada ───")
for t in oks:
    print("  ok  " + t)
