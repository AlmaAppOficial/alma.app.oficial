#!/bin/bash
# Destaca o tf_archive_99.sh em segundo plano.
#
# Existe porque a sessao que chama tem timeout curto (minutos) e o archive leva
# perto de uma hora. Mesmo motivo do `build_jejum_20260826.sh` e do
# `build_e_auditar_20260805.sh`: quem observa le o log e o arquivo de status,
# nao fica preso no processo.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

mkdir -p _prova_20260827
chmod +x _scripts/tf_archive_99.sh
rm -f /tmp/alma99.status /tmp/alma99_run.log

nohup bash _scripts/tf_archive_99.sh > /tmp/alma99_run.log 2>&1 < /dev/null &
echo "PID=$!"
echo "log:    /tmp/alma99_run.log"
echo "status: /tmp/alma99.status  (aparece so no fim)"
