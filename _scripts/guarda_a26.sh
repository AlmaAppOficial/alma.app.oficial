#!/bin/bash
# GUARDA A26 — nenhum controle de aparencia dentro de Shared/Corpo/.
#
# Por que NAO e uma fase de build: o projeto tem
# ENABLE_USER_SCRIPT_SANDBOXING = YES, e o sandbox nega leitura de
# Shared/Corpo a partir de uma fase de script — nem declarando o diretorio em
# inputPaths funciona. Provado em 05/08: grep morre com "Operation not
# permitted". A v1 da fase engolia esse erro com 2>/dev/null e aprovava tudo:
# guarda cega, o mesmo modo de falha que A26d denuncia.
#
# Roda como hook de pre-commit e a mao. Ver Shared/AparenciaDoApp.swift,
# secao "DIVIDA CONHECIDA".
cd "$(dirname "$0")/.." || exit 1
DIR="Shared/Corpo"

# Anti-cegueira: se o canario nao aparece, o instrumento esta quebrado e a
# guarda REPROVA. Guarda que nao enxerga nunca aprova.
if [ -z "$(grep -rl 'struct CorpoHomeView' "$DIR" 2>/dev/null)" ]; then
  echo "GUARDA A26: nao consegui ler $DIR — guarda cega, reprovando por principio." >&2
  exit 1
fi

ACHADOS=$(grep -rn "AparenciaDoApp" "$DIR" 2>/dev/null | grep -vE ":[0-9]+:[[:space:]]*//" || true)
N=$(printf '%s' "$ACHADOS" | grep -c . || true)

if [ "$N" -gt 0 ]; then
  echo "" >&2
  echo "GUARDA A26 REPROVOU — controle de aparencia dentro de $DIR:" >&2
  printf '%s\n' "$ACHADOS" | sed 's/^/   /' >&2
  echo "" >&2
  echo "A aparencia vive so em Alma > Perfil > Modo escuro ate a divida do" >&2
  echo "fullScreenCover ser resolvida (Shared/AparenciaDoApp.swift)." >&2
  echo "Um controle ali nao funciona e e risco de Guideline 2.1." >&2
  exit 1
fi

echo "GUARDA A26: ok — nenhum controle de aparencia em $DIR"
exit 0
