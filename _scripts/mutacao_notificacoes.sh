#!/bin/bash
# TESTE DE MUTAÇÃO — encaminhamento por toque em notificação (2026-08-05)
#
# Mesmo contrato de _scripts/mutacao.sh: para cada mutação, aplica → verifica →
# restaura. ESPERADO = VERMELHO. Mutação que passa VERDE denuncia uma prova
# inútil, e é ela que vale reportar.
#
# LEIA ISTO ANTES DE CONFIAR NO VERDE
# ═══════════════════════════════════════════════════════════════════════════
# Este script exercita o LINT ESTÁTICO (lint_wiring.py). Ele prova que as
# linhas de produção existem e que apagá-las deixa o portão vermelho.
# Ele NÃO prova que o iOS entrega o toque, nem que a aba muda na tela.
#
# A parte que roda de verdade (o mapa identificador→destino e a sobrevivência
# do destino à partida fria) está nas asserções R0..R7 do
# AuditoriaBloqueadores, que rodam no aparelho/simulador em DEBUG. As mutações
# M-R9 e M-R10 abaixo são as delas, e para ficarem vermelhas precisam de um
# build — por isso estão marcadas como NÃO EXECUTADAS aqui e listadas ao final
# como dívida declarada, e não como verde.
# ═══════════════════════════════════════════════════════════════════════════
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1

LINT="python3 _scripts/lint_wiring.py ."
verde=0; vermelho=0; furos=()

# $1 = id · $2 = arquivo · $3 = sed expr · $4 = verificação · $5 = descrição
mutar() {
  local id="$1" arq="$2" expr="$3" verif="$4" desc="$5"
  cp "$arq" "/tmp/mutn_backup_$$"
  sed -i '' "$expr" "$arq"

  if ! diff -q "/tmp/mutn_backup_$$" "$arq" > /dev/null; then
    if eval "$verif" > /tmp/mutn_out_$$ 2>&1; then
      echo "  ✗ $id  VERDE com o bug dentro — PROVA INÚTIL: $desc"
      furos+=("$id — $desc"); verde=$((verde+1))
    else
      echo "  ✓ $id  vermelho, como deve ser: $desc"
      vermelho=$((vermelho+1))
    fi
  else
    echo "  ! $id  a mutação não alterou o arquivo (padrão não casou) — $desc"
    furos+=("$id — mutação não aplicada"); verde=$((verde+1))
  fi

  cp "/tmp/mutn_backup_$$" "$arq"; rm -f "/tmp/mutn_backup_$$" /tmp/mutn_out_$$
}

echo "═════ MUTAÇÃO — notificações levam à tela certa ═════"
echo

# ── Base: o lint tem de estar VERDE antes de qualquer mutação. Um lint já
#    vermelho faria toda mutação "passar" por motivo errado.
if ! $LINT > /tmp/mutn_base_$$ 2>&1; then
  echo "ABORTADO: o lint já está vermelho ANTES das mutações."
  cat /tmp/mutn_base_$$; rm -f /tmp/mutn_base_$$
  exit 2
fi
echo "  base: lint verde antes de mutar ✓"
rm -f /tmp/mutn_base_$$
echo

mutar "M-R1" "Shared/AlmaApp.swift" \
  's|RotaDaNotificacao\.destino(identificador:|MUTANTE_ROTA(identificador:|' \
  "$LINT" "o delegate volta a tratar só o push do feed"

mutar "M-R2" "Shared/MainTabView.swift" \
  's|^        .onAppear { encaminharNotificacaoPendente() }$|        // MUTANTE|' \
  "$LINT" "APP FECHADO: some o onAppear e a partida fria perde o destino"

mutar "M-R3" "Shared/MainTabView.swift" \
  's|.onChange(of: roteador.pendente)|.onChange(of: roteador.MUTANTE)|' \
  "$LINT" "APP EM SEGUNDO PLANO: some o onChange"

mutar "M-R4" "Shared/HomeView.swift" \
  's|^            showChat = true$|            // MUTANTE|' \
  "$LINT" "a Início deixa de abrir o chat pelo destino"

mutar "M-R5" "Shared/Corpo/RootTabView.swift" \
  's|^        selection = aba.rawValue$|        // MUTANTE|' \
  "$LINT" "o almoço para de chegar na Dieta: o módulo abre sempre na Início"

mutar "M-R6" "Shared/Corpo/NotificationManager.swift" \
  's|^        content.userInfo = RotaDaNotificacao.carimbo(para: id)$|        // MUTANTE|' \
  "$LINT" "os lembretes do Corpo saem sem carimbo de destino"

mutar "M-R7" "Shared/LembretesDaAlma.swift" \
  's|^        content.userInfo = RotaDaNotificacao.carimbo(para: id)$|        // MUTANTE|' \
  "$LINT" "os lembretes de meditação saem sem carimbo"

mutar "M-R8" "Shared/AddictionFreeView.swift" \
  's|^                content.userInfo = RotaDaNotificacao.carimbo(para: "addiction_\\(msg.hours)")$|                // MUTANTE|' \
  "$LINT" "os marcos de vício saem sem carimbo"

mutar "M-R9" "Alma.App.Oficial.xcodeproj/project.pbxproj" \
  's|LembretesDaAlma.swift in Sources \*/ = {isa = PBXBuildFile|HabitNotificationManager.swift in Sources */ = {isa = PBXBuildFile|' \
  "$LINT" "alguém registra o HabitNotificationManager no target sem revisar a dívida"

echo
echo "═════ RESULTADO ═════"
echo "vermelhas (boas): $vermelho · verdes (furos): $verde"
if [ ${#furos[@]} -gt 0 ]; then
  echo "FUROS:"
  for f in "${furos[@]}"; do echo "   ✗ $f"; done
fi

echo
echo "═════ NÃO PROVADO AQUI — dívida declarada, não verde ═════"
echo "  M-R9  · asserção R5 (destino sobrevive à partida fria): mutação = trocar"
echo "          o estado guardado por NotificationCenter.post. Só fica vermelha"
echo "          rodando o harness em DEBUG no simulador — exige build."
echo "  M-R10 · asserção R2 (almoço → Dieta): mutação = trocar o destino no"
echo "          catálogo. Mesma condição."
echo "  SEM XCUITEST: nada aqui prova que o iOS chama o delegate ao tocar na"
echo "  notificação, nem que a aba muda NA TELA. Ver CLAUDE.md, 'XCUITest"
echo "  ausente'. Isso é uma cegueira conhecida e está declarada de propósito."

[ ${#furos[@]} -eq 0 ] || exit 1
