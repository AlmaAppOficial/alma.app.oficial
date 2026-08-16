#!/bin/bash
# [2026-08-14] LEVANTAMENTO SOMENTE-LEITURA de `users/{uid}/profile/data`.
#
# Pedido do Assis ao mandar cortar o envio do sexo para o Firestore:
# *"confira o que já foi para o servidor e me diga"*.
#
# ⚠️ NÃO APAGA NADA. Nem um documento, nem um campo. Apagar histórico é decisão
# dele, e este script existe para que a decisão seja tomada com número na mão.
#
# Estratégia: `gcloud firestore` não lista subcoleções por caminho parcial sem
# um índice de collection group, então a via honesta é a API REST com
# `runQuery` de COLLECTION GROUP sobre `profile` — que enxerga todos os
# `users/*/profile` de uma vez.

set -u
PROJETO=$(gcloud config get-value project 2>/dev/null)
echo "projeto: ${PROJETO:-<nenhum>}"
TOKEN=$(gcloud auth print-access-token 2>/dev/null)
if [ -z "${TOKEN:-}" ]; then
    echo "SEM CREDENCIAL — rode 'gcloud auth login' e repita."
    echo "NADA foi consultado. Não presuma nada a partir desta saída."
    exit 3
fi

URL="https://firestore.googleapis.com/v1/projects/$PROJETO/databases/(default)/documents:runQuery"

echo
echo "── contando documentos em collection group 'profile' ──"
RESP=$(curl -s -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"structuredQuery":{"from":[{"collectionId":"profile","allDescendants":true}],"limit":1000}}')

echo "$RESP" > /tmp/profile_dump.json
echo "resposta salva em /tmp/profile_dump.json ($(wc -c < /tmp/profile_dump.json) bytes)"

if echo "$RESP" | grep -q '"error"'; then
    echo "ERRO da API:"
    echo "$RESP" | head -20
    exit 4
fi

python3 - <<'PY'
import json
try:
    dados = json.load(open('/tmp/profile_dump.json'))
except Exception as e:
    print("não deu para ler a resposta:", e); raise SystemExit(4)

docs = [d['document'] for d in dados if isinstance(d, dict) and 'document' in d]
print(f"documentos em users/*/profile : {len(docs)}")

com_genero, com_sexo, so_nascimento, campos = 0, 0, 0, {}
for d in docs:
    f = d.get('fields', {})
    for k in f: campos[k] = campos.get(k, 0) + 1
    if 'gender' in f: com_genero += 1
    if 'biologicalSex' in f or 'sexoBiologico' in f: com_sexo += 1
    if 'gender' not in f and 'birthDate' in f: so_nascimento += 1

print(f"  com campo 'gender'          : {com_genero}   <- é o histórico a decidir")
print(f"  com campo de sexo biológico : {com_sexo}   <- tem de ser 0 (nunca sincronizou)")
print(f"  só com nascimento           : {so_nascimento}")
print("\ncampos encontrados (nome: quantos documentos):")
for k, v in sorted(campos.items(), key=lambda x: -x[1]):
    print(f"    {k}: {v}")

if com_genero:
    print("\nDistribuição dos valores de 'gender' (sem identificar ninguém):")
    from collections import Counter
    c = Counter(d.get('fields', {}).get('gender', {}).get('stringValue', '?')
                for d in docs if 'gender' in d.get('fields', {}))
    for valor, n in c.most_common():
        print(f"    {valor}: {n}")
PY
