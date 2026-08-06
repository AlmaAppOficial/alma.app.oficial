# Entrega — porção editável + unidade do alimento personalizado (06/08/2026)

Branch `feat/build84-chat-e-ciclos`. **Nada foi commitado, nada foi enviado.**
O motivo do commit não ter sido feito está na seção 4.

---

## 1. O que ficou pronto

### Peça 1 — a porção deixa de ser um decreto da IA

`Shared/Corpo/FoodScanView.swift`

- `FoodScanResult.macrosDaPorcao` (var computada presa a `porcaoG`) virou
  `macros(para gramas:)`; `macrosDaPorcao` continua existindo como
  `macros(para: porcaoG)` — as asserções H2/H2b/H2d de 05/08 seguem falando
  exatamente do que falavam, sem recalibração.
- `@State porcaoAjustada: Int?` nasce `nil`: **a estimativa da IA já vem
  preenchida como ponto de partida** (requisito 1). Quem concorda não toca em
  nada.
- Controle novo entre os números e o botão: slider + botões −/+. **Os quatro
  números recalculam à vista** (requisito 2), porque são derivados de `gramas`
  no mesmo `resultSection`.
- A estimativa **não é sobrescrita**. Depois de ajustar, a tela mostra "A IA
  estimou 250 g · voltar à estimativa". Apagá-la apagaria a diferença entre o
  que a máquina viu e o que a pessoa corrigiu — que é o que ensina quanto
  confiar na leitura.
- **UM `let gramas`** no topo, lido pelos tiles, pelo rótulo do botão e pelo
  `addFood`. Divergir exigiria criar uma segunda variável.
- Os dois textos que carregam a quantidade viraram funções estáticas
  (`rotuloDaPorcao`, `rotuloDeConfirmacao`) — enquanto viviam soltos no corpo
  da View, nenhuma asserção conseguia ler o que o botão promete.

Dois ajustes que saíram da revisão:

- **Slider sem `step:`**. Com passo de 5 a grade ancorava no piso (10, 15, 20…)
  e a estimativa da IA é inteiro qualquer: 247 g pulava para 245 ao primeiro
  toque, e os botões −/+ andavam por 242, 237… — duas grades que nunca se
  encontravam. Dois controles discordando sobre quais números existem é a mesma
  família de bug que este trabalho fecha.
- **Piso acompanha estimativas pequenas** (`piso = min(10, max(1, porcaoG))`).
  Com piso fixo em 10, uma estimativa de 5 g deixaria o rótulo dizendo "5 g" e
  o slider parado em 10.

### Peça 2 — o `CustomFoodForm` para de trocar a unidade

`Shared/Corpo/AddFoodView.swift`

- Campo novo "Peso da porção (g)", **pré-preenchido com 100**: em 100 a
  conversão é a identidade, então quem ignorar o campo recebe exatamente o
  comportamento antigo. Uma correção não pode criar erro novo para quem não
  olhou.
- `converterPara100g(_:gramasDaPorcao:)` converte antes de gravar o
  `StoredFood`. O `Meal` recebe o número digitado **intacto** — o arredondamento
  fica só no item de catálogo.
- A porção passa a aparecer no nome. Este era o único caminho de registro que
  não dizia de quanto falava, nem em texto nem em campo.
- `Int(porcaoG) ?? 100` (código morto, mas era literalmente o "chuta 100 g em
  silêncio" que o conserto mata) virou `guard let`.
- O rótulo não diz mais "por porção de 0 g" enquanto o campo está sendo digitado.

### Reparo que não era do pedido, mas bloqueava tudo

`Shared/AuditoriaBloqueadores.swift` — o commit `4944881` **de hoje** deixou
`Invalid redeclaration of 'semPremium'` (linhas 252 e 562, mesmo escopo). O alvo
Debug **não compila desde as 13:09 de hoje**. Junto veio `A27a/A27b/A27c`
duplicados com o bloco de HealthKit de 05/08.

Renomeados para `acaoSemPremium`/`acaoComPremium` e `P1a/P1b/P1c`. Vai em
**commit separado**, para poder ser mantido caso o commit da feature precise ser
revertido.

---

## 2. O que foi PROVADO — e como

| Prova | Resultado |
|---|---|
| Lint de wiring (`lint_wiring.py`) | **30 regras, 0 falhas** |
| Mutação do lint (`mutacao_porcao_editavel.sh`) | **7 mutações, 7 vermelhas, 0 furos** |
| Aritmética das asserções, replicada fora do Swift | 936/122/18/41 em 450 g · 171 kcal/100 g · confere |
| Integridade do harness (escopo e ids) | 176 declarações, 0 duplicadas · 137 ids, 0 duplicados |
| Revisão independente, duas passadas | 3 asserções fracas corrigidas, 1 furo de canário tapado |

**A M-E7 nasceu de um furo real:** o `proibe` do E-W5b exigia UM espaço e o
arquivo usa alinhamento por colunas — uma reversão escrita no estilo da casa
passava batido pelo canário. Corrigido para `\s+` e a mutação existe para vigiar.

**Três asserções nasceram fracas e foram refeitas** (achado da revisão):

- **E3 era eco**: assertava `porcaoG == 250` dez linhas depois de passar 250 ao
  construtor, e o comentário prometia pegar `let`→`var`, o que não pegava. Agora
  trava o elo que a refatoração criou: `macrosDaPorcao` continua sendo
  `macros(para: porcaoG)`, senão H2/H2b/H2d passam a falar de outra coisa.
- **E2 fazia `.contains`** do literal que ela mesma passou. Agora extrai o
  número das duas frases — produzidas por funções diferentes — e compara.
- **E1 declarava um alvo de mutação que não cobre** (o botão da View). O
  comentário agora diz o que ela cobre e manda o resto para o lint.

---

## 3. O que NÃO foi provado — dívida declarada, não verde

1. **O harness E0..E4b não foi executado, e o projeto não foi compilado.** Não há
   Xcode no ambiente onde isto foi escrito. As asserções estão escritas e a
   aritmética delas foi conferida à mão; que passem — e que o alvo compile —
   exige rodar `_scripts/build_e_auditar_20260805.sh` no Mac.
2. **Ninguém viu a tela.** Nada aqui prova que arrastar o slider redesenha os
   quatro números. `E-W4` prova que ele escreve no estado, `E-W2` que os tiles
   leem a mesma variável do registro; o elo "e o pixel mudou" segue sem prova,
   como desde 05/08. Sem XCUITest não dá.
3. **"O build Debug volta a compilar" é análise de escopo, não build verde.** A
   redeclaração foi provada por indentação e contagem, não pelo compilador.

---

## 4. Por que o commit não foi feito

O ambiente monta o repositório por FUSE e **não consegue remover
`.git/index.lock`** — nenhuma escrita do git completa. Sobrou um `index.lock` de
0 byte que **trava qualquer git nesta máquina até ser apagado**.

`_scripts/commitar_porcao_editavel.sh` apaga o lock e faz os dois commits, por
caminho explícito, sem push. Rodar:

```bash
bash ~/Desktop/ALMA/alma.app.oficial-main/_scripts/commitar_porcao_editavel.sh
```

O commit 1 vem de `_validacao_20260806/reparo_4944881.patch`, gerado a partir do
HEAD e testado com `patch --dry-run`.

---

## 5. O que falta para virar build — o tamanho

Hoje: **`MARKETING_VERSION = 2.0`, `CURRENT_PROJECT_VERSION = 93`**, com **10
commits** parados desde o archive do build 93.

| # | Passo | Tamanho | Risco |
|---|---|---|---|
| 1 | Rodar `commitar_porcao_editavel.sh` | ~1 min | baixo — script pronto e testado |
| 2 | Bump: `MARKETING_VERSION` 2.0 → 2.0.1 (**12 ocorrências**) e `CURRENT_PROJECT_VERSION` 93 → 94 (**12 ocorrências**) | ~5 min | baixo — `build93_bump_e_commit.sh` já faz esse padrão com sed + conferência de que só a versão mudou |
| 3 | **Compilar e rodar o harness** (`build_e_auditar_20260805.sh`) | 10–20 min | **É AQUI QUE MORA O RISCO.** É a primeira compilação de tudo o que escrevi hoje, e do reparo. |
| 4 | Corrigir o que o compilador achar | 0 min a algumas horas | **desconhecido, e é honesto dizer que é desconhecido** |
| 5 | Archive + upload (`archive93_lancar.sh` como molde) | 20–40 min, quase tudo espera | baixo — caminho já percorrido no 92 e no 93 |

**Trabalho de código: passos 1 e 2 somam ~6 minutos.** O passo 3 é onde a
estimativa deixa de valer, porque nada disto passou por compilador.

### Duas coisas que não são código e podem ser o gargalo real

- **A 2.0 estava em revisão da Apple** em 05/08 (está escrito no commit
  `366c1ac` e no cabeçalho do `build_e_auditar_20260805.sh`). **Não consigo
  verificar o estado atual no App Store Connect daqui.** Se a 2.0 ainda estiver
  em revisão, subir a 2.0.1 exige resolver a 2.0 antes — e isso é espera, não
  trabalho.
- **Se "2.0.1" é o número certo, é decisão sua.** O lote inclui *entitlement de
  assinatura chegando ao servidor* e mudança de paywall, que é mais do que um
  patch. O bump é o mesmo esforço em qualquer número.

### Uma dívida que ficou de fora, de propósito

Os arquivos legados em `CorpoAlma_com_Watch/` **não têm** a correção da porção de
05/08 nem a de hoje. São a cópia pré-fusão. Não toquei neles — mexer ali sem
pedido é exatamente o commit cruzado que o CLAUDE.md proíbe.
