# 2.0.1 (build 94) — o que aconteceu hoje

06/08/2026 · branch `feat/build84-chat-e-ciclos` · **nada enviado para revisão**

---

## A descoberta que explica o dia

**O Xcode foi atualizado para 26.6 ontem às 18:44 e as plataformas iOS 26.5 e
watchOS 26.5 nunca foram baixadas.** Resultado: `xcodebuild -showdestinations`
não listava **nenhum** destino elegível — nem simulador, nem device. A máquina
passou o dia inteiro sem conseguir compilar nada.

Isso não é curiosidade de ambiente. É a causa raiz de tudo o que veio depois:
**os seis commits de entitlement/paywall de hoje entraram sem uma única
compilação**, e três defeitos que qualquer build teria pego passaram direto.

Baixadas: iOS 26.5 (8,52 GB) e watchOS 26.5 (3,96 GB).

---

## Os três quebra-builds encontrados, todos de hoje

| # | Defeito | Origem | Commit do reparo |
|---|---|---|---|
| 1 | `Invalid redeclaration of 'semPremium'` (`:252` e `:562`, mesmo escopo) | `4944881` | `6738d81` |
| 2 | `A27a/b/c` duplicados com o bloco de HealthKit de 05/08 | `4944881` | `6738d81` |
| 3 | `path = "Shared/AlmaEntitlementBridge.swift"` dentro do grupo `Shared` → procurava em `Shared/Shared/` | `e618d9b` | `66cb823` |
| 4 | `transacao.jwsRepresentation` — a propriedade é do `VerificationResult`, não da `Transaction` | `e618d9b` | `66cb823` |

O defeito 3 é **literalmente o mesmo** que a `366c1ac` consertou em 05/08 no
`RotaDaNotificacao.swift`, com a mesma correção. Varri o pbxproj: era a última
ocorrência do padrão.

O defeito 4 não é detalhe de API. O JWS é o **envelope assinado**; `Transaction`
é o que sobra depois de abri-lo. Um payload já aberto não provaria nada ao
servidor — que verifica assinatura, pelo mesmo caminho do `appleNotifications`.

---

## O trabalho pedido: a porção deixa de ser um decreto

**`FoodScanView`** — a estimativa da IA vem preenchida como ponto de partida e
agora é ajustável antes de confirmar; os quatro números recalculam à vista. A
estimativa não é sobrescrita: a tela continua dizendo "A IA estimou 250 g", com
um toque para voltar. Um único `let gramas` alimenta os tiles, o rótulo do botão
e o registro.

**`CustomFoodForm`** — campo "Peso da porção (g)", pré-preenchido com 100 (em
100 a conversão é identidade, então quem ignorar o campo recebe o comportamento
antigo). O `Meal` recebe o número digitado intacto; a conversão para 100 g fica
só no item de catálogo.

**Dívida registrada:** `MealDetailView` existe, está no target, **não é
alcançável** e **não edita nada**. Anotado no topo do arquivo e no `CLAUDE.md`,
para quem pegar a 2.1 não achar que há meio caminho andado.

---

## O que foi provado, e por qual meio

| Prova | Resultado | Meio |
|---|---|---|
| Lint de wiring | 30 regras, 0 falhas | execução |
| Mutação do lint | **7 mutações, 7 vermelhas, 0 furos** | execução |
| **Compilação** | **BUILD SUCCEEDED (exit 0)**, Debug, iPhone 17 Pro Max, SDK 26.5 | execução |
| **Harness em runtime** | **135 aprovados, 2 reprovados** | execução |
| Archive | ARCHIVE SUCCEEDED · iPhone **e** Watch, ambos `2.0.1 (94)` | execução |
| Export | EXPORT SUCCEEDED · IPA de 348 MB | execução |
| Validação da Apple | **VERIFY SUCCEEDED with no errors** | execução |
| Upload | **UPLOAD SUCCEEDED** · Delivery `0c662fca-5ae9-4238-a234-8fd9272598e4` | execução |

**As duas reprovadas são `A26d` e `A27g`** — exatamente as duas que a `366c1ac`
já declarava vermelhas de propósito desde 05/08. Nenhuma reprovação nova.

**As oito asserções da porção editável passaram**, com os números que eu tinha
calculado à mão antes de existir compilador:

```
✓ E0  comparador vivo — estimativa=520kcal vs ajuste=936kcal
✓ E1  exibido=936kcal/122P/18C/41G · registrado=936kcal/122P/18C/41G
✓ E1b ajustado=936 (esperado 936) · estimado=520
✓ E2  botão=450 · diário=450 · "Adicionar 450 g à Almoço" / "Prato de teste · 450 g"
✓ E2b extrator distingue: 250→250 · sem número→nil
✓ E3  estimativa=520 · parametrizada=520 · ajustada=936
✓ E4  600 kcal em 350 g → 171 kcal/100 g
✓ E4b em 100 g=600 (identidade) · em 350 g=171 (não é cópia)
```

---

## O que CONTINUA sem prova

1. **Ninguém viu a tela.** Nada aqui prova que arrastar o slider redesenha os
   quatro números. `E-W4` prova que o controle escreve no estado, `E-W2` que os
   tiles leem a mesma variável do registro — o elo "e o pixel mudou" segue sem
   prova, como desde 05/08. Sem XCUITest não dá. **É por isso que o build no
   TestFlight precisa passar pela mão do Assis antes de ir para revisão.**
2. **O fluxo de compra não foi exercitado.** Os reparos do entitlement fazem o
   app compilar e o JWS certo viajar. Que a assinatura de fato chegue ao
   servidor e destrave o acesso é coisa de sandbox num aparelho.
3. **A porção editável nunca foi usada por uma pessoa.** A aritmética está
   provada; a ergonomia não. Se o passo de −/+ for pequeno demais ou o slider
   difícil de mirar, só um toque revela.

---

## Correção de uma afirmação minha, no mesmo dia

Escrevi, na primeira versão das notas do revisor, que **o teste grátis não
existe mais**. Estava errado, e o Felipe pegou.

Li a asserção `A22a` como se cobrisse o paywall inteiro. Ela cobre só os textos
**estáticos**. Há dois "trials" com o mesmo nome:

- a **oferta introdutória do StoreKit**, configurada no ASC — **existe**,
  `FREE_TRIAL`, uma semana, um ciclo, desde 03/04/2026, e o paywall a exibe só
  para quem é elegível;
- o **trial local no app** (`isTrialActive`) — não existe, é falso fixo, e é
  contra este que a `A22a` foi escrita.

Reconferido hoje na API do ASC (`functions/asc_ofertas_intro.mjs`, read-only).
**Divergência não resolvida:** de manhã contaram 30 territórios, eu contei 175.
Não sei qual está certo; as duas medições concordam que a oferta está ativa,
inclusive no Brasil.

**Achado adjacente:** o ASC tem **um único** produto de assinatura,
`com.almaapp.app.premium_monthly`. O `premium_annual` que as notas de abril
listam **não existe** — o próprio `StoreKitManager.swift:6` já dizia isso em
comentário. As notas de abril apodreceram; o app não.

---

## O que está esperando decisão

- **Enviar para revisão** — bloqueado por escolha do Felipe, por duas razões
  boas: ninguém tocou na tela nova, e os screenshots da 2.0.1 estão sendo
  refeitos noutra sessão (os atuais têm banner de trial que não vale mais).
- **Texto de novidades e notas do revisor** — proposta em
  `_validacao_20260806/12_textos_da_2_0_1.md`, nada gravado no ASC.
- **Três coisas que preciso que alguém confira no console**, listadas no fim
  daquele arquivo: a contagem real de territórios da oferta, se vale manter
  preço na nota, e se a conta demo está com onboarding completo no Firebase.
