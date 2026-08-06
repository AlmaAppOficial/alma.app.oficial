# Plano — porção editável no scan + unidade do CustomFoodForm (06/08/2026)

Escrito ANTES de tocar em código, como combinado. Dois bugs da mesma família:
número errado entrando no diário, que é o dado que dá sentido a esta parte do app.

---

## Peça 1 — a porção da IA deixa de ser um decreto

**Estado hoje:** `FoodScanView.swift:31` — `let porcaoG: Int`. Não há Slider nem
Stepper na tela. Ou a pessoa aceita o número da IA, ou não registra.

**Decisão de desenho:** a estimativa da IA continua sendo a estimativa — não vou
sobrescrevê-la. O que entra é um AJUSTE por cima dela:

- `FoodScanResult.porcaoG` permanece o que a IA leu na foto (imutável).
- A View ganha `porcaoAjustada: Int?`, que nasce `nil` — ou seja, **a estimativa
  já vem preenchida como ponto de partida**, que é o requisito 1.
- `porcaoEmUso(r) = porcaoAjustada ?? r.porcaoG`.
- Quando ajustada, a tela diz quanto a IA tinha estimado e oferece voltar. A
  estimativa nunca some de vista; ela deixa de ser a única opção.

**Por que não transformar `porcaoG` em `@State` direto:** perderia o número
original. Uma tela que diz "450 g" sem lembrar que a IA leu 250 g apaga a
diferença entre o que a máquina viu e o que a pessoa corrigiu — e é justamente
essa diferença que a pessoa precisa enxergar para calibrar a confiança.

**Recálculo ao vivo (requisito 2):** `macrosDaPorcao` hoje é um `var` computado
preso a `porcaoG`. Vira função `macros(para gramas:)`, e `macrosDaPorcao` passa a
ser `macros(para: porcaoG)` — as asserções H2/H2b/H2d existentes continuam
compilando e verdes, sem recalibração. A tela chama a versão parametrizada.

**A estrutura que torna a divergência difícil:** um único `let gramas` no topo
de `resultSection`, lido por três consumidores — os tiles, o rótulo do botão e a
chamada de `addFood`. Divergir exigiria criar uma segunda variável.

**Rótulos como função estática:** `rotuloDaPorcao(gramas:)` e
`rotuloDeConfirmacao(gramas:refeicao:)`. Sem isso, "o que o botão promete" é uma
string dentro do corpo da View e o harness não tem como afirmar nada sobre ela.
Com isso, a asserção compara o texto que a pessoa lê no botão com o número que
foi gravado.

**Faixa do controle:** 10 g a `max(1000, estimativa × 2)`, passo 5, mais botões
−5/+5. O slider do `AddFoodView` para em 500 g, o que não cobre um prato cheio —
não vou herdar esse teto aqui.

---

## Peça 2 — o `CustomFoodForm` para de trocar a unidade em silêncio

**Estado hoje:**
- `AddFoodView.swift:375` rotula os campos **"Macros (por porção)"**.
- `:405-414` cria o `Meal` com esses valores como total da refeição — **certo**,
  se são por porção.
- `:417-425` grava os MESMOS números em `StoredFood(kcalPer100:...)` — **errado**.
  Uma marmita de 600 kcal vira 600 kcal **por 100 g** na próxima leitura pelo
  código de barras. A 350 g isso vira 2 100 kcal.

**Correção:** um campo "Peso da porção (g)", pré-preenchido com 100.

- O `Meal` continua recebendo **exatamente** os números digitados. O que a pessoa
  escreveu é o que entra no diário, sem arredondamento no caminho.
- O `StoredFood` passa a receber a conversão para 100 g:
  `por100 = round(valor × 100 / gramas)`.
- O nome do item passa a carregar a porção — hoje o caminho do alimento
  personalizado é o único que não põe grama nenhuma no nome.
- Pré-preenchido com 100 porque, com 100, a conversão é a identidade: quem
  ignorar o campo recebe exatamente o comportamento de hoje. A correção não pode
  criar um erro novo para quem não olhou.

**Deriva conhecida e aceita:** 600 kcal em 350 g → 171 kcal/100 g → de volta a
350 g dá 599 kcal. Um kcal de arredondamento fica no item do CATÁLOGO, nunca no
número que a pessoa digitou. Vai comentado no código.

---

## O que vai ser provado, e como

| id | afirma | mutação que tem de deixar vermelho |
|---|---|---|
| **E1** | exibido == confirmado == gravado, com a porção **ajustada** | fazer o botão gravar `r.porcaoG` em vez da porção em uso |
| **E1b** | guarda anti-cegueira: o ajuste realmente muda o número | — (compara contra a estimativa; morre se o ajuste for ignorado) |
| **E2** | o rótulo do botão carrega o número que foi gravado | trocar o número dentro de `rotuloDeConfirmacao` |
| **E3** | a estimativa da IA sobrevive ao ajuste | fazer o ajuste sobrescrever `porcaoG` |
| **E4** | o `CustomFoodForm` converte para 100 g em vez de copiar | voltar `kcalPer100: Int(kcal) ?? 0` |
| **E4b** | canário da conversão: identidade em 100 g, e ≠ cópia fora de 100 g | — |
| **E-W1..W4** | lint estático dos mesmos pontos | ver `_scripts/mutacao_porcao_editavel.sh` |

**Limite declarado desde já:** não há Xcode neste ambiente. As asserções de
runtime (E1..E4b) são escritas mas **não executadas por mim**; as regras de lint
(E-W*) rodam e são provadas por mutação aqui. Vou separar as duas coisas no
relatório, como manda a Regra 3.
