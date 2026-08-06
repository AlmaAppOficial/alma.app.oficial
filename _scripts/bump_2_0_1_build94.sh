#!/bin/bash
# BUMP 2.0 (build 93) → 2.0.1 (build 94) — 06/08/2026
#
# Molde: _scripts/build93_bump_e_commit.sh. A parte que importa não é o sed, é a
# CONFERÊNCIA logo depois: o diff do pbxproj tem de conter SÓ linhas de versão.
# Um pbxproj é fácil de sujar sem perceber (o Xcode reescreve o arquivo inteiro
# ao abrir), e sujeira aqui vira build assinado errado.
#
# Estado de partida, conferido antes de escrever isto:
#   MARKETING_VERSION = 2.0;         → 12 ocorrências, todas iguais
#   CURRENT_PROJECT_VERSION = 93;    → 12 ocorrências, todas iguais
#   PRODUCT_BUNDLE_IDENTIFIER        → 12 (os 12 pares target × configuração)
#
# NÃO FAZ PUSH. NÃO FAZ ARCHIVE. NÃO SOBE NADA.
set -eu

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"
PBX="Alma.App.Oficial.xcodeproj/project.pbxproj"

echo "═════ 1 · estado antes ═════"
echo -n "  MARKETING_VERSION = 2.0;       → "; grep -c "MARKETING_VERSION = 2\.0;" "$PBX"
echo -n "  CURRENT_PROJECT_VERSION = 93;  → "; grep -c "CURRENT_PROJECT_VERSION = 93;" "$PBX"
[ "$(grep -c 'MARKETING_VERSION = 2\.0;' "$PBX")" = "12" ] || { echo "ABORTADO: esperava 12 de MARKETING_VERSION = 2.0"; exit 1; }
[ "$(grep -c 'CURRENT_PROJECT_VERSION = 93;' "$PBX")" = "12" ] || { echo "ABORTADO: esperava 12 de CURRENT_PROJECT_VERSION = 93"; exit 1; }
echo

echo "═════ 2 · bump ═════"
# O ponto escapado importa: sem escapar, `2.0;` casaria também com `2X0;`.
sed -i '' 's/MARKETING_VERSION = 2\.0;/MARKETING_VERSION = 2.0.1;/g' "$PBX"
sed -i '' 's/CURRENT_PROJECT_VERSION = 93;/CURRENT_PROJECT_VERSION = 94;/g' "$PBX"
echo -n "  MARKETING_VERSION = 2.0.1;     → "; grep -c "MARKETING_VERSION = 2\.0\.1;" "$PBX"
echo -n "  CURRENT_PROJECT_VERSION = 94;  → "; grep -c "CURRENT_PROJECT_VERSION = 94;" "$PBX"
echo -n "  sobrou de 2.0 puro:            → "; grep -c "MARKETING_VERSION = 2\.0;" "$PBX" || true
echo -n "  sobrou de 93:                  → "; grep -c "CURRENT_PROJECT_VERSION = 93;" "$PBX" || true
echo

echo "═════ 3 · SÓ A VERSÃO MUDOU? (a conferência que justifica o script) ═════"
git --no-optional-locks diff --stat "$PBX"
echo "  --- linhas alteradas que NÃO são de versão ---"
SUJEIRA=$(git --no-optional-locks diff -U0 "$PBX" | grep -E '^[+-]' | grep -v '^[+-][+-]' \
  | grep -vE 'MARKETING_VERSION|CURRENT_PROJECT_VERSION' || true)
if [ -n "$SUJEIRA" ]; then
  echo "$SUJEIRA"
  echo "  ABORTADO: o diff do pbxproj tem linha que não é de versão."
  exit 1
fi
echo "  (nenhuma — bom)"
echo

echo "═════ 4 · commit por caminho explícito ═════"
git add "$PBX"
git commit -F - <<'MSG'
2.0.1 (build 94)

Sobe a versão para a leva que estava parada desde o archive do build 93. Só o
pbxproj muda: 12 ocorrências de MARKETING_VERSION e 12 de
CURRENT_PROJECT_VERSION, uma por par target × configuração. O script confere que
o diff não tem nenhuma linha que não seja de versão antes de commitar — pbxproj
é fácil de sujar sem perceber, e sujeira aqui vira build assinado errado.

O que a 2.0.1 carrega, em ordem cronológica:
· a8bee0e  toda notificação leva à tela que ela pede, inclusive na partida fria
· 366c1ac  scan honesto: a tela e o diário contam o mesmo número
· 5cdd7a6  documentação do dia: dívidas e impacto real nos dados
· dbc774b  apaga os dois arquivos mortos com preço chumbado
· 3243399  entitlement: a assinatura da Apple chega ao servidor
· e618d9b  o app conta ao servidor que a compra é desta conta
· ad569c1  paywall: tira do preço o que já era de graça
· 4944881  o botão pago que engolia o toque agora oferece o Premium
· 4ee4f11  assinante pagando e não recebendo deixa de ser invisível
· b1ddf55  tira o índice inválido que impedia QUALQUER índice de subir
· 6738d81  harness volta a compilar (reparo do 4944881, de hoje)
· 9ba23fc  a porção deixa de ser um decreto da IA

Se 2.0.1 é o número certo é decisão do Felipe: o lote inclui entitlement de
assinatura chegando ao servidor e mudança de paywall, que é mais do que patch.
O esforço do bump é o mesmo em qualquer número.

Sem push. Sem archive e sem upload.
MSG
echo "  commit do bump feito ✓"
echo

echo "═════ 5 · resultado ═════"
git log --oneline -4
