#!/bin/bash
# TESTE DE MUTAÇÃO — a regra nova do projeto.
#
# [2026-08-04] Uma prova só conta se ficar VERMELHA quando a linha de produção
# que ela protege é apagada. A reauditoria aplicou 4 mutações e o harness
# continuou 40/40; este script reproduz aquele experimento e o amplia, e passa
# a ser o portão de entrada de qualquer assertion nova.
#
# Para cada mutação: aplica → roda a verificação → restaura → reporta.
# ESPERADO = VERMELHO. Uma mutação que passa VERDE é uma prova inútil.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

LINT="python3 _scripts/lint_wiring.py ."
verde=0; vermelho=0; furos=()

restaurar() { git checkout HEAD -- "$1" 2>/dev/null; }

# $1 = id · $2 = arquivo · $3 = sed expr · $4 = verificação · $5 = descrição
mutar() {
  local id="$1" arq="$2" expr="$3" verif="$4" desc="$5"
  cp "$arq" "/tmp/mut_backup_$$"
  sed -i '' "$expr" "$arq"

  if ! diff -q "/tmp/mut_backup_$$" "$arq" > /dev/null; then
    if eval "$verif" > /tmp/mut_out_$$ 2>&1; then
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

  cp "/tmp/mut_backup_$$" "$arq"; rm -f "/tmp/mut_backup_$$" /tmp/mut_out_$$
}

echo "═════ TESTE DE MUTAÇÃO — lint de wiring ═════"
echo "(as 4 mutações da reauditoria + 4 novas)"
echo

mutar "M1" "Shared/AccountDeletionService.swift" \
  's|^        LocalDataCleanupService.clearAll()$|        // MUTANTE|' \
  "$LINT" "exclusão de conta deixa de apagar dados locais (LGPD)"

mutar "M2" "Shared/Corpo/CorpoHomeView.swift" \
  's|^                    model.addWater(250)$|                    if model.hasPremiumAccess {\n                        model.addWater(250)\n                    }|' \
  "$LINT" "gate de premium reintroduzido no botão de água"

mutar "M3" "Shared/Corpo/WorkoutSessionView.swift" \
  's|^        model.registrarTreinoConcluido()$|        // MUTANTE|' \
  "$LINT" "concluir treino deixa de gravar o dia"

mutar "M4" "Shared/Corpo/Models.swift" \
  's|didSet { store.set(waterMl, forKey: "waterMl") }|didSet { }|' \
  "$LINT" "água nunca chega ao disco"

mutar "M5" "Shared/AlmaApp.swift" \
  's|^                .task { LocalDataCleanupService.retomarLimpezaPendenteSeNecessario() }$|                // MUTANTE|' \
  "$LINT" "limpeza interrompida não é retomada no boot (D-1)"

mutar "M6" "Shared/LocalDataCleanupService.swift" \
  's|^        UserProfileStore.resetar()$|        // MUTANTE|' \
  "$LINT" "perfil em memória não é zerado (D-2)"

mutar "M7" "Shared/AccountDeletionService.swift" \
  's|^        Self.executarLimpezaLocal()$|        // MUTANTE|' \
  "$LINT" "requestDeletion deixa de chamar a limpeza"

mutar "M8" "Shared/AlmaApp.swift" \
  's|^        guard !LocalDataCleanupService.temLimpezaPendente else { return }$|        // MUTANTE|' \
  "$LINT" "token FCM recria users/{uid} durante a exclusão (D-5)"

echo
echo "═════ RESULTADO ═════"
echo "mutações que ficaram vermelhas (prova válida): $vermelho"
echo "mutações que passaram batidas (prova inútil):  $verde"
for f in "${furos[@]:-}"; do [ -n "$f" ] && echo "   ✗ $f"; done
echo
echo "───── working tree depois da restauração ─────"
git status --short -- Shared/ | head
[ "$verde" -eq 0 ] && echo "OK: nenhuma prova inútil" || echo "ATENÇÃO: há prova inútil"
