# Relatório — "ausência é ausência, não zero" (iOS, 13/08/2026)

Branch `feat/build84-chat-e-ciclos`. Nenhum build, archive, TestFlight ou App
Store Connect — a 2.0.2 está em revisão. Nenhum arquivo de `functions/` ou
`fastlane/metadata/` foi tocado (duas outras sessões trabalhando lá).

Evidências de execução: `_validacao_20260813/`.
Harness: `_scripts/testes_saude_honesta.swift` · `_scripts/mutacao_saude_honesta.sh`.

---

## Os seis itens, confirmados na fonte antes de qualquer edição

| # | Onde | Confirmado? | Observação |
|---|---|---|---|
| 1 | `FeminineHealthView.swift:592-628`, `:694-700` | **sim** | `pregnancyWeeks` devolvia `0`; `CycleCalculator.trimester(weeks: 0)` = 1 → card "Trimestre 1" com o texto sobre os órgãos do bebê |
| 2 | `Corpo/Models.swift:303`, `NutritionEngine.swift:138` | **sim, e pior que o relatado** | ver §Item 2 |
| 3 | `Corpo/OpenFoodFacts.swift:159-162` | **sim** | `n?.kcal ?? 0` — a distinção existe no JSON e morria no parse |
| 4a | `InsightsView.swift:254-255` | **sim** | única das 4 linhas sem portão `> 0` |
| 4b | `HealthKitManager.swift:229-240` vs `:311-318` | **sim** | fallback para ontem só no caminho da tela; `stepsToday()` sem ele |
| 4c | `HealthKitManager.swift:210-220` + `HomeView.swift:480-482` | **sim** | portão aceitava FC, conta usa só HRV, `else { .low }` = "Relaxado" |

---

## O que ficou VERMELHO (mutação) — a prova

`./_scripts/mutacao_saude_honesta.sh` → **exit 0 · 8 etapas como esperado · 0 problemas**.
Base: **33 asserções, todas verdes**, com o exit code do `swiftc` registrado no
log (`[swiftc exit=0 · binario gerado: …]`).

| Mutação | Defeito replantado | Asserções que caíram |
|---|---|---|
| M1 | `pregnancyDisplay` volta a devolver semana 0 sem DPP | `G1 G1b G1c G1d` |
| M2 | `passosDeHoje` volta a tratar 0 como medição | `P1 P3` |
| M3 | `nivelDeStress` volta ao `else { .low }` | `S1 S1b` |
| M4 | parse da Open Food Facts volta ao `?? 0` | `N1 N1c N1d` |
| M5 | **canário do verificador** — harness morre no meio | detector acusou o encolhimento |

Fecho: verde de novo após restaurar, e os três arquivos mutados **byte a byte
idênticos** ao original.

### As armadilhas que o script fecha

- **Binário velho.** `rm -f "$BIN"` antes de cada compilação, e conferência de
  que o executável foi gerado. Um `swiftc` que falha em silêncio não deixa o
  script rodar a medição anterior.
- **Compilação não conferida.** O exit code do `swiftc` é capturado e vira um
  **terceiro resultado gritado** (`MUTAÇÃO INVÁLIDA — NÃO COMPILOU`), nunca
  confundido com "reprovou".
- **Asserção de ordem sem exigir existência.** Não há nenhuma comparação por
  posição neste harness; toda asserção compara valor contra valor esperado.

### Dois erros meus que o próprio harness pegou — e ficam registrados

1. **Contador cego.** A primeira versão contava asserções no shell com
   `grep -c '^  [✓✗] '`. Bracket expression com caractere multibyte não casa
   fora de um locale UTF-8: devolvia **0 sempre**, e a checagem "o harness
   encolheu?" passava comparando 0 com 0. Verdade vácua dentro do verificador.
   Corrigido: o harness imprime `TOTAL_ASSERCOES=N` em ASCII e o script aborta
   se não conseguir ler o número.

2. **Asserção que não provava o que dizia.** `P1b` testava `.nan` alegando
   proteger a guarda `isFinite`. Mas `Double.nan > 0` é **falso** — o `> 0`
   sozinho já rejeitava o NaN, e a asserção passava com ou sem a guarda. Quem
   discrimina é o **infinito** (`.infinity > 0` é verdadeiro e
   `Int(Double.infinity)` derruba o app). `P1b`/`S1b` passaram a usar infinito;
   os casos NaN viraram `P1c`/`S1c`, rotulados como guarda de regressão e
   **não** como prova de `isFinite`. Foi o canário M5 que revelou isto.

---

## O que continua SEM PROVA

1. **Nenhuma tela foi vista.** Zero capturas. O estado vazio da gravidez, o
   novo alerta "Sem valores nutricionais", o "—" nos passos e o sumiço do badge
   "Relaxado" estão provados na REGRA, nunca no pixel.

2. ~~O alvo iOS não foi compilado.~~ **RESOLVIDO — e o compilador achou um
   defeito real que a varredura mecânica não pegava.** Ver §Compilação.

3. **Macros ausentes ainda colapsam em 0** no `FoodItem` (a energia, não). Está
   comentado no código como fronteira consciente: `FoodItem`/`StoredFood`
   carregam macros como `Int` não-opcional e `StoredFood` é `Codable` em
   `UserDefaults` — torná-los opcionais é refatoração da dieta inteira com um
   decodificador sintetizado no meio, que não cabia aqui.

4. **`inteiro(_:)` — a guarda `isFinite` é inalcançável via JSON.** A asserção
   `N4` tentou `1e400` e o próprio `JSONDecoder` recusou antes. Declarado no
   log em vez de escondido atrás de um verde.

5. **DPP implausível** (data mais de 280 dias no futuro) continua caindo em
   semana 0 com "Faltam N dias" — coerente, mas não validado como entrada.

---

## Compilação — autorizada pelo Assis, e valeu a pena

`xcodebuild build`, esquema `Alma.App.Oficial (iOS)`, Debug, simulador.
**Só compila:** sem archive, sem export, sem upload, sem tocar no App Store
Connect (a 2.0.2 está em revisão). Script: `_scripts/honestidade_compilar.sh`,
que também **não mexe em DerivedData** — há outras sessões vivas no repositório.

### Primeira rodada: BUILD FAILED, 4 erros — e o erro era meu

```
error: Build input file cannot be found:
'…/alma.app.oficial-main/Shared/Shared/RegrasDeSaude.swift'
```

`Shared/Shared`. Ao registrar o arquivo novo no projeto passei
`Shared/RegrasDeSaude.swift` como caminho, mas o grupo do Xcode já carrega
`Shared/` na base — então o caminho foi concatenado duas vezes. O
`PBXFileReference` correto é `path = RegrasDeSaude.swift`, igual ao do
`HealthKitManager.swift` (linha 303) e ao do `CycleCalculator.swift` (linha 395),
que eu tinha ali do lado para comparar e não comparei.

**O ponto que interessa:** este defeito era **invisível** para tudo o que eu
tinha feito até então. O harness de mutação passou (compila os arquivos soltos,
não pelo projeto). O `swiftc -parse` passou (o arquivo existe, o caminho é do
Xcode). A varredura de símbolos passou (todos tratados). Um `.pbxproj` errado
não é erro de Swift, é erro de wiring — e só o build enxerga. Sem a autorização
do Assis, isto teria ido para o próximo `git pull` dele como um projeto que não
abre.

### Segunda rodada: BUILD SUCCEEDED

`_validacao_20260813/51_build_resultado.txt` e `52_build_avisos.txt`.

- **0 erros.**
- **Controle positivo:** os dez arquivos que toquei aparecem no log de
  compilação (6 a 12 ocorrências cada). Um `BUILD SUCCEEDED` que tivesse pulado
  os arquivos novos seria outra medição do nada — a mesma família do `strings`
  no `.apk` e dos `Info.plist` de bundle de recurso do build 96.
- **Controle negativo:** `0` ocorrências de `Shared/Shared` no log.
- **5 avisos, 3 únicos, nenhum nos meus arquivos:** metadata de AppIntents,
  coerção de `UIView?` para `Any`, e uma propriedade `main actor-isolated`
  (erro no modo Swift 6). Todos pré-existentes.

Com isto, as três assinaturas que viraram `Optional` (`steps: Int?`,
`stressLevel: StressLevel?`, `asFoodItem: FoodItem?`, mais
`stepsFormatted: String?`) estão verificadas **pelo compilador**, não por
leitura.

---

## Item 2 — investigação e recomendação (NADA foi implementado)

### Correção da minha própria estimativa: são 228 kcal/dia, não 166

**166 é o delta do BMR**, antes do fator de atividade. `suggestedKcal`
(`NutritionEngine.swift:59-69`) multiplica o BMR pelo fator, então o erro que
chega no prato da pessoa é maior:

| atividade | fator | erro real por dia |
|---|---|---|
| Sedentário | 1,20 | 199 kcal |
| **Leve (o padrão)** | 1,375 | **228 kcal** |
| Moderado | 1,55 | 257 kcal |
| Intenso | 1,725 | 286 kcal |

Exemplo (mulher, 65 kg, 165 cm, 35 anos, manter, leve): meta correta **1850**,
meta exibida **2078**. *(Aritmética a partir da fórmula lida em
`NutritionEngine.swift:53-68` — não é execução do binário de produção.)*

### Sexo e nível de atividade são o MESMO defeito com dois nomes

`Models.swift:303-304`, uma linha embaixo da outra:

```swift
sex           = BiologicalSex(rawValue: store.string(forKey: "sexBiological") ?? "") ?? .masculino
activityLevel = ActivityLevel(rawValue: store.string(forKey: "activityLevel") ?? "") ?? .leve
```

Dois `??` assumindo um valor que ninguém informou, alimentando a mesma fórmula,
sob o mesmo rótulo "calculada para você". E o de atividade **não é o menor**:
para a mesma mulher do exemplo, `sedentário` daria 1614 contra os 1850 de
`leve` — **236 kcal**, mais que o termo de sexo. Tratar um sem o outro conserta
metade de um número e deixa a outra metade mentindo com a mesma cara.

**Nada no app escreve `model.sex` nem `model.activityLevel`** exceto os dois
`Picker` de `NutritionEngine.swift:138` e `:145`, dentro do `GoalEditorView` —
alcançável só por Dieta → "Meta" (`DietaView.swift:120`). Confirmado por
varredura: zero outros escritores.

### O campo do onboarding: conferido na fonte, é IDENTIDADE DE GÊNERO

O Assis lembrava que o onboarding já pergunta **sexo**. Fui conferir o rótulo
que a pessoa vê, as opções, e o que é gravado. **É identidade de gênero.**

`Shared/OnboardingBiometricsView.swift:186-198`, literal:

```swift
// ── Género ────────────────────────────────────────────────
VStack(alignment: .leading, spacing: 10) {
    Text("Como você se identifica?")
    ...
    let genders = ["Feminino", "Masculino", "Não binário", "Prefiro não dizer"]
```

O que é gravado (`Shared/UserMemoryManager.swift:24-29`):

```swift
// Identidade — lida/escrita directamente em UserDefaults (não encriptada, não sensível)
// gender: "Feminino" | "Masculino" | "Não binário" | "Prefiro não dizer"
var gender: String {
    get { UserDefaults.standard.string(forKey: "alma_user_gender") ?? "" }
```

Tipo `String`, chave `alma_user_gender`, UserDefaults local. **Não há caminho de
pular:** `canAdvance` (`:34-38`) trava o passo 1 sem resposta — mas *"Prefiro
não dizer"* **é** uma resposta válida, e não carrega informação de sexo nenhuma.

**Provas por enumeração, não por grep vazio:**

- O literal `"Sexo"` aparece **uma única vez em todo o código-fonte**, e é o
  `Picker("Sexo", selection: $model.sex)` de `NutritionEngine.swift:138` — a
  tela da Meta, não o onboarding.
- Existe **uma única** tela de onboarding no app inteiro
  (`find` por `*onboard*` → só `Shared/OnboardingBiometricsView.swift`).
- Os literais `"Feminino"`/`"Masculino"` aparecem em exatamente 3 arquivos:
  o onboarding (junto com as outras duas opções), o `enum BiologicalSex`, e o
  `UserMemoryManager`.

**De onde vem a lembrança — e ela não bate com nenhum dos dois apps.** O
comentário de `Models.swift:318-320` diz que as medidas "eram coletadas no
onboarding do Corpo & Alma, que a fusão removeu". Fui ver: o
`CorpoAlma_com_Watch/CorpoEAlma/OnboardingView.swift` pergunta **nome, objetivo,
idade, peso e altura — e não pergunta sexo**. Ali também o único `Picker("Sexo")`
está no `NutritionEngine.swift:132`, dentro da tela de Meta. Ou seja, o defeito
é o mesmo nos dois apps, e a pergunta de sexo nunca existiu em onboarding
nenhum.

### Conclusão: o caminho C continua sendo o certo

Como o campo é identidade com quatro opções — duas delas sem tradução possível
para o Mifflin —, **não dá para "só ligar o dado na fórmula"**. Ligar direto
significaria decidir que identidade de gênero é sexo biológico, em silêncio,
dentro de uma conta de saúde. O rótulo da tela (*"Como você se identifica?"*) e
o comentário do store (*"não sensível"*) mostram que o campo foi desenhado para
outra pergunta.

O que sobra é o híbrido, com a ressalva dita na cara.

### Caminho A — perguntar sexo biológico no onboarding

- **A favor:** a meta vira cálculo pessoal de verdade; pergunta feita uma vez.
- **Contra:** é a segunda pergunta sobre o mesmo território, logo após "Como
  você se identifica?" — e o Mifflin não aceita "não binário" nem "prefiro não
  dizer", então parte das pessoas fica sem resposta possível. Acrescenta campo
  sensível a uma tela que já tem cinco blocos. E **não resolve quem já passou
  pelo onboarding**: essas pessoas continuam com `.masculino` silencioso, então
  ainda seria preciso um segundo mecanismo.

### Caminho B — marcar a meta como estimada até a pessoa confirmar

- **A favor:** honesto imediatamente, sem pergunta nova, e cobre quem já está
  instalado.
- **Contra:** rotula o número, mas o número continua errado em 199–286 kcal/dia
  para toda mulher que não confirmar. Honestidade sobre um número errado é
  melhor que mentira, e ainda assim não é um número certo. E "estimada com
  perfil padrão" ou esconde qual é o padrão, ou diz "perfil masculino" para uma
  mulher — as duas opções são ruins.

### Recomendação — caminho C, na versão enxuta

O Assis tem razão numa coisa: uma máquina de estados de "proposta/confirmação"
é complexidade demais. Dá para ter a honestidade sem ela.

**1. `AppModel.sex` e `AppModel.activityLevel` viram opcionais.** Mata os dois
`??` de `Models.swift:303-304`. `nil` = ninguém informou, que é a verdade.

**2. Derivar o sexo do gênero já coletado, na leitura:** *Feminino* →
`.feminino`, *Masculino* → `.masculino`, *Não binário / Prefiro não dizer /
vazio* → continua `nil`. Sem chave nova, sem migração — a decisão é tomada na
leitura, o mesmo mecanismo que resolveu o item 1 e que cobre quem já está
instalado.

**3. Uma linha de texto onde o número aparece**, e só isso — sem fluxo de
confirmação, sem terceiro estado. Debaixo da meta sugerida, algo como
*"Calculada usando **Feminino**. Não é isso? Ajuste em Perfil para o cálculo."*
O `Picker` que corrige já está na mesma tela, dez pontos abaixo
(`NutritionEngine.swift:138`). Quem concorda não faz nada; quem discorda vê o
pressuposto e o conserta sem sair de onde está.

**4. Sem sexo derivável → sem número.** Sexo (e atividade) entram em
`missingProfileFields`, e a tela usa a frase que já existe para peso/altura/idade
ausentes: *"informe suas medidas"*. Quem escolheu não dizer cai no caminho
manual que já existe (`customKcalGoal`).

**Por que assim:**
- usa dado que o app já tem: quase ninguém vê pergunta nova, e a cobertura é
  alta porque a pergunta é obrigatória no onboarding;
- cobre quem já está instalado sem migração e sem escrever nada;
- o pressuposto fica **visível na tela onde o número está**, em vez de invisível
  no `?? .masculino`;
- não obriga ninguém a declarar sexo biológico;
- nada sai do aparelho — o gênero já mora em `UserDefaults` local
  (corregedoria inalterada).

**O custo, dito na cara:** identidade de gênero **não é** sexo biológico.
Derivar é um *padrão*, não uma verdade — e é por isso que o pressuposto tem de
aparecer escrito e ser trocável num toque. Uma mulher trans que respondeu
"Feminino" recebe a fórmula feminina por padrão e troca se quiser. Ainda assim é
melhor do que hoje, em que **todo mundo** recebe a masculina em silêncio.

**Custo estimado:** ~2–3 h + harness de mutação. Atritos conhecidos: o `didSet`
que persiste `sex.rawValue`, e os dois `Picker`, que precisam de um estado "não
informado" ou de um `Binding` intermediário.

**Alternativa, se o Assis quiser mesmo perguntar:** acrescentar *sexo biológico*
ao passo 2 do onboarding (o de peso e altura), separado da pergunta de
identidade e explicado como insumo da fórmula. Resolve quem entra a partir daí,
mas **não** resolve quem já está instalado — para esses, os pontos 1, 2 e 4
continuam necessários de qualquer jeito.

---

## Para o Android casar (item 3) — a regra escrita

Não toquei em repositório Android nenhum. A regra a espelhar:

1. **Nutriente ausente ≠ 0.** No parse da Open Food Facts, campo que não veio
   vira `null`, nunca `0` (`n?.kcal ?? 0` é o defeito exato).
2. **Zero declarado sobrevive.** Água mineral tem 0 kcal de verdade e a base diz
   isso; a correção **não** é "tratar 0 como ausente". A asserção `N3` existe só
   para prender esse lado.
3. **Sem energia não existe item de dieta.** O produto não entra no diário; a
   UI oferece completar o cadastro **já com nome e marca preenchidos**, que a
   base forneceu.
4. **Suplemento é exceção legítima:** ali a pessoa informa a kcal da dose dela,
   então produto sem kcal continua sendo fluxo válido — só a mensagem muda.
5. Cuidado com `Int(Double)` de valor não finito: é crash. Guardar com
   `isFinite`.
