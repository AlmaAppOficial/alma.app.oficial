#!/bin/bash
# Teste de mutação do módulo de jejum — 26/08/2026
#
# A regra deste projeto: uma asserção só vale se ficar VERMELHA quando a linha
# de produção que ela protege é apagada. Este script apaga, uma de cada vez, as
# linhas que sustentam as garantias do módulo, e exige vermelho.
#
# Mutação que NÃO COMPILA não testa nada — é a lição da primeira rodada do
# `mutacao_texto.sh`, e por isso `roda()` distingue os dois casos.
#
# NÃO toca no repositório: cada mutação é aplicada numa CÓPIA em /tmp.
set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

ORIG=$(mktemp -d)
cp Shared/Corpo/UnidadeDeMedida.swift Shared/Corpo/Refeicao.swift \
   Shared/Corpo/Jejum.swift Shared/Corpo/JejumConteudo.swift \
   Shared/Corpo/QuebraDeJejum.swift "$ORIG/"
cp _scripts/testes_jejum.swift "$ORIG/main.swift"

verdes=0; vermelhas=0; furos=(); naocompilou=(); naoaplicou=()
MUTOK=0

roda() {          # $1 = descrição
  # [26/08] Uma mutação que NÃO FOI APLICADA (padrão não encontrado, porque o
  # texto de produção mudou) rodava a base intocada e passava verde — e era
  # contada como FURO. Isso é pior que inútil: acusa de cega uma asserção que
  # está perfeita, e foi o que aconteceu com a M11 depois da reescrita do texto.
  # Um caso que não é "asserção cega" não pode entrar na conta de furos.
  if [ "$MUTOK" != "1" ]; then
    echo "  ⚠ NÃO APLICADA (padrão sumiu do código) — $1"
    naoaplicou+=("$1")
    return
  fi
  local T=$(mktemp -d)
  cp "$ORIG"/*.swift "$T/"
  cp "$MUT/"*.swift "$T/" 2>/dev/null
  local saida
  if ! saida=$(xcrun swiftc -O "$T/UnidadeDeMedida.swift" "$T/Refeicao.swift" \
        "$T/Jejum.swift" "$T/JejumConteudo.swift" "$T/QuebraDeJejum.swift" \
        "$T/main.swift" -o "$T/t" 2>&1); then
    echo "  ⚠ NÃO COMPILOU — $1"
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

echo "═══ MUTAÇÃO — MÓDULO DE JEJUM ═══"
echo
echo "── base (tem de estar verde) ──"
MUT=$(mktemp -d)
if xcrun swiftc -O "$ORIG"/UnidadeDeMedida.swift "$ORIG"/Refeicao.swift \
     "$ORIG"/Jejum.swift "$ORIG"/JejumConteudo.swift "$ORIG"/QuebraDeJejum.swift \
     "$ORIG"/main.swift -o /tmp/jejum_base 2>/dev/null && /tmp/jejum_base > /dev/null 2>&1; then
  echo "  ✓ base verde"
else
  echo "  ✗✗ A BASE ESTÁ VERMELHA. Nenhuma mutação abaixo significa nada."
  exit 1
fi

echo
echo "── M1 · a pausa deixa de descontar tempo ──"
mutar Jejum.swift \
  'return acumuladoAntesDaPausa + max(0, agora.timeIntervalSince(inicio))' \
  'return max(0, agora.timeIntervalSince(comecouEm))'
roda "cronômetro ignora a pausa"

echo
echo "── M2 · o relógio para trás volta a produzir negativo ──"
mutar Jejum.swift \
  'return acumuladoAntesDaPausa + max(0, agora.timeIntervalSince(inicio))' \
  'return acumuladoAntesDaPausa + agora.timeIntervalSince(inicio)'
roda "decorrido sem o piso em zero"

echo
echo "── M3 · a sequência passa a pontuar DURAÇÃO (a escalada) ──"
mutar Jejum.swift \
  'let diasComMeta = Set(historico' \
  'if let maior = historico.map(\.duracao).max(), maior > 24*3600 { return Int(maior/3600) }
        let diasComMeta = Set(historico'
roda "sequência premia jejum mais longo"

echo
echo "── M4 · o teto de 24 h cai (a OMAD vira 36 h) ──"
#
# [26/08] A primeira versão desta mutação ACRESCENTAVA um `case trintaESeis` ao
# enum, e não compilava. O motivo é uma boa notícia sobre o desenho e vale
# registrar: `ProtocoloDeJejum` é percorrido por `switch` exaustivo em cinco
# lugares (`rotulo`, `horasDeJejum`, `horasDeJanela`, `detalhe`, `simbolo`), e
# por isso NÃO É POSSÍVEL acrescentar protocolo sem passar por cada uma dessas
# decisões. O compilador é a primeira guarda.
#
# Mas "não compilou" não prova asserção nenhuma. A mutação abaixo compila e
# ataca a mesma garantia por dentro: mantém a lista do mesmo tamanho e estica a
# duração de um dos casos.
mutar Jejum.swift \
  '        case .omad:             return 23' \
  '        case .omad:             return 36'
roda "protocolo oferecido passa de 24 h"

echo
echo "── M5 · a restrição alimentar deixa de filtrar ──"
mutar QuebraDeJejum.swift \
  'candidato.grupos.allSatisfy { !evitar.contains($0) }' \
  'true'
roda "alergia declarada não filtra nada"

echo
echo "── M6 · o motor devolve prato vazio (a cegueira de M5) ──"
mutar QuebraDeJejum.swift \
  'let permitidos = candidatos.filter { candidato in' \
  'if !evitar.isEmpty { return nil }
        let permitidos = candidatos.filter { candidato in'
roda "sugestão vazia quando há restrição"

echo
echo "── M7 · o que não foi interpretado deixa de ser reportado ──"
mutar QuebraDeJejum.swift \
  'return (evitar, naoLidas)' \
  'return (evitar, [])'
roda "restrição não lida engolida em silêncio"

echo
echo "── M8 · a porção leve cresce com a duração (o oposto da regra) ──"
mutar QuebraDeJejum.swift \
  '        case .moderada:   return 250
        case .cuidadosa:  return 200' \
  '        case .moderada:   return 250
        case .cuidadosa:  return 600'
roda "jejum mais longo recebe porção leve MAIOR"

echo
echo "── M9 · o teto do orçamento cai ──"
mutar QuebraDeJejum.swift \
  'public static let orcamentoMaximo = 1100' \
  'public static let orcamentoMaximo = 9000'
roda "orçamento sem teto"

echo
echo "── M10 · o orçamento padrão se disfarça de meta pessoal ──"
mutar QuebraDeJejum.swift \
  'guard let meta = kcalGoal else { return (orcamentoSemMeta, false) }' \
  'guard let meta = kcalGoal else { return (orcamentoSemMeta, true) }'
roda "padrão rotulado como meta da pessoa"

echo
echo "── M13 · o carboidrato deixa de ser o último (a regra da sequência) ──"
mutar QuebraDeJejum.swift \
  'public static let ordemDeComer: [PapelNoPrato] = [.proteina, .vegetal, .gordura, .carboidrato]' \
  'public static let ordemDeComer: [PapelNoPrato] = [.carboidrato, .proteina, .vegetal, .gordura]'
roda "carboidrato volta a vir primeiro"

echo
echo "── M14 · fruta volta a abrir a quebra (o que saiu em 26/08) ──"
mutar QuebraDeJejum.swift \
  '        CandidatoDeQuebra(nome: "Queijo cottage",           quantidadeBase: 150, grupos: [.lactose]),' \
  '        CandidatoDeQuebra(nome: "Banana",                   quantidadeBase: 150, grupos: []),'
roda "carboidrato abre a quebra"

echo
echo "── M15 · o primeiro prato deixa de ser proteína pura ──"
mutar QuebraDeJejum.swift \
  '            primeiro = ajustarPara(kcal: alvo, componentes: [leve])
                .map { ItemDaQuebra(componente: $0, papel: .proteina) }' \
  '            primeiro = ajustarPara(kcal: alvo, componentes: [leve])
                .map { ItemDaQuebra(componente: $0, papel: .carboidrato) }'
roda "primeiro prato rotulado como carboidrato"

echo
echo "── M11 · uma promessa de resultado entra no conteúdo ──"
mutar JejumConteudo.swift \
  'O que isso quer dizer na prática:' \
  'Com ele você emagrece de verdade. O que isso quer dizer na prática:'
roda "promessa de resultado no texto"

echo
echo "── M12 · uma afirmação perde a fonte ──"
mutar JejumConteudo.swift \
  'url: "https://my.clevelandclinic.org/health/articles/24058-autophagy"' \
  'url: ""'
roda "afirmação de saúde sem URL"

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
echo "    · nenhuma View — nada aqui viu uma tela;"
echo "    · JejumStore (UserDefaults e UNUserNotificationCenter só existem no"
echo "      aparelho) — persistência e agendamento não são exercitados;"
echo "    · o toque na notificação e a troca de aba (exige XCUITest, que este"
echo "      projeto não tem — ver CLAUDE.md)."
echo "══════════════════════════════════════════════"
rm -rf "$ORIG"
[ ${#furos[@]} -eq 0 ] || exit 1
