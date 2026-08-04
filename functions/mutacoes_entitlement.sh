#!/bin/bash
# Teste de mutacao da maquina de estados do entitlement.
# Para cada mutacao: apaga/altera uma linha de producao, compila, roda as
# assercoes, e exige que ELAS FIQUEM VERMELHAS. Restaura sempre.
cd ~/Desktop/ALMA/alma.app.oficial-main/functions || exit 1
ALVO=src/entitlementState.ts
BACKUP=/tmp/entitlementState.original.ts
cp "$ALVO" "$BACKUP"

rodar() {
  npm run build > /tmp/mut_ts_build.log 2>&1
  if ! grep -q . /dev/null; then :; fi
  node testes_entitlement.mjs > /tmp/mut_ts_run.log 2>&1
  echo $?
}

testar_mutacao() {
  local nome="$1" ; shift
  cp "$BACKUP" "$ALVO"
  python3 - "$ALVO" "$@" <<'PY'
import sys, re
caminho, antigo, novo = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(caminho, encoding='utf-8').read()
if antigo not in t:
    print("PADRAO-NAO-ENCONTRADO"); sys.exit(3)
open(caminho, 'w', encoding='utf-8').write(t.replace(antigo, novo, 1))
PY
  local code
  code=$(rodar)
  echo "── MUTACAO: $nome"
  if [ "$code" = "0" ]; then
    echo "   ✗✗ ASSERCOES CEGAS — passaram sem a linha de producao"
    grep -c '✓' /tmp/mut_ts_run.log | sed 's/^/   aprovados: /'
  else
    echo "   ✓ assercoes acusaram (exit=$code)"
    grep '✗' /tmp/mut_ts_run.log | grep -v REPROVADOS | head -6 | sed 's/^/   /'
  fi
  cp "$BACKUP" "$ALVO"
}

echo "═══ BATERIA DE MUTACOES — entitlementState ═══"
echo

testar_mutacao "corte imediato em REFUND/REVOKE" \
  "if (evento.tipo === 'REFUND' || evento.tipo === 'REVOKE') {" \
  "if (false) {"

testar_mutacao "EXPIRED / GRACE_PERIOD_EXPIRED" \
  "if (evento.tipo === 'EXPIRED' || evento.tipo === 'GRACE_PERIOD_EXPIRED') {" \
  "if (false) {"

testar_mutacao "tolerancia vencida ainda vale (troca > por <)" \
  "tolerancia && tolerancia > agoraMs" \
  "tolerancia && tolerancia < agoraMs"

testar_mutacao "expiresDate no passado passa a valer" \
  "if (expira <= agoraMs) {" \
  "if (false) {"

testar_mutacao "sem expiresDate concede acesso" \
  "if (!expira) {" \
  "if (false) {"

# Restaura e confirma verde
cp "$BACKUP" "$ALVO"
npm run build > /dev/null 2>&1
echo
echo "═══ RESTAURADO ═══"
node testes_entitlement.mjs | tail -3
echo "FIM_MUTACOES"
