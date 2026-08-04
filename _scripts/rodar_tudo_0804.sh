#!/bin/bash
# Encadeia as duas validações de 04/08 numa execução só.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
bash _scripts/validar_20260804.sh          > /tmp/validar_0804.log 2>&1
bash _scripts/conferencia_visual_abas.sh   > /tmp/abas_0804.log    2>&1
echo CONCLUIDO
