#!/bin/bash
# mutacao_refeicao.sh — Regra 1 do CLAUDE.md aplicada aos componentes editáveis.
#
# Três mutações, cada uma apagando uma linha de produção que uma asserção diz
# proteger:
#
#   M1 · `componentes` deixa de ser opcional (vira `[]` com decoder sintetizado).
#        É o código que se escreveria sem conhecer a armadilha, e o que apagaria
#        o DIÁRIO DO DIA de todo mundo. R1/R1b/R1d têm de cair.
#
#   M2 · `comComponentes` para de somar e passa a aceitar totais dados de fora
#        (aqui: zera). É a divergência entre total e soma — o bug de 05/08 com
#        outra roupa. R3/R4 têm de cair.
#
#   M3 · `trocandoComponentes` deixa de preservar o `id`. Sutil e caro: salvar
#        uma edição criaria uma refeição NOVA em vez de atualizar a existente, e
#        o `atualizarRefeicao` (que casa por id) não acharia nada — a edição
#        sumiria em silêncio. R4b tem de cair.
#
# Uso: ./_scripts/mutacao_refeicao.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ALVO="Shared/Corpo/Refeicao.swift"
EVID="_validacao_20260812"
mkdir -p "$EVID"
BKP="/tmp/Refeicao.original.$$"
cp "$ALVO" "$BKP"
restaurar() { cp "$BKP" "$ALVO"; }
trap restaurar EXIT

verde=0; vermelho=0

roda() {
  local saida
  saida="$(/usr/bin/xcrun swiftc -O Shared/Corpo/UnidadeDeMedida.swift "$ALVO" \
            _scripts/testes_refeicao.swift -o /tmp/testes_refeicao_mut 2>&1)"
  # Mutação que não compila não testa nada — lição da primeira rodada do
  # `mutacao_texto.sh`, onde um build silenciosamente quebrado fez o script
  # acusar de cegas asserções que estavam perfeitas.
  if [ -n "$saida" ] && echo "$saida" | grep -q 'error:'; then
    echo "BUILD_SWIFT_FALHOU"
    echo "$saida" | grep 'error:' | head -3
    return 3
  fi
  /tmp/testes_refeicao_mut 2>&1
}

echo "═════ 0 · LINHA DE BASE ═════"
BASE="$(roda)"; RC=$?
echo "$BASE" | tee "$EVID/20_base_refeicao.txt" | tail -2
if [ $RC -eq 0 ]; then echo "  → BASE VERDE"; verde=$((verde+1))
else echo "  → ✗✗ BASE JÁ VERMELHA — nada a mutar"; exit 2; fi

espera_vermelho() {
  local ev="$1"; shift
  local desc="$1"; shift
  local saida rc
  saida="$(roda)"; rc=$?
  echo "$saida" > "$EVID/${ev}"
  if echo "$saida" | grep -q 'BUILD_SWIFT_FALHOU'; then
    echo "  → ✗✗ MUTAÇÃO INVÁLIDA — não compila, então não testou nada:"
    echo "$saida" | grep 'error:' | head -3 | sed 's/^/      /'
    vermelho=$((vermelho+1)); restaurar; return
  fi
  local faltou=""
  for a in "$@"; do echo "$saida" | grep -q "✗ $a " || faltou="$faltou $a"; done
  if [ -z "$faltou" ]; then
    echo "  → ✓ VERMELHO como exigido ($desc)"
    for a in "$@"; do echo "$saida" | grep -m1 "✗ $a " | sed 's/^/      /'; done
    verde=$((verde+1))
  else
    echo "  → ✗✗ NÃO REPROVOU — asserção cega. Faltou:$faltou"
    vermelho=$((vermelho+1))
  fi
  restaurar
}

echo
echo '═════ M1 · o decoder de Meal passa a EXIGIR a chave componentes ═════'
#
# [nota de método, 12/08] A primeira versão desta mutação trocava o tipo da
# propriedade de `[X]?` para `[X] = []`. Ela foi DESCARTADA por ser inválida: o
# harness usa `voltou?.componentes?.count`, que não compila contra tipo
# não-opcional, então a mutação derrubava o build e não media nada — e o script
# a acusou corretamente de "MUTAÇÃO INVÁLIDA".
#
# O que interessa provar não é a sintaxe do tipo, é o COMPORTAMENTO em tempo de
# execução: um decodificador que exige a chave apaga o diário de quem já usa o
# app. Esta versão injeta exatamente esse decodificador, mantendo o tipo — o
# mesmo estrago, por um caminho que compila e portanto é mensurável.
/usr/bin/python3 - "$ALVO" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
alvo = '        self.componentes = componentes\n    }\n'
assert alvo in t, 'M1 nao achou o fim do init memberwise'
injecao = alvo + '''
    // [MUTAÇÃO M1] decoder que exige a chave `componentes`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decode(MealType.self, forKey: .type)
        name = try c.decode(String.self, forKey: .name)
        kcal = try c.decode(Int.self, forKey: .kcal)
        protein = try c.decode(Int.self, forKey: .protein)
        carbs = try c.decode(Int.self, forKey: .carbs)
        fat = try c.decode(Int.self, forKey: .fat)
        done = try c.decode(Bool.self, forKey: .done)
        componentes = try c.decode([ComponenteDaRefeicao].self, forKey: .componentes)
    }
'''
open(p, 'w', encoding='utf-8').write(t.replace(alvo, injecao, 1))
print('  mutação M1 aplicada')
PY
espera_vermelho "21_mutacao_m1_diario.txt" "o diário do dia some" "R1" "R1b" "R1d"

echo
echo "═════ M2 · comComponentes para de somar ═════"
/usr/bin/python3 - "$ALVO" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
i = t.index('    public static func comComponentes(')
j = t.index('\n    }\n', i) + len('\n    }\n')
novo = ('''    public static func comComponentes(type: MealType, name: String,
                                      componentes: [ComponenteDaRefeicao],
                                      done: Bool = true,
                                      id: UUID = UUID()) -> Meal {
        // [MUTAÇÃO M2] total deixa de vir da soma.
        Meal(id: id, type: type, name: name, kcal: 0, protein: 0, carbs: 0,
             fat: 0, done: done, componentes: componentes)
    }
''')
open(p, 'w', encoding='utf-8').write(t[:i] + novo + t[j:])
print('  mutação M2 aplicada')
PY
espera_vermelho "22_mutacao_m2_soma.txt" "total e soma divergem" "R3" "R4"

echo
echo "═════ M3 · trocandoComponentes perde o id ═════"
/usr/bin/python3 - "$ALVO" <<'PY'
import sys
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
alvo = """        Meal.comComponentes(type: type, name: name, componentes: novos,
                            done: done, id: id)"""
assert alvo in t, 'M3 nao achou a chamada'
novo = """        Meal.comComponentes(type: type, name: name, componentes: novos,
                            done: done)"""
open(p, 'w', encoding='utf-8').write(t.replace(alvo, novo, 1))
print('  mutação M3 aplicada')
PY
espera_vermelho "23_mutacao_m3_id.txt" "salvar cria refeição nova em vez de editar" "R4b"

echo
echo "═════ FECHO ═════"
restaurar
FIM="$(roda)"; RC=$?
echo "$FIM" | tail -2
if [ $RC -eq 0 ]; then echo "  → ✓ verde de novo"; else echo "  → ✗✗ vermelho após restaurar"; vermelho=$((vermelho+1)); fi
if diff -q "$BKP" "$ALVO" >/dev/null; then
  echo "  → ✓ arquivo idêntico ao original"; verde=$((verde+1))
else
  echo "  → ✗✗ RESÍDUO DE MUTAÇÃO"; vermelho=$((vermelho+1))
fi

echo
echo "═════ RESUMO: $verde etapa(s) como esperado · $vermelho problema(s) ═════"
[ $vermelho -eq 0 ] || exit 1
