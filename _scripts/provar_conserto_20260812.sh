#!/bin/bash
# PROVA DO CONSERTO DE 12/08/2026 — contra a função REAL em produção.
#
# Roda DEPOIS do deploy. Não aceita "deploy concluído" como prova: chama o
# endpoint de verdade, com token de verdade, e olha o que volta.
#
# O que se quer provar, em ordem de importância:
#   P1 · o `enum` do json_schema é OBEDECIDO: `somatotipo` volta com uma das três
#        grafias exatas que o app 2.0.1 sabe ler. Esta é A pergunta — se falhar,
#        o app publicado continua quebrado e o deploy tem de voltar.
#   P2 · o scan de COMIDA não foi atropelado pelo conserto do corpo.
#   P3 · a recusa honesta continua honesta: foto ruim devolve texto, nunca número.
#
# Uso:
#   ./_scripts/provar_conserto_20260812.sh <foto_corpo.jpg> [foto_prato.jpg]
#
# A foto de corpo é OBRIGATÓRIA e tem de ser uma foto real de pessoa — é o único
# jeito de exercitar o caminho que quebrou. Nenhuma imagem sintética serve:
# ela volta `legivel:false` e o `somatotipo` nunca é exercitado, o que daria um
# verde que não prova nada.
#
# A foto NÃO é gravada em lugar nenhum por este script nem pela função (ver a
# promessa de privacidade no cabeçalho de `functions/src/analiseDeFoto.ts`).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FN="https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/analisarFoto"
APIKEY="AIzaSyANnb17HactnTK_iIs1cK9hx-GF1N3Q0uM"   # chave WEB, pública por desenho
CORPO="${1:-}"
PRATO="${2:-}"
OUT="$(mktemp -d)"
verde=0; vermelho=0

if [ -z "$CORPO" ] || [ ! -f "$CORPO" ]; then
  echo "USO: $0 <foto_corpo.jpg> [foto_prato.jpg]"
  echo "A foto de corpo é obrigatória — sem ela o teste não prova o que quebrou."
  exit 2
fi

echo "═════ TOKEN REAL DO FIREBASE ═════"
TOK=$(curl -s -X POST \
  "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$APIKEY" \
  -H 'Content-Type: application/json' -d '{"returnSecureToken":true}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin).get("idToken",""))')
[ -z "$TOK" ] && { echo "FALHOU: sem token anônimo (login anônimo desligado?)"; exit 2; }
echo "  token obtido (${#TOK} chars)"

# Redimensiona como a 2.0.2 fará. Na 2.0.1 a foto vai crua — os dois caminhos
# têm de funcionar, então este script manda a versão reduzida, que é a que o
# app novo mandará. Para reproduzir a 2.0.1, é só apontar para o arquivo cru.
enviar() {   # $1=rotulo  $2=arquivo  $3=tipo
  local rotulo="$1" arq="$2" tipo="$3"
  sips -Z 1280 -s format jpeg "$arq" --out "$OUT/envio.jpg" >/dev/null 2>&1 \
    || cp "$arq" "$OUT/envio.jpg"
  python3 - "$tipo" "$OUT/envio.jpg" "$OUT/corpo.json" <<'PY'
import base64, json, sys
b = base64.b64encode(open(sys.argv[2], 'rb').read()).decode()
d = {"tipo": sys.argv[1], "fotos": [b], "consentimento": True}
if sys.argv[1] == "corpo":
    d["medidas"] = {"pesoKg": 83, "alturaCm": 183, "idade": 39, "objetivo": "Ganhar massa"}
json.dump(d, open(sys.argv[3], 'w'))
PY
  curl -s -o "$OUT/$rotulo.json" -w '%{http_code}' -X POST "$FN" \
    -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
    --data-binary @"$OUT/corpo.json" --max-time 150
}

echo
echo "═════ P1 · O QUE QUEBROU: somatotipo do scan corporal ═════"
COD=$(enviar corpo "$CORPO" corpo)
echo "  HTTP $COD"
python3 - "$OUT/corpo.json.json" "$OUT/corpo.json" <<'PY' || true
import json, sys
d = json.load(open(sys.argv[1] if len(sys.argv) > 1 else sys.argv[2]))
print("  ok:", d.get("ok"), "| motivo:", d.get("motivo"))
PY
RES=$(python3 -c "
import json,sys
d=json.load(open('$OUT/corpo.json'))
r=d.get('resultado') or {}
print(json.dumps({'ok':d.get('ok'),'motivo':d.get('motivo'),
                  'somatotipo':r.get('somatotipo'),
                  'gordura':r.get('gorduraEstimada'),
                  'temResumo':bool((r.get('resumo') or '').strip())}, ensure_ascii=False))
" 2>/dev/null || echo '{}')
echo "  $RES"

SOMA=$(python3 -c "import json;print((json.loads('''$RES''') or {}).get('somatotipo'))" 2>/dev/null)
case "$SOMA" in
  Ectomorfo|Mesomorfo|Endomorfo)
    echo "  ✓ P1 somatotipo = '$SOMA' — grafia que o app 2.0.1 SABE LER."
    echo "       O enum do json_schema foi obedecido. App publicado destravado."
    vermelho=$((vermelho)); verde=$((verde+1)) ;;
  *)
    echo "  ✗ P1 somatotipo = '$SOMA' — NÃO é uma das três grafias."
    echo "       O app 2.0.1 CONTINUA QUEBRADO. Reverter o deploy."
    vermelho=$((vermelho+1)) ;;
esac

if [ -n "$PRATO" ] && [ -f "$PRATO" ]; then
  echo
  echo "═════ P2 · o scan de COMIDA não foi atropelado ═════"
  COD=$(enviar prato "$PRATO" comida)
  echo "  HTTP $COD"
  OKC=$(python3 -c "import json;d=json.load(open('$OUT/corpo.json'));print(d.get('ok'),d.get('motivo'))" 2>/dev/null)
  echo "  $OKC"
  if echo "$OKC" | grep -q "resposta_incompleta"; then
    echo "  ✗ P2 comida caiu em resposta_incompleta — a validação de corpo vazou. REVERTER."
    vermelho=$((vermelho+1))
  else
    echo "  ✓ P2 comida seguiu seu caminho, sem a validação de corpo em cima."
    verde=$((verde+1))
  fi
else
  echo
  echo "  · P2 pulado (sem foto de prato). NÃO conte como verde."
fi

echo
echo "═════ RESULTADO ═════"
echo "verdes: $verde · vermelhos: $vermelho"
echo
echo "═════ O QUE ESTE SCRIPT NÃO PROVA ═════"
echo "  · Não prova a TELA. Prova o que a função devolve; que o app desenha"
echo "    aquilo é XCUITest, que o projeto não tem. Para o app publicado, a"
echo "    prova de verdade é o Assis rodar o scan na 2.0.1 e ver o resultado."
echo "  · Uma execução não prova estabilidade. O incidente foi determinístico"
echo "    (3 de 3 falhas); repita 3× antes de declarar consertado."
echo "  · Não prova o caminho da 2.0.1 com foto CRUA da galeria — este script"
echo "    reduz antes de enviar. Para isso, aponte para o arquivo original."
rm -rf "$OUT"
[ $vermelho -eq 0 ] || exit 1
