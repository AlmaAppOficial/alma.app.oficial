# Relatório — sessão de 14/08/2026 (iOS)

Branch `feat/build84-chat-e-ciclos`, HEAD `8519a6c`. Sem push. Nada de
`functions/`, `fastlane/metadata/` ou `HomeView.swift` foi tocado (outras
sessões trabalhando lá). Sem archive, sem upload, sem App Store Connect — a
2.0.2 está em revisão.

Continuação do `RELATORIO_HONESTIDADE_20260813.md`, que deixou dois itens
abertos: **(1)** ligar o sexo na meta calórica e **(2)** compilar.

Evidência de execução: `_validacao_20260814/01_build_conferido.txt`.
Scripts: `_scripts/honestidade_compilar_do_zero.sh` ·
`_scripts/honestidade_conferir_build.sh`.

---

## Item 1 — o campo do onboarding: conferido na fonte, e o Assis não está enganado

**Conclusão: o campo do onboarding é identidade de gênero, não sexo. MAS a
lembrança do Assis aponta para uma tela que existe de verdade e diz "Sexo"
com todas as letras — só que não é o onboarding.** Por isso eu parei aqui em
vez de ligar o dado na fórmula.

### O que a pessoa vê no onboarding (literal, `Shared/OnboardingBiometricsView.swift`)

```swift
:186    // ── Género ────────────────────────────────────────────────
:188    Text("Como você se identifica?")
:191    let genders = ["Feminino", "Masculino", "Não binário", "Prefiro não dizer"]
```

O que é gravado (`Shared/UserMemoryManager.swift:24-29`):

```swift
// Identidade — lida/escrita directamente em UserDefaults (não encriptada, não sensível)
// gender: "Feminino" | "Masculino" | "Não binário" | "Prefiro não dizer"
var gender: String {
    get { UserDefaults.standard.string(forKey: "alma_user_gender") ?? "" }
```

Tipo `String`, chave `alma_user_gender`, `UserDefaults` local. Gravado em
`:438-444` via `UserMemoryManager.shared.setIdentity(gender:...)`.

**Caminho de não responder:** o passo é obrigatório —
`canAdvance` (`:34-38`) trava o "Continuar" com `!selectedGender.isEmpty`.
Mas *"Prefiro não dizer"* **é** uma resposta válida que satisfaz o gate e não
carrega informação de sexo nenhuma. Ou seja: 100% das pessoas respondem,
e uma parte delas responde algo que a fórmula de Mifflin não sabe usar.

### Onde a lembrança do Assis acerta — e isso é o ponto importante

O literal `"Sexo"`, como rótulo visível, existe em **exatamente 5 lugares em
todos os apps do ALMA**, e **todos os 5 são a tela de Meta da Dieta**:

| App | Arquivo:linha |
|---|---|
| Alma iOS | `Shared/Corpo/NutritionEngine.swift:138` |
| Alma Android | `.../corpo/ui/dieta/DietaScreen.kt:494` |
| Corpo & Alma iOS | `CorpoEAlma/NutritionEngine.swift:132` |
| Corpo & Alma (worktree apis) | idem `:132` |
| Corpo & Alma Android | `.../ui/dieta/DietaScreen.kt:454` |

E ali as opções são **exatamente as duas que o Mifflin usa**
(`enum BiologicalSex`, `NutritionEngine.swift:15-20`: Masculino, Feminino).

Então quando o Assis diz *"já perguntamos"* → *"O sexo"*, ele está descrevendo
uma tela real, com o rótulo certo e as opções certas. O que não bate é **onde**
ela fica — e é justamente o *onde* que decide o desenho:

- **Onboarding** — obrigatório, todo mundo passa. Cobertura ~100%.
- **Dieta → "Meta"** (`DietaView.swift:120`) — opt-in, escondido. Cobertura
  perto de zero. Quem nunca abriu essa tela nunca informou sexo nem atividade.

Confirmado por enumeração (não por grep vazio): existe **uma única** tela de
onboarding viva no app (`find` por `*onboard*` → só
`OnboardingBiometricsView.swift`; o `_archive/` é de abril e o
`src/components/OnboardingFlow.tsx` é web, não está no `.pbxproj` — 0
referências —, e não pergunta sexo nem gênero). E **o único escritor** de
`model.sex` no app inteiro é o `Picker` de `NutritionEngine.swift:138`
(mais o `didSet` que persiste, `Models.swift:173`, e o reset de faxina, `:1043`).

### Por que eu não liguei direto

Ligar `alma_user_gender` na fórmula significa decidir, em silêncio e dentro de
uma conta de saúde, que identidade de gênero é sexo biológico — e ainda deixa
"Não binário" e "Prefiro não dizer" sem resposta possível. O rótulo da tela
(*"Como você se identifica?"*) e o comentário do store (*"não sensível"*)
mostram que o campo foi desenhado para outra pergunta.

**Aguardando decisão do Assis.** As opções estão no fim deste documento.

### O `activityLevel` está preso na mesma decisão

`Shared/Corpo/Models.swift:303-304`, uma linha embaixo da outra:

```swift
sex           = BiologicalSex(rawValue: store.string(forKey: "sexBiological") ?? "") ?? .masculino
activityLevel = ActivityLevel(rawValue: store.string(forKey: "activityLevel") ?? "") ?? .leve
```

Os dois `??` alimentam a mesma conta (`suggestedKcalGoal`, `Models.swift:440-444`),
sob o mesmo rótulo *"Calculada pelo seu peso, altura, idade, sexo, atividade e
objetivo"* (`NutritionEngine.swift:124`). Tratar um sem o outro conserta metade
de um número.

**Aritmética conferida por mim, do zero, a partir da fórmula lida em
`NutritionEngine.swift:53-68`** (não é execução do binário):

- termo de sexo no Mifflin: `+5` (masculino) vs `−161` (feminino) = **166 kcal**
  de diferença no BMR;
- o BMR é multiplicado pelo fator de atividade, então o erro que chega no prato
  é maior: **199** (sedentário) · **228** (leve, o padrão) · **257** (moderado) ·
  **286** (intenso) kcal/dia.
- Exemplo — mulher, 65 kg, 165 cm, 35 anos, manter, leve: correto **1850**,
  exibido **2078**. Se ela for sedentária de verdade: **1614** — ou seja, o
  termo de atividade sozinho vale **236 kcal**, mais que o de sexo.

### Onde o conserto encosta, seja qual for o caminho escolhido

`Models.swift:426-437` — a assimetria exata:

```swift
var hasBodyProfile: Bool { weightKg > 0 && heightCm > 0 && ageYears > 0 }

var missingProfileFields: [String] {          // peso, altura, idade…
    ...                                        // …e NÃO sexo, NÃO atividade
}
```

Peso, altura e idade ausentes derrubam a meta para `nil` e a tela diz
*"informe suas medidas"* (`NutritionEngine.swift:119`) — comportamento honesto
que **já existe e já funciona**. Sexo e atividade escapam desse mesmo portão por
causa dos dois `??`. Qualquer um dos caminhos abaixo é, na prática, fazer os
dois entrarem nesse portão que já está construído.

---

## Item 2 — compilação: feita, e a primeira tentativa foi um verde vazio

### A tentativa das 09:07 foi descartada por ela mesma

`_scripts/honestidade_compilar.sh` devolveu **"** BUILD SUCCEEDED **"** — e o
controle positivo deu **0 ocorrências nos 12 arquivos**, com **0 avisos** (a
rodada de ontem tinha 5). Build incremental: como nada mudou desde ontem, o
xcodebuild não recompilou nada. O log tinha zero etapas de Swift.

**Um verde que não type-checou uma única linha.** Mesma família do `strings` no
`.apk` que mediu o nada porque o DEX estava comprimido. Quem gritou foi o
controle positivo — sozinho, o "BUILD SUCCEEDED" teria passado por prova.

Por causa disso o conferidor ganhou um **segundo canário**: o log *tem* de
conter etapas de compilação Swift; sem isso, o controle positivo é verdade
vácua e o script diz isso em voz alta.

### A rodada válida: do zero, em DerivedData próprio

`_scripts/honestidade_compilar_do_zero.sh` — `-derivedDataPath /tmp/...`.
**Sem `clean`** (o DerivedData padrão é compartilhado com as outras sessões) e
**sem `touch` em arquivo nenhum** (o `HomeView.swift` é da outra sessão).

```
etapas de compilacao Swift no log: 786    <- canário 2: houve compilação de verdade
** BUILD SUCCEEDED **   ·   erros: 0   ·   avisos: 5 (3 únicos)

CONTROLE POSITIVO — o build viu cada arquivo:
  RegrasDeSaude 6 · CycleCalculator 6 · HealthKitManager 6 · HomeView 12
  InsightsView 12 · FeminineHealthView 6 · OpenFoodFacts 6 · AddFoodView 6
  SupplementsView 6 · Models 12 · NutritionEngine 6 · OnboardingBiometricsView 6
CONTROLE NEGATIVO — "Shared/Shared" no log: 0
CANÁRIO 1 — arquivo inexistente: 0 (busca discrimina)
avisos nos arquivos mexidos em 13/08: 0
```

Os 3 avisos únicos são pré-existentes e nenhum é dos arquivos da faxina:
metadata de AppIntents, coerção de `UIView?` para `Any`, e uma propriedade
`main actor-isolated` (erro no modo Swift 6).

Com isto, as assinaturas que viraram opcionais em 13/08 (`steps: Int?`,
`stressLevel: StressLevel?`, `asFoodItem: FoodItem?`, `stepsFormatted: String?`)
estão verificadas **pelo compilador**, não por leitura.

### A ressalva honesta

Às 09:07 o working tree não tinha nenhuma fonte Swift suja. Às 09:12, no fim do
build, tinha: **`M Shared/HomeView.swift` e `M Shared/MainTabView.swift`** — a
outra sessão começou a editar durante a minha compilação. Então, para **esses
dois arquivos**, o que compilou foi a versão em voo dela, não a de `8519a6c`
(compilou limpo, mas é outra coisa). Para os outros 10 o verde é do commit.

Para `HomeView.swift` em `8519a6c`, a evidência mais forte continua sendo o log
de ontem (`_validacao_20260813/51_build_resultado.txt`: HomeView 12 ocorrências,
0 erros, mesmos controles).

---

## O que continua sem prova

1. **Nenhuma tela foi vista.** Zero capturas nesta sessão. Tudo provado na regra
   e no compilador, nada no pixel.
2. **Item 1 não foi implementado** — de propósito, aguardando a decisão abaixo.
3. Os itens 3, 4 e 5 da lista de ontem seguem abertos (macros ausentes colapsando
   em 0 no `FoodItem`; `isFinite` inalcançável via JSON; DPP implausível).

---

## A decisão que preciso do Assis

O dado que existe hoje, obrigatório e com cobertura alta, é **identidade de
gênero com 4 opções**. O dado que a fórmula precisa é **sexo biológico com 2**.
As opções, com o custo de cada uma dita na cara:

**A — Derivar do gênero já coletado, e mostrar o pressuposto na tela.**
*Feminino* → feminino, *Masculino* → masculino, *Não binário / Prefiro não
dizer* → sem número (cai no "informe suas medidas" que já existe). Debaixo da
meta, uma linha: *"Calculada usando Feminino. Não é isso? Ajuste aqui."* — o
`Picker` que corrige já está dez pontos abaixo na mesma tela.
· Cobre quem já tem o app instalado, sem migração e sem pergunta nova.
· **Custo:** identidade não é sexo. Derivar é um padrão, não uma verdade — por
isso o pressuposto tem de aparecer escrito e ser trocável num toque.

**B — Perguntar sexo biológico no onboarding**, no passo 2 (o de peso e altura),
separado da pergunta de identidade e explicado como insumo da fórmula.
· O dado passa a ser o certo, sem derivação.
· **Custo:** segunda pergunta sobre o mesmo território; e **não resolve quem já
está instalado** — para esses, o A continua necessário de qualquer jeito.

**C — Não calcular sem confirmação.** Sexo e atividade entram em
`missingProfileFields`; sem eles, a tela diz "informe suas medidas" em vez de um
número.
· É o mais honesto e o mais simples de provar.
· **Custo:** todo mundo que nunca abriu Dieta → Meta perde a meta sugerida da
noite para o dia. É mudança de produto, não conserto de bug — por isso não faço
sem o seu OK.

**D — Deixar como está por enquanto** e voltar depois da 2.0.2 sair da revisão.

Minha recomendação continua sendo **A + B juntos** (A resolve o instalado, B
resolve quem entra a partir de agora), e o `activityLevel` tratado no mesmo
movimento — senão conserta-se metade de um número e a outra metade continua
mentindo com a mesma cara.
