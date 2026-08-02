#!/bin/bash
# Build + instalação do Alma no iPhone do Felipe (via rede/USB).
# Uso: ./device_build.sh
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

DEVICE_ID="34E59A81-D56B-53A3-A347-F14F26D7C078"
KEY="/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_G345G9MJ9B.p8"

echo "── estado do device ──"
xcrun devicectl list devices 2>/dev/null | grep -i "iphone"

echo "── build para o device ──"
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath /tmp/alma_device \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID G345G9MJ9B \
  -authenticationKeyIssuerID a052dbae-b7ee-4e05-a3f1-4d618d17fcf4 \
  build > /tmp/alma_device_build.log 2>&1
echo "BUILD_EXIT:$?"
grep -m1 "BUILD SUCCEEDED\|BUILD FAILED" /tmp/alma_device_build.log

APP="/tmp/alma_device/Build/Products/Debug-iphoneos/Alma.App.Oficial.app"
if [ -d "$APP" ]; then
  echo "── instalando no iPhone ──"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1 | tail -5
  echo "INSTALL_EXIT:$?"
else
  echo "APP_NAO_GERADO — ver /tmp/alma_device_build.log"
  grep -m5 "error:" /tmp/alma_device_build.log | head -5
fi
