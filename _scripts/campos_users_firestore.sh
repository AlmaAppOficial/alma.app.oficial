#!/bin/bash
# [2026-08-14] Quais campos existem nos documentos `users/{uid}`?
#
# O levantamento de `users/*/profile` deu 0 com controle positivo válido. Falta
# a outra metade da pergunta do Assis — *"confira o que já foi para o
# servidor"*: o sync escrevia numa SUBcoleção, mas nada garante que uma versão
# anterior do app, ou o iOS, não tenha gravado gênero direto no documento do
# usuário. Ausência só é conclusiva por enumeração.
#
# SOMENTE LEITURA. Não imprime UID nem valor que identifique alguém — só nomes
# de campo e contagens.

set -u
PROJETO=$(gcloud config get-value project 2>/dev/null)
TOKEN=$(gcloud auth print-access-token 2>/dev/null)
[ -z "${TOKEN:-}" ] && { echo "SEM CREDENCIAL"; exit 3; }

curl -s -X POST \
  "https://firestore.googleapis.com/v1/projects/$PROJETO/databases/(default)/documents:runQuery" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"structuredQuery":{"from":[{"collectionId":"users","allDescendants":false}],"limit":500}}' \
  > /tmp/users_dump.json 2>/dev/null

python3 - <<'PY'
import json
from collections import Counter
d = json.load(open('/tmp/users_dump.json'))
if isinstance(d, dict) and 'error' in d:
    print("ERRO:", d['error'].get('message')); raise SystemExit(4)
docs = [x['document'] for x in d if isinstance(x, dict) and 'document' in x]
print(f"documentos em users/: {len(docs)}")
if not docs:
    print("MÉTODO SUSPEITO — a consulta anterior achou 15. Descartar."); raise SystemExit(5)

campos = Counter()
for doc in docs:
    campos.update(doc.get('fields', {}).keys())

print("\ncampos (nome: em quantos documentos):")
for k, v in campos.most_common():
    print(f"    {k}: {v}")

sensiveis = [k for k in campos if any(t in k.lower() for t in
             ('gender', 'genero', 'sex', 'ciclo', 'cycle', 'pregnan', 'gravid', 'humor', 'mood'))]
print("\nCAMPOS SENSÍVEIS ENCONTRADOS:", sensiveis if sensiveis else "NENHUM")
print("\nCONTROLE POSITIVO — campos conhecidos que TÊM de aparecer:")
for esperado in ('legacyCorpoEntitlement', 'email', 'createdAt', 'isAdmin'):
    print(f"    {esperado}: {campos.get(esperado, 0)}")
print("  (se TODOS derem 0, a leitura de campos está cega e o resultado não vale)")
PY
