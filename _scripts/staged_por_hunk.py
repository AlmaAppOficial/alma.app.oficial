#!/usr/bin/env python3
"""Põe no índice APENAS os hunks escolhidos de um arquivo. Nada de `git add -A`.

    python3 _scripts/staged_por_hunk.py <arquivo> <n,n,n>     # aplica
    python3 _scripts/staged_por_hunk.py <arquivo> --listar    # só numera

═══════════════════════════════════════════════════════════════════════════
POR QUE ESTE SCRIPT EXISTE (2026-08-12)

Quando esta sessão começou, a árvore já tinha trabalho NÃO COMMITADO de outra
sessão (datado de 07/08: virada do dia no Corpo, pontuação de sono). Dois dos
arquivos que a fila da 2.0.2 precisava tocar — `Models.swift` e
`AuditoriaBloqueadores.swift` — passaram a carregar as duas coisas ao mesmo
tempo.

A regra anti-commit-cruzado do CLAUDE.md proíbe `git add -A`. Mas aqui
`git add <arquivo>` seria igualmente errado, e por um motivo pior: levaria para
dentro de um commit sobre unidade de medida um trabalho que eu não escrevi, não
revisei e não sei se está terminado. "Por caminho explícito" resolve o caso em
que os domínios estão em arquivos diferentes; não resolve este.

A primeira tentativa foi classificar os hunks por palavra-chave
(`hunks_de_quem.py`) e ela ERROU nos dois sentidos: marcou como alheios três
hunks meus (porque `Meal` e `unidade` aparecem em qualquer código de dieta) e
depois marcou como meu um hunk alheio. O que a salvou foi eu ter LIDO o
conteúdo em vez de confiar no rótulo.

Daí este script: a escolha é por ÍNDICE, feita por gente que olhou o diff.
A máquina só executa — e depois confere.
═══════════════════════════════════════════════════════════════════════════
"""
import subprocess
import sys

arquivo = sys.argv[1]
diff = subprocess.run(['git', 'diff', '-U3', '--', arquivo],
                      capture_output=True, text=True, check=True).stdout
if not diff.strip():
    print(f'{arquivo}: sem mudanças')
    sys.exit(0)

linhas = diff.split('\n')
i0 = next(i for i, l in enumerate(linhas) if l.startswith('@@'))
cabecalho = linhas[:i0]

hunks, atual = [], None
for l in linhas[i0:]:
    if l.startswith('@@'):
        if atual:
            hunks.append(atual)
        atual = [l]
    elif atual is not None:
        atual.append(l)
if atual:
    hunks.append(atual)

if len(sys.argv) < 3 or sys.argv[2] == '--listar':
    for n, h in enumerate(hunks, 1):
        add = sum(1 for x in h if x.startswith('+') and not x.startswith('++'))
        rem = sum(1 for x in h if x.startswith('-') and not x.startswith('--'))
        print(f'  {n:2d}. +{add:<4} -{rem:<4} {h[0][:80]}')
    sys.exit(0)

escolhidos = [int(x) for x in sys.argv[2].split(',') if x.strip()]
fora = [n for n in escolhidos if n < 1 or n > len(hunks)]
if fora:
    print(f'ABORTADO: hunk(s) inexistente(s): {fora} (o arquivo tem {len(hunks)})')
    sys.exit(2)

patch = '\n'.join(cabecalho + [l for n in escolhidos for l in hunks[n - 1]])
if not patch.endswith('\n'):
    patch += '\n'

r = subprocess.run(['git', 'apply', '--cached', '--recount', '-'],
                   input=patch, capture_output=True, text=True)
if r.returncode != 0:
    print('ABORTADO: git apply --cached recusou o patch. Índice intocado.')
    print(r.stderr.strip())
    sys.exit(3)

print(f'{arquivo}: {len(escolhidos)} de {len(hunks)} hunk(s) no índice '
      f'({",".join(map(str, escolhidos))})')
