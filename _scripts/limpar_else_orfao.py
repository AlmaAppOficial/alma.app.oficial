#!/usr/bin/env python3
"""Remove os `else { showPaywall = true }` que ficaram órfãos ao liberar os
gates de premium do TreinoView (freemium B11)."""
import sys

caminho = sys.argv[1]
linhas = open(caminho).read().split("\n")
saida = [l for l in linhas if l.strip() != "else { showPaywall = true }"]
print("removidas:", len(linhas) - len(saida))
open(caminho, "w").write("\n".join(saida))
