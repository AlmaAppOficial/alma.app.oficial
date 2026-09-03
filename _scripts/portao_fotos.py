#!/usr/bin/env python3
"""PORTÃO DE CONTEÚDO DAS FOTOS — julga o BINÁRIO, não a árvore de trabalho.

Compilar verde não prova que a imagem entrou no app. A referência de pasta do
Xcode pode não ter sido copiada, o alvo pode ter ficado sem a fase de Resources,
e o `.app` sai assim mesmo, silencioso. Este portão abre o bundle construído e
conta o que está lá dentro.

Saída: 0 = aprovou · 1 = reprovou · 2 = CEGO (não medi nada; descartar)

O modo de falha que este arquivo existe para evitar é o do CLAUDE.md: uma busca
que devolve zero nos dois mundos e é lida como "não vazou". Por isso todo
resultado aqui depende de um CONTROLE POSITIVO passar antes.
"""
import argparse
import pathlib
import subprocess
import sys

# A string exata que a licença free do RepDB (termo 2) exige, em inglês.
# 33 bytes — acima do limiar de ~15 em que o Swift embute a string inline e ela
# deixa de ser encontrável no binário.
ATRIBUICAO = "Exercise data by RepDB (repdb.co)"

# As 5 reprovadas na revisão de 03/09. Tinham entrado no commit anterior, então
# a ausência delas aqui é o que distingue este build do anterior — não é uma
# checagem de "nunca existiu".
SAIRAM = [
    "banded-standing-curl-peak.webp",
    "banded-standing-curl-start.webp",
    "box-squat-peak.webp",
    "box-squat-start.webp",
    "dancer-pose-main.webp",
]

# Amostra das 16 que entraram hoje.
ENTRARAM = [
    "banded-it-band-stretch-main.webp",
    "push-jerk-peak.webp",
    "single-leg-romanian-deadlift-start.webp",
    "kneeling-cable-row-peak.webp",
]

ESPERADO_WEBP = 605


def no_binario(caminho: pathlib.Path, texto: str) -> int:
    """Conta ocorrências byte a byte. `grep -a -F` e não `strings`: strings
    perde acento e quebra em byte alto, que é metade do texto deste app."""
    try:
        r = subprocess.run(["grep", "-a", "-c", "-F", texto, str(caminho)],
                           capture_output=True, text=True)
        return int(r.stdout.strip() or 0)
    except Exception:
        return -1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True, help="caminho do .app construído")
    a = ap.parse_args()
    app = pathlib.Path(a.app)
    binario = app / "Alma.App.Oficial"
    pasta = app / "ExerciciosFotos"

    print(f"=== .app: {app}")
    if not app.exists():
        print("CEGO: o .app não existe. Não medi nada.")
        return 2
    if not binario.exists():
        print(f"CEGO: binário ausente em {binario}. Não medi nada.")
        return 2

    # ── CONTROLE POSITIVO DO MÉTODO ──────────────────────────────────────────
    # Sem isto, um `grep` quebrado devolveria 0 para tudo e o portão aprovaria
    # a ausência como se fosse presença conferida.
    print("\n--- CONTROLE do método de leitura do binário ---")
    ctrl_pos = "Alma.App.Oficial"
    n_pos = no_binario(binario, ctrl_pos)
    ctrl_neg = "STRING-QUE-NAO-EXISTE-EM-LUGAR-NENHUM-a91f7c"
    n_neg = no_binario(binario, ctrl_neg)
    print(f"    positivo {ctrl_pos!r} => {n_pos}   (tem de ser > 0)")
    print(f"    negativo {ctrl_neg!r} => {n_neg}   (tem de ser 0)")
    if n_pos <= 0 or n_neg != 0:
        print("\n✗✗ PORTÃO CEGO: o método não se provou. Resultado DESCARTADO.")
        return 2
    print("    => método provado.")

    falhas = []

    # ── 1. A PASTA ENTROU NO BUNDLE ──────────────────────────────────────────
    print("\n--- 1. a referência de pasta virou pasta de verdade no .app? ---")
    if not pasta.is_dir():
        print(f"    ✗ {pasta} NÃO existe no bundle.")
        print("\n✗✗ REPROVADO: as fotos não entraram. Build sem imagem nenhuma.")
        return 1
    webps = sorted(p.name for p in pasta.glob("*.webp"))
    print(f"    OK  {pasta.name}/ existe — {len(webps)} arquivos .webp")
    if len(webps) != ESPERADO_WEBP:
        falhas.append(f"contagem de .webp: {len(webps)}, esperado {ESPERADO_WEBP}")
        print(f"    ✗  esperado {ESPERADO_WEBP}")

    # ── 2. O QUE ENTROU HOJE ESTÁ LÁ ─────────────────────────────────────────
    print("\n--- 2. as 16 novas (amostra de 4) ---")
    dentro = set(webps)
    for n in ENTRARAM:
        ok = n in dentro
        print(f"    {'OK ' if ok else '✗  '} {n}")
        if not ok:
            falhas.append(f"nova ausente do bundle: {n}")

    # ── 3. O QUE SAIU HOJE NÃO ESTÁ MAIS ─────────────────────────────────────
    print("\n--- 3. as 5 reprovadas saíram mesmo do bundle? ---")
    for n in SAIRAM:
        ok = n not in dentro
        print(f"    {'OK ' if ok else '✗  '} {n} {'ausente' if ok else 'AINDA PRESENTE'}")
        if not ok:
            falhas.append(f"reprovada ainda no bundle: {n}")

    # ── 4. A ATRIBUIÇÃO DA LICENÇA ───────────────────────────────────────────
    # Termo 2 do RepDB: atribuição obrigatória, como link visível. Se ela sumir
    # do binário, o app está distribuindo o acervo fora da licença.
    print("\n--- 4. atribuição do RepDB (termo 2 da licença) ---")
    n_atr = no_binario(binario, ATRIBUICAO)
    ok = n_atr > 0
    print(f"    {'OK ' if ok else '✗  '} {ATRIBUICAO!r} => {n_atr} ({len(ATRIBUICAO.encode())}B)")
    if not ok:
        falhas.append("atribuição do RepDB ausente do binário — licença violada")

    # ── VEREDITO ─────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    if falhas:
        print(f"✗✗ PORTÃO REPROVOU — {len(falhas)} problema(s):")
        for f in falhas:
            print(f"    · {f}")
        return 1
    print(f"PORTÃO APROVOU — {len(webps)} fotos no bundle, as 16 novas dentro,")
    print("as 5 reprovadas fora, e a atribuição da licença no binário.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
