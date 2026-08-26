#!/bin/bash
# Archive + export + VALIDATE + UPLOAD do Alma iOS — build 98 / versao 2.0.3.
#
# Autorizacao (26/08): o Assis pediu o app no TestFlight ate sexta, para o
# Rodrigao e a Adriana testarem. Upload para o TestFlight: SIM.
# ENVIAR PARA REVISAO: NAO. Promover para grupo externo: NAO.
# Este script termina no upload de proposito e NAO deve ganhar nenhuma etapa
# depois desta. O botao final e do Assis.
#
# Molde: _scripts/tf_upload_97.sh + _scripts/tf_archive_94.sh.
# Armadilhas herdadas do 91/92/93/94/97:
#   - SEM -authenticationKey* no ARCHIVE (quebra os targets do Watch);
#     COM eles no export, onde funcionam.
#   - -allowProvisioningUpdates nos dois passos, por causa do App Group do Watch.
#   - A chave mora em ~/.appstoreconnect (o disco externo some no meio da sessao).
#
# CONTROLE POSITIVO (26/08): "xcodebuild ja devolveu BUILD SUCCEEDED tendo
# compilado zero arquivos". Por isso este script CONTA os arquivos compilados e
# imprime a versao de CADA .app do archive. Um archive verde com Watch em 97 e
# app em 98 e exatamente o modo de falha das 8-vs-12 ocorrencias.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"          # a G345G9MJ9B esta morta
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ESPERADO_BUILD="98"
ESPERADO_VERSAO="2.0.3"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }

rm -rf /tmp/alma98.xcarchive /tmp/alma98_ipa
echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1

echo "=== 1. ARCHIVE (Release, generic/platform=iOS) ==="
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/alma98.xcarchive \
  -allowProvisioningUpdates \
  archive > /tmp/alma98_archive.log 2>&1
echo "ARCHIVE_EXIT:$?"
echo "  arquivos Swift compilados: $(grep -c '^ *SwiftCompile ' /tmp/alma98_archive.log)"
grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma98_archive.log
grep -m5 "error:" /tmp/alma98_archive.log
[ -d /tmp/alma98.xcarchive ] || { echo "SEM ARCHIVE — parando"; exit 3; }

echo ""
echo "=== 2. VERSOES DE CADA ALVO (tem de dizer $ESPERADO_VERSAO ($ESPERADO_BUILD) em TODOS) ==="
# Esta e a prova das 12 ocorrencias. Se o Watch ou a complicacao sairem em 97,
# o bump pegou 8 e nao 12, e este script para aqui.
DIVERGENTE=0
while IFS= read -r p; do
  ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$p" 2>/dev/null)
  V=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$p" 2>/dev/null)
  B=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$p" 2>/dev/null)
  printf '  %-52s %s (%s)' "$ID" "$V" "$B"
  if [ "$B" != "$ESPERADO_BUILD" ] || [ "$V" != "$ESPERADO_VERSAO" ]; then
    printf '   <<< DIVERGENTE'; DIVERGENTE=1
  fi
  printf '\n'
done < <(find /tmp/alma98.xcarchive/Products/Applications -name Info.plist 2>/dev/null)

if [ "$DIVERGENTE" -ne 0 ]; then
  echo ""
  echo "PARANDO: algum alvo ficou fora de $ESPERADO_VERSAO ($ESPERADO_BUILD)."
  echo "E o modo de falha das 8-vs-12 ocorrencias. NAO vou subir."
  exit 5
fi
echo "  todos os alvos em $ESPERADO_VERSAO ($ESPERADO_BUILD)."

echo ""
echo "=== 3. EXPORT ==="
xcodebuild -exportArchive \
  -archivePath /tmp/alma98.xcarchive \
  -exportPath /tmp/alma98_ipa \
  -exportOptionsPlist _scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma98_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma98_export.log
grep -m5 "error:" /tmp/alma98_export.log
IPA=$(ls /tmp/alma98_ipa/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando antes do upload"; exit 3; }
ls -lh "$IPA"

echo ""
echo "=== 4. VALIDATE (antes de subir) ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma98_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma98_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo ""
echo "=== 5. UPLOAD PARA O TESTFLIGHT ==="
# "altool ja reportou falha duas vezes tendo enviado com sucesso" — por isso o
# texto e o exit code daqui NAO sao a conferencia. A conferencia e o
# _prova_20260826/asc.py, que le o estado no App Store Connect.
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma98_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — confira pelo ASC, nao por isto)"
tail -20 /tmp/alma98_upload.log

echo ""
echo "=== DISCO DEPOIS ==="; df -H /System/Volumes/Data | tail -1
echo "FIM_98 — NADA foi enviado para revisao, NADA foi promovido."
echo "FIM" > /tmp/alma98.status
