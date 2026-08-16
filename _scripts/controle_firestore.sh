#!/bin/bash
# [2026-08-14] CONTROLE POSITIVO do levantamento do Firestore.
#
# O levantamento devolveu "0 documentos em users/*/profile". Um zero é
# exatamente o tipo de resultado que não se pode aceitar sem controle: se a
# consulta estivesse malformada, sem permissão ou apontando para o projeto
# errado, ela devolveria zero do mesmo jeito — e eu reportaria "nada foi para o
# servidor" tendo medido o nada.
#
# É o modo de falha do `strings` no `.apk` comprimido, e o do BUILD SUCCEEDED
# com zero arquivos compilados. A regra do projeto: **ausência só é conclusiva
# quando o método prova que sabe encontrar presença.**
#
# Este script consulta coleções que SABIDAMENTE têm documentos. Se elas também
# vierem 0, o levantamento é descartado.

set -u
PROJETO=$(gcloud config get-value project 2>/dev/null)
TOKEN=$(gcloud auth print-access-token 2>/dev/null)
[ -z "${TOKEN:-}" ] && { echo "SEM CREDENCIAL"; exit 3; }
URL="https://firestore.googleapis.com/v1/projects/$PROJETO/databases/(default)/documents:runQuery"

consultar() {   # $1 = collectionId
    curl -s -X POST "$URL" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"structuredQuery\":{\"from\":[{\"collectionId\":\"$1\",\"allDescendants\":true}],\"limit\":50}}"
}

echo "projeto: $PROJETO"
echo
for c in users entitlements moods profile chat feed admins colecaoQueNaoExisteNunca; do
    R=$(consultar "$c")
    if echo "$R" | grep -q '"error"'; then
        MSG=$(echo "$R" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d[0]["error"]["message"] if isinstance(d,list) else d.get("error",{}).get("message",""))' 2>/dev/null)
        printf "  %-26s ERRO: %s\n" "$c" "${MSG:0:60}"
    else
        N=$(echo "$R" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(sum(1 for x in d if isinstance(x,dict) and "document" in x))' 2>/dev/null)
        printf "  %-26s %s documento(s)\n" "$c" "${N:-?}"
    fi
done

echo
echo "LEITURA:"
echo "  • 'users' ou 'entitlements' com N>0  → o método FUNCIONA e o 0 de 'profile' é real."
echo "  • tudo 0, inclusive as conhecidas    → MÉTODO CEGO, descartar o levantamento."
echo "  • 'colecaoQueNaoExisteNunca' com N>0 → a consulta não discrimina, descartar."
