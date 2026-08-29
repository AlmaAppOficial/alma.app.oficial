#!/bin/bash
# Archive + portao de conteudo + export + validate + upload — build 100 / 2.0.4.
#
# AUTORIZACAO (29/08): subir ao TestFlight, SIM. ENVIAR PARA REVISAO: NAO.
# Promover faixa: NAO. Tocar a 2.0.3: NAO. Este script TERMINA no upload de
# proposito. O botao final e do Assis.
#
# Herdado do tf_archive_99.sh, com as armadilhas ja pagas:
#   - SEM -authenticationKey* no ARCHIVE (quebra os alvos do Watch);
#     COM eles no export, onde funcionam.
#   - -allowProvisioningUpdates nos dois passos (App Group do Watch).
#   - Chave em ~/.appstoreconnect (o disco externo some no meio da sessao).
#   - "xcodebuild devolveu BUILD SUCCEEDED tendo compilado zero arquivos":
#     por isso o script CONTA os arquivos compilados.
#   - O veredito do upload sai do ASC, nunca do texto do altool.
#
# O QUE MUDA EM RELACAO AO 99:
#   - O bump agora e de 14 ocorrencias (era 12): entrou o alvo
#     AlmaJejumWidgetExtension. Quem prova e a conferencia de bundles do passo 2,
#     que agora tem de achar 4 (app + Watch + complicacao + widget do jejum).
#   - O portao de conteudo mudou de assunto: nao e mais o jejum reescrito, e
#     sim o conserto do paywall + o PT-BR + a Live Activity embutida.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ESPERADO_BUILD="100"
ESPERADO_VERSAO="2.0.4"
ARCH="/tmp/alma100.xcarchive"
SAIDA="/tmp/alma100_ipa"
PORTAO="$HOME/Desktop/alma/_validacao_20260829/portao_conteudo_100.py"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }

rm -rf "$SAIDA" "$ARCH"
echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1

echo ""
echo "=== 1. ARCHIVE (Release, generic/platform=iOS) — do zero, sem reaproveitar ==="
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCH" \
  -allowProvisioningUpdates \
  archive > /tmp/alma100_archive.log 2>&1
echo "ARCHIVE_EXIT:$?"
echo "  arquivos Swift compilados: $(grep -c '^ *SwiftCompile ' /tmp/alma100_archive.log)"
grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma100_archive.log
grep -m8 "error:" /tmp/alma100_archive.log
[ -d "$ARCH" ] || { echo "SEM ARCHIVE — parando"; tail -40 /tmp/alma100_archive.log; exit 3; }

echo ""
echo "=== 2. VERSOES DE CADA BUNDLE (tem de dizer $ESPERADO_VERSAO ($ESPERADO_BUILD) em TODOS) ==="
bash _prova_20260826/conferir_versoes.sh "$ARCH" "$ESPERADO_VERSAO" "$ESPERADO_BUILD" \
  || { echo "NAO vou subir."; exit 5; }

echo ""
echo "=== 3. PORTAO DE CONTEUDO (com controle positivo) ==="
python3 "$PORTAO" --app "$ARCH/Products/Applications/Alma.App.Oficial.app"
PEXIT=$?
case "$PEXIT" in
  0) echo "    portao APROVOU." ;;
  2) echo ""; echo "PARANDO: portao CEGO. Nao sei o que ha no binario, entao nao subo."; exit 6 ;;
  *) echo ""; echo "PARANDO: portao REPROVOU."; exit 6 ;;
esac

echo ""
echo "=== 4. EXPORT ==="
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
[ -z "$IPA" ] && { echo "SEM IPA — parando antes do upload"; tail -30 /tmp/alma100_export.log; exit 3; }
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
  || { echo "  DIVERGENTE ou ilegivel — PARANDO."; exit 7; }

echo ""
echo "=== 4c. O IPA carrega a extensao do jejum? ==="
unzip -l "$IPA" | grep -c "AlmaJejumWidgetExtension.appex" | sed 's/^/  entradas do appex no IPA: /'
unzip -l "$IPA" | grep -E "\.appex/|Watch/" | awk '{print $4}' | cut -d/ -f1-4 | sort -u | head

echo ""
echo "=== 5. VALIDATE (antes de subir) ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma100_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma100_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo ""
echo "=== 6. UPLOAD PARA O TESTFLIGHT ==="
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma100_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — quem decide e o ASC, nao isto)"
grep -E 'No errors uploading|UPLOAD FAILED|ERROR' /tmp/alma100_upload.log | tail -4

echo ""
echo "=== 7. VEREDITO PELO ASC (ate 10 min) ==="
CHEGOU=0
for i in $(seq 1 20); do
  sleep 30
  if python3 _prova_20260826/asc.py 2>/dev/null | grep -qE '^100 '; then
    echo "BUILD 100 APARECEU NO ASC (tentativa $i)."
    CHEGOU=1
    break
  fi
done
[ "$CHEGOU" -eq 0 ] && echo "AINDA NAO APARECEU — nao conclua nada daqui; consulte o ASC de novo mais tarde."

echo ""
echo "=== ESTADO FINAL NO ASC ==="
python3 _prova_20260826/asc.py 2>&1 | head -10

echo ""
echo "=== DISCO DEPOIS ==="; df -H /System/Volumes/Data | tail -1
echo "FIM_100 — NADA foi enviado para revisao, NADA foi promovido, a 2.0.3 NAO foi tocada."
echo "FIM" > /tmp/alma100.status
