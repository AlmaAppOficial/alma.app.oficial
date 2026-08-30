#!/bin/bash
# Archive + portao de conteudo + export + validate + upload — build 101 / 2.1.
#
# POR QUE EXISTE (30/08): o Assis decidiu que a versao se chama 2.1, nao 2.0.4.
# O build 100 (VALID no TestFlight) carrega 2.0.4 embutida nos 4 bundles e no
# train do ASC — nao serve para uma versao que se apresenta como 2.1. Build
# number 100 ja foi consumido pela Apple; este sobe como 101.
#
# AUTORIZACAO (30/08): subir ao TestFlight, SIM. ENVIAR PARA REVISAO: NAO.
# Criar a versao no ASC: NAO. Promover faixa: NAO. Este script TERMINA no
# upload de proposito. O botao final e do Assis.
#
# Herdado do tf_archive_100.sh, com as armadilhas ja pagas:
#   - SEM -authenticationKey* no ARCHIVE (quebra os alvos do Watch);
#     COM eles no export, onde funcionam.
#   - -allowProvisioningUpdates nos dois passos (App Group do Watch).
#   - Chave em ~/.appstoreconnect (o disco externo some no meio da sessao).
#   - "xcodebuild devolveu BUILD SUCCEEDED tendo compilado zero arquivos":
#     por isso o script CONTA os arquivos compilados.
#   - O veredito do upload sai do ASC, nunca do texto do altool.
#
# O QUE MUDA EM RELACAO AO 100:
#   - So o rotulo: MARKETING_VERSION 2.0.4->2.1, CURRENT_PROJECT_VERSION
#     100->101 (14 ocorrencias cada no pbxproj, conferidas antes e depois).
#     Nenhuma linha de codigo mudou desde o HEAD que gerou o 100 (c78504c).
#   - O portao de conteudo continua o do 100 (portao_conteudo_100.py): ele
#     julga CONTEUDO (paywall + PT-BR + Live Activity), nao versao, e o
#     conteudo prometido e o mesmo.
#   - O veredito do ASC usa _validacao_20260830/asc_estado_20260830.py, que
#     le o train (preReleaseVersion) por include= — o asc.py antigo tentava
#     ler relationship como attribute e imprimia '-' para todo build.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ESPERADO_BUILD="101"
ESPERADO_VERSAO="2.1"
ARCH="/tmp/alma101.xcarchive"
SAIDA="/tmp/alma101_ipa"
PORTAO="$HOME/Desktop/alma/_validacao_20260829/portao_conteudo_100.py"
ASC_ESTADO="$HOME/Desktop/alma/_validacao_20260830/asc_estado_20260830.py"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }

rm -rf "$SAIDA" "$ARCH"
echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1

echo ""
echo "=== 0. O PBXPROJ DIZ O QUE EU ESPERO? (contagem 14/14, zero restos) ==="
P="Alma.App.Oficial.xcodeproj/project.pbxproj"
C1=$(grep -c "MARKETING_VERSION = ${ESPERADO_VERSAO};" "$P")
C2=$(grep -c "CURRENT_PROJECT_VERSION = ${ESPERADO_BUILD};" "$P")
R1=$(grep -c "2\.0\.4" "$P")
R2=$(grep -c "= 100;" "$P")
echo "  MARKETING_VERSION = ${ESPERADO_VERSAO}; ....... $C1 (esperado 14)"
echo "  CURRENT_PROJECT_VERSION = ${ESPERADO_BUILD}; . $C2 (esperado 14)"
echo "  restos de 2.0.4 / '= 100;' ....... $R1 / $R2 (esperado 0 / 0)"
[ "$C1" = "14" ] && [ "$C2" = "14" ] && [ "$R1" = "0" ] && [ "$R2" = "0" ] \
  || { echo "PBXPROJ NAO ESTA COMO ESPERADO — parando antes de compilar."; exit 5; }

echo ""
echo "=== 1. ARCHIVE (Release, generic/platform=iOS) — do zero, sem reaproveitar ==="
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCH" \
  -allowProvisioningUpdates \
  archive > /tmp/alma101_archive.log 2>&1
echo "ARCHIVE_EXIT:$?"
echo "  arquivos Swift compilados: $(grep -c '^ *SwiftCompile ' /tmp/alma101_archive.log)"
grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma101_archive.log
grep -m8 "error:" /tmp/alma101_archive.log
[ -d "$ARCH" ] || { echo "SEM ARCHIVE — parando"; tail -40 /tmp/alma101_archive.log; exit 3; }

echo ""
echo "=== 2. VERSOES DE CADA BUNDLE (tem de dizer $ESPERADO_VERSAO ($ESPERADO_BUILD) em TODOS os 4) ==="
CONF=$(bash _prova_20260826/conferir_versoes.sh "$ARCH" "$ESPERADO_VERSAO" "$ESPERADO_BUILD") \
  || { echo "$CONF"; echo "NAO vou subir."; exit 5; }
echo "$CONF"
echo "$CONF" | grep -q "bundles conferidos: 4" \
  || { echo "PARANDO: esperava 4 bundles (app + Watch + complicacao + widget do jejum)."; exit 5; }

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
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma101_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma101_export.log
grep -m5 "error:" /tmp/alma101_export.log
IPA=$(ls "$SAIDA"/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando antes do upload"; tail -30 /tmp/alma101_export.log; exit 3; }
ls -lh "$IPA"

echo ""
echo "=== 4b. O IPA E ESTE ARCHIVE? (LC_UUID) ==="
rm -rf /tmp/alma101_conf && mkdir -p /tmp/alma101_conf && \
  (cd /tmp/alma101_conf && unzip -q "$IPA" "Payload/Alma.App.Oficial.app/Alma.App.Oficial")
U_ARCH=$(dwarfdump --uuid "$ARCH/Products/Applications/Alma.App.Oficial.app/Alma.App.Oficial" 2>/dev/null | awk '{print $2}' | head -1)
U_IPA=$(dwarfdump --uuid /tmp/alma101_conf/Payload/Alma.App.Oficial.app/Alma.App.Oficial 2>/dev/null | awk '{print $2}' | head -1)
echo "  archive: $U_ARCH"
echo "  ipa    : $U_IPA"
[ -n "$U_ARCH" ] && [ "$U_ARCH" = "$U_IPA" ] \
  && echo "  MESMO BINARIO — o portao julgou o que vai subir." \
  || { echo "  DIVERGENTE ou ilegivel — PARANDO."; exit 7; }

echo ""
echo "=== 4c. O IPA carrega a extensao do jejum e o Watch? ==="
unzip -l "$IPA" | grep -oE 'Payload/Alma\.App\.Oficial\.app/(PlugIns/[^/]+|Watch/[^/]+)' | sort -u

echo ""
echo "=== 5. VALIDATE (antes de subir) ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma101_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma101_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo ""
echo "=== 6. UPLOAD PARA O TESTFLIGHT ==="
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma101_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — quem decide e o ASC, nao isto)"
grep -E 'No errors uploading|UPLOAD FAILED|ERROR' /tmp/alma101_upload.log | tail -4

echo ""
echo "=== 7. VEREDITO PELO ASC (ate 10 min) ==="
CHEGOU=0
for i in $(seq 1 20); do
  sleep 30
  if python3 "$ASC_ESTADO" 2>/dev/null | grep -qE "^101 "; then
    echo "BUILD 101 APARECEU NO ASC (tentativa $i)."
    CHEGOU=1
    break
  fi
done
[ "$CHEGOU" -eq 0 ] && echo "AINDA NAO APARECEU — nao conclua nada daqui; consulte o ASC de novo mais tarde."

echo ""
echo "=== ESTADO FINAL NO ASC ==="
python3 "$ASC_ESTADO" 2>&1 | head -12

echo ""
echo "=== DISCO DEPOIS ==="; df -H /System/Volumes/Data | tail -1
echo "FIM_101 — NADA foi enviado para revisao, NADA foi promovido, nenhuma versao foi criada no ASC."
echo "FIM" > /tmp/alma101.status
