#!/usr/bin/env python3
"""TESTE DE MUTAÇÃO — o lado SERVIDOR do scan por foto (2026-08-12).

Prova que as guardas escritas depois do incidente de 12/08 reprovam de verdade,
em vez de ficarem verdes por não enxergar nada. Contrato de sempre:
aplica → verifica → restaura. ESPERADO = VERMELHO.

O que cada mutação tenta reintroduzir:
  MS-1  a CAUSA RAIZ — `somatotipo` volta a ser `['string','null']`
  MS-2  a instrução para de pedir o campo pelo nome
  MS-3  o normalizador passa a CHUTAR um tipo em vez de devolver null (B8)
  MS-4  o normalizador para de dobrar acento
  MS-5  o detector de formato chama qualquer coisa de JPEG
  MS-6  HEIC deixa de ser reconhecido

Dois verificadores diferentes, de propósito:
  · lint_wiring.py  — prende as LINHAS (esquema, instrução), verificação estática
  · testes_scan.mjs — prende o COMPORTAMENTO das funções puras, rodando o
                      JavaScript compilado que vai para produção

Como rodar:
    python3 _scripts/mutacao_scan_servidor.py

Escrito em Python e não em bash porque os padrões têm aspas, colchetes e
barras invertidas que o `sed -i ''` dos outros scripts embaralha — e mutação que
não casa vira furo silencioso, que é justamente o que estes arquivos combatem.

── O QUE ESTE SCRIPT NÃO PROVA (cegueira declarada) ────────────────────────────
Nada aqui chama a OpenAI. O `enum` do `json_schema` só vale se o PROVEDOR o
obedecer; isso quem prova é `_scripts/provar_scan_ponta_a_ponta.sh`, que gasta
cota e precisa de foto real. Também não prova nada do lado Swift — esse tem
lint + `_scripts/mutacao_scan_honesto.sh`, e nenhum teste de tela, porque o
projeto não tem XCUITest (dívida declarada no CLAUDE.md).
"""
import io
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TS = RAIZ / "functions/src/analiseDeFoto.ts"
BACKUP = Path("/tmp/mutacao_scan_servidor.bak")


def lint() -> bool:
    return subprocess.run(["python3", "_scripts/lint_wiring.py", "."],
                          cwd=RAIZ, capture_output=True).returncode == 0


def testes() -> bool:
    """Recompila e roda as asserções contra o `lib/` recém-gerado."""
    c = subprocess.run(["npx", "tsc", "-p", "tsconfig.json"],
                       cwd=RAIZ / "functions", capture_output=True)
    if c.returncode != 0:
        return False          # não compilar também é reprovar
    return subprocess.run(["node", "testes_scan.mjs"],
                          cwd=RAIZ / "functions", capture_output=True).returncode == 0


CASOS = [
    ("MS-1", "somatotipo: { type: 'string', enum: SOMATOTIPOS }",
             "somatotipo: { type: ['string', 'null'] }", lint,
             "A CAUSA RAIZ de 12/08: campo volta a ser livre e anulável"),
    ("MS-2", '- "somatotipo": EXATAMENTE uma destas três palavras',
             '- "somatotipoX": EXATAMENTE uma destas tres palavras', lint,
             "a instrução para de pedir o somatotipo pelo nome"),
    ("MS-3", "  return melhor?.tipo ?? null;",
             "  return melhor?.tipo ?? 'Mesomorfo';", testes,
             "o normalizador CHUTA um tipo em vez de admitir que não sabe (B8)"),
    # O padrão usa os ESCAPES `\\u0300-\\u036f` porque é assim que está na fonte.
    # Escrever aqui os caracteres combinantes literais — que renderizam igual —
    # faz o padrão não casar, e mutação que não casa é furo silencioso: o script
    # reporta sucesso sem ter testado nada. Aconteceu na primeira versão deste
    # arquivo, em 12/08, e foi pega pelo próprio contador de furos.
    ("MS-4", ".normalize('NFD').replace(/[\\u0300-\\u036f]/g, '')",
             ".normalize('NFD')", testes,
             "o normalizador para de dobrar acento"),
    ("MS-5", "if (cab[0] === 0xFF && cab[1] === 0xD8 && cab[2] === 0xFF) return 'jpeg';",
             "if (true) return 'jpeg';", testes,
             "o detector de formato chama qualquer coisa de JPEG"),
    ("MS-6", "if (['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].includes(marca)) return 'heic';",
             "if (false) return 'heic';", testes,
             "HEIC deixa de ser reconhecido e o rótulo volta a mentir"),
]


def main() -> int:
    print("═════ MUTAÇÃO — servidor do scan por foto ═════\n")
    if not lint():
        print("ABORTADO: o lint já está vermelho ANTES das mutações."); return 2
    if not testes():
        print("ABORTADO: testes_scan.mjs já está vermelho ANTES das mutações."); return 2
    print("  base: lint verde E asserções verdes antes de mutar ✓\n")

    vermelhas, furos = 0, []
    for cid, de, para, verificar, desc in CASOS:
        fonte = io.open(TS, encoding="utf-8").read()
        if fonte.count(de) != 1:
            print(f"  ! {cid}  MUTAÇÃO NÃO APLICADA (padrão casou {fonte.count(de)}×) — {desc}")
            furos.append(f"{cid} — padrão obsoleto, a mutação não testou nada")
            continue
        shutil.copy(TS, BACKUP)
        io.open(TS, "w", encoding="utf-8").write(fonte.replace(de, para, 1))
        try:
            if verificar():
                print(f"  ✗ {cid}  VERDE COM O BUG DENTRO — PROVA INÚTIL: {desc}")
                furos.append(f"{cid} — {desc}")
            else:
                print(f"  ✓ {cid}  vermelho, como deve ser: {desc}")
                vermelhas += 1
        finally:
            shutil.copy(BACKUP, TS)
            BACKUP.unlink(missing_ok=True)

    # Deixa o `lib/` coerente com a fonte restaurada.
    subprocess.run(["npx", "tsc", "-p", "tsconfig.json"],
                   cwd=RAIZ / "functions", capture_output=True)

    print(f"\n═════ RESULTADO ═════\nvermelhas (boas): {vermelhas} · furos: {len(furos)}")
    for f in furos:
        print(f"   ✗ {f}")
    return 1 if furos else 0


if __name__ == "__main__":
    sys.exit(main())
