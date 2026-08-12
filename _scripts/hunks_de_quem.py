#!/usr/bin/env python3
"""Classifica os hunks de um arquivo entre "meus" (2.0.2) e "de outra sessão".

Existe porque três arquivos deste commit — `Models.swift`,
`AuditoriaBloqueadores.swift` e o `.pbxproj` — carregam ao mesmo tempo o
trabalho da fila da 2.0.2 e um WIP não commitado que já estava na árvore quando
esta sessão começou (datado de 07/08, sobre virada do dia e pontuação de sono).

A regra anti-commit-cruzado do CLAUDE.md proíbe `git add -A` justamente por
isto. Mas `git add <arquivo>` também não serve quando o arquivo tem as duas
coisas: ele arrastaria o WIP alheio para dentro de um commit sobre unidade de
medida.

Este script não decide nada sozinho — ele MOSTRA, para a decisão ser tomada
com o diff à vista. Uso:

    python3 _scripts/hunks_de_quem.py <arquivo>            # relatório
    python3 _scripts/hunks_de_quem.py <arquivo> --patch    # patch só com os meus
"""
import re
import subprocess
import sys

# Marcas do trabalho da 2.0.2. Um hunk que contenha qualquer uma é meu.
MINHAS = [
    '2026-08-12', 'Unidade', 'unidade', 'textoDaQuantidade', 'quantidade:',
    'componentes', 'Componente', 'Refeicao.swift', 'UnidadeDeMedida',
    'TextoDaPessoa', 'registrarPrato', 'atualizarRefeicao', 'escalarPor100',
    'StoredFood', 'FoodItem', 'MealType', 'Meal',
]
# Marcas do WIP da outra sessão. Vencem sobre as de cima em caso de empate.
DELAS = [
    '2026-08-07', 'dadoDiarioAindaVale', 'reavaliarDiaAtual',
    'PontuacaoDeSono', 'rodape', 'A18f',
]

arquivo = sys.argv[1]
so_patch = '--patch' in sys.argv

diff = subprocess.run(['git', 'diff', '-U3', '--', arquivo],
                      capture_output=True, text=True, check=True).stdout
if not diff.strip():
    print(f'{arquivo}: sem mudanças', file=sys.stderr)
    sys.exit(0)

linhas = diff.split('\n')
inicio = next(i for i, l in enumerate(linhas) if l.startswith('@@'))
cabecalho = linhas[:inicio]

hunks, atual = [], None
for l in linhas[inicio:]:
    if l.startswith('@@'):
        if atual:
            hunks.append(atual)
        atual = [l]
    elif atual is not None:
        atual.append(l)
if atual:
    hunks.append(atual)

meus, delas, mistos = [], [], []
for h in hunks:
    corpo = '\n'.join(x for x in h if x[:1] in '+-')
    tem_minha = any(m in corpo for m in MINHAS)
    tem_dela = any(d in corpo for d in DELAS)
    # A marca da OUTRA sessão vence o empate, e de propósito.
    #
    # A lista `MINHAS` tem palavras comuns ("Meal", "unidade", "componentes")
    # que aparecem em qualquer hunk que encoste em dieta — inclusive nos que são
    # inteiramente do WIP de 07/08. Na primeira rodada isso marcou três hunks
    # alheios como MISTOS. Já `DELAS` são nomes próprios do trabalho daquela
    # sessão (`dadoDiarioAindaVale`, `reavaliarDiaAtual`, `A18f`) e a data dela.
    #
    # Errar para o lado de "é dela" deixa um hunk meu de fora do commit — o
    # compilador reclama na hora e eu percebo. Errar para o outro lado leva
    # trabalho não verificado de outra pessoa para dentro de um commit meu, em
    # silêncio. Os dois erros não custam a mesma coisa.
    if tem_dela:
        delas.append(h)
    elif tem_minha:
        meus.append(h)
    else:
        mistos.append(h)   # sem marca nenhuma: decisão humana

if so_patch:
    if mistos:
        print('ABORTADO: há hunk MISTO — separar à mão. Nada foi gerado.',
              file=sys.stderr)
        sys.exit(2)
    print('\n'.join(cabecalho + [l for h in meus for l in h]))
    sys.exit(0)

print(f'── {arquivo} ──')
print(f'  meus   : {len(meus)} hunk(s)')
print(f'  outros : {len(delas)} hunk(s)')
print(f'  MISTOS : {len(mistos)} hunk(s)')
for h in delas:
    print(f'    [outra sessão] {h[0][:70]}')
for h in mistos:
    print(f'    [MISTO — ATENÇÃO] {h[0][:70]}')
    for l in h[1:]:
        if l[:1] in '+-':
            print(f'        {l[:100]}')
