#!/bin/bash
# Planta uma mutação nos ARQUIVOS DE PRODUÇÃO, roda o harness, e restaura.
#
# Uso: bash mutar.sh <m1|m2|m3|m4|m5> <saida.txt> "<rótulo>"
#
# Três travas, cada uma contra um jeito já visto de a mutação medir o nada:
#
#  1. A substituição CONFERE que casou exatamente uma vez. Mutação que não
#     aplicou e mesmo assim roda devolve verde e parece prova. Aqui ela aborta.
#  2. O `rodar.sh` PARA se o swiftc não devolver 0 — build quebrado não pode
#     virar "passou". (Foi assim que uma mutação passou verde medindo a
#     biblioteca antiga: erro de compilação indo para /dev/null.)
#  3. A restauração é conferida por sha1 contra o original, nos DOIS arquivos, e
#     o script grita se divergir. Produção com mutação esquecida dentro é pior
#     que nenhuma prova.
#
# m5 mexe em `ScanResultView.swift`, que não compila aqui (SwiftUI) e é lido
# como TEXTO pelo harness — por isso os dois arquivos entram no backup.

set -u
REPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main"
MODELO="$REPO/Shared/Corpo/AIBodyScan.swift"
TELA="$REPO/Shared/Corpo/ScanResultView.swift"
QUAL="$1"; SAIDA="$2"; ROTULO="${3:-sem rótulo}"
BK_MODELO="/tmp/AIBodyScan.original.$$.swift"
BK_TELA="/tmp/ScanResultView.original.$$.swift"

cd "$REPO" || exit 9
cp "$MODELO" "$BK_MODELO" || exit 9
cp "$TELA"   "$BK_TELA"   || exit 9
SHA_MODELO_ORIG=$(shasum "$MODELO" | cut -d' ' -f1)
SHA_TELA_ORIG=$(shasum "$TELA" | cut -d' ' -f1)

python3 - "$MODELO" "$TELA" "$QUAL" <<'PY'
import sys
modelo, tela, qual = sys.argv[1], sys.argv[2], sys.argv[3]

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

FRASE_BOA = """        gorduraInformada(gordura) != nil
            ? "peso, altura, idade e % de gordura informados"
            : "peso, altura e idade\""""
FRASE_FIXA = """        "peso, altura, idade e % de gordura informados"   // MUTAÇÃO: lista fixa"""

BANNER_BOM = r"""Text("Este resultado foi calculado apenas com \(BodyAnalysis.medidasUsadas(gordura: analysis.estimatedBodyFat)). Nenhuma foto foi analisada.")"""
BANNER_FIXO = r"""Text("Este resultado foi calculado apenas com peso, altura, idade e % de gordura informados. Nenhuma foto foi analisada.")"""

# (arquivo, de, para)
trocas = {
    'm1': [(modelo, REGRA_BOA, REGRA_CEGA)],
    'm2': [(modelo, HEURISTICA_BOA, HEURISTICA_INGENUA)],
    'm3': [(modelo, REGRA_BOA, REGRA_CEGA), (modelo, HEURISTICA_BOA, HEURISTICA_INGENUA)],
    'm4': [(modelo, FRASE_BOA, FRASE_FIXA)],
    'm5': [(tela, BANNER_BOM, BANNER_FIXO)],
}[qual]

for caminho, velho, novo in trocas:
    fonte = open(caminho, encoding='utf-8').read()
    n = fonte.count(velho)
    if n != 1:
        print(f"✗✗ ABORTADO: o trecho a mutar apareceu {n} vezes em {caminho} (esperava 1).")
        print("   A mutação NÃO foi aplicada — nenhum resultado valeria nada.")
        sys.exit(3)
    open(caminho, 'w', encoding='utf-8').write(fonte.replace(velho, novo, 1))

print(f"mutação {qual} aplicada ({len(trocas)} troca(s) confirmada(s) por contagem)")
PY

if [ $? -ne 0 ]; then
  cp "$BK_MODELO" "$MODELO"; cp "$BK_TELA" "$TELA"; rm -f "$BK_MODELO" "$BK_TELA"
  echo "✗✗ mutação não aplicada — arquivos restaurados, nada foi medido."
  exit 3
fi

SHA_MODELO_MUT=$(shasum "$MODELO" | cut -d' ' -f1)
SHA_TELA_MUT=$(shasum "$TELA" | cut -d' ' -f1)
if [ "$SHA_MODELO_MUT" = "$SHA_MODELO_ORIG" ] && [ "$SHA_TELA_MUT" = "$SHA_TELA_ORIG" ]; then
  cp "$BK_MODELO" "$MODELO"; cp "$BK_TELA" "$TELA"; rm -f "$BK_MODELO" "$BK_TELA"
  echo "✗✗ nenhum arquivo mudou apesar do 'aplicada' — abortando."
  exit 3
fi

bash "$REPO/_validacao_20260812_gordura/harness/rodar.sh" "$SAIDA" "$ROTULO"
STATUS=$?

cp "$BK_MODELO" "$MODELO"; cp "$BK_TELA" "$TELA"
SHA_MODELO_REST=$(shasum "$MODELO" | cut -d' ' -f1)
SHA_TELA_REST=$(shasum "$TELA" | cut -d' ' -f1)
rm -f "$BK_MODELO" "$BK_TELA"

{
  echo ""
  echo "─── MUTAÇÃO E RESTAURAÇÃO ───"
  echo "AIBodyScan.swift     original $SHA_MODELO_ORIG"
  echo "                     mutado   $SHA_MODELO_MUT"
  echo "                     restaur. $SHA_MODELO_REST"
  echo "ScanResultView.swift original $SHA_TELA_ORIG"
  echo "                     mutado   $SHA_TELA_MUT"
  echo "                     restaur. $SHA_TELA_REST"
  if [ "$SHA_MODELO_REST" = "$SHA_MODELO_ORIG" ] && [ "$SHA_TELA_REST" = "$SHA_TELA_ORIG" ]; then
    echo "✓ produção restaurada byte a byte nos dois arquivos."
  else
    echo "✗✗ RESTAURAÇÃO FALHOU — produção mutada no disco. INTERVIR."
  fi
} >> "$REPO/_validacao_20260812_gordura/$SAIDA"

tail -30 "$REPO/_validacao_20260812_gordura/$SAIDA"
exit $STATUS
