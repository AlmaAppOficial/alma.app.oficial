#!/bin/bash
# Teste de mutação do registro de séries — 02/09/2026
#
# A regra deste projeto: uma asserção só vale se ficar VERMELHA quando a linha
# de produção que ela protege é apagada. Este script apaga, uma de cada vez, as
# linhas que sustentam as garantias, e exige vermelho.
#
# Mutação que NÃO COMPILA não testa nada, e mutação NÃO APLICADA (padrão sumiu
# do código) não pode contar como furo — `roda()` distingue os três casos,
# como o `mutacao_jejum.sh`.
#
# NÃO toca no repositório: cada mutação é aplicada numa CÓPIA em /tmp.
set -u
cd "$HOME/Desktop/alma/alma.app.oficial-main" || exit 3

ORIG=$(mktemp -d)
cp Shared/Corpo/Exercicio.swift Shared/Corpo/RegistroDeSeries.swift "$ORIG/"
cp _scripts/testes_series.swift "$ORIG/main.swift"

verdes=0; vermelhas=0; furos=(); naocompilou=(); naoaplicou=()
MUTOK=0
MUT=""

roda() {          # $1 = descrição
  if [ "$MUTOK" != "1" ]; then
    echo "  ⚠ NÃO APLICADA (padrão sumiu do código) — $1"
    naoaplicou+=("$1")
    return
  fi
  local T=$(mktemp -d)
  cp "$ORIG"/*.swift "$T/"
  cp "$MUT/"*.swift "$T/" 2>/dev/null
  local saida
  if ! saida=$(xcrun swiftc -O "$T/Exercicio.swift" "$T/RegistroDeSeries.swift" \
        "$T/main.swift" -o "$T/t" 2>&1); then
    echo "  ⚠ NÃO COMPILOU — $1"
    echo "$saida" | grep 'error:' | head -3 | sed 's/^/      /'
    naocompilou+=("$1")
    rm -rf "$T"; return
  fi
  if "$T/t" > "$T/saida.txt" 2>&1; then
    echo "  ✗ FURO (passou verde) — $1"
    furos+=("$1")
    verdes=$((verdes+1))
  else
    local quais
    quais=$(grep -c '✗' "$T/saida.txt")
    echo "  ✓ vermelha ($quais asserções) — $1"
    grep '✗' "$T/saida.txt" | head -3 | sed 's/^/      /'
    vermelhas=$((vermelhas+1))
  fi
  rm -rf "$T"
}

mutar() {         # $1 = arquivo · $2 = de · $3 = para
  MUT=$(mktemp -d)
  cp "$ORIG/$1" "$MUT/$1"
  if python3 - "$MUT/$1" "$2" "$3" <<'PY'
import sys
p, de, para = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
if de not in s:
    print(f'   !! padrão não encontrado em {p}: {de[:60]}')
    sys.exit(9)
open(p, 'w', encoding='utf-8').write(s.replace(de, para, 1))
PY
  then MUTOK=1; else MUTOK=0; fi
}

echo "═══ MUTAÇÃO — REGISTRO DE SÉRIES ═══"
echo
echo "── base (tem de estar verde) ──"
BASE="$ORIG/base"
if xcrun swiftc -O "$ORIG"/Exercicio.swift "$ORIG"/RegistroDeSeries.swift \
     "$ORIG"/main.swift -o "$BASE" 2>"$ORIG/base_compile.txt" && "$BASE" > "$ORIG/base_run.txt" 2>&1; then
  echo "  ✓ base verde"
else
  echo "  ✗✗ A BASE ESTÁ VERMELHA. Nenhuma mutação abaixo significa nada."
  grep 'error:' "$ORIG/base_compile.txt" | head -5 | sed 's/^/      /'
  grep '✗' "$ORIG/base_run.txt" | head -5 | sed 's/^/      /'
  exit 1
fi

echo
echo "── M1 · a armadilha: campo NÃO opcional entra em Exercise ──"
# É a mutação que mais importa. `customWorkouts` é lido com `try?`; com este
# campo, todo treino já gravado deixa de decodificar e some da lista, calado.
mutar Exercicio.swift \
  '    let instructions: [String]
}' \
  '    let instructions: [String]
    let cargaKg: Double
}'
roda "Exercise ganha campo obrigatório → treino antigo deixa de ler"

echo
echo "── M2 · em branco passa a gravar ──"
mutar RegistroDeSeries.swift \
  '        guard repeticoes != nil || segundos != nil || cargaKg != nil else { return nil }' \
  ''
roda "montar grava registro vazio"

echo
echo "── M3 · registrar não escreve no disco (só no cache) ──"
# A família de asserção que já saiu verde sem gravar nada: se o teste relesse
# pela MESMA instância, o cache mascararia isto.
mutar RegistroDeSeries.swift \
  '        if let d = try? Self.codificar(lista) { store.set(d, forKey: Self.chave) }' \
  ''
roda "gravação só em memória"

echo
echo "── M4 · as repetições voltam do campo errado ──"
mutar RegistroDeSeries.swift \
  '        repeticoes = try c.decodeIfPresent(Int.self, forKey: .repeticoes)' \
  '        repeticoes = try c.decodeIfPresent(Int.self, forKey: .segundos)'
roda "reps lidas da chave de segundos"

echo
echo "── M5 · a carga não volta do disco ──"
mutar RegistroDeSeries.swift \
  '        cargaKg = try c.decodeIfPresent(Double.self, forKey: .cargaKg)' \
  '        cargaKg = nil'
roda "carga perdida na leitura"

echo
echo "── M6 · o teto cai ──"
mutar RegistroDeSeries.swift \
  '        if lista.count > Self.maximo { lista.removeFirst(lista.count - Self.maximo) }' \
  ''
roda "lista cresce sem limite"

echo
echo "── M7 · a última vira a última DA LISTA, não a mais recente ──"
mutar RegistroDeSeries.swift \
  '        lista.filter { $0.exercicioSlug == exercicioSlug }.max { $0.quando < $1.quando }' \
  '        lista.filter { $0.exercicioSlug == exercicioSlug }.last'
roda "última por posição em vez de instante"

echo
echo "── M8 · todo exercício vira repetições ──"
mutar RegistroDeSeries.swift \
  '        return reps.range(of: padrao, options: .regularExpression) != nil ? .segundos : .repeticoes' \
  '        return .repeticoes'
roda "exercício por tempo pede reps"

echo
echo "── M9 · a tolerância some: um registro ruim derruba a lista ──"
mutar RegistroDeSeries.swift \
  '        init(from decoder: Decoder) {
            valor = try? T(from: decoder)' \
  '        init(from decoder: Decoder) throws {
            valor = try T(from: decoder)'
roda "decode sem tolerância"

echo
echo "── M10 · o filtro de caracteres da carga afrouxa (sinal e letra passam) ──"
# [02/09] A primeira versão desta mutação apagava um `valor >= 0` que vinha
# DEPOIS do filtro — e saiu VERDE. Não era asserção cega: era guarda
# inalcançável (sem "-" permitido, o Double nunca é negativo). O `>= 0` saiu
# da produção e a mutação passou a atacar a linha que protege de verdade.
mutar RegistroDeSeries.swift \
  '        let permitido = limpo.allSatisfy { $0.isNumber || $0 == "." }' \
  '        let permitido = true'
roda "carga aceita sinal, letra e notação científica"

echo
echo "── M11 · o texto da carga sai com ponto (não é PT-BR) ──"
mutar RegistroDeSeries.swift \
  '        return s.replacingOccurrences(of: ".", with: ",")' \
  '        return s'
roda "carga exibida com ponto decimal"

echo
echo "── M12 · \"Série anterior\" e \"Última vez\" viram a mesma coisa ──"
mutar RegistroDeSeries.swift \
  '        if ultima.sessao == sessaoAtual {' \
  '        if false {'
roda "mesma sessão tratada como outra"

echo
echo "── M13 · a série zero passa a existir ──"
mutar RegistroDeSeries.swift \
  '                               numero: max(1, numero), repeticoes: repeticoes,' \
  '                               numero: numero, repeticoes: repeticoes,'
roda "número da série sem piso"

echo
echo "── M14 · o slug para de dobrar acentos ──"
mutar Exercicio.swift \
  '    let folded = nome.folding(options: [.diacriticInsensitive, .caseInsensitive],
                              locale: Locale(identifier: "pt_BR"))' \
  '    let folded = nome'
roda "slug com acento (chave instável)"

echo
echo "── M15 · o slug não é mais gravado na escrita ──"
mutar RegistroDeSeries.swift \
  '                               exercicioSlug: slugDeExercicio(nome), exercicio: nome,' \
  '                               exercicioSlug: nome, exercicio: nome,'
roda "slug igual ao nome cru"

echo
echo "── M16 · o inteiro aceita negativo ──"
mutar RegistroDeSeries.swift \
  '        guard !digitos.isEmpty, let n = Int(digitos), n >= 0, n <= teto else { return nil }' \
  '        guard let n = Int(limpo), n <= teto else { return nil }'
roda "inteiro negativo aceito"

echo
echo "══════════════════════════════════════════════"
echo "  $vermelhas vermelhas · ${#furos[@]} furos · ${#naocompilou[@]} não compilaram · ${#naoaplicou[@]} não aplicadas"
if [ ${#furos[@]} -gt 0 ]; then
  echo "  FUROS (asserção cega — a garantia não é garantida):"
  printf '    · %s\n' "${furos[@]}"
fi
if [ ${#naocompilou[@]} -gt 0 ]; then
  echo "  NÃO COMPILARAM (mutação inválida, não prova nem desprova):"
  printf '    · %s\n' "${naocompilou[@]}"
fi
if [ ${#naoaplicou[@]} -gt 0 ]; then
  echo "  NÃO APLICADAS (o padrão sumiu — conserte a mutação, não a asserção):"
  printf '    · %s\n' "${naoaplicou[@]}"
fi
echo
echo "  O QUE ESTE SCRIPT NÃO EXECUTA, declarado:"
echo "    · nenhuma View — se \"Completar série\" chama registrarSerie é a"
echo "      auditoria S1–S3 (simulador) e a mutação M-S no app que provam;"
echo "    · a exclusão de conta — B9e no simulador, com a mutação M-B9e."
echo "══════════════════════════════════════════════"
rm -rf "$ORIG"
[ ${#furos[@]} -eq 0 ] && [ ${#naocompilou[@]} -eq 0 ] && [ ${#naoaplicou[@]} -eq 0 ] || exit 1
