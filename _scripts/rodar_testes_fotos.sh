#!/bin/bash
# Compila o catálogo + o modelo persistido com swiftc e roda as asserções das
# fotos dos exercícios — sem simulador, sem Xcode aberto.
#
# `exerciseLibrary` (Models.swift, 1.400 linhas de SwiftUI) entra como STUB
# vazio: ele só alimenta o fallback de `ExerciseCatalog.load()`, e o que está
# sob teste aqui é o DECODIFICADOR, que o harness chama direto. Stub de coisa
# que não está sob teste é legítimo; stub da coisa testada seria fraude.
#
# O catálogo de HEAD sai do próprio git — não de uma cópia que alguém deixou
# numa pasta e que pode ter sido editada junto.
#
# Saída: 0 = verde · 1 = vermelho · 3 = nem compilou (que NÃO é o mesmo que
#        verde: é a AUSÊNCIA de teste)
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 3

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp _scripts/testes_fotos.swift "$TMP/main.swift"
printf 'let exerciseLibrary: [Exercise] = []\n' > "$TMP/stub_catalogo_legado.swift"

# Catálogo de HEAD direto do objeto do git.
if ! git show HEAD:Shared/Corpo/exercises_v2.json > "$TMP/head.json" 2>"$TMP/git_erro"; then
    echo "✗✗ não consegui extrair o catálogo de HEAD do git:"
    sed 's/^/   /' "$TMP/git_erro"
    exit 3
fi

echo "── COMPILANDO (produção + asserções) ──"
if ! xcrun swiftc -O \
      Shared/Corpo/Exercicio.swift \
      Shared/Corpo/ExerciseLibraryV2.swift \
      "$TMP/stub_catalogo_legado.swift" \
      "$TMP/main.swift" -o "$TMP/t" 2>"$TMP/erros"; then
    echo "✗✗ NÃO COMPILOU — nenhuma asserção rodou. Isto NÃO é um teste"
    echo "   vermelho, é a AUSÊNCIA de teste. Erros:"
    grep 'error:' "$TMP/erros" | sed 's/^/   /' | head -30
    exit 3
fi

"$TMP/t" Shared/Corpo/exercises_v2.json "$TMP/head.json" Shared/Corpo/ExerciciosFotos
exit $?
