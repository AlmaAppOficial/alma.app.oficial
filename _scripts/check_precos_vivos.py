#!/usr/bin/env python3
"""
Guarda: nenhum preço escrito à mão nas TELAS VIVAS do Alma iOS.

"Tela viva" = arquivo .swift que realmente entra numa PBXSourcesBuildPhase do
project.pbxproj (ou vem de um PBXFileSystemSynchronizedRootGroup, que compila a
pasta inteira). Arquivo órfão no disco não é tela viva e é ignorado de propósito.

Preço legítimo vem do StoreKit (Product.displayPrice). Qualquer valor monetário
digitado no fonte é violação.

GUARDA ANTI-CEGUEIRA (obrigatória neste projeto — ver A26d no CLAUDE.md):
um coletor que resolve zero arquivo faz a asserção passar verde para sempre.
Antes de afirmar qualquer coisa, o script exige que o conjunto vivo contenha
arquivos-sentinela conhecidos. Sem isso, ele se declara CEGO e falha.

Uso: check_precos_vivos.py <raiz-do-projeto>
Saída: exit 0 = VERDE, 1 = VERMELHO, 2 = CEGO.
"""
import os
import re
import sys

SENTINELAS = [  # arquivos que comprovadamente compilam; se sumirem, o parser quebrou
    "SubscriptionView.swift",
    "CorpoPaywallView.swift",
    "AuditoriaBloqueadores.swift",
]

# valor monetário digitado à mão
PADROES = [
    (re.compile(r'R\$\s*\d'), "literal em reais (R$ ...)"),
    (re.compile(r'US\$\s*\d'), "literal em dólares (US$ ...)"),
    (re.compile(r'\$\s*\d+[.,]\d{2}'), "literal com cifrão ($ 0,00)"),
    # cobre "price: 24.99," e também "let price: Double = 24.99" (anotação de tipo
    # no meio). A forma sem o trecho [^=\n]{0,30} passou verde numa mutação — a
    # regex antiga só via o caso sem tipo declarado.
    (re.compile(r'\b(price|preco|preço|valor|amount)\b[^=\n]{0,30}[:=]\s*\d+[.,]\d+'),
     "preço numérico chumbado"),
    (re.compile(r'"\s*\d+[.,]\d{2}\s*(/|\s)*(mês|mes|ano|month|year)'), "valor + período em string"),
]


def carregar_pbx(raiz):
    for d in os.listdir(raiz):
        if d.endswith(".xcodeproj"):
            p = os.path.join(raiz, d, "project.pbxproj")
            if os.path.isfile(p):
                return open(p, encoding="utf-8", errors="ignore").read(), d
    sys.exit("CEGO: nenhum .xcodeproj encontrado")


def arquivos_vivos(raiz, pbx):
    """Resolve fileRef -> path para cada build file dentro de Sources."""
    # 1) mapa de PBXFileReference: id -> path
    refs = {}
    for m in re.finditer(
        r'([0-9A-F]{8,})\s*/\*.*?\*/\s*=\s*\{isa = PBXFileReference;[^}]*?path = "?([^";]+)"?;[^}]*?\}',
        pbx, re.S,
    ):
        refs[m.group(1)] = m.group(2)

    # 2) mapa de PBXBuildFile: buildId -> fileRef
    builds = {}
    for m in re.finditer(
        r'([0-9A-F]{8,})\s*/\*.*?\*/\s*=\s*\{isa = PBXBuildFile;[^}]*?fileRef = ([0-9A-F]{8,})',
        pbx, re.S,
    ):
        builds[m.group(1)] = m.group(2)

    # 3) ids citados dentro de cada PBXSourcesBuildPhase
    vivos_ids = set()
    for bloco in re.finditer(
        r'isa = PBXSourcesBuildPhase;.*?files = \((.*?)\);', pbx, re.S
    ):
        vivos_ids.update(re.findall(r'([0-9A-F]{8,})\s*/\*', bloco.group(1)))

    # 4) resolve para caminhos reais em disco
    nomes = set()
    for bid in vivos_ids:
        fref = builds.get(bid)
        if fref and fref in refs:
            nomes.add(os.path.basename(refs[fref]))

    caminhos = []
    for dirpath, dirnames, filenames in os.walk(raiz):
        if any(x in dirpath for x in (".git", "DerivedData", ".build", "_screenshots")):
            continue
        for fn in filenames:
            if fn.endswith(".swift") and fn in nomes:
                caminhos.append(os.path.join(dirpath, fn))

    # 5) pastas sincronizadas: compilam inteiras, sem listar arquivo por arquivo
    for m in re.finditer(r'isa = PBXFileSystemSynchronizedRootGroup;[^}]*?path = "?([^";]+)"?;', pbx):
        pasta = os.path.join(raiz, m.group(1))
        for dirpath, _, filenames in os.walk(pasta):
            for fn in filenames:
                if fn.endswith(".swift"):
                    caminhos.append(os.path.join(dirpath, fn))

    return sorted(set(caminhos))


def sem_comentarios(texto):
    texto = re.sub(r'/\*.*?\*/', '', texto, flags=re.S)
    return "\n".join(re.sub(r'(^|\s)//.*$', '', l) for l in texto.split("\n"))


def main():
    raiz = sys.argv[1] if len(sys.argv) > 1 else sys.exit("uso: %s <raiz>" % sys.argv[0])
    pbx, projnome = carregar_pbx(raiz)
    vivos = arquivos_vivos(raiz, pbx)

    # ── GUARDA ANTI-CEGUEIRA ─────────────────────────────────────────────────
    base = {os.path.basename(p) for p in vivos}
    faltando = [s for s in SENTINELAS if s not in base]
    if len(vivos) < 50 or faltando:
        print("CEGO: o coletor resolveu %d arquivo(s) vivo(s); sentinelas ausentes: %s"
              % (len(vivos), ", ".join(faltando) or "nenhuma"))
        print("      Asserção NÃO confiável — parser do pbxproj quebrou.")
        return 2
    print("coletor OK: %d arquivos vivos, sentinelas presentes (%s)"
          % (len(vivos), ", ".join(SENTINELAS)))

    viol, coment = [], []
    for p in vivos:
        try:
            bruto = open(p, encoding="utf-8", errors="ignore").read()
        except OSError:
            continue
        limpo = sem_comentarios(bruto)
        rel = os.path.relpath(p, raiz)
        for n, linha in enumerate(limpo.split("\n"), 1):
            for rx, rot in PADROES:
                if rx.search(linha):
                    viol.append((rel, n, rot, linha.strip()[:100]))
        for n, linha in enumerate(bruto.split("\n"), 1):
            if re.search(r'R\$\s*\d', linha) and re.match(r'\s*(//|\*)', linha):
                coment.append((rel, n, linha.strip()[:100]))

    if coment:
        print("\n-- menções em COMENTÁRIO (não embarcam string na tela, informativo):")
        for rel, n, l in coment:
            print("   %s:%d  %s" % (rel, n, l))

    if viol:
        print("\nVERMELHO: %d preço(s) escrito(s) à mão em tela viva" % len(viol))
        for rel, n, rot, l in viol:
            print("   %s:%d  [%s]  %s" % (rel, n, rot, l))
        return 1

    print("\nVERDE: nenhum preço escrito à mão em tela viva (%d arquivos varridos)" % len(vivos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
