#!/bin/bash
# Archive + export + VALIDATE + UPLOAD do Alma iOS — build 94 / versão 2.0.1.
#
# Autorização do Felipe (06/08): archive, export e upload para o TestFlight, SIM.
# ENVIAR PARA REVISÃO, NÃO. Este script para no upload, de propósito, e não
# encosta em submissão.
#
# Molde: _scripts/tf_archive_93.sh. Mesmas armadilhas conhecidas do 91/92/93:
#  • SEM `-authenticationKey*` no ARCHIVE (quebra os targets do Watch);
#    COM eles no export/upload, onde funcionam.
#  • `-allowProvisioningUpdates` nos dois passos, por causa do App Group do Watch.
#
# Diferença em relação ao 93: rodo `--validate-app` ANTES do upload e paro se
# ele reprovar. O Felipe pediu para ir "até VALID" — validar antes é o que
# transforma isso numa afirmação verificada em vez de uma esperança.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY="/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_4Y98QV45J3.p8"
KEY_ID="4Y98QV45J3"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"

rm -rf /tmp/alma94.xcarchive /tmp/alma94_ipa
echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1

echo "=== 1. ARCHIVE ==="
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/alma94.xcarchive \
  -allowProvisioningUpdates \
  archive > /tmp/alma94_archive.log 2>&1
echo "ARCHIVE_EXIT:$?"
grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma94_archive.log
grep -m5 "error:" /tmp/alma94_archive.log
[ -d /tmp/alma94.xcarchive ] || { echo "SEM ARCHIVE — parando"; exit 3; }

echo "=== CONTEUDO DO ARCHIVE (iPhone + Watch) ==="
find /tmp/alma94.xcarchive/Products/Applications -maxdepth 4 -name "*.app" 2>/dev/null
echo "=== VERSOES (tem de dizer 2.0.1 (94) em todos) ==="
for p in $(find /tmp/alma94.xcarchive/Products/Applications -maxdepth 4 -name Info.plist 2>/dev/null | head -6); do
  echo "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$p" 2>/dev/null) \
$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$p" 2>/dev/null) \
($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$p" 2>/dev/null))"
done

echo "=== 2. EXPORT ==="
xcodebuild -exportArchive \
  -archivePath /tmp/alma94.xcarchive \
  -exportPath /tmp/alma94_ipa \
  -exportOptionsPlist _scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma94_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma94_export.log
grep -m5 "error:" /tmp/alma94_export.log
IPA=$(ls /tmp/alma94_ipa/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando antes do upload"; exit 3; }
ls -lh "$IPA"

mkdir -p ~/.appstoreconnect/private_keys
cp "$KEY" ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8 2>/dev/null
chmod 600 ~/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8 2>/dev/null

echo "=== 3. VALIDATE (antes de subir) ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma94_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma94_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo "=== 4. UPLOAD PARA O TESTFLIGHT ==="
# Autorizado pelo Felipe: upload SIM. Submissao a revisao NAO — este script
# nao tem e nao deve ganhar nenhuma etapa depois desta.
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma94_upload.log 2>&1
echo "UPLOAD_EXIT:$?"
tail -20 /tmp/alma94_upload.log

echo "=== DISCO DEPOIS ==="; df -H /System/Volumes/Data | tail -1
echo "FIM_94 — NADA foi enviado para revisao."
