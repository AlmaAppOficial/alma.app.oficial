#!/bin/bash
# Archive + PORTAO DE CONTEUDO + export + validate + upload — build 99 / 2.0.3.
#
# AUTORIZACAO (27/08): subir ao TestFlight, SIM. O padrao desta casa e que build
# de TestFlight nao e publicacao. ENVIAR PARA REVISAO DA APP STORE: NAO.
# Promover para grupo externo: NAO. Substituir/expirar o 98: NAO.
# Este script termina no upload de proposito e NAO deve ganhar nenhuma etapa
# depois desta. O botao final e do Assis.
#
# O QUE MUDA EM RELACAO AO tf_archive_98.sh — e por que
#
# 1. PORTAO DE CONTEUDO (passo 3, novo). O 98 subiu com a versao VELHA do modulo
#    de jejum e TODO portao existente estava verde: archive compilou, 3 bundles
#    em 2.0.3 (98), altool validou, ASC disse VALID. Nenhum deles perguntava se
#    o BINARIO continha o codigo que o build prometia. Agora um pergunta, e ele
#    barra o export — nao adianta descobrir depois do upload.
#
# 2. REAPROVEITAMENTO DE ARCHIVE agora exige conteudo, nao so numero de versao.
#    No 98 o portao de reuso era `versao confere -> reaproveita`. Foi inofensivo
#    naquele dia (nada mudou entre as duas rodadas), mas e exatamente onde um
#    archive velho passaria sem ninguem notar. Agora: reaproveita SO se a versao
#    conferir E o portao de conteudo aprovar.
#
# 3. VEREDITO DO UPLOAD SAI DO ASC. Herdado do 98, onde o altool deu
#    UPLOAD_EXIT:1 com 500 e depois 409 — e o build chegou assim mesmo.
#    O texto do comando nao decide; o estado no App Store Connect decide.
#
# ARMADILHAS HERDADAS de 91/92/93/94/97/98, mantidas:
#   - SEM -authenticationKey* no ARCHIVE (quebra os alvos do Watch);
#     COM eles no export, onde funcionam.
#   - -allowProvisioningUpdates nos dois passos (App Group do Watch).
#   - A chave mora em ~/.appstoreconnect (o disco externo some no meio da sessao).
#   - "xcodebuild ja devolveu BUILD SUCCEEDED tendo compilado zero arquivos":
#     por isso o script CONTA os arquivos compilados.
#   - Bump de versao e de 12 ocorrencias, nao 8 (6 alvos x 2 configuracoes).
#     Quem prova isso e a conferencia dos 3 bundles no passo 2.
set -u
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

KEY_ID="4Y98QV45J3"          # a G345G9MJ9B esta morta
ISSUER="a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"
ESPERADO_BUILD="99"
ESPERADO_VERSAO="2.0.3"
ARCH="/tmp/alma99.xcarchive"
SAIDA="/tmp/alma99_ipa"

# O par de commits que define "a versao certa do jejum".
VELHO="5d25391"   # texto arcaico, quebra abrindo com fruta — NAO pode entrar
NOVO="6183d3c"    # texto claro, proteina primeiro, carboidrato por ultimo
ARQUIVOS_JEJUM="Shared/Corpo/JejumConteudo.swift Shared/Corpo/QuebraDeJejum.swift \
Shared/Corpo/QuebraDeJejumView.swift Shared/Corpo/JejumView.swift Shared/Corpo/Jejum.swift"

[ -f "$KEY" ] || { echo "SEM CHAVE em $KEY — parando"; exit 2; }

portao() {
  python3 _scripts/portao_de_conteudo.py \
    --velho "$VELHO" --novo "$NOVO" \
    --arquivos $ARQUIVOS_JEJUM \
    --app "$ARCH/Products/Applications/Alma.App.Oficial.app" \
    --dsym "$ARCH/dSYMs/Alma.App.Oficial.app.dSYM"
}

rm -rf "$SAIDA"
echo "=== DISCO ANTES ==="; df -H /System/Volumes/Data | tail -1

echo ""
echo "=== 1. ARCHIVE (Release, generic/platform=iOS) ==="
REAPROVEITADO=0
if [ -d "$ARCH" ] \
   && bash _prova_20260826/conferir_versoes.sh "$ARCH" "$ESPERADO_VERSAO" "$ESPERADO_BUILD" >/dev/null 2>&1 \
   && portao >/dev/null 2>&1; then
  echo "  archive de $ESPERADO_VERSAO ($ESPERADO_BUILD) ja existe, confere E passa no portao — reaproveitando."
  REAPROVEITADO=1
else
  rm -rf "$ARCH"
  xcodebuild -project Alma.App.Oficial.xcodeproj \
    -scheme "Alma.App.Oficial (iOS)" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCH" \
    -allowProvisioningUpdates \
    archive > /tmp/alma99_archive.log 2>&1
  echo "ARCHIVE_EXIT:$?"
  echo "  arquivos Swift compilados: $(grep -c '^ *SwiftCompile ' /tmp/alma99_archive.log)"
  grep -m1 "ARCHIVE SUCCEEDED\|ARCHIVE FAILED" /tmp/alma99_archive.log
  grep -m5 "error:" /tmp/alma99_archive.log
fi
[ -d "$ARCH" ] || { echo "SEM ARCHIVE — parando"; exit 3; }

echo ""
echo "=== 2. VERSOES DE CADA ALVO (tem de dizer $ESPERADO_VERSAO ($ESPERADO_BUILD) em TODOS) ==="
bash _prova_20260826/conferir_versoes.sh "$ARCH" "$ESPERADO_VERSAO" "$ESPERADO_BUILD" \
  || { echo "NAO vou subir."; exit 5; }

echo ""
echo "=== 3. PORTAO DE CONTEUDO — o binario tem o jejum reescrito? ==="
echo "    Este e o passo que nao existia no 98."
if [ "$REAPROVEITADO" -eq 1 ]; then echo "    (roda de novo mesmo tendo reaproveitado: o veredito vai para o log)"; fi
portao
PEXIT=$?
case "$PEXIT" in
  0) echo "    portao APROVOU." ;;
  2) echo ""; echo "PARANDO: portao CEGO. Nao sei o que ha no binario, entao nao subo."; exit 6 ;;
  *) echo ""; echo "PARANDO: portao REPROVOU. Este e exatamente o erro do 98."; exit 6 ;;
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
  -authenticationKeyIssuerID "$ISSUER" > /tmp/alma99_export.log 2>&1
echo "EXPORT_EXIT:$?"
grep -m1 "EXPORT SUCCEEDED" /tmp/alma99_export.log
grep -m5 "error:" /tmp/alma99_export.log
IPA=$(ls "$SAIDA"/*.ipa 2>/dev/null | head -1)
echo "IPA: $IPA"
[ -z "$IPA" ] && { echo "SEM IPA — parando antes do upload"; exit 3; }
ls -lh "$IPA"

echo ""
echo "=== 4b. O IPA E ESTE ARCHIVE? (LC_UUID) ==="
# O portao julgou o ARCHIVE. Sem isto, nada liga o que foi julgado ao que sobe.
rm -rf /tmp/alma99_conf && mkdir -p /tmp/alma99_conf && \
  (cd /tmp/alma99_conf && unzip -q "$IPA" "Payload/Alma.App.Oficial.app/Alma.App.Oficial")
U_ARCH=$(dwarfdump --uuid "$ARCH/Products/Applications/Alma.App.Oficial.app/Alma.App.Oficial" 2>/dev/null | awk '{print $2}' | head -1)
U_IPA=$(dwarfdump --uuid /tmp/alma99_conf/Payload/Alma.App.Oficial.app/Alma.App.Oficial 2>/dev/null | awk '{print $2}' | head -1)
echo "  archive: $U_ARCH"
echo "  ipa    : $U_IPA"
[ -n "$U_ARCH" ] && [ "$U_ARCH" = "$U_IPA" ] \
  && echo "  MESMO BINARIO — o portao julgou o que vai subir." \
  || { echo "  DIVERGENTE ou ilegivel — PARANDO."; exit 7; }

echo ""
echo "=== 5. VALIDATE (antes de subir) ==="
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma99_validate.log 2>&1
VEXIT=$?
echo "VALIDATE_EXIT:$VEXIT"
tail -20 /tmp/alma99_validate.log
[ "$VEXIT" -eq 0 ] || { echo "VALIDACAO REPROVOU — NAO vou subir."; exit 4; }

echo ""
echo "=== 6. UPLOAD PARA O TESTFLIGHT ==="
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" > /tmp/alma99_upload.log 2>&1
echo "UPLOAD_EXIT:$? (informativo — quem decide e o ASC, nao isto)"
grep -E 'No errors uploading|UPLOAD FAILED|ERROR' /tmp/alma99_upload.log | tail -4

echo ""
echo "=== 7. VEREDITO PELO ASC (ate 10 min) ==="
CHEGOU=0
for i in $(seq 1 20); do
  sleep 30
  if python3 _prova_20260826/asc.py 2>/dev/null | grep -qE '^99 '; then
    echo "BUILD 99 APARECEU NO ASC (tentativa $i)."
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
echo "FIM_99 — NADA foi enviado para revisao, NADA foi promovido, o 98 NAO foi tocado."
echo "FIM" > /tmp/alma99.status
