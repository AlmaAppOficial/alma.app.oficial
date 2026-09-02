#!/bin/bash
# Teste de MUTAÇÃO das asserções de `testes_fotos.swift`.
#
# Uma asserção que nunca reprova não é asserção, é papel pintado. Este script
# apaga (ou inverte) a linha de produção que cada bloco protege, roda o harness
# de novo e EXIGE que ele fique vermelho. Se ficar verde sem a linha, a
# asserção é cega e não conta.
#
# Nada aqui toca a árvore de trabalho: cada mutação vive numa cópia em $TMPDIR.
# A pasta das 594 fotos entra por LINK, não por cópia (11 MB × 5 mutações num
# Mac com pouco disco é um problema que não precisa existir).
#
# Saída: 0 = todas as mutações foram detectadas · 1 = existe asserção cega
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 3

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"
mkdir -p "$BASE"

cp Shared/Corpo/Exercicio.swift          "$BASE/Exercicio.swift"
cp Shared/Corpo/ExerciseLibraryV2.swift  "$BASE/ExerciseLibraryV2.swift"
cp Shared/Corpo/exercises_v2.json        "$BASE/exercises_v2.json"
cp _scripts/testes_fotos.swift           "$BASE/main.swift"
ln -s "$RAIZ/Shared/Corpo/ExerciciosFotos" "$BASE/ExerciciosFotos"
printf 'let exerciseLibrary: [Exercise] = []\n' > "$BASE/stub.swift"
git show HEAD:Shared/Corpo/exercises_v2.json > "$BASE/head.json" || exit 3

falhas=0

# $1 = rótulo · $2 = pasta da mutação · $3 = padrão que TEM de aparecer vermelho
verifica() {
    local rotulo="$1" dir="$2" alvo="$3"
    local saida rc
    if ! xcrun swiftc -O "$dir/Exercicio.swift" "$dir/ExerciseLibraryV2.swift" \
            "$dir/stub.swift" "$dir/main.swift" -o "$dir/t" 2>"$dir/erros"; then
        # Não compilar TAMBÉM é detecção: a mutação foi rejeitada pelo
        # compilador antes de virar bug. Só precisa ficar dito qual foi.
        echo "  ✓ $rotulo — a mutação nem compila (o compilador é a barreira):"
        grep -m2 'error:' "$dir/erros" | sed 's/^/      /'
        return
    fi
    saida=$("$dir/t" "$dir/exercises_v2.json" "$dir/head.json" "$dir/ExerciciosFotos" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "  ✗✗ $rotulo — ASSERÇÃO CEGA: o harness ficou VERDE sem a linha."
        falhas=$((falhas + 1))
        return
    fi
    if echo "$saida" | grep -qE "✗.*($alvo)"; then
        echo "  ✓ $rotulo — vermelho em $alvo, como tem de ser:"
        echo "$saida" | grep -E "✗" | head -4 | sed 's/^/     /'
    else
        echo "  ✗✗ $rotulo — ficou vermelho, mas NÃO em $alvo (asserção errada acusou):"
        echo "$saida" | grep -E "✗" | head -4 | sed 's/^/     /'
        falhas=$((falhas + 1))
    fi
}

nova() {
    local d="$TMP/$1"
    mkdir -p "$d"
    cp "$BASE"/*.swift "$BASE"/*.json "$d/"
    ln -s "$RAIZ/Shared/Corpo/ExerciciosFotos" "$d/ExerciciosFotos"
    echo "$d"
}

# Uma mutação que não foi aplicada NÃO é "asserção cega" — é script quebrado, e
# confundir os dois produz exatamente o relatório falso que estas regras
# existem para impedir. $1 = rótulo · $2 = arquivo · $3 = marca que prova que
# a edição pegou.
aplicou() {
    if grep -qF "$3" "$2"; then return 0; fi
    echo "  ⚠︎ $1 — A MUTAÇÃO NÃO FOI APLICADA (o padrão não casou em $(basename "$2"))."
    echo "     Isto não diz nada sobre a asserção; diz que este script quebrou."
    falhas=$((falhas + 1))
    return 1
}

echo "═══ MUTAÇÃO 1 — campo NOVO e NÃO-OPCIONAL em \`Exercise\` ═══"
echo "    (é o defeito literal que a regra existe para impedir: o treino"
echo "     gravado da pessoa deixa de decodificar e some em silêncio)"
D=$(nova m1)
/usr/bin/sed -i '' 's|^    let instructions: \[String\]$|    let instructions: [String]\n    let fotos: [String]|' "$D/Exercicio.swift"
aplicou "M1" "$D/Exercicio.swift" "let fotos: [String]" && verifica "M1" "$D" "F1|F2"

echo
echo "═══ MUTAÇÃO 2 — \`fotos\` passa a ser obrigatório no ExerciseV2 ═══"
echo "    (581 dos 1.095 não têm o campo; o catálogo inteiro pararia de"
echo "     decodificar e \`load()\` cairia no fallback SEM avisar)"
D=$(nova m2)
/usr/bin/sed -i '' 's|decodeIfPresent(\[String\].self, forKey: .fotos)|decode([String].self, forKey: .fotos)|' "$D/ExerciseLibraryV2.swift"
aplicou "M2" "$D/ExerciseLibraryV2.swift" "decode([String].self, forKey: .fotos)" && verifica "M2" "$D" "F0|F4"

echo
echo "═══ MUTAÇÃO 3 — o catálogo aponta para um arquivo que não existe ═══"
echo "    (não quebra nada visível: a tela desenha o corpo anatômico e"
echo "     ninguém descobre — por isso a conferência é contra o disco)"
D=$(nova m3)
/usr/bin/python3 - "$D/exercises_v2.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1], encoding="utf-8"))
for e in c:
    if e.get("fotos"):
        e["fotos"][0] = "arquivo-que-nao-existe.webp"
        break
json.dump(c, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
PY
aplicou "M3" "$D/exercises_v2.json" "arquivo-que-nao-existe.webp" && verifica "M3" "$D" "F5"

echo
echo "═══ MUTAÇÃO 4 — a ponte V2→legado passa a levar a foto para o disco ═══"
echo "    (\`asLegacyExercise()\` roda quando a pessoa salva um treino;"
echo "     é por onde uma foto vazaria para o formato persistido)"
D=$(nova m4)
/usr/bin/sed -i '' 's|symbol: displaySymbol,|symbol: fotos?.first ?? displaySymbol,|' "$D/ExerciseLibraryV2.swift"
aplicou "M4" "$D/ExerciseLibraryV2.swift" "symbol: fotos?.first ?? displaySymbol," && verifica "M4" "$D" "F3"

echo
echo "═══ MUTAÇÃO 5 — o catálogo é SUBSTITUÍDO em vez de fundido ═══"
echo "    (a regra nº 1 do trabalho: manter os 1.095 ids vivos)"
D=$(nova m5)
/usr/bin/python3 - "$D/exercises_v2.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1], encoding="utf-8"))
json.dump([e for e in c if "fotos" in e], open(sys.argv[1], "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
PY
verifica "M5" "$D" "F0|F6"

echo
echo "══════════════════════════════════════════════"
if [ "$falhas" -eq 0 ]; then
    echo "  5 mutações, 5 detectadas — as asserções enxergam."
else
    echo "  $falhas mutação(ões) NÃO detectada(s) — há asserção cega."
fi
echo "══════════════════════════════════════════════"
exit $([ "$falhas" -eq 0 ] && echo 0 || echo 1)
