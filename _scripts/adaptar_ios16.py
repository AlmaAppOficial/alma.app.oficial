#!/usr/bin/env python3
"""Adapta o módulo Corpo (escrito para iOS 17) ao deployment target do Alma (16).

Dois padrões:
  1. .onChange(of: X) { _, y in     ->  .onChange(of: X) { y in
     (a forma de dois parâmetros é iOS 17+)
  2. .navigationDestination(item: $X) { y in ... }
     -> variante com isPresented: + binding derivado (iOS 16)

Preferimos adaptar a subir o deployment target: subir para iOS 17 cortaria
usuários do Alma que hoje conseguem instalar.
"""
import pathlib
import re

CORPO = pathlib.Path("/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo")

n_onchange = 0
n_navdest = 0

for path in sorted(CORPO.glob("*.swift")):
    src = path.read_text()
    original = src

    # ── 1. onChange de dois parâmetros ────────────────────────────────────────
    src, k = re.subn(
        r"\.onChange\(of:\s*([^)]+)\)\s*\{\s*_,\s*(\w+)\s+in",
        r".onChange(of: \1) { \2 in",
        src,
    )
    n_onchange += k

    # ── 2. navigationDestination(item:) ───────────────────────────────────────
    # Casa: .navigationDestination(item: $nome) { arg in
    padrao = re.compile(
        r"\.navigationDestination\(item:\s*\$(\w+)\)\s*\{\s*(\w+)\s+in\n",
    )
    while True:
        m = padrao.search(src)
        if not m:
            break
        var, arg = m.group(1), m.group(2)
        # Encontra o fim do bloco contando chaves a partir da abertura
        inicio_bloco = src.index("{", m.start())
        nivel = 0
        i = inicio_bloco
        while i < len(src):
            if src[i] == "{":
                nivel += 1
            elif src[i] == "}":
                nivel -= 1
                if nivel == 0:
                    break
            i += 1
        corpo = src[m.end():i]
        indent = " " * (m.start() - src.rfind("\n", 0, m.start()) - 1)
        novo = (
            f"{indent}// [Fusão] variante iOS 16 de navigationDestination(item:)\n"
            f"{indent}.navigationDestination(isPresented: Binding(\n"
            f"{indent}    get: {{ {var} != nil }},\n"
            f"{indent}    set: {{ if !$0 {{ {var} = nil }} }}\n"
            f"{indent})) {{\n"
            f"{indent}    if let {arg} = {var} {{\n"
            f"{corpo.rstrip()}\n"
            f"{indent}    }}\n"
            f"{indent}}}"
        )
        src = src[:m.start()] + novo + src[i + 1:]
        n_navdest += 1

    if src != original:
        path.write_text(src)
        print(f"adaptado: {path.name}")

print(f"\nonChange corrigidos: {n_onchange}")
print(f"navigationDestination corrigidos: {n_navdest}")
