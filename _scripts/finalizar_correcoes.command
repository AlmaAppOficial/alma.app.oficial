#!/bin/bash
# finalizar_correcoes.command
#
# Executa no MAC do Felipe os passos que o Cowork (VM Linux sandboxed) nao
# conseguiu fazer: deploy Firestore rules e commit limpo.
#
# Uso:
#   Duplo-clique no Finder
#   OU: bash ~/Desktop/ALMA/alma.app.oficial-main/_scripts/finalizar_correcoes.command

set -e

cd "$(dirname "$0")/.."
REPO_DIR="$(pwd)"
echo "==> Repo: $REPO_DIR"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 1. Adicionar HealthKitManager.swift ao Xcode (ja foi feito pelo Claude via pbxproj)
# ──────────────────────────────────────────────────────────────────────────────
echo "==> [1/4] Verificando Xcode project..."
if grep -q "HealthKitManager.swift" Alma.App.Oficial.xcodeproj/project.pbxproj; then
  echo "    ✓ HealthKitManager.swift ja esta referenciado no pbxproj"
else
  echo "    ⚠ HealthKitManager.swift NAO esta no pbxproj — abre Xcode e arrasta manualmente"
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 2. Deploy Firestore rules (feed_posts + user_interactions)
# ──────────────────────────────────────────────────────────────────────────────
echo "==> [2/4] Deploy Firestore rules..."
if ! command -v firebase >/dev/null 2>&1; then
  echo "    Firebase CLI nao instalado. Instalando via npm..."
  npm install -g firebase-tools
fi

echo "    Deployando para alma-app-7dae6..."
firebase deploy --only firestore:rules --project alma-app-7dae6 || {
  echo ""
  echo "    ⚠ Deploy falhou. Provavel que precises fazer login primeiro:"
  echo "      firebase login"
  echo "    Depois re-executa este script."
  exit 1
}
echo "    ✓ Rules deployadas"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 3. Commit das correcoes criticas (seletivo — nao agrega edits pre-existentes)
# ──────────────────────────────────────────────────────────────────────────────
echo "==> [3/4] Commit das correcoes criticas..."

# Limpar lock orfao se existir
[ -f .git/index.lock ] && rm -f .git/index.lock

# Remover do index lixo committado
git rm -rf --cached segundo-cerebro/ 2>/dev/null || true
git rm --cached "Alma.App.Oficial.xcodeproj.zip" 2>/dev/null || true
git ls-files | grep -i "\.DS_Store$" | xargs -r git rm --cached 2>/dev/null || true

# Stage apenas os arquivos tocados pelas correcoes criticas
git add \
  .github/workflows/firebase-hosting.yml \
  .gitignore \
  Alma.App.Oficial.xcodeproj/project.pbxproj \
  Shared/Alma_App_OficialApp.swift \
  Shared/HealthKitManager.swift \
  Shared/MainTabView.swift \
  Shared/OpenAIService.swift \
  firestore.rules \
  _archive/ \
  _scripts/ \
  CHANGELOG_CORRECOES_CRITICAS.md 2>/dev/null || true

# Remover refs das pastas arquivadas/ignoradas
git add -u 2>/dev/null || true

echo ""
echo "    Arquivos staged:"
git diff --cached --name-status | head -40
echo ""

read -p "    Quer commitar estas mudancas agora? (s/N): " -n 1 CONFIRM
echo ""
if [[ "$CONFIRM" =~ ^[SsYy]$ ]]; then
  git commit -m "fix: correcoes criticas (build + seguranca + feed rules)

- ios/Alma/ movido para _archive/ (resolve dois @main em conflito)
- HealthKitManager extraido de MainTabView para arquivo proprio (+pbxproj)
- OpenAIService: fallback directo removido (evita leak de API key)
- firestore.rules: regras para feed_posts e user_interactions
- firebase-hosting.yml: projectId alinhado com .firebaserc
- .gitignore: segundo-cerebro, .DS_Store, _archive, zip de backup"
  echo "    ✓ Commit criado"
else
  echo "    ⏭ Pulando commit (rode 'git commit' manualmente quando quiser)"
fi
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 4. Validacao final
# ──────────────────────────────────────────────────────────────────────────────
echo "==> [4/4] Validacao final..."
echo ""
echo "    @main count (esperado: 1):"
grep -rn "^@main" Shared/ ios/ 2>/dev/null | wc -l | xargs echo "    →"
echo ""
echo "    HealthKitManager refs em pbxproj (esperado: 6):"
grep -c "HealthKitManager" Alma.App.Oficial.xcodeproj/project.pbxproj | xargs echo "    →"
echo ""
echo "    firestore.rules tem feed_posts (esperado: >0):"
grep -c "feed_posts" firestore.rules | xargs echo "    →"
echo ""
echo "✅ Pronto. Agora abre o Xcode (Product → Clean Build Folder → Build) e confirma."
echo ""
echo "Em caso de problema no Xcode com HealthKitManager:"
echo "  1. File → Add Files to 'Alma App Oficial'..."
echo "  2. Seleciona Shared/HealthKitManager.swift"
echo "  3. Garante que os 2 targets (iOS + macOS) estao marcados"
