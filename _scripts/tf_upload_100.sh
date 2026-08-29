#!/bin/bash
# Retomada do tf_archive_100.sh a partir do passo 4 — o archive de /tmp/alma100.xcarchive
# ja existe, ja foi conferido (4 bundles em 2.0.4/100) e ja passou no portao de conteudo.
#
# TERMINA NO UPLOAD. Nao envia para revisao, nao promove faixa, nao toca a 2.0.3.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ARCH="/tmp/alma100.xcarchive"
SAIDA="/tmp/alma100_ipa"
PORTAO="$HOME/Desktop/alma/_validacao_20260829/portao_conteudo_100.py"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }
[ -d "$ARCH" ] || { echo "SEM ARCHIVE — parando"; exit 3; }

echo "=== 2bis. RECONFERIR versoes (o archive pode ter mudado desde a 1a rodada) ==="
bash _prova_20260826/conferir_versoes.sh "$ARCH" "2.0.4" "100" || { echo "NAO subo."; exit 5; }

echo ""
echo "=== 3bis. RECONFERIR portao de conteudo ==="
python3 "$PORTAO" --app "$ARCH/Products/Applications/Alma.App.Oficial.app"
PEXIT=$?
case "$PEXIT" in
  0) echo "    portao APROVOU." ;;
  2) echo "PARANDO: portao CEGO."; exit 6 ;;
  *) echo "PARANDO: portao REPROVOU."; exit 6 ;;
esac

echo ""
echo "=== 4. EXPORT ==="
rm -rf "$SAIDA"
xcodebuild -exportArchive \
  -archivePath "$ARCH" \
  -exportPath "$SAIDA" \
  -exportOptionsPlist _scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma100_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma100_export.log
grep -m5 "error:" /tmp/alma100_export.log
IPA=$(ls "$SAIDA"/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando"; tail -30 /tmp/alma100_export.log; exit 3; }
ls -lh "$IPA"

echo ""
echo "=== 4b. O IPA E ESTE ARCHIVE? (LC_UUID) ==="
rm -rf /tmp/alma100_conf && mkdir -p /tmp/alma100_conf && \
  (cd /tmp/alma100_conf && unzip -q "$IPA" "Payload/Alma.App.Oficial.app/Alma.App.Oficial")
U_ARCH=$(dwarfdump --uuid "$ARCH/Products/Applications/Alma.App.Oficial.app/Alma.App.Oficial" 2>/dev/null | awk '{print $2}' | head -1)
U_IPA=$(dwarfdump --uuid /tmp/alma100_conf/Payload/Alma.App.Oficial.app/Alma.App.Oficial 2>/dev/null | awk '{print $2}' | head -1)
echo "  archive: $U_ARCH"
echo "  ipa    : $U_IPA"
[ -n "$U_ARCH" ] && [ "$U_ARCH" = "$U_IPA" ] \
  && echo "  MESMO BINARIO — o portao julgou o que vai subir." \
  || { echo "  DIVERGENTE — PARANDO."; exit 7; }

echo ""
echo "=== 4c. O IPA carrega a extensao do jejum e o Watch? ==="
unzip -l "$IPA" | grep -oE 'Payload/Alma\.App\.Oficial\.app/(PlugIns/[^/]+|Watch/[^/]+)' | sort -u

echo ""
echo "=== 5. VALIDATE ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma100_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma100_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO subo."; exit 4; }

echo ""
echo "=== 6. UPLOAD PARA O TESTFLIGHT ==="
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma100_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — quem decide e o ASC)"
grep -E 'No errors uploading|UPLOAD FAILED|ERROR' /tmp/alma100_upload.log | tail -4

echo ""
echo "=== 7. VEREDITO PELO ASC (ate 15 min) ==="
CHEGOU=0
for i in $(seq 1 30); do
  sleep 30
  if python3 _prova_20260826/asc.py 2>/dev/null | grep -qE '^100 '; then
    echo "BUILD 100 APARECEU NO ASC (tentativa $i)."
    CHEGOU=1
    break
  fi
done
[ "$CHEGOU" -eq 0 ] && echo "AINDA NAO APARECEU — consultar o ASC de novo mais tarde."

echo ""
echo "=== ESTADO FINAL NO ASC ==="
python3 _prova_20260826/asc.py 2>&1 | head -12

echo ""
echo "FIM_100 — NADA enviado para revisao, NADA promovido, a 2.0.3 NAO foi tocada."
echo "FIM" > /tmp/alma100_up.status
