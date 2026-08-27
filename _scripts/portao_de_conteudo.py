#!/usr/bin/env python3
"""PORTÃO DE CONTEÚDO — o binário contém a versão do código que o build promete?

════════════════════════════════════════════════════════════════════════════════
POR QUE ESTE ARQUIVO EXISTE  [2026-08-27]

O build 2.0.3 (98) subiu ao TestFlight com a versão VELHA do módulo de jejum.
Nada estava quebrado: o archive compilou, os 3 bundles conferiram em 2.0.3 (98),
o `altool` validou, o ASC disse VALID. Todo portão que existia estava verde.

Nenhum deles perguntava a única coisa que importava: **o binário contém o código
que este build promete entregar?** A reescrita foi commitada 1h44 depois do
archive, e não havia nada no caminho capaz de notar.

Este arquivo é essa pergunta, feita de forma que não dependa de ninguém lembrar.

════════════════════════════════════════════════════════════════════════════════
COMO ELE PERGUNTA — os dois lados, nunca um só

Presença sozinha não basta. Um binário pode conter a reescrita E os restos da
versão velha (arquivo duplicado no alvo, cópia esquecida, merge malfeito). Nesse
caso não se sabe qual das duas a tela desenha, e "algo está certo" é falso.
Por isso:

    APROVA  ⇔  as strings exclusivas da versão NOVA estão presentes
               E  as strings exclusivas da versão VELHA estão ausentes
               E  o canário está vivo

Coexistência REPROVA.

════════════════════════════════════════════════════════════════════════════════
AS TRÊS ARMADILHAS QUE ESTE ARQUIVO DESARMA — todas encontradas medindo, em
26 e 27/08, e todas capazes de produzir verde mentiroso.

1. STRING CURTA NÃO EXISTE NO BINÁRIO.
   Swift guarda string de até 15 bytes UTF-8 INLINE (small string optimization):
   ela vira valor imediato na instrução, não sequência contínua de bytes.
   Varrer bytes NUNCA vai achar. Medido no archive 98: 'Cancelar' (8),
   'Galeria' (7), 'Respira fundo' (13) dão ausente e estão no app há meses.
   → Este script REJEITA string de ≤15 bytes na montagem do conjunto, em vez de
     produzir falso-negativo silencioso.

2. SUBSTRING FABRICA PRESENÇA.
   Na conferência do 98, 2 das 65 strings "só da nova" apareceram presentes.
   Eram substrings de literais da VELHA: 'Depois, o prato principal' vive dentro
   de '2. Depois, o prato principal'. Varredura de bytes não sabe a diferença.
   → Este script REMOVE de cada conjunto tudo que seja substring do outro.

3. AUSÊNCIA DE SÍMBOLO NÃO PROVA NADA NO BINÁRIO EXPORTADO.
   O export usa `stripSwiftSymbols=true` e há dead-stripping real: no 98,
   `CorpoPaywallView` aparece 9× no dSYM e 0× no binário, estando compilado.
   → Símbolo só é julgado contra o **dSYM** (DWARF não-stripado). Zero no DWARF
     significa NUNCA COMPILADO. Zero no binário não significa nada.

════════════════════════════════════════════════════════════════════════════════
CANÁRIO ANTICEGUEIRA — a lição A26d deste projeto, aplicada à própria guarda

"Um coletor que não enxerga nada faz qualquer asserção de AUSÊNCIA passar para
sempre — o pior tipo de verde." (CLAUDE.md, 05/08)

Metade deste portão é asserção de ausência. Se o coletor ficar cego — caminho
errado, .app vazio, arquitetura inesperada, regex que parou de casar — o lado
"velho ausente" passa sozinho e de graça.

Por isso o canário: as strings que existem nas DUAS versões. Se o módulo está
no build, ALGUMA delas tem de aparecer. Nenhuma aparecendo significa que o
coletor não está vendo o módulo, e a saída é **CEGO (exit 2)** — nunca APROVADO
e nunca REPROVADO. Um portão que não sabe se enxerga não tem direito a veredito.

O canário não é escrito à mão: sai da interseção dos dois refs. Não apodrece.

════════════════════════════════════════════════════════════════════════════════
O QUE ESTE PORTÃO **NÃO** PROVA — dito aqui para não ser suposto lá fora

  · NÃO prova que a tela DESENHA o texto. Prova que os bytes estão no binário.
    O elo binário→tela é XCUITest, que este projeto não tem (ver CLAUDE.md).
  · NÃO prova que o IPA enviado é este archive. Isso é o LC_UUID, conferido
    separadamente pelo `tf_archive_99.sh`.
  · NÃO prova ausência de string de ≤15 bytes. Ele se recusa a opinar sobre
    elas, o que é diferente de aprová-las.

USO
    python3 _scripts/portao_de_conteudo.py \
        --velho 5d25391 --novo 6183d3c \
        --arquivos Shared/Corpo/JejumConteudo.swift Shared/Corpo/QuebraDeJejum.swift \
                   Shared/Corpo/QuebraDeJejumView.swift Shared/Corpo/JejumView.swift \
                   Shared/Corpo/Jejum.swift \
        --app /tmp/alma99.xcarchive/Products/Applications/Alma.App.Oficial.app \
        --dsym /tmp/alma99.xcarchive/dSYMs/Alma.App.Oficial.app.dSYM

SAÍDA
    exit 0 = APROVADO   (novo presente, velho ausente, canário vivo)
    exit 1 = REPROVADO  (falta novo, ou sobrou velho, ou os dois coexistem)
    exit 2 = CEGO       (o coletor não está enxergando — veredito recusado)
    exit 3 = uso errado / artefato ausente
"""

import argparse
import pathlib
import re
import subprocess
import sys

# Limite da small string optimization do Swift, em BYTES UTF-8.
LIMITE_INLINE = 15

# Abaixo disto o conjunto não tem poder de discriminar e o portão recusa veredito.
PISO_DISCRIMINANTE = 5
PISO_CANARIO = 3

# Fração do canário que precisa aparecer para o coletor ser considerado vidente.
#
# [27/08] FURO ENCONTRADO POR MUTAÇÃO, nesta guarda, antes de ela ser usada.
# A checagem era `if not vivos` — só zero contava como cego. Apontei o coletor
# para o "Alma Watch App.app", que NÃO tem o módulo de jejum, e o canário voltou
# 1/50: uma única string genérica que o Watch também usa. 2% passou pela porta,
# e o veredito saiu REPROVADO em vez de CEGO.
#
# REPROVADO ali não era perigoso — a asserção de presença barra o upload de
# qualquer jeito. Era MENTIROSO, que é o defeito que este projeto persegue:
# manda o próximo caçar bug de código quando o problema era caminho errado.
# É o espelho do M11 ("acusar de cega uma asserção perfeita engana tanto quanto
# verde comprado"): chamar de reprovado um coletor cego engana igual.
#
# 0,50 é folgado de propósito. Medido no archive 98, com o módulo de fato no
# build: 50/50 = 100%. Nada legítimo chega perto de metade.
FRACAO_CANARIO_EXIGIDA = 0.50

# Fração das strings novas que precisa estar presente. Não é 100% porque um
# literal pode ser dobrado pelo otimizador ou viver atrás de `#if DEBUG`.
# Medido no 98: 59 de 62 exclusivas da velha apareceram — 95%.
FRACAO_NOVA_EXIGIDA = 0.90

LITERAL = re.compile(r'"([^"\\\n]{1,400})"')
DECLARACAO = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|nonisolated\s+)*'
    r'(?:enum|struct|final\s+class|class|actor)\s+([A-Z][A-Za-z0-9_]*)',
    re.M,
)

MAGICOS_MACHO = (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xce\xfa\xed\xfe")


def sem_comentarios(texto: str) -> str:
    """Comentário não chega ao binário. Incluí-lo fabricaria discriminante falso.

    Foi exatamente assim que `frutas` enganou a primeira análise do 98: a lista
    sumiu em 6183d3c, mas a PALAVRA sobreviveu num comentário explicando a
    remoção — e o binário tinha um 'frutas' vindo de outro arquivo.
    """
    texto = re.sub(r"/\*.*?\*/", "", texto, flags=re.S)
    texto = re.sub(r"^\s*//.*$", "", texto, flags=re.M)
    return texto


def conteudo_no_ref(ref: str, caminho: str, raiz: pathlib.Path) -> str:
    r = subprocess.run(
        ["git", "show", f"{ref}:{caminho}"],
        cwd=raiz, capture_output=True, text=True,
    )
    return r.stdout if r.returncode == 0 else ""


def colher(ref: str, arquivos: list[str], raiz: pathlib.Path):
    """Devolve (literais, tipos declarados) de uma versão dos arquivos."""
    literais, tipos = set(), set()
    for caminho in arquivos:
        bruto = conteudo_no_ref(ref, caminho, raiz)
        if not bruto:
            continue
        limpo = sem_comentarios(bruto)
        for m in LITERAL.finditer(limpo):
            v = m.group(1)
            if len(v.encode("utf-8")) > LIMITE_INLINE:   # armadilha 1
                literais.add(v)
        for m in DECLARACAO.finditer(limpo):
            tipos.add(m.group(1))
    return literais, tipos


def desubstring(alvo: set[str], outro: set[str]) -> set[str]:
    """Tira de `alvo` tudo que viva dentro de alguma string de `outro`.

    Armadilha 2. Sem isto, 'Depois, o prato principal' conta como presente
    porque '2. Depois, o prato principal' está no binário.
    """
    return {s for s in alvo if not any(s in t for t in outro)}


def machos(app: pathlib.Path) -> list[pathlib.Path]:
    achados = []
    for p in app.rglob("*"):
        if p.is_file() and not p.is_symlink():
            try:
                if p.open("rb").read(4) in MAGICOS_MACHO:
                    achados.append(p)
            except OSError:
                pass
    return achados


def bytes_do_dsym(dsym: pathlib.Path) -> bytes:
    dwarf = dsym / "Contents" / "Resources" / "DWARF"
    if not dwarf.is_dir():
        return b""
    return b"".join(p.read_bytes() for p in dwarf.iterdir() if p.is_file())


def presentes(conjunto: set[str], dados: bytes) -> set[str]:
    return {s for s in conjunto if s.encode("utf-8") in dados}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--velho", required=True, help="ref git da versão que NÃO pode estar no build")
    ap.add_argument("--novo", required=True, help="ref git da versão que TEM de estar no build")
    ap.add_argument("--arquivos", required=True, nargs="+")
    ap.add_argument("--app", required=True)
    ap.add_argument("--dsym", default=None)
    ap.add_argument("--raiz", default=None)
    a = ap.parse_args()

    raiz = pathlib.Path(a.raiz) if a.raiz else pathlib.Path(__file__).resolve().parent.parent
    app = pathlib.Path(a.app)
    if not app.exists():
        print(f"SEM APP em {app}")
        return 3

    print("═══ PORTÃO DE CONTEÚDO ═══")
    print(f"  velho (não pode entrar): {a.velho}")
    print(f"  novo  (tem de entrar)  : {a.novo}")
    print(f"  app                    : {app}")

    lit_velho, tip_velho = colher(a.velho, a.arquivos, raiz)
    lit_novo, tip_novo = colher(a.novo, a.arquivos, raiz)
    if not lit_velho and not lit_novo:
        print("\nCEGO: não colhi literal nenhum dos dois refs — refs ou caminhos errados?")
        return 2

    so_velho = desubstring(lit_velho - lit_novo, lit_novo)
    so_novo = desubstring(lit_novo - lit_velho, lit_velho)
    canario = lit_velho & lit_novo                      # existe nas duas versões

    print(f"\n  exclusivas do velho : {len(so_velho)}")
    print(f"  exclusivas do novo  : {len(so_novo)}")
    print(f"  canário (interseção): {len(canario)}")

    if len(so_novo) < PISO_DISCRIMINANTE or len(so_velho) < PISO_DISCRIMINANTE:
        print(f"\nCEGO: conjunto discriminante abaixo do piso ({PISO_DISCRIMINANTE}).")
        print("Sem poder de separar as duas versões, este portão não tem veredito a dar.")
        return 2
    if len(canario) < PISO_CANARIO:
        print(f"\nCEGO: canário abaixo do piso ({PISO_CANARIO}) — sem como detectar cegueira.")
        return 2

    bins = machos(app)
    dados = b"".join(p.read_bytes() for p in bins)
    print(f"\n  Mach-O varridos: {len(bins)}   bytes: {len(dados):,}")

    # ── CANÁRIO ────────────────────────────────────────────────────────────────
    vivos = presentes(canario, dados)
    frac_canario = len(vivos) / len(canario)
    print(f"  canário vivo: {len(vivos)}/{len(canario)}  ({frac_canario:.0%})")
    if frac_canario < FRACAO_CANARIO_EXIGIDA:
        print(f"\nCEGO: só {frac_canario:.0%} do canário apareceu "
              f"(exigido {FRACAO_CANARIO_EXIGIDA:.0%}).")
        print("As strings do canário existem nas DUAS versões: se o módulo estivesse")
        print("neste binário, elas estariam aqui. Ou o módulo não está no build, ou")
        print("o coletor não o enxerga — caminho errado, .app errado, arquitetura")
        print("inesperada.")
        print("")
        print("Não digo APROVADO porque metade deste portão é asserção de AUSÊNCIA,")
        print("e ausência medida por coletor cego passa de graça. Não digo REPROVADO")
        print("porque não vi o binário para poder reprová-lo. Confira o --app.")
        return 2

    # ── OS DOIS LADOS ──────────────────────────────────────────────────────────
    achadas_novo = presentes(so_novo, dados)
    achadas_velho = presentes(so_velho, dados)
    frac = len(achadas_novo) / len(so_novo)

    print(f"\n  NOVO  presente: {len(achadas_novo)}/{len(so_novo)}  ({frac:.0%})")
    print(f"  VELHO presente: {len(achadas_velho)}/{len(so_velho)}   (tem de ser 0)")

    if achadas_velho:
        print("\n  restos da versão velha encontrados:")
        for s in sorted(achadas_velho)[:10]:
            print(f"     {s[:100]!r}")
    faltando = so_novo - achadas_novo
    if faltando:
        print("\n  strings da versão nova que NÃO apareceram:")
        for s in sorted(faltando)[:10]:
            print(f"     {s[:100]!r}")

    # ── SÍMBOLOS, só contra o dSYM (armadilha 3) ───────────────────────────────
    veredito_simbolos = None
    if a.dsym:
        dsym = pathlib.Path(a.dsym)
        dw = bytes_do_dsym(dsym)
        if not dw:
            print(f"\n  (dSYM ilegível em {dsym} — checagem de símbolo pulada)")
        else:
            s_novo = tip_novo - tip_velho
            s_velho = tip_velho - tip_novo
            comuns = tip_novo & tip_velho
            vivos_s = {t for t in comuns if t.encode() in dw}
            print(f"\n  dSYM: {len(dw):,} bytes   canário de tipo vivo: {len(vivos_s)}/{len(comuns)}")
            if comuns and not vivos_s:
                print("  CEGO no dSYM: nenhum tipo comum encontrado — checagem recusada.")
            else:
                pres_novo = {t for t in s_novo if t.encode() in dw}
                pres_velho = {t for t in s_velho if t.encode() in dw}
                print(f"  tipos só do NOVO  no DWARF: {len(pres_novo)}/{len(s_novo)}"
                      f"  {sorted(s_novo) if s_novo else ''}")
                print(f"  tipos só do VELHO no DWARF: {len(pres_velho)}/{len(s_velho)}"
                      f"  (tem de ser 0)")
                veredito_simbolos = (
                    (not s_novo or pres_novo == s_novo) and not pres_velho
                )

    # ── VEREDITO ───────────────────────────────────────────────────────────────
    print("\n═══ VEREDITO ═══")
    problemas = []
    if achadas_velho:
        problemas.append(
            f"{len(achadas_velho)} string(s) exclusivas da versão VELHA estão no binário"
        )
    if frac < FRACAO_NOVA_EXIGIDA:
        problemas.append(
            f"só {frac:.0%} das strings da versão NOVA apareceram "
            f"(exigido {FRACAO_NOVA_EXIGIDA:.0%})"
        )
    if veredito_simbolos is False:
        problemas.append("os tipos declarados no dSYM não batem com a versão nova")
    if achadas_velho and achadas_novo:
        problemas.append(
            "AS DUAS VERSÕES COEXISTEM no binário — não dá para saber qual a tela desenha"
        )

    if problemas:
        print("REPROVADO. NÃO subir este build.")
        for p in problemas:
            print(f"  · {p}")
        return 1

    print("APROVADO: o binário contém a versão nova e nenhum resto da velha.")
    print("  (prova bytes no binário, não pixels na tela — ver cabeçalho)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
