#!/bin/bash
# Prova a promessa de privacidade: o healthContext NÃO é gravado no Firestore.
# Cria um usuário, manda uma mensagem COM contexto, e lê de volta
# users/{uid}/messages via REST com o token do próprio usuário.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

API_KEY=$(/usr/libexec/PlistBuddy -c 'Print :API_KEY' Shared/GoogleService-Info.plist)
RESP=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$API_KEY" \
  -H 'Content-Type: application/json' -d '{"returnSecureToken":true}')
TOKEN=$(echo "$RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["idToken"])')
UID_=$(echo "$RESP" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["localId"])')

echo "uid de teste: $UID_"

/usr/bin/python3 - "$TOKEN" <<'PY'
import json, sys, urllib.request, time
token = sys.argv[1]
ctx = ("[Contexto de hoje — 02/08, 11:00]\n"
       "Movimento: 11.240 passos · 45 min de exercicio\n"
       "Sono: 4h30 na noite passada\n"
       "Meditacao: ainda nao meditou hoje · sequencia de 6 dias")
body = json.dumps({"message": "Teste de privacidade do contexto.", "healthContext": ctx}).encode()
req = urllib.request.Request("https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat",
                             data=body, method="POST")
req.add_header("Authorization", "Bearer " + token)
req.add_header("Content-Type", "application/json")
with urllib.request.urlopen(req) as r:
    print("envio:", r.status)
PY

sleep 5
echo "── conteúdo gravado em users/{uid}/messages ──"
curl -s "https://firestore.googleapis.com/v1/projects/alma-app-7dae6/databases/(default)/documents/users/$UID_/messages" \
  -H "Authorization: Bearer $TOKEN" \
| /usr/bin/python3 -c "
import sys, json
d = json.load(sys.stdin)
docs = d.get('documents', [])
if not docs:
    print('nenhum documento (verificar regras)')
for doc in docs:
    f = doc['fields']
    role = f.get('role', {}).get('stringValue', '?')
    content = f.get('content', {}).get('stringValue', '')
    print(f'  [{role}] {content[:110]}')
    print(f'      campos gravados: {sorted(f.keys())}')
print()
raw = json.dumps(d)
for termo in ['Contexto de hoje', 'passos', 'Sono', '4h30', 'healthContext', 'Movimento']:
    print(f'  contém \"{termo}\"? -> {termo in raw}')
"
