#!/bin/bash
# TESTE DE MUTAÇÃO — a porção deixa de ser um decreto (2026-08-06)
#
# Cobre os dois bugs desta leva, ambos da mesma família (número errado indo
# para o diário):
#   (a) a porção estimada pela IA não podia ser corrigida antes de registrar;
#   (b) o CustomFoodForm gravava valor POR PORÇÃO no campo POR 100 G.
#
# Contrato de sempre: aplica → verifica → restaura. ESPERADO = VERMELHO.
#
# ESTE SCRIPT EXERCITA O LINT ESTÁTICO. As asserções E0..E4b rodam no harness
# em DEBUG e provam a ARITMÉTICA (936 kcal exibidos == 936 kcal registrados);
# as mutações delas exigem build e estão listadas ao final como dívida, não
# como verde.
#
# [2026-08-06] Duas diferenças em relação ao mutacao_scan_honesto.sh, de
# propósito: a raiz é derivada da posição do script (em vez de caminho absoluto
# do Mac) e o `sed -i` detecta BSD vs GNU. Assim o script roda igual no Mac do
# Felipe e num ambiente Linux — foi num Linux que ele rodou pela primeira vez.
set -u

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

LINT="python3 _scripts/lint_wiring.py ."
verde=0; vermelho=0; furos=()

# BSD (macOS) exige sufixo depois do -i; GNU não aceita o sufixo vazio.
if sed --version >/dev/null 2>&1; then SEDI=(sed -i); else SEDI=(sed -i ''); fi

mutar() {
  local id="$1" arq="$2" expr="$3" verif="$4" desc="$5"
  cp "$arq" "/tmp/mutp_backup_$$"
  "${SEDI[@]}" "$expr" "$arq"

  if ! diff -q "/tmp/mutp_backup_$$" "$arq" > /dev/null; then
    if eval "$verif" > /tmp/mutp_out_$$ 2>&1; then
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

  cp "/tmp/mutp_backup_$$" "$arq"; rm -f "/tmp/mutp_backup_$$" /tmp/mutp_out_$$
}

echo "═════ MUTAÇÃO — porção editável e unidade do alimento personalizado ═════"
echo

if ! $LINT > /tmp/mutp_base_$$ 2>&1; then
  echo "ABORTADO: o lint já está vermelho ANTES das mutações."
  cat /tmp/mutp_base_$$; rm -f /tmp/mutp_base_$$
  exit 2
fi
echo "  base: lint verde antes de mutar ✓"
rm -f /tmp/mutp_base_$$
echo

# ── (a) porção editável ────────────────────────────────────────────────────
mutar "M-E1" "Shared/Corpo/FoodScanView.swift" \
  's|model.addFood(r.comoFoodItem, grams: gramas, to: mealType)|model.addFood(r.comoFoodItem, grams: r.porcaoG, to: mealType)|' \
  "$LINT" "O BUG QUE E1 PROCURA: grava a estimativa da IA e joga fora o ajuste"

mutar "M-E2" "Shared/Corpo/FoodScanView.swift" \
  's|        let gramas = porcaoEmUso(r)|        let gramas = r.porcaoG|' \
  "$LINT" "a fonte única da quantidade some; cada ponta volta a ler a sua"

mutar "M-E3" "Shared/Corpo/FoodScanView.swift" \
  's|Label(Self.rotuloDeConfirmacao(gramas: gramas, refeicao: mealType),|Label("Adicionar \\(gramas) g",|' \
  "$LINT" "o rótulo volta a ser string solta e E2 fica sem o que ler"

mutar "M-E4" "Shared/Corpo/FoodScanView.swift" \
  's|set: { novo in porcaoAjustada = max(piso, Int(novo.rounded())) }|set: { _ in }|' \
  "$LINT" "o Slider para de escrever no estado — a porção volta a ser decreto"

mutar "M-E5" "Shared/Corpo/FoodScanView.swift" \
  's|macroTile("\\(macros.kcal)", "kcal", Theme.coral)|macroTile("\\(r.kcalPer100)", "kcal", Theme.coral)|' \
  "$LINT" "os tiles voltam a mostrar por 100 g, ignorando a quantidade em uso"

# ── (b) unidade do alimento personalizado ──────────────────────────────────
mutar "M-E6" "Shared/Corpo/AddFoodView.swift" \
  's|kcalPer100:    Self.converterPara100g(Int(kcal) ?? 0,    gramasDaPorcao: gramas),|kcalPer100: Int(kcal) ?? 0,|' \
  "$LINT" "O BUG ORIGINAL: valor da porção copiado para o campo por-100-g"

# M-E7 nasceu de um furo achado na revisão de 06/08: o `proibe` do E-W5b exigia
# UM espaço depois de `kcalPer100:`, e o arquivo usa alinhamento por colunas.
# Uma reversão escrita no estilo alinhado passava batido pelo canário. Esta
# mutação é a reversão NO ESTILO DA CASA — se ela ficar verde, o canário voltou
# a ser cego do mesmo jeito.
mutar "M-E7" "Shared/Corpo/AddFoodView.swift" \
  's|kcalPer100:    Self.converterPara100g(Int(kcal) ?? 0,    gramasDaPorcao: gramas),|kcalPer100:    Int(kcal) ?? 0,|' \
  "$LINT" "a mesma reversão, mas alinhada por colunas — o furo que a revisão achou"

echo
echo "═════ RESULTADO ═════"
echo "vermelhas (boas): $vermelho · verdes (furos): $verde"
if [ ${#furos[@]} -gt 0 ]; then
  echo "FUROS:"
  for f in "${furos[@]}"; do echo "   ✗ $f"; done
fi

echo
echo "═════ NÃO PROVADO AQUI — dívida declarada, não verde ═════"
echo "  M-E7 · asserção E1 (936 exibidos == 936 registrados com a porção"
echo "         ajustada): mutação = passar porcaoCorrigida para uma das pontas"
echo "         e porcaoG para a outra. Aritmética, roda no harness em DEBUG —"
echo "         exige build."
echo "  M-E8 · asserção E0 (o canário do comparador): mutação = fazer"
echo "         confereComExibido devolver true sempre. Mesma condição."
echo "  M-E9 · asserção E4/E4b (conversão para 100 g): mutação = fazer"
echo "         converterPara100g devolver o valor sem converter. Mesma condição."
echo "  SEM XCUITEST: nada aqui prova o que o olho vê NA TELA, nem que arrastar"
echo "  o Slider redesenha os quatro números. E-W4 prova que o Slider escreve"
echo "  em porcaoAjustada e E-W2 prova que os tiles leem a mesma variável que o"
echo "  registro — o elo 'e o pixel mudou' continua sem prova. Cegueira"
echo "  conhecida e declarada, como em 05/08."

[ ${#furos[@]} -eq 0 ] || exit 1
