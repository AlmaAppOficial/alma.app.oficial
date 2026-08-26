#!/usr/bin/env python3
"""Reprova promessa de resultado no módulo de jejum.

    python3 _scripts/check_promessas_jejum.py

POR QUE ESTE SCRIPT EXISTE
──────────────────────────
O módulo de jejum vai declarar categoria de saúde no Play e passar pela revisão
da App Store, e este projeto já teve problema de política de loja por promessa.
A regra é dura e não tem exceção: o app descreve o que foi OBSERVADO em estudos,
nunca o que vai acontecer com quem está lendo.

    ✗ "O jejum 16/8 emagrece."
    ✓ "Em ensaios clínicos, jejum e restrição calórica produziram perda de peso
       semelhante quando o total de calorias foi o mesmo."

A asserção J8 (`AuditoriaBloqueadores`) faz a mesma varredura em RUNTIME, sobre
o conteúdo montado. Esta aqui roda sobre a FONTE e prende o commit — as duas
juntas cobrem os dois lados: o texto que existe no arquivo e o texto que chega
à tela.

ANTI-CEGUEIRA (lição do A26d)
─────────────────────────────
Um varredor que não encontra nada para varrer aprova tudo, para sempre — é o
pior tipo de verde. Se o coletor devolver menos strings do que o piso, este
script sai com `CEGO` e código 2, que NÃO é aprovação.

SAÍDA
─────
    0  nenhuma promessa encontrada
    1  promessa encontrada (lista impressa)
    2  CEGO — o coletor não enxergou o que devia enxergar
"""
import re
import sys
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# Os arquivos do módulo. Se um deles sumir, é `CEGO` — ver o piso lá embaixo.
ARQUIVOS = [
    'Shared/Corpo/JejumConteudo.swift',
    'Shared/Corpo/Jejum.swift',
    'Shared/Corpo/JejumView.swift',
    'Shared/Corpo/QuebraDeJejum.swift',
    'Shared/Corpo/QuebraDeJejumView.swift',
    'Shared/Corpo/JejumStore.swift',
]

# Pisos do coletor. Calibrados na primeira execução, 26/08/2026: 291 literais
# de uma linha e 54 linhas dentro de `"""`. Os números são bem abaixo do real,
# para não ficar vermelho a cada frase editada, mas altos o bastante para pegar
# "o regex parou de casar".
#
# ⚠️ SÃO DOIS PISOS, E ISSO FOI DESCOBERTO POR MUTAÇÃO.
#
# A primeira versão tinha um piso só, sobre o total. A quinta mutação de 26/08
# apagou a linha que coleta o miolo das strings multilinha — e o script passou
# VERDE, porque os 291 literais de uma linha sozinhos já superavam o piso único.
#
# Era o pior caso possível: **as afirmações de saúde deste módulo moram quase
# todas dentro de `"""`** (`oQueALiteraturaObserva`, `sobreAQuebra`, as
# contraindicações). Um coletor cego justamente ali aprovaria qualquer promessa
# escrita no único lugar onde ela seria escrita.
#
# Com dois pisos, cegar metade do coletor fica vermelho.
PISO_DE_LITERAIS = 120
PISO_DE_MULTILINHA = 25

# As palavras proibidas, já sem acento (a comparação normaliza os dois lados).
#
# Cada uma é uma promessa de RESULTADO ou uma alegação terapêutica — o que a
# App Store Review Guideline 1.4.1 e a política de saúde do Play olham primeiro.
PROMESSAS = [
    'emagre',            # emagrece, emagrecer, emagrecimento
    'perca ',            # "perca 5 kg"
    'perde peso',
    'voce vai perder',
    'cura ', 'curar', 'cura de',
    'reverte', 'reverter',
    'garante', 'garantido', 'garantia de resultado',
    'queima gordura', 'queimar gordura',
    'desintoxic', 'detox', 'elimina toxinas',
    'acelera o metabolismo', 'acelerar o metabolismo',
    'resultado garantido',
    'comprovadamente eficaz',
    'trata ',            # "trata diabetes"
    'previne o',         # "previne o câncer"
]

# Onde a palavra pode aparecer legitimamente: o próprio comentário que a
# proíbe, e a lista de proibidas dentro do código. Sem esta exceção o script
# reprovaria a si mesmo — e o autor aprenderia a não escrever a regra.
LINHAS_ISENTAS = re.compile(r'^\s*(//|///|\*)')


def sem_acento(t: str) -> str:
    return ''.join(c for c in unicodedata.normalize('NFD', t.lower())
                   if unicodedata.category(c) != 'Mn')


def strings_de(caminho: Path):
    """Devolve (linha, texto, tipo) de cada string literal do arquivo.

    `tipo` é 'literal' ou 'multilinha' — os dois são contados separadamente
    porque cada um tem o próprio piso anti-cegueira. Ver o comentário dos
    pisos.

    Só literais: comentário é para quem lê o código, não para quem usa o app —
    e é onde a regra precisa poder ser escrita por extenso.
    """
    achadas = []
    dentro_de_multilinha = False
    for n, linha in enumerate(caminho.read_text(encoding='utf-8').splitlines(), 1):
        marcas = linha.count('"""')
        if dentro_de_multilinha:
            if marcas:
                dentro_de_multilinha = False
                continue
            achadas.append((n, linha, 'multilinha'))
            continue
        if marcas == 1:
            dentro_de_multilinha = True
            continue
        if LINHAS_ISENTAS.match(linha):
            continue
        for m in re.finditer(r'"([^"\\]*(?:\\.[^"\\]*)*)"', linha):
            if m.group(1).strip():
                achadas.append((n, m.group(1), 'literal'))
    return achadas


def main() -> int:
    faltando = [a for a in ARQUIVOS if not (RAIZ / a).exists()]
    if faltando:
        print(f'CEGO: arquivo do módulo não encontrado: {faltando}')
        return 2

    contagem = {'literal': 0, 'multilinha': 0}
    violacoes = []
    for rel in ARQUIVOS:
        caminho = RAIZ / rel
        for n, texto, tipo in strings_de(caminho):
            contagem[tipo] += 1
            plano = sem_acento(texto)
            for p in PROMESSAS:
                if p in plano:
                    violacoes.append((rel, n, p, texto.strip()[:90]))

    total = contagem['literal'] + contagem['multilinha']

    cegueiras = []
    if contagem['literal'] < PISO_DE_LITERAIS:
        cegueiras.append(f"literais: viu {contagem['literal']}, piso {PISO_DE_LITERAIS}")
    if contagem['multilinha'] < PISO_DE_MULTILINHA:
        cegueiras.append(f"multilinha: viu {contagem['multilinha']}, piso {PISO_DE_MULTILINHA}")
    if cegueiras:
        print('CEGO: ' + ' · '.join(cegueiras))
        print('      O coletor parou de enxergar parte do texto.')
        print('      Isto NÃO é aprovação — e uma promessa escrita na parte cega')
        print('      passaria batido.')
        return 2

    if violacoes:
        print(f'✗ REPROVADO — {len(violacoes)} promessa(s) de resultado '
              f'em {total} strings varridas:\n')
        for rel, n, p, trecho in violacoes:
            print(f'  {rel}:{n}  «{p}»')
            print(f'      {trecho}')
        print('\nO módulo descreve o que foi observado, nunca o que vai acontecer')
        print('com quem lê. Ver o cabeçalho de Shared/Corpo/JejumConteudo.swift.')
        return 1

    print(f'✓ {total} strings varridas em {len(ARQUIVOS)} arquivos '
          f"({contagem['literal']} literais + {contagem['multilinha']} linhas "
          'em multilinha) — nenhuma promessa de resultado.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
