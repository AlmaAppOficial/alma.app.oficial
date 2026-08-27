#!/usr/bin/env python3
"""TERCEIRA VIA — o tipo do campo, lido do field metadata do binário.

Por que uma terceira via, se o portão já olha strings e dSYM:

  · STRINGS provam texto. Um literal pode ser dobrado, ficar atrás de `#if`,
    ou — o caso real de 26/08 — aparecer por ser substring de outro.
  · dSYM prova compilação. Mas é um arquivo SEPARADO do que sobe: se alguém
    trocar o binário e não o dSYM, o DWARF mente.
  · FIELD METADATA prova ESTRUTURA, e mora DENTRO do binário que sobe.

O Swift grava, no próprio binário, o nome e o tipo mangled de cada campo de
struct/class (secção `__swift5_fieldmd`, usada pela reflexão). Esse registo não
é literal de texto nem símbolo de depuração: é uma terceira coisa, com um
terceiro modo de falha. Três vias independentes concordando é o que separa
medida de coincidência.

O DISCRIMINANTE, medido em 27/08:

    `SugestaoDeQuebra.pratoPrincipal` mudou de TIPO entre os dois commits.
      5d25391 → [ComponenteDaRefeicao]   mangled: pratoPrincipalSayAA20ComponenteDaRefeicaoVGv
      6183d3c → [ItemDaQuebra]           mangled: pratoPrincipalSay12ItemDaQuebra...

    Otimizador não fabrica um tipo no lugar do outro. Dead-stripping remove o
    registo inteiro, nunca o reescreve com outro tipo. Então:
      · achou o tipo NOVO e não o velho  → é a reescrita, sem dúvida
      · achou o VELHO                    → é a versão velha, sem dúvida
      · não achou nenhum                 → CEGO, e o script se recusa a opinar

O canário anticegueira aqui é o próprio nome do campo (`pratoPrincipal`): ele
existe nas duas versões. Se nem ele aparecer, o coletor não está vendo a
estrutura e nenhuma conclusão pode sair daqui.

USO
    python3 _scripts/prova_tipo_do_campo.py <caminho/para/Alma.App.Oficial.app>

    exit 0 = é a versão NOVA (6183d3c)
    exit 1 = é a versão VELHA (5d25391), ou as duas coexistem
    exit 2 = CEGO — nem o canário apareceu
    exit 3 = artefato ausente
"""

import pathlib
import sys

# ── O DESCRITOR DE CAMPO, LIDO DOS ARTEFATOS — não deduzido ──────────────────
#
# [27/08] Primeira versão deste arquivo procurava o NOME DO TIPO por extenso
# perto do nome do campo. Deu CEGO no archive do 99, que estava correto. Duas
# coisas erradas, as duas descobertas olhando os bytes:
#
# 1. O SWIFT COMPRIME O MANGLING. No 98 o descritor sai por extenso:
#        pratoPrincipalSayAA20ComponenteDaRefeicaoVGv
#    No 99 ele sai comprimido, com referência de substituição:
#        pratoPrincipalSayAA06ItemDaF0VGv
#    `F0` é uma substituição para um nome já mencionado. Procurar a string
#    "ItemDaQuebra" ali nunca acharia — e não achar não significava ausência.
#
# 2. O NOME DO TIPO SOZINHO NÃO DISCRIMINA NADA. `ComponenteDaRefeicao`
#    aparece 7 vezes no binário do 99: o tipo continua existindo no código
#    novo, só não é mais o tipo DESTE campo. Contar o nome solto daria
#    "as duas versões coexistem" — falso, e na direção perigosa.
#
# Por isso o discriminante é o DESCRITOR INTEIRO, campo e tipo colados, na
# forma exata em que cada versão o grava. Os dois foram lidos dos artefatos
# reais (archives 98 e 99), não escritos de memória.
CAMPO = b"pratoPrincipal"                                    # canário: nas duas versões
DESCRITOR_VELHO = b"pratoPrincipalSayAA20ComponenteDaRefeicaoVGv"   # 5d25391
DESCRITOR_NOVO = b"pratoPrincipalSayAA06ItemDaF0VGv"                # 6183d3c

MAGICOS = (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xce\xfa\xed\xfe")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 3
    app = pathlib.Path(sys.argv[1])
    if not app.exists():
        print(f"SEM APP em {app}")
        return 3

    dados = b""
    n = 0
    for p in app.rglob("*"):
        if p.is_file() and not p.is_symlink():
            try:
                if p.open("rb").read(4) in MAGICOS:
                    dados += p.read_bytes()
                    n += 1
            except OSError:
                pass
    print(f"Mach-O varridos: {n}   bytes: {len(dados):,}\n")

    par_velho = DESCRITOR_VELHO in dados
    par_novo = DESCRITOR_NOVO in dados

    canario = CAMPO in dados
    print(f"  canário  {CAMPO.decode():<24} {'PRESENTE' if canario else 'AUSENTE'}")
    print(f"  descritor VELHO  {DESCRITOR_VELHO.decode():<44} {'PRESENTE' if par_velho else 'ausente'}")
    print(f"  descritor NOVO   {DESCRITOR_NOVO.decode():<44} {'PRESENTE' if par_novo else 'ausente'}")

    print("\n═══ VEREDITO ═══")
    if not canario:
        print("CEGO: o campo `pratoPrincipal` não apareceu no binário.")
        print("Ele existe nas DUAS versões — se o módulo estivesse aqui, ele estaria.")
        print("Sem canário não há conclusão a tirar. Confira o caminho do .app.")
        return 2
    if par_novo and par_velho:
        print("REPROVADO: os DOIS tipos aparecem colados ao campo.")
        print("As duas versões coexistem — não dá para saber qual a tela desenha.")
        return 1
    if par_novo:
        print("APROVADO: `pratoPrincipal` é [ItemDaQuebra] — é a reescrita (6183d3c).")
        return 0
    if par_velho:
        print("REPROVADO: `pratoPrincipal` é [ComponenteDaRefeicao] — versão VELHA (5d25391).")
        return 1
    print("CEGO: o campo apareceu, mas sem tipo casado a ele.")
    print("Estrutura inesperada — não vou adivinhar.")
    return 2


if __name__ == "__main__":
    sys.exit(main())
