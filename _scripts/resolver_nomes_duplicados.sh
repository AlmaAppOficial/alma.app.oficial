#!/bin/bash
# O Xcode gera .stringsdata pelo NOME do arquivo — dois HomeView.swift em pastas
# diferentes colidem. Renomeia os do módulo Corpo com prefixo, e atualiza o
# pbxproj.
set -u
SHARED="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared"
CORPO="$SHARED/Corpo"
PROJ="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Alma.App.Oficial.xcodeproj/project.pbxproj"

echo "=== nomes duplicados entre Shared/ e Shared/Corpo/ ==="
DUPS=$(comm -12 \
  <(ls "$SHARED"/*.swift | xargs -n1 basename | sort) \
  <(ls "$CORPO"/*.swift | xargs -n1 basename | sort))
echo "$DUPS"

for NOME in $DUPS; do
  BASE="${NOME%.swift}"
  NOVO="Corpo${BASE}.swift"
  mv "$CORPO/$NOME" "$CORPO/$NOVO"
  # pbxproj: troca só as referências do módulo (path "Corpo/...")
  perl -pi -e "s{Corpo/${NOME}}{Corpo/${NOVO}}g" "$PROJ"
  perl -pi -e "s{/\\* ${NOME} \\*/}{/* ${NOVO} */}g if /Corpo\\/${NOVO}/" "$PROJ"
  echo "renomeado: $NOME -> $NOVO"
done

echo
echo "=== conferência ==="
echo -n "duplicados restantes: "
comm -12 \
  <(ls "$SHARED"/*.swift | xargs -n1 basename | sort) \
  <(ls "$CORPO"/*.swift | xargs -n1 basename | sort) | wc -l
plutil -lint "$PROJ" | tail -1
