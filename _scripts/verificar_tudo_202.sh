#!/bin/bash
# verificar_tudo_202.sh — roda os quatro harnesses da fila da 2.0.2 de uma vez.
#
# Não é substituto das mutações (`mutacao_*.sh`): isto aqui só diz que está
# verde. Verde sem mutação não prova que a asserção enxerga — é o ponto inteiro
# da Regra 1 do CLAUDE.md. Serve para conferir rapidamente que nada regrediu
# depois de mexer em qualquer um dos arquivos.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

falhou=0

echo "═════ 1/3 · UNIDADE (Swift) ═════"
/usr/bin/xcrun swiftc -O Shared/Corpo/UnidadeDeMedida.swift \
  _scripts/testes_unidade.swift -o /tmp/v_unidade 2>&1 | grep error: && falhou=1
/tmp/v_unidade | tail -1 || falhou=1

echo "═════ 2/3 · TEXTO DA PESSOA (Swift) ═════"
/usr/bin/xcrun swiftc -O Shared/Corpo/TextoDaPessoa.swift \
  _scripts/testes_texto.swift -o /tmp/v_texto 2>&1 | grep error: && falhou=1
/tmp/v_texto | tail -1 || falhou=1

echo "═════ 3/3 · REFEIÇÃO (Swift) ═════"
/usr/bin/xcrun swiftc -O Shared/Corpo/UnidadeDeMedida.swift Shared/Corpo/Refeicao.swift \
  _scripts/testes_refeicao.swift -o /tmp/v_refeicao 2>&1 | grep error: && falhou=1
/tmp/v_refeicao | tail -1 || falhou=1

echo "═════ SERVIDOR (TypeScript) ═════"
( cd functions && npm run build >/dev/null 2>&1 && node testes_scan.mjs ) \
  | grep -E 'asserções:|canário' || falhou=1

echo
[ $falhou -eq 0 ] && echo "TUDO VERDE" || echo "HOUVE FALHA — ver acima"
exit $falhou
