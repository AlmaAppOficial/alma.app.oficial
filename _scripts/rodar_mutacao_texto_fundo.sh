#!/bin/bash
# Dispara `mutacao_texto.sh` em segundo plano.
#
# Existe pelo mesmo motivo do `build202_fundo.sh`: a mutação do servidor roda
# `npm run build` seis vezes e passa do tempo que a sessão de agente aguenta
# numa chamada só. Em primeiro plano, a chamada morre e o script fica órfão no
# meio de uma mutação — ou seja, com o código de produção MUTADO no disco.
# O `trap restaurar EXIT` de lá cobre o caso, mas não depender disso é melhor.
#
# Uso:  ./_scripts/rodar_mutacao_texto_fundo.sh
#       tail -f /tmp/mut_texto.log
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 1
rm -f /tmp/mut_texto.log
nohup ./_scripts/mutacao_texto.sh > /tmp/mut_texto.log 2>&1 &
echo "pid=$!  log=/tmp/mut_texto.log"
