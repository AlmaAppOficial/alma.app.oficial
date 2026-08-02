#!/bin/bash
# Verificação de ponta a ponta do healthContext na Cloud Function `chat`.
# Cria um usuário anônimo real, envia a MESMA pergunta duas vezes:
#   A) com healthContext  → a Alma deve considerar os dados
#   B) sem healthContext  → nada de saúde chega ao modelo
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

API_KEY=$(/usr/libexec/PlistBuddy -c 'Print :API_KEY' Shared/GoogleService-Info.plist)
URL="https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat"

TOKEN=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$API_KEY" \
  -H 'Content-Type: application/json' -d '{"returnSecureToken":true}' \
  | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["idToken"])')

PERGUNTA="Oi Alma. Como voce me ve hoje?"
CONTEXTO="[Contexto de hoje — 02/08, 10:40]
Movimento: 11.240 passos · 45 min de exercicio
Sono: 4h30 na noite passada
Meditacao: ainda nao meditou hoje · sequencia de 6 dias"

echo "════════ A) COM healthContext ════════"
/usr/bin/python3 - "$TOKEN" "$URL" "$PERGUNTA" "$CONTEXTO" <<'PY'
import json, sys, urllib.request
token, url, msg, ctx = sys.argv[1:5]
body = json.dumps({"message": msg, "healthContext": ctx}).encode()
req = urllib.request.Request(url, data=body, method="POST")
req.add_header("Authorization", "Bearer " + token)
req.add_header("Content-Type", "application/json")
with urllib.request.urlopen(req) as r:
    print("HTTP", r.status)
    print(json.loads(r.read())["reply"])
PY

sleep 3
echo
echo "════════ B) SEM healthContext ════════"
/usr/bin/python3 - "$TOKEN" "$URL" "$PERGUNTA" <<'PY'
import json, sys, urllib.request
token, url, msg = sys.argv[1:4]
body = json.dumps({"message": msg}).encode()
req = urllib.request.Request(url, data=body, method="POST")
req.add_header("Authorization", "Bearer " + token)
req.add_header("Content-Type", "application/json")
with urllib.request.urlopen(req) as r:
    print("HTTP", r.status)
    print(json.loads(r.read())["reply"])
PY

echo
echo "UID de teste (para conferir no Firestore que o contexto NAO foi gravado):"
/usr/bin/python3 -c "
import base64, json, sys
p = '$TOKEN'.split('.')[1]
p += '=' * (-len(p) % 4)
print(json.loads(base64.urlsafe_b64decode(p))['user_id'])
"
