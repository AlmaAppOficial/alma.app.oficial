#!/bin/bash
# Archive + portao de conteudo + export + validate + upload — build 105 / 2.5.
#
# AUTORIZACAO (04/09): arquivar e SUBIR ao ASC, SIM.
# ENVIAR PARA REVISAO: NAO. Criar versao no ASC: NAO. Promover faixa: NAO.
# Este script TERMINA no upload de proposito. O botao final e do Assis.
#
# Herdado de tf_archive_101.sh. O que muda: o portao de conteudo e proprio
# deste build e julga as DUAS coisas que este build existe para levar,
# com controle positivo e negativo medidos no binario da 104 (ja publicada):
#   ausencia  "Execute com forma controlada."  -> 104: 1   105 esperado: 0
#   presenca  "padroesDeExercicio"             -> 104: 0   105 esperado: >=1
#   presenca  "PadroesDeExercicio" (classe)    -> 104: 0   105 esperado: >=1
#   controle+ "RegistroDeSeries" (classe)      -> 104: 2   105 esperado: >=1
#   controle- "TipoQueNaoExiste_XYZ"           -> 104: 0   105 esperado: 0
# Sem o controle+ o portao esta CEGO (nao mediu nada) e o script para.
# Os marcadores sao ASCII e >15 bytes de proposito: 'strings' e ASCII, e o
# Swift esconde literal de ate 15 bytes dentro da propria String.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ESPERADO_BUILD="105"
ESPERADO_VERSAO="2.5"
ARCH="/tmp/alma105.xcarchive"
SAIDA="/tmp/alma105_ipa"
ASC_ESTADO="$HOME/Desktop/alma/_validacao_20260830/asc_estado_20260830.py"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }
rm -rf "$SAIDA" "$ARCH"

echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1
LIVRE=$(df -g /System/Volumes/Data | tail -1 | awk '{print $4}')
[ "$LIVRE" -lt 5 ] && { echo "MENOS DE 5 GiB LIVRES ($LIVRE) — parando."; exit 9; }

echo ""
echo "=== 0. O PBXPROJ DIZ O QUE EU ESPERO? (14/14, zero restos) ==="
P="Alma.App.Oficial.xcodeproj/project.pbxproj"
C1=$(grep -c "MARKETING_VERSION = ${ESPERADO_VERSAO};" "$P")
C2=$(grep -c "CURRENT_PROJECT_VERSION = ${ESPERADO_BUILD};" "$P")
R1=$(grep -c "MARKETING_VERSION = 2\.4;" "$P")
R2=$(grep -c "CURRENT_PROJECT_VERSION = 104;" "$P")
echo "  MARKETING_VERSION = ${ESPERADO_VERSAO}; ....... $C1 (esperado 14)"
echo "  CURRENT_PROJECT_VERSION = ${ESPERADO_BUILD}; . $C2 (esperado 14)"
echo "  restos de 2.4 / 104 ....... $R1 / $R2 (esperado 0 / 0)"
[ "$C1" = "14" ] && [ "$C2" = "14" ] && [ "$R1" = "0" ] && [ "$R2" = "0" ] \
  || { echo "PBXPROJ NAO ESTA COMO ESPERADO — parando antes de compilar."; exit 5; }

echo ""
echo "=== 1. ARCHIVE (Release, generic/platform=iOS) ==="
xcodebuild -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCH" \
  -allowProvisioningUpdates \
  archive > /tmp/alma105_archive.log 2>&1
echo "ARCHIVE_EXIT:$?"
echo "  arquivos Swift compilados: $(grep -c '^ *SwiftCompile ' /tmp/alma105_archive.log)"
grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma105_archive.log
grep -m8 "error:" /tmp/alma105_archive.log
[ -d "$ARCH" ] || { echo "SEM ARCHIVE — parando"; tail -40 /tmp/alma105_archive.log; exit 3; }

echo ""
echo "=== 2. VERSOES DE CADA BUNDLE ==="
CONF=$(bash _prova_20260826/conferir_versoes.sh "$ARCH" "$ESPERADO_VERSAO" "$ESPERADO_BUILD") \
  || { echo "$CONF"; echo "NAO vou subir."; exit 5; }
echo "$CONF"
echo "$CONF" | grep -q "bundles conferidos: 4" \
  || { echo "PARANDO: esperava 4 bundles."; exit 5; }

echo ""
echo "=== 3. PORTAO DE CONTEUDO NO BINARIO ==="
BIN="$ARCH/Products/Applications/Alma.App.Oficial.app/Alma.App.Oficial"
[ -f "$BIN" ] || { echo "SEM BINARIO — parando"; exit 6; }
c() { strings -a "$BIN" | grep -c "$1"; }
AUS=$(c 'Execute com forma controlada')
PRE1=$(c 'padroesDeExercicio')
PRE2=$(c 'PadroesDeExercicio')
CTLP=$(c 'RegistroDeSeries')
CTLN=$(c 'TipoQueNaoExiste_XYZ')
echo "  ausencia  fabricador de exercicio ... $AUS (104: 1 / esperado 0)"
echo "  presenca  chave padroesDeExercicio .. $PRE1 (104: 0 / esperado >=1)"
echo "  presenca  classe PadroesDeExercicio . $PRE2 (104: 0 / esperado >=1)"
echo "  CONTROLE+ classe RegistroDeSeries ... $CTLP (104: 2 / esperado >=1)"
echo "  CONTROLE- simbolo inexistente ....... $CTLN (esperado 0)"
if [ "$CTLP" -lt 1 ] || [ "$CTLN" -ne 0 ]; then
  echo ""; echo "PARANDO: portao CEGO — o controle falhou, entao a ausencia nao prova nada."; exit 2
fi
if [ "$AUS" -ne 0 ]; then
  echo ""; echo "PARANDO: o fabricador de exercicio AINDA esta no binario."; exit 6
fi
if [ "$PRE1" -lt 1 ] || [ "$PRE2" -lt 1 ]; then
  echo ""; echo "PARANDO: o 'Meu padrao' NAO esta no binario."; exit 6
fi
echo "    portao APROVOU (com controle positivo e negativo)."

echo ""
echo "=== 4. EXPORT ==="
xcodebuild -exportArchive \
  -archivePath "$ARCH" \
  -exportPath "$SAIDA" \
  -exportOptionsPlist _scripts/ExportOptions-AppStore.plist \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma105_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma105_export.log
grep -m5 "error:" /tmp/alma105_export.log
IPA=$(ls "$SAIDA"/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando"; tail -30 /tmp/alma105_export.log; exit 3; }
ls -lh "$IPA"

echo ""
echo "=== 4b. O IPA E ESTE ARCHIVE? (LC_UUID) ==="
rm -rf /tmp/alma105_conf && mkdir -p /tmp/alma105_conf && \
  (cd /tmp/alma105_conf && unzip -q "$IPA" "Payload/Alma.App.Oficial.app/Alma.App.Oficial")
U_ARCH=$(dwarfdump --uuid "$BIN" 2>/dev/null | awk '{print $2}' | head -1)
U_IPA=$(dwarfdump --uuid /tmp/alma105_conf/Payload/Alma.App.Oficial.app/Alma.App.Oficial 2>/dev/null | awk '{print $2}' | head -1)
echo "  archive: $U_ARCH"
echo "  ipa    : $U_IPA"
[ -n "$U_ARCH" ] && [ "$U_ARCH" = "$U_IPA" ] \
  && echo "  MESMO BINARIO — o portao julgou o que vai subir." \
  || { echo "  DIVERGENTE ou ilegivel — PARANDO."; exit 7; }

echo ""
echo "=== 4c. Extensoes e Watch no IPA ==="
unzip -l "$IPA" | grep -oE 'Payload/Alma\.App\.Oficial\.app/(PlugIns/[^/]+|Watch/[^/]+)' | sort -u

echo ""
echo "=== 5. VALIDATE ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma105_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma105_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo ""
echo "=== 6. UPLOAD ==="
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma105_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — quem decide e o ASC)"
grep -E 'No errors uploading|UPLOAD FAILED|ERROR' /tmp/alma105_upload.log | tail -4

echo ""
echo "=== 7. VEREDITO PELO ASC (ate 15 min) ==="
CHEGOU=0
for i in $(seq 1 30); do
  sleep 30
  if python3 "$ASC_ESTADO" 2>/dev/null | grep -qE '^105 '; then
    echo "BUILD 105 APARECEU NO ASC (tentativa $i)."; CHEGOU=1; break
  fi
done
[ "$CHEGOU" -eq 0 ] && echo "AINDA NAO APARECEU — consultar o ASC mais tarde."

echo ""
echo "=== ESTADO FINAL NO ASC ==="
python3 "$ASC_ESTADO" 2>&1 | head -12

echo ""
echo "=== DISCO DEPOIS ==="; df -H /System/Volumes/Data | tail -1
echo "FIM_105 — NADA enviado para revisao, NADA promovido, nenhuma versao criada no ASC."
echo "FIM" > /tmp/alma105.status
