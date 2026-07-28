# Alma iOS — pendente para o build 83

**Situação:** o build 82 está **em distribuição** na App Store, sem nada bloqueando.
As mudanças abaixo já estão no código local e sobem no próximo build. Nada foi
commitado (regra do projeto).

---

## 1. Paywall — Guideline 3.1.2(c) · `Shared/SubscriptionView.swift`

Correção **preventiva**: a Apple rejeitou exatamente este padrão no Corpo & Alma
em 28/07. O Alma passou na revisão do 82 com a versão antiga, mas o mesmo
critério pode ser aplicado na próxima submissão.

| | Antes (build 82, no ar) | Agora (build 83) |
|---|---|---|
| Destaque | "7 dias grátis" — 20pt bold branco | **preço/mês — 28pt bold rounded** |
| Subordinado | preço em `subheadline`, opacidade 65% | trial em `footnote`, opacidade 85% |
| CTA | "Iniciar 7 dias grátis" | **"Assinar agora"** |

O texto do trial **permanece** na tela — a 3.1.2 exige divulgar a duração do
teste. O que mudou foi só a hierarquia visual.

## 2. "7 dias grátis" só para quem é elegível — `StoreKitManager` + `HomeView` + `SubscriptionView`

A oferta introdutória é consumida **uma vez por Apple ID / grupo de assinatura**.
O app nunca consultava isso: `bannerSubtitle` do `HomeView` devolvia
`"7 dias grátis · Acesso completo"` como texto padrão para **todo** usuário fora
do trial. Quem já tivesse assinado e cancelado veria uma promessa que a App Store
não honraria na compra — alegação enganosa (3.1.2).

**Fix:** `StoreKitManager.isEligibleForIntroOffer`, alimentado por
`Product.SubscriptionInfo.isEligibleForIntroOffer` após o carregamento dos
produtos. O banner da Home e a nota do paywall só mencionam o teste quando o
StoreKit confirma. Começa `false` e só vira `true` com confirmação — em falha de
rede preferimos deixar de anunciar um teste real a anunciar um inexistente.

*(Mesmo fix aplicado no Corpo & Alma: `StoreManager.isEligibleForIntroOffer` +
`PaywallView`, incluindo o texto legal, que agora só cita a conversão do teste
quando ele existe.)*

## 3. Paywall para assinante — `Shared/PaywallTriggerManager.swift`

Bug do audit de 25/jul: nenhum dos dois gatilhos (1ª meditação concluída e
verificação no launch) checava premium — **assinante pagante via paywall**.

Guarda `hasPremiumAccess` adicionada nos dois pontos, lendo os flags do App Group
`group.com.almaapp.shared`:
- `alma_isPremium` (StoreKit, custom claims ou trial, publicado pelo AccessManager)
- `corpoealma_isPremium` + `..._updatedAt`, validade de 30 dias

Cobre a **assinatura única**: quem assina o Corpo & Alma não vê paywall no Alma,
e vice-versa.

---

## Antes de fechar o build 83

- [ ] Confirmar no **App Store Connect** que os produtos `com.almaapp.app.premium_monthly`
      e `.premium_annual` têm oferta introdutória **Free · 1 semana** ativa no Brasil.
      O `.storekit` local só governa o simulador; se a oferta não existir em
      produção, "7 dias grátis" vira alegação falsa (2.3).
- [ ] Bump `CURRENT_PROJECT_VERSION` **82 → 84** (o `.pbxproj` no disco diz 82,
      mas o aparelho roda **v1.0.4 (83)** — o 83 foi gerado fora deste arquivo,
      então 83 já está queimado)
- [ ] Testar o paywall **em modo escuro** (foi o que derrubou o C&A no Guideline 4)

## Limpeza opcional (não bloqueia)

`Shared/PaywallView.swift` e `Shared/DynamicPricingManager.swift` têm **0
referências no `project.pbxproj`** — não compilam, não vão para o binário. Por
isso o social proof fictício que ainda vive neles ("4.8 ★ · 2.400 avaliações",
"500+ meditações") nunca chegou a nenhum usuário. Vale apagar os dois arquivos
para o repositório não guardar armadilha.

---

## ⚠️ Trabalho local não commitado (risco de perda)

O repositório tem **20 arquivos modificados** e nenhum commit local pendente —
ou seja, tudo o que foi feito desde julho existe só no disco. Inclui o
`project.pbxproj` que coloca `StreakManager` e `PaywallTriggerManager` nos
targets: **sem ele, o Bug 3 (streak) regride**.

Não commito por regra sua. Mas vale um commit quando você achar seguro — hoje um
`git checkout` acidental apaga semanas de trabalho.

*Nota: antes de qualquer commit em massa, adicionar `GoogleService-Info.plist` ao
`.gitignore` do Corpo & Alma.*
