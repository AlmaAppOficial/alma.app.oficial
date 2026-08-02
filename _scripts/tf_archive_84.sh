#!/bin/bash
# Archive + export do Alma iOS para TestFlight (build 84 / versão 1.0.5).
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

KEY="/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_G345G9MJ9B.p8"
KEY_ID="G345G9MJ9B"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"

rm -rf /tmp/alma86.xcarchive /tmp/alma86_ipa

xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath /tmp/alma86.xcarchive \
  -allowProvisioningUpdates \
  archive > /tmp/alma_archive2.log 2>&1
echo "ARCHIVE_EXIT:$?"

xcodebuild -exportArchive \
  -archivePath /tmp/alma86.xcarchive \
  -exportPath /tmp/alma86_ipa \
  -exportOptionsPlist _scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma_export2.log 2>&1
echo "EXPORT_EXIT:$?"
