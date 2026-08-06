#!/usr/bin/env bash
# Prova que o chat RESPONDE — pelo caminho real, com token real.
#
# "Deploy complete!" não prova nada sobre o chat funcionar. Esta prova manda uma
# mensagem de verdade para a função em produção, com um ID token do Firebase
# Auth, e exige que volte texto. É o mesmo caminho que o app percorre: mesmo
# endpoint, mesmo cabeçalho, mesmo corpo.
#
#   ./prova_chat.sh antes   # baseline, ANTES do deploy
#   ./prova_chat.sh depois  # verificação, DEPOIS do deploy
#
# Cria um usuário descartável, usa, e APAGA no fim — inclusive se falhar (trap).
set -uo pipefail

MOMENTO="${1:-agora}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAIDA="$RAIZ/_validacao_20260806/prova_chat_${MOMENTO}.txt"
URL="https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat"

API_KEY=$(/usr/libexec/PlistBuddy -c "Print :API_KEY" "$RAIZ/Shared/GoogleService-Info.plist")
EMAIL="prova-chat-$(date +%s)@alma-teste.invalid"
SENHA="Prova!$(date +%s)aA"

ID_TOKEN=""
apagar_usuario() {
  if [ -n "$ID_TOKEN" ]; then
    curl -s -X POST \
      "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${API_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{\"idToken\":\"${ID_TOKEN}\"}" > /dev/null
    echo "usuário de teste apagado" | tee -a "$SAIDA"
  fi
}
trap apagar_usuario EXIT

{
  echo "═══ PROVA DO CHAT (${MOMENTO}) — $(date -u +%Y-%m-%dT%H:%M:%SZ) ═══"
  echo "endpoint: $URL"
} > "$SAIDA"

# ── 1. token real do Firebase Auth ──────────────────────────────────────────
RESP=$(curl -s -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${SENHA}\",\"returnSecureToken\":true}")
ID_TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('idToken',''))" 2>/dev/null)

if [ -z "$ID_TOKEN" ]; then
  echo "✗ não consegui um ID token: $RESP" | tee -a "$SAIDA"
  exit 2
fi
echo "✓ ID token obtido (usuário descartável)" | tee -a "$SAIDA"

# ── 2. a mensagem, pelo caminho real ────────────────────────────────────────
PERGUNTA="Oi Alma, responda so com a palavra FUNCIONANDO, por favor."
CORPO=$(python3 -c "import json,sys; print(json.dumps({'message': sys.argv[1]}))" "$PERGUNTA")

HTTP=$(curl -s -o /tmp/prova_chat_body.json -w "%{http_code}" -X POST "$URL" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
  -H 'Content-Type: application/json' \
  --max-time 70 \
  -d "$CORPO")

RESPOSTA=$(python3 -c "
import json
try:
    d = json.load(open('/tmp/prova_chat_body.json'))
    print(d.get('reply') or d.get('message') or d.get('response') or d.get('error') or json.dumps(d)[:400])
except Exception as e:
    print('(corpo ilegível: %s)' % e)
")

{
  echo "HTTP: $HTTP"
  echo "pergunta: $PERGUNTA"
  echo "resposta: $RESPOSTA"
} | tee -a "$SAIDA"

# ── 3. veredicto ────────────────────────────────────────────────────────────
# 200 sozinho não basta: um 200 com corpo vazio seria "verde" e mudo. Exigimos
# texto de verdade — a Alma tem de ter respondido alguma coisa.
if [ "$HTTP" = "200" ] && [ "${#RESPOSTA}" -ge 3 ]; then
  echo "✓ CHAT RESPONDE — HTTP 200 com ${#RESPOSTA} caracteres de resposta" | tee -a "$SAIDA"
  exit 0
fi
echo "✗✗ CHAT NÃO RESPONDEU COMO ESPERADO (HTTP $HTTP)" | tee -a "$SAIDA"
exit 1
