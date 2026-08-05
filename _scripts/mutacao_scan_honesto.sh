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
mutar "M-H1" "Shared/Corpo/FoodScanView.swift" \
  's|model.addFood(r.comoFoodItem, grams: r.porcaoG, to: mealType)|model.addFood(r.comoFoodItem, grams: 100, to: mealType)|' \
  "$LINT" "O BUG ORIGINAL: volta grams: 100 fixo, ignorando a porção da IA"

mutar "M-H2" "Shared/Corpo/FoodScanView.swift" \
  's|macroTile("\\(r.macrosDaPorcao.kcal)", "kcal", Theme.coral)|macroTile("\\(r.kcalPer100)", "kcal", Theme.coral)|' \
  "$LINT" "os tiles voltam a mostrar por 100 g debaixo da frase da porção"

mutar "M-H3" "Shared/Corpo/Models.swift" \
  's|^    static func escalarPor100(_ valorPor100: Int, gramas: Int) -> Int {|    static func MUTANTE(_ valorPor100: Int, gramas: Int) -> Int {|' \
  "$LINT" "a fonte única da escala some e cada ponta faz a própria conta"

# ── (a) vazamento de texto ─────────────────────────────────────────────────
mutar "M-H4" "Shared/Corpo/AnaliseDeFotoService.swift" \
  's|guard let somatotipo = r.somatotipo.flatMap(Somatotype.init(rawValue:)),|guard let somatotipo = Optional(Somatotype(rawValue: r.somatotipo ?? "") ?? base.analysis.somatotype),|' \
  "$LINT" "volta o fallback do mock para o somatotipo"

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
