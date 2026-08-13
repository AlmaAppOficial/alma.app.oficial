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

2. **O alvo iOS não foi compilado** — você pediu nada de build. O que rodou foi
   `swiftc` sobre o subconjunto puro (`CycleCalculator`, `RegrasDeSaude`,
   `OpenFoodFacts`, `UnidadeDeMedida`) mais `swiftc -parse` nos dez arquivos
   tocados (`_validacao_20260813/40_sintaxe_swiftc_parse.txt`, todos exit 0).
   `-parse` é sintaxe, **não** verificação de tipos: mudei assinaturas
   (`steps: Int?`, `stressLevel: StressLevel?`, `stepsFormatted: String?`,
   `asFoodItem: FoodItem?`) e um erro de tipo nas views não apareceria aí.
   Fiz varredura mecânica de **todas** as ocorrências de cada símbolo alterado
   em `Shared/ ios/ AlmaWatch/` e todas estão tratadas — mas isso é leitura, não
   compilador. **Um `xcodebuild build` local (sem archive, sem upload, sem
   tocar no ASC) fecharia isto em ~2 min, se você autorizar.**

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

## Item 2 — investigação e recomendação (NADA foi implementado)

### O defeito é maior do que o relatório dizia

`Models.swift:303` faz `?? .masculino` e **nada no app escreve `model.sex`**
exceto o `Picker` de `NutritionEngine.swift:138`, dentro do `GoalEditorView` —
alcançável só por Dieta → "Meta". Confirmado por varredura: zero outros
escritores.

O relatório falava em "cerca de 166 kcal a mais por dia". **166 é o delta do
BMR**, e `suggestedKcal` multiplica o BMR pelo fator de atividade:

| atividade | fator | erro real por dia |
|---|---|---|
| Sedentário | 1,20 | **199 kcal** |
| Leve (o padrão) | 1,375 | **228 kcal** |
| Moderado | 1,55 | 257 kcal |
| Intenso | 1,725 | 286 kcal |

Exemplo (mulher, 65 kg, 165 cm, 35 anos, manter, leve): meta correta **1850**,
meta exibida **2078**. *(Aritmética a partir da fórmula lida em
`NutritionEngine.swift:53-68` — não é execução do binário de produção.)*

E o padrão `activityLevel = .leve` erra na **mesma ordem de grandeza**: para a
mesma pessoa, sedentário daria 1614 contra 1850, ou seja 236 kcal. Não é um
problema "menor" — é do mesmo tamanho.

### O achado que muda a decisão

**O onboarding já pergunta gênero, e a pergunta é obrigatória.**
`OnboardingBiometricsView.swift:191` oferece *Feminino · Masculino · Não
binário · Prefiro não dizer*, e `canAdvance` (`:36`) trava o passo 1 sem
resposta. O valor vive em `UserMemoryManager.gender` (`alma_user_gender`), local.
O mesmo fluxo já coleta peso e altura (passo 2) e idade (data de nascimento).

Ou seja: **o onboarding coleta todos os insumos do Mifflin menos o termo de
sexo — e tem, ali do lado, uma resposta adjacente que ninguém usa.**

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

### Recomendação — caminho C, híbrido

**1. `AppModel.sex` vira `BiologicalSex?`.** Mata o `?? .masculino`. `nil` =
ninguém informou, que é a verdade.

**2. Propor a partir do gênero que o onboarding JÁ coletou**, na leitura:
*Feminino* → `.feminino`, *Masculino* → `.masculino`, *Não binário / Prefiro
não dizer / vazio* → continua `nil`. Guardado como **proposta**, distinta de
valor confirmado.

**3. A tela da Meta passa a ter três estados**, com vocabulário que ela já tem
(`"Meta sugerida (em uso)"` / `"informe suas medidas"`):
   - **confirmado** → "Meta sugerida (em uso)", como hoje;
   - **derivado, não confirmado** → número + "Estimada — confirme seu perfil",
     com confirmação de um toque;
   - **`nil`** → sem número; sexo entra em `missingProfileFields`, e o caminho
     que já existe (`customKcalGoal`, meta manual) atende quem não quer
     responder.

**Por que C:**
- usa dado que o app já tem, então quase ninguém vê pergunta nova, e a cobertura
  é alta porque a pergunta de gênero é obrigatória;
- **cobre quem já está instalado sem migração**, porque a decisão é tomada na
  leitura — o mesmo mecanismo que resolveu o item 1;
- nunca apresenta valor não confirmado como "calculada para você";
- não obriga ninguém a responder sobre sexo biológico: quem não quer cai no
  caminho manual;
- nada sai do aparelho — o gênero já mora em `UserDefaults` local
  (corregedoria inalterada).

**O custo, dito na cara:** identidade de gênero **não é** sexo biológico.
Derivar é um *padrão*, não uma verdade — e é exatamente por isso que precisa
vir rotulado como estimativa e ser trocável num toque. Uma mulher trans que
respondeu "Feminino" recebe a fórmula feminina por padrão e troca se quiser.
É melhor do que hoje, em que **todo mundo** recebe a masculina em silêncio.

**Sugestão de escopo junto:** aplicar a mesma régua ao `activityLevel` (erro do
mesmo tamanho) e só então dizer "calculada para você".

**Custo estimado:** ~2–3 h de implementação + harness de mutação. Os pontos de
atrito conhecidos são o `didSet` que persiste `sex.rawValue` e o `Picker`, que
precisa de um terceiro estado "não informado" ou de um `Binding` intermediário.

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
