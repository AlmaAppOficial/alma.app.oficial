#!/bin/bash
# Planta uma mutação no ARQUIVO DE PRODUÇÃO, roda o harness, e restaura.
#
# Uso: bash mutar.sh <m1|m2|m3> <saida.txt> "<rótulo>"
#
# Três travas, cada uma contra um jeito já visto de a mutação medir o nada:
#
#  1. A substituição CONFERE que casou exatamente uma vez. Mutação que não
#     aplicou e mesmo assim roda devolve verde e parece prova. Aqui ela aborta.
#  2. O `rodar.sh` PARA se o swiftc não devolver 0 — build quebrado não pode
#     virar "passou". (Foi assim que uma mutação passou verde medindo a
#     biblioteca antiga: erro de compilação indo para /dev/null.)
#  3. A restauração é conferida por sha1 contra o original, e o script grita se
#     divergir. Arquivo de produção com mutação esquecida dentro é pior que
#     nenhuma prova.

set -u
REPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main"
ALVO="$REPO/Shared/Corpo/AIBodyScan.swift"
QUAL="$1"; SAIDA="$2"; ROTULO="${3:-sem rótulo}"
BACKUP="/tmp/AIBodyScan.original.$$.swift"

cd "$REPO" || exit 9
cp "$ALVO" "$BACKUP" || exit 9
SHA_ORIGINAL=$(shasum "$ALVO" | cut -d' ' -f1)

python3 - "$ALVO" "$QUAL" <<'PY'
import sys
caminho, qual = sys.argv[1], sys.argv[2]
fonte = open(caminho, encoding='utf-8').read()

# ── as duas linhas de produção que a parte 2 acrescentou ──────────────────
REGRA_BOA = """        guard gorduraInformada(gordura) != nil else { return nil }
        return bruto"""
REGRA_CEGA = """        return bruto   // MUTAÇÃO: a guarda saiu"""

HEURISTICA_BOA = """        let soma: Somatotype?
        if let gordura = BodyAnalysis.gorduraInformada(input.bodyFat) {
            if gordura >= 25 || bmi >= 27 { soma = .endomorfo }
            else if gordura <= 12 && bmi < 21 { soma = .ectomorfo }
            else { soma = .mesomorfo }
        } else {
            soma = nil
        }"""
HEURISTICA_INGENUA = """        let soma: Somatotype?
        // MUTAÇÃO: a heurística ingênua, exatamente como estava antes do conserto
        if input.bodyFat >= 25 || bmi >= 27 { soma = .endomorfo }
        else if input.bodyFat <= 12 && bmi < 21 { soma = .ectomorfo }
        else { soma = .mesomorfo }"""

trocas = {
    'm1': [(REGRA_BOA, REGRA_CEGA)],
    'm2': [(HEURISTICA_BOA, HEURISTICA_INGENUA)],
    'm3': [(REGRA_BOA, REGRA_CEGA), (HEURISTICA_BOA, HEURISTICA_INGENUA)],
}[qual]

for velho, novo in trocas:
    n = fonte.count(velho)
    if n != 1:
        print(f"✗✗ ABORTADO: o trecho a mutar apareceu {n} vezes (esperava 1).")
        print("   A mutação NÃO foi aplicada — nenhum resultado valeria nada.")
        sys.exit(3)
    fonte = fonte.replace(velho, novo, 1)

open(caminho, 'w', encoding='utf-8').write(fonte)
print(f"mutação {qual} aplicada ({len(trocas)} troca(s) confirmada(s) por contagem)")
PY

if [ $? -ne 0 ]; then
  cp "$BACKUP" "$ALVO"; rm -f "$BACKUP"
  echo "✗✗ mutação não aplicada — arquivo restaurado, nada foi medido."
  exit 3
fi

SHA_MUTADO=$(shasum "$ALVO" | cut -d' ' -f1)
if [ "$SHA_MUTADO" = "$SHA_ORIGINAL" ]; then
  cp "$BACKUP" "$ALVO"; rm -f "$BACKUP"
  echo "✗✗ o arquivo não mudou apesar do 'aplicada' — abortando."
  exit 3
fi

bash "$REPO/_validacao_20260812_gordura/harness/rodar.sh" "$SAIDA" "$ROTULO"
STATUS=$?

cp "$BACKUP" "$ALVO"
SHA_RESTAURADO=$(shasum "$ALVO" | cut -d' ' -f1)
rm -f "$BACKUP"

{
  echo ""
  echo "─── MUTAÇÃO E RESTAURAÇÃO ───"
  echo "sha1 original:   $SHA_ORIGINAL"
  echo "sha1 mutado:     $SHA_MUTADO   (diferente = a mutação entrou mesmo)"
  echo "sha1 restaurado: $SHA_RESTAURADO"
  if [ "$SHA_RESTAURADO" = "$SHA_ORIGINAL" ]; then
    echo "✓ produção restaurada byte a byte."
  else
    echo "✗✗ RESTAURAÇÃO FALHOU — o arquivo de produção está mutado. INTERVIR."
  fi
} >> "$REPO/_validacao_20260812_gordura/$SAIDA"

tail -25 "$REPO/_validacao_20260812_gordura/$SAIDA"
exit $STATUS
