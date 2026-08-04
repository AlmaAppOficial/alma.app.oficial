#!/bin/bash
# Deploy da função chat — COM compilação obrigatória.
#
# [2026-08-04] O primeiro deploy de hoje "funcionou" e não implantou nada: o
# firebase.json não tinha hook `predeploy`, então o CLI empacotou o
# `functions/lib/index.js` COMPILADO ANTIGO. O log dizia "Successful update
# operation" e a função em produção continuou com o código velho — a
# verificação (b) falhou por isso, não por bug de lógica.
#
# É a mesma família de erro do resto desta sessão: uma etapa que declara
# sucesso sem ter feito o trabalho. Agora o build é explícito e verificado
# ANTES do deploy: se o marcador não estiver no JS compilado, não sobe.
set -e
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/functions

echo "───── compilando ─────"
npx tsc -p tsconfig.json

echo "───── conferindo o JS compilado ─────"
for marcador in "entitlements" "rajadaMax" "ehAssinante"; do
  n=$(grep -c "$marcador" lib/index.js || true)
  echo "  $marcador: $n ocorrência(s)"
  [ "$n" -eq 0 ] && { echo "✗ ABORTADO: '$marcador' não está no JS compilado"; exit 1; }
done

echo "───── deploy ─────"
cd ..
npx firebase deploy --only functions:chat --project alma-app-7dae6 --non-interactive
