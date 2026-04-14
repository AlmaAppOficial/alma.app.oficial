# Correções Críticas — 2026-04-14

Aplicadas automaticamente pelo Claude para destravar build e produção.

## 🔴 Problemas resolvidos

### 1. Dois `@main` em conflito (quebrava build)
- **Antes:** `Shared/AlmaApp.swift:30` **e** `ios/Alma/AlmaApp.swift:21` declaravam `@main`. Compilador recusa.
- **Agora:** `ios/Alma/` foi movido para `_archive/ios_Alma_refactor_paralelo_20260414/`. Único `@main` é `Shared/AlmaApp.swift`.
- **Ação Xcode necessária:** remover a referência à pasta `ios/Alma` do target "Alma App Oficial" no Xcode (File → remove reference). Pasta `ios/AlmaTests/` continua no lugar.

### 2. `Alma_App_OficialApp.swift` placeholder vazio
- **Antes:** ficheiro vazio, confuso.
- **Agora:** neutralizado com header claro indicando que é DEPRECATED e não deve conter código.
- **Ação Xcode necessária:** quando for seguro, remover do target e apagar do disco.

### 3. `HealthKitManager` + `StressLevel` dentro de `MainTabView.swift`
- **Antes:** 128 linhas de HealthKit misturadas com a view de tabs (213 linhas totais).
- **Agora:**
  - Criado `Shared/HealthKitManager.swift` (137 linhas) com `StressLevel` + `HealthKitManager`.
  - `Shared/MainTabView.swift` reduzido de 213 → 87 linhas.
- **Ação Xcode necessária:** adicionar `HealthKitManager.swift` ao target no Xcode (drag-drop para o Project Navigator).

### 4. Fallback OpenAI direto (risco de leak da API key)
- **Antes:** `OpenAIService.swift` chamava OpenAI directamente se houvesse `OPENAI_API_KEY` no Info.plist — qualquer um com IPA extraía a chave.
- **Agora:** função `callOpenAIDirect` removida, comentários claros indicando porquê. Toda comunicação passa pela Cloud Function autenticada com rate-limit.

## 🟡 Problemas resolvidos

### 5. Divergência de projectId Firebase Hosting
- **Antes:** `.github/workflows/firebase-hosting.yml` → `projectId: almaappoficial`; `.firebaserc` → `alma-app-7dae6`. Deploy apontava para projeto errado.
- **Agora:** workflow alinhado com `.firebaserc` (`alma-app-7dae6`).

### 6. Regras Firestore faltantes para Feed
- **Antes:** `FirestoreFeedRepository` usa collections `feed_posts/` e `user_interactions/{uid}/posts/`, mas nenhuma regra existia → Firebase bloqueia por default deny.
- **Agora:** `firestore.rules` inclui:
  - `feed_posts/{postId}` → read autenticado, write só via Admin SDK
  - `user_interactions/{userId}/posts/{postId}` → read/write apenas pelo próprio user
- **Acção necessária:** `firebase deploy --only firestore:rules` para aplicar em produção.

### 7. Arquivos de lixo no repo
- **Antes:** `segundo-cerebro/` (notas Obsidian pessoais), `Alma.App.Oficial.xcodeproj.zip` (backup do Xcode), `_archive/`, `.DS_Store` — todos commitados.
- **Agora:** adicionados ao `.gitignore`. Os arquivos já trackeados não são removidos automaticamente — rodar:
  ```bash
  git rm -rf --cached segundo-cerebro/
  git rm --cached Alma.App.Oficial.xcodeproj.zip
  git commit -m "chore: ignorar segundo-cerebro e zip de backup"
  ```

## 📁 Arquivos modificados
```
.github/workflows/firebase-hosting.yml        (projectId corrigido)
.gitignore                                    (novas entradas)
Shared/AlmaApp.swift                          (inalterado — único @main)
Shared/Alma_App_OficialApp.swift              (neutralizado)
Shared/HealthKitManager.swift                 (NOVO — extraído)
Shared/MainTabView.swift                      (reduzido 213→87 linhas)
Shared/OpenAIService.swift                    (fallback inseguro removido)
firestore.rules                               (regras feed + user_interactions)
ios/Alma/                                     (movido para _archive/)
```

## ⏭️ Próximos passos (não-críticos, mas recomendados)

1. **Bundle ID unificado** — decidir entre `com.almaapp.app` vs `AlmaOficial.Alma` e alinhar Xcode + Capacitor + App Store Connect.
2. **Firebase App Check** — activar Apple App Attest no Firebase Console e integrar no iOS para blindar API keys.
3. **Crashlytics** — adicionar `FirebaseCrashlytics` ao SPM e inicializar em `AppDelegate`.
4. **Server-side receipt validation** para IAP — evitar burla via jailbreak.
5. **ATT prompt** (App Tracking Transparency) antes de Meta CAPI/Pixel no iOS.
6. **Rotar chaves** se o repo já foi público: Firebase API_KEY, Facebook Client Token, OPENAI_API_KEY no GCP.

## ✅ Verificações executadas
- `grep -rn "^@main" Shared/ ios/` → apenas 1 resultado (`Shared/AlmaApp.swift:30`)
- `grep -rn "class HealthKitManager"` → apenas 1 resultado (`Shared/HealthKitManager.swift:41`)
- `grep -rn "callOpenAIDirect\|openAIKey"` → 0 resultados
- `.firebaserc` + `firebase-hosting.yml` ambos apontam para `alma-app-7dae6`
- `firestore.rules` tem 4 ocorrências de `feed_posts`/`user_interactions`
