# Textos da 2.0.1 — novidades e notas do revisor (proposta, 06/08/2026)

Nada foi gravado no App Store Connect. É proposta para o Felipe aprovar.

---

## 1. "Novidades desta versão" (What's New)

**Princípio que segui:** verdade não é a mesma coisa que material de vitrine. A
2.0.1 conserta, entre outras coisas, assinante que pagava e não recebia. Isso é
verdade e está no ACTION_LOG — mas a ficha da loja é lida por quem está
decidindo se assina, e "corrigimos o problema que impedia sua assinatura de
funcionar" transforma um conserto em anúncio de que o app cobrava sem entregar.

Escrevi na voz do app, sem jargão e sem drama, e sem citar o que a pessoa não
consegue ver.

### Proposta

```
Ajustes desta versão:

• No scan de comida, agora você ajusta a quantidade antes de adicionar
  à refeição. A estimativa da IA vem preenchida — corrija se o prato
  tinha mais ou menos que isso, e as calorias e macros acompanham na hora.

• Ao cadastrar um alimento seu, você informa o peso da porção. Os valores
  passam a ser guardados corretamente para a próxima vez que você usar
  o mesmo alimento.

• As notificações agora abrem direto na tela que elas pedem, mesmo com
  o app fechado.

• A tela de assinatura foi reescrita: ela lista exatamente o que o
  Premium inclui, sem citar o que já é gratuito.

• Melhorias na sincronização da assinatura e correções de estabilidade.
```

**Onde cada linha se apoia**

| Linha | Commit |
|---|---|
| porção editável | `9ba23fc` |
| peso da porção no alimento personalizado | `9ba23fc` |
| notificações | `a8bee0e` |
| tela de assinatura | `ad569c1` |
| sincronização da assinatura | `3243399`, `e618d9b`, `4ee4f11`, `b1ddf55` |

**Sobre a última linha, que é a delicada.** "Melhorias na sincronização da
assinatura" é verdadeira e é o padrão da indústria para este caso. Não é
eufemismo vazio: o que mudou foi o app passar a contar ao servidor que a compra
é daquela conta, e o servidor passar a receber o aviso da Apple. Quem for
afetado positivamente é quem já pagou — e essa pessoa não precisa ler na loja
que estava sendo prejudicada; ela precisa que funcione.

**O que deixei DE FORA de propósito**, porque a pessoa não vê: o reparo do
harness, as asserções novas, o índice do Firestore, o lint. Mesma regra que o
Assis aplicou no 91 e no 92.

**Sobre "correções de estabilidade":** quando escrevi isto, ainda não tinha
compilado, e marquei a linha como a única sem lastro. **Ela ganhou lastro no pior
jeito possível.** A compilação revelou três defeitos que impediam o app de ser
construído — dois deles na ponte de assinatura escrita hoje. Se tivessem
chegado ao build, não seria instabilidade: seria um app que não existe. A linha
é honesta e eu a manteria.

**O que continua sem lastro é a primeira linha**, a da porção editável. Ela
descreve interface que ninguém viu funcionar. O harness prova que os números
batem; não prova que o slider redesenha a tela. Enquanto o Felipe não tocar no
build do TestFlight, esta linha é uma promessa apoiada em aritmética.

---

## 2. Notas do revisor — precisam mudar, e mais do que eu esperava

`docs/APPLE_REVIEW_NOTES.md` está **datado de 2026-04-21** e descreve a versão
1.0 rejeitada. Três problemas, em ordem de gravidade:

### ⚠️ ERRO MEU, corrigido — havia dois "trials" e eu tratei como um

**A primeira versão desta seção afirmava que o teste grátis não existe mais.
Estava errada.** Li a asserção `A22a` como se ela cobrisse o paywall inteiro, e
ela cobre só os textos ESTÁTICOS de assinatura. São duas coisas com o mesmo
nome:

1. **A oferta introdutória do StoreKit**, configurada no ASC — **existe**. O
   paywall a exibe quando o StoreKit a devolve (`CorpoPaywallView.swift:114`,
   protegido por `isEligibleForIntroOffer`), ou seja, só para quem tem direito.
2. **O trial local dentro do app** (`isTrialActive`) — não existe, é falso fixo.
   É contra ESTE que a `A22a` existe.

**Reconferido na API do ASC hoje**, `functions/asc_ofertas_intro.mjs`
(read-only, saída em `13_ofertas_intro_asc.txt`):

```
com.almaapp.app.premium_monthly — estado APPROVED
OFERTA INTRODUTÓRIA: 175 registros · 175 valendo hoje (2026-08-06)
tipo=FREE_TRIAL · duração=ONE_WEEK · ciclos=1
início=2026-04-03 · sem data de fim
Brasil: SIM · EUA: SIM
```

**Divergência que vale conferir:** de manhã o número foi **30 territórios**; eu
medi **175**. Minha consulta usou `limit=200` e contou os registros devolvidos —
uma consulta com limite menor devolveria menos. Não sei qual dos dois está certo
e não vou fingir que sei; o que importa para a nota é que a oferta **está
ativa**, inclusive no Brasil, e isso as duas medições concordam.

**Então a menção ao trial FICA nas notas** — omiti-la seria pior: o revisor vê a
oferta na folha da Apple e não encontra explicação. Mas com precisão: é oferta
introdutória da App Store, de uma semana, um ciclo, só para quem ainda não usou.
Nada que sugira trial dentro do app nem direito universal.

### 🔴 As notas listam um produto anual que NÃO EXISTE

Linha 49 do arquivo: `Annual: com.almaapp.app.premium_annual (R$ 499,90/year…)`.

Consultado hoje (`14_produtos_asc.txt`): o app tem **um único** grupo de
assinatura ("Alma Premium", 22008487) com **um único** produto,
`com.almaapp.app.premium_monthly`. Nenhum IAP fora de assinatura. O anual não
existe.

O próprio código já sabe disso — `StoreKitManager.swift:6` diz, em comentário:
*"com.almaapp.app.premium_annual → Assinatura anual — AINDA NÃO EXISTE no ASC"*.
Quem apodreceu foi a nota de abril, não o app.

**Também tirei os preços da nota.** R$ 49,90 / R$ 499,90 são de abril e eu não
tenho como afirmar que valem hoje. Preço em nota de revisor é passivo: muda no
ASC e a nota vira mentira sem ninguém tocar nela. O revisor vê o preço na tela.

### 🟠 Faltam os passos para o revisor testar o que a 2.0.1 mudou

A 2.0.1 mexe em compra e assinatura. A Apple vai olhar. As notas atuais
descrevem só o fluxo de compra do 1.0 — não dizem nada sobre restauração nem
sobre o que fazer se o entitlement demorar.

### 🟡 A pendência crítica do próprio arquivo nunca foi resolvida

Linhas 75-82 dizem que a conta demo `alma.app.oficial@gmail.com` **precisa ser
verificada no Firebase antes de resubmeter**, com um ⚠️ na linha 12. Está lá
desde abril. Se a conta não estiver com onboarding completo, o revisor cai no
onboarding em vez do app — e isso já rendeu rejeição a outros.

### Proposta de texto (o que muda em relação ao de abril)

```
DEMO ACCOUNT — APP LOGIN (Firebase Authentication)
Email: alma.app.oficial@gmail.com
Password: Drifelipe17
NOTE: Account has full profile configured (onboarding complete).

---

SANDBOX TESTER — IN-APP PURCHASE (Guideline 2.1)
Email: alma.sandbox.demo@gmail.com
Password: Drifelipe17
Country: Brazil

Subscription Product ID (there is only one):
- Monthly: com.almaapp.app.premium_monthly

INTRODUCTORY OFFER
This product has an App Store introductory offer: a one-week free trial, one
billing cycle, available to users who have not previously used it. The paywall
shows it only when StoreKit reports the account as eligible
(isEligibleForIntroOffer), so a returning subscriber correctly sees the regular
price instead. There is no separate in-app trial.

WHAT CHANGED IN 2.0.1 REGARDING PURCHASES
This build changes how the app confirms an active subscription. The receipt is
now validated server-side and linked to the signed-in account, and the server
also receives App Store Server Notifications. Previous builds relied on the
client alone, which could leave a paying user without access.

STEPS TO TEST THE SUBSCRIPTION FLOW:
1. Settings > App Store > Sandbox Account: sign in with the tester above
2. Open the app and log in with the Demo Account
3. Open any premium feature (AI chat, or "Escanear com IA" in the Diet tab)
4. Tap "Assinar" and complete the sandbox purchase — no real charge
5. Premium unlocks immediately

STEPS TO TEST RESTORE:
1. With the same sandbox account, delete and reinstall the app
2. Log in with the Demo Account
3. Open the paywall and tap "Restaurar compras" — access is restored

[MANTER SEM ALTERAÇÃO o bloco de account deletion, Guideline 5.1.1.v]

IMPORTANT NOTES:
- The app requires an internet connection (Firebase + OpenAI backend)
- AI features require an active subscription
- Photo analysis sends the image to our server, which forwards it to the AI
  provider. The image is not stored by us. The user consents per submission.
- Account deletion is irreversible
```

**Antes de gravar isto no ASC, três coisas precisam ser conferidas por alguém
que enxerga o console** (eu não consigo daqui):

1. Existe mesmo alguma oferta introdutória configurada nos dois produtos? Se
   existir, a frase "There is NO free trial" passa a ser falsa e o problema
   inverte de lado.
2. Os preços atuais, se você quiser mantê-los na nota. Sugiro **tirar os preços
   da nota** — eles mudam e a nota apodrece, como apodreceu.
3. A conta demo está com onboarding completo no Firebase?
