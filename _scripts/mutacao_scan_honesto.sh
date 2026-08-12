#!/bin/bash
# TESTE DE MUTAÇÃO — a tela e o registro contam a mesma coisa (2026-08-05)
#
# Cobre os dois bugs achados na varredura do scan:
#   (a) texto do caminho SEM IA vazando para o resultado COM IA;
#   (b) porção exibida ≠ porção registrada na dieta.
#
# Contrato de sempre: aplica → verifica → restaura. ESPERADO = VERMELHO.
#
# ESTE SCRIPT EXERCITA O LINT ESTÁTICO. As asserções H1..H2d rodam no harness
# em DEBUG e provam a ARITMÉTICA (520 kcal exibidos == 520 kcal registrados);
# as mutações delas exigem build e estão listadas ao final como dívida, não
# como verde.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

LINT="python3 _scripts/lint_wiring.py ."
verde=0; vermelho=0; furos=()

mutar() {
  local id="$1" arq="$2" expr="$3" verif="$4" desc="$5"
  cp "$arq" "/tmp/mutc_backup_$$"
  sed -i '' "$expr" "$arq"

  if ! diff -q "/tmp/mutc_backup_$$" "$arq" > /dev/null; then
    if eval "$verif" > /tmp/mutc_out_$$ 2>&1; then
      echo "  ✗ $id  VERDE com o bug dentro — PROVA INÚTIL: $desc"
      furos+=("$id — $desc"); verde=$((verde+1))
    else
      echo "  ✓ $id  vermelho, como deve ser: $desc"
      vermelho=$((vermelho+1))
    fi
  else
    echo "  ! $id  a mutação não alterou o arquivo (padrão não casou) — $desc"
    furos+=("$id — mutação não aplicada"); verde=$((verde+1))
  fi

  cp "/tmp/mutc_backup_$$" "$arq"; rm -f "/tmp/mutc_backup_$$" /tmp/mutc_out_$$
}

echo "═════ MUTAÇÃO — scan honesto: exibido == registrado ═════"
echo

if ! $LINT > /tmp/mutc_base_$$ 2>&1; then
  echo "ABORTADO: o lint já está vermelho ANTES das mutações."
  cat /tmp/mutc_base_$$; rm -f /tmp/mutc_base_$$
  exit 2
fi
echo "  base: lint verde antes de mutar ✓"
rm -f /tmp/mutc_base_$$
echo

# ── (b) porção ─────────────────────────────────────────────────────────────
# [2026-08-12] O padrão desta mutação estava OBSOLETO desde 06/08: procurava
# `grams: r.porcaoG`, que deixou de existir quando a porção virou ajustável
# (commit 9ba23fc, linha atual `grams: gramas`). O `mutar` reporta isso como
# furo — "a mutação não alterou o arquivo" —, então o script vinha acusando um
# buraco que não existia. Corrigido para a linha viva.
mutar "M-H1" "Shared/Corpo/FoodScanView.swift" \
  's|model.addFood(r.comoFoodItem, grams: gramas, to: mealType)|model.addFood(r.comoFoodItem, grams: 100, to: mealType)|' \
  "$LINT" "O BUG ORIGINAL: volta grams: 100 fixo, ignorando a porção em uso"

# [2026-08-12] Mesmo defeito do M-H1, achado na mesma revisão: o padrão
# `r.macrosDaPorcao.kcal` morreu em 06/08 e a linha viva é `macros.kcal`.
# A mutação não casava, o `mutar` contava furo e o script saía com exit 1.
mutar "M-H2" "Shared/Corpo/FoodScanView.swift" \
  's|macroTile("\\(macros.kcal)", "kcal", Theme.coral)|macroTile("\\(r.kcalPer100)", "kcal", Theme.coral)|' \
  "$LINT" "os tiles voltam a mostrar por 100 g debaixo da frase da porção"

mutar "M-H3" "Shared/Corpo/Models.swift" \
  's|^    static func escalarPor100(_ valorPor100: Int, gramas: Int) -> Int {|    static func MUTANTE(_ valorPor100: Int, gramas: Int) -> Int {|' \
  "$LINT" "a fonte única da escala some e cada ponta faz a própria conta"

# ── (a) vazamento de texto ─────────────────────────────────────────────────
# [2026-08-12] M-H4 foi reescrita e ganhou três irmãs. A versão de 05/08 mutava
# `guard let somatotipo = r.somatotipo.flatMap(...)`, linha que deixou de
# existir: era ELA a causa do incidente de 12/08 — tratava o RÓTULO como se
# fosse a leitura da foto e derrubava a análise inteira quando ele não vinha na
# grafia exata. Quatro tentativas do Assis, quatro telas de erro.
#
# O invariante não foi afrouxado, foi partido em dois, e as mutações seguem os
# dois pedaços: M-H4/M-H4c provam que o rótulo não pode voltar a sair do mock
# nem ser chutado; M-H4b prova que o RESUMO — o que sustenta a leitura —
# continua obrigatório. Sem M-H4b, alguém afrouxaria o resumo junto achando que
# é a mesma flexibilização, e aí a tela volta a mentir.
mutar "M-H4" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|let somatotipo = Self.somatotipoDaIA(r.somatotipo)|let somatotipo = Self.somatotipoDaIA(r.somatotipo) ?? base.analysis.somatotype|' \
  "$LINT" "o rótulo volta a sair do mock quando a IA não manda"

mutar "M-H4b" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|guard !resumoLimpo.isEmpty else {|guard true else {|' \
  "$LINT" "resumo vazio deixa de derrubar a análise (a metade NÃO afrouxada)"

mutar "M-H4c" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|let somatotipo = Self.somatotipoDaIA(r.somatotipo)|let somatotipo = Self.somatotipoDaIA(r.somatotipo) ?? .mesomorfo|' \
  "$LINT" "o normalizador passa a CHUTAR .mesomorfo em vez de omitir o rótulo"

mutar "M-H4d" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|let somatotipo = Self.somatotipoDaIA(r.somatotipo)|let somatotipo: Somatotype? = nil|' \
  "$LINT" "o normalizador some do caminho e o rótulo nunca mais aparece"

# ── As duas abaixo nasceram de uma REVISÃO, não de imaginação ───────────────
# A primeira versão da regra H-W4c olhava só o sítio de chamada e só na grafia
# com ponto. Estas duas mutações passavam VERDE COM O BUG DENTRO, e a segunda é
# a mais perigosa das duas: o chute plantado DENTRO da função que promete não
# chutar — o lugar mais natural de alguém introduzir o defeito de boa-fé.
# É o modo de falha da A26d (guarda cega) cometido pela própria guarda.
mutar "M-H4e" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|return melhor?.tipo|return melhor?.tipo ?? .mesomorfo|' \
  "$LINT" "CEGUEIRA 1: o chute plantado DENTRO do normalizador"

mutar "M-H4f" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|let somatotipo = Self.somatotipoDaIA(r.somatotipo)|let somatotipo = Self.somatotipoDaIA(r.somatotipo) ?? Somatotype.mesomorfo|' \
  "$LINT" "CEGUEIRA 2: o mesmo chute com o nome do tipo QUALIFICADO"

mutar "M-H5" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|observations: r.observacoes.isEmpty ? Self.observacoesPadraoDaIA : r.observacoes|observations: r.observacoes.isEmpty ? base.analysis.observations : r.observacoes|' \
  "$LINT" "O BUG ORIGINAL: 'adicione foto de frente e de lado' volta a vazar"

mutar "M-H6" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|focusAreas: r.focos.isEmpty ? Self.focosPadraoDaIA : r.focos|focusAreas: r.focos.isEmpty ? base.analysis.focusAreas : r.focos|' \
  "$LINT" "os focos voltam a sair do mock"

echo
echo "═════ RESULTADO ═════"
echo "vermelhas (boas): $vermelho · verdes (furos): $verde"
if [ ${#furos[@]} -gt 0 ]; then
  echo "FUROS:"
  for f in "${furos[@]}"; do echo "   ✗ $f"; done
fi

echo
echo "═════ NÃO PROVADO AQUI — dívida declarada, não verde ═════"
echo "  M-H7 · asserção H2 (520 exibidos == 520 registrados): mutação = trocar"
echo "         a porção dentro de macrosDaPorcao. Aritmética, roda no harness"
echo "         em DEBUG — exige build."
echo "  M-H8 · asserção H1 (nenhum texto do mock no caminho de IA): mutação ="
echo "         pôr 'adicione foto' num dos textos padrão. Mesma condição."
echo "  SEM XCUITEST: nada aqui prova o que o olho vê NA TELA. O H2 prova que o"
echo "  número que a View calcula e o número que o AppModel grava são iguais —"
echo "  não que a View desenhou aquele número. Cegueira conhecida e declarada."

[ ${#furos[@]} -eq 0 ] || exit 1
