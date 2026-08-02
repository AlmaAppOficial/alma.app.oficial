#!/bin/bash
# Port do módulo Corpo (C&A) para dentro do Alma.
# Copia os fontes da base de integração para Shared/Corpo/ e renomeia os tipos
# que colidem com o Alma (PaywallView, HomeView, InsightsView).
set -u

ORIGEM="/Users/almaappoficial/Desktop/ALMA/CorpoAlma_com_Watch/CorpoEAlma"
DESTINO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo"

rm -rf "$DESTINO"
mkdir -p "$DESTINO"

cp "$ORIGEM"/*.swift "$DESTINO"/ 2>/dev/null
cp "$ORIGEM"/exercises_v2.json "$DESTINO"/ 2>/dev/null

# Arquivos que NÃO vão: o app do C&A tem o próprio ponto de entrada, login e
# assets — dentro do Alma quem manda são os do Alma.
rm -f "$DESTINO"/CorpoEAlmaApp.swift \
      "$DESTINO"/ContentView.swift \
      "$DESTINO"/AuthManager.swift \
      "$DESTINO"/LoginView.swift \
      "$DESTINO"/OnboardingView.swift 2>/dev/null

echo "arquivos portados: $(ls "$DESTINO"/*.swift 2>/dev/null | wc -l)"
ls "$DESTINO"/*.swift | xargs -n1 basename | tr '\n' ' '
echo

# ── Colisões de nome com o Alma ──────────────────────────────────────────────
# Renomeia SÓ as declarações e usos dentro do módulo Corpo.
cd "$DESTINO" || exit 1
for PAR in "PaywallView:CorpoPaywallView" "HomeView:CorpoHomeView" "InsightsView:CorpoInsightsView"; do
  DE="${PAR%%:*}"; PARA="${PAR##*:}"
  # \b para não pegar CorpoHomeView já renomeado nem sufixos
  perl -pi -e "s/\\b${DE}\\b/${PARA}/g" *.swift
  echo "renomeado: $DE -> $PARA"
done

echo
echo "=== conferência pós-rename ==="
echo -n "ainda há 'struct PaywallView' no módulo? "; grep -c 'struct PaywallView\b' *.swift | grep -v ':0' | head -1 || echo "não"
echo -n "CorpoPaywallView declarado: "; grep -l 'struct CorpoPaywallView' *.swift | head -1
echo -n "CorpoHomeView declarado: "; grep -l 'struct CorpoHomeView' *.swift | head -1
echo -n "CorpoInsightsView declarado: "; grep -l 'struct CorpoInsightsView' *.swift | head -1
echo -n "MainTabView (raiz do módulo): "; grep -l 'struct MainTabView' *.swift | head -1
