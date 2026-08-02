#!/bin/bash
# Deploy da Cloud Function `chat` do Alma (autorizado pelo Assis).
# Uso: ./deploy_chat_fn.sh
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

./functions/node_modules/.bin/tsc -p functions/tsconfig.json
echo "TSC_EXIT:$?"

firebase deploy --only functions:chat --project alma-app-7dae6 --non-interactive \
  > /tmp/alma_deploy_health.log 2>&1
echo "DEPLOY_EXIT:$?"
tail -4 /tmp/alma_deploy_health.log
