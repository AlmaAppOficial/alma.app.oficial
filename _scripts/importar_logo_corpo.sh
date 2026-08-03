#!/bin/bash
# Cria o imageset da logo do Corpo a partir do ícone do app Corpo & Alma.
# O C&A nunca teve um asset de logo — só AppIcon. Decisão do Assis: extrair.
set -u
ORIGEM="/Users/almaappoficial/Desktop/ALMA/CorpoAlma_com_Watch/CorpoEAlma/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
DEST="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Assets.xcassets/CorpoLogo.imageset"

mkdir -p "$DEST"
# 1x/2x/3x a partir do 1024 (o botão usa ~28pt, então 3x = 84px basta e sobra)
sips -Z 120 "$ORIGEM" --out "$DEST/CorpoLogo.png"       > /dev/null 2>&1
sips -Z 240 "$ORIGEM" --out "$DEST/CorpoLogo@2x.png"    > /dev/null 2>&1
sips -Z 360 "$ORIGEM" --out "$DEST/CorpoLogo@3x.png"    > /dev/null 2>&1

cat > "$DEST/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "CorpoLogo.png",    "idiom" : "universal", "scale" : "1x" },
    { "filename" : "CorpoLogo@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "CorpoLogo@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "criado: $DEST"
ls -la "$DEST" | grep png | awk '{print "  ", $NF, $5, "bytes"}'
