#!/bin/bash
# Upload do build 84 do Alma para o App Store Connect (TestFlight).
# Autorizado pelo Assis em 30/07/2026. NÃO submete à App Store review.
set -u

export API_PRIVATE_KEYS_DIR="/Volumes/felipe 1 tb/Alma_Credentials"
KEY_ID="G345G9MJ9B"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
IPA="/tmp/alma88_ipa/Alma.App.Oficial.ipa"

case "${1:-}" in
  validate)
    xcrun altool --validate-app -f "$IPA" -t ios \
      --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma_validate.log 2>&1
    echo "VALIDATE_EXIT:$?"
    ;;
  upload)
    xcrun altool --upload-app -f "$IPA" -t ios \
      --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma_upload.log 2>&1
    echo "UPLOAD_EXIT:$?"
    ;;
  *)
    echo "uso: $0 validate|upload"
    exit 2
    ;;
esac
