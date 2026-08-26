# Jejum intermitente na Dieta — entrega de 26/08/2026

Ramo `feat/build84-chat-e-ciclos`. **Sem push, sem deploy.**
Commits: `5d25391` (1ª rodada) e a 2ª rodada, abaixo.

---

## 0. SEGUNDA RODADA — o retorno do Assis

Duas coisas voltaram da revisão dele. As duas foram atendidas, e a segunda
mudou o **código**, não só o texto.

### 0.1 "Português muito arcaico e pouco claro"

Ele tem razão. Saíram frases como *"o líquido que vem da comida some junto com
ela"*, *"quebrou é quebrado"* e — a pior — *"refeições de quebra muito grandes,
carregadas de carboidrato de absorção rápida e fritura, aparecem associadas a
picos de glicose acentuados e a sintomas como saciedade precoce, distensão e
náusea"*, que é frase de artigo científico colada numa tela de celular.

**Todo o texto do módulo foi reescrito.** As regras ficaram escritas no
cabeçalho do `JejumConteudo.swift`, para valerem para a próxima frase também:

1. uma ideia por frase, frase curta, voz ativa;
2. palavra do dia a dia — "açúcar no sangue" e não "variabilidade glicêmica",
   "enjoo" e não "náusea", "inchaço" e não "distensão";
3. a informação primeiro, o contexto depois;
4. se precisa de duas leituras, está errada.

Alguns antes/depois:

| Antes | Depois |
|---|---|
| "Água conta, e conta muito" | "Água, café e chá não quebram o jejum" |
| "o líquido que vem da comida some junto com ela" | "Boa parte da água do seu dia vem da comida, e nas horas de jejum ela não vem" |
| "Não mude tudo no mesmo dia" | "Não corte o café no mesmo dia" |
| "quebrou é quebrado" | "Se perder um dia, a conta começa de novo. Só isso." |
| "menor variabilidade glicêmica" | "menos oscilação de açúcar no sangue" |
| "Consolidado / Resultados mistos / Preliminar" | "Bem estabelecido / Resultados mistos / Ainda em estudo" |

**O que não mudou:** os rótulos de força da evidência, as fontes, as URLs e as
ressalvas. Simplificar a língua não é apagar o "resultados mistos" — e clareza
não é infantilizar.

### 0.2 "O que é colocado na boca após a quebra do jejum deve ser proteína"

**A intuição dele está certa, e a evidência é melhor do que ele imagina.**
Apurado antes de escrever qualquer coisa:

- **Sequência de alimentos.** Comer proteína e vegetal antes do carboidrato
  baixa o açúcar no sangue nas horas seguintes. Num estudo cruzado com pessoas
  com diabetes tipo 2, a MESMA refeição em ordens diferentes deu glicose ~29%
  menor aos 30 min e ~37% menor aos 60 min. Repetido em vários estudos.
  *(Shukla e colegas, Diabetes Care, 2015.)*
- **Saciedade.** Proteína segura a fome por mais tempo que a mesma caloria com
  menos proteína — direção confiável, tamanho do efeito não, porque os
  protocolos variam muito e há risco de viés. *(Revisão de 2020.)*
- **A ressalva que não podia faltar.** O que os estudos NÃO mostram é que
  "quanto mais proteína, melhor" logo depois de jejum longo. Porção grande de
  qualquer coisa cai mal. A orientação é **pequeno E proteína** — está escrita
  assim na tela, com essas palavras.
- **O que ainda não foi mostrado, e está dito:** que essa ordem melhore o
  controle do diabetes a longo prazo. Os estudos são pequenos e mediram a
  resposta logo depois da refeição.

**O motor mudou por causa disso:**

1. **A porção que abre a quebra virou proteína pura.** A fruta que ela tinha
   saiu — fruta é carboidrato, e abrir a quebra com carboidrato contradizia a
   regra que a própria tela ensina duas telas adiante. A lista `frutas` foi
   removida do `QuebraDeJejum.swift`, com o motivo escrito no lugar dela.
2. **O prato principal sai ordenado e numerado, com o carboidrato por último.**
   A ordem é dado, não decoração: `PapelNoPrato.ordemDeComer` é quem manda, e a
   View só desenha o que recebe.
3. Duas afirmações novas em "Saber mais" — a ordem dos alimentos e a saciedade
   da proteína — cada uma com fonte, URL e rótulo de força.
4. Uma dica nova: **"Deixe o carboidrato por último"**, que vale para qualquer
   refeição, não só para a quebra.

Isso está protegido por três mutações novas (M13, M14, M15) e quatro asserções
novas (J10, J11, J11b no app; mais o bloco T5b no teste de linha de comando).

### 0.3 Prova da segunda rodada

- **61 asserções** com `swiftc` (eram 53) — todas verdes
- **15 mutações, 15 vermelhas, 0 furos** (eram 12)
- **16 asserções `J*`** no app (eram 13) — todas verdes
- Lint de promessa: 379 strings varridas, nenhuma promessa. Pisos recalibrados.
- Capturas refeitas: 24 PNGs do jejum, claro e escuro

Uma correção no próprio arsenal: a mutação **M11 apareceu como FURO** e não era.
O padrão que ela procurava tinha sumido na reescrita do texto, então ela rodava
sobre o código intocado e passava verde — e o script contava isso como asserção
cega. Um caso "não aplicada" agora é reportado em categoria própria, separada de
"furo". Acusar de cega uma asserção que está perfeita é o modo de falha inverso
do verde comprado, e engana igual.

---

## 1. O que foi construído

O jejum entrou **dentro da Dieta**, num card entre a meta calórica e as
refeições (`DietaView.swift:37`). Não virou aba nem módulo ao lado: a janela
alimentar e o que se come dentro dela são a mesma decisão, e separá-las
produziria dois lugares para o mesmo assunto.

### Arquivos novos (`Shared/Corpo/`)

| Arquivo | O que é |
|---|---|
| `Jejum.swift` | Protocolos, estado do jejum em curso, histórico, sequência. **Foundation puro.** |
| `QuebraDeJejum.swift` | O motor que monta a refeição de quebra. **Foundation puro.** |
| `JejumConteudo.swift` | Dicas, o que a literatura observa, contraindicações. Toda afirmação com fonte. **Foundation puro.** |
| `JejumStore.swift` | Persistência (UserDefaults) e notificações. |
| `JejumView.swift` | O card da Dieta + a tela do módulo (Jejum / Saber mais / Histórico) + a tela de contraindicações. |
| `QuebraDeJejumView.swift` | A tela da refeição de quebra. |

Os três primeiros só importam Foundation de propósito: é o que permite
exercitá-los com `swiftc`, sem simulador, e portanto reprová-los por mutação.

### Timer e protocolos

16/8, 18/6, 20/4, 5:2 e OMAD. Escolher, começar, pausar, retomar, encerrar,
descartar. Histórico com estatísticas.

**O estado sobrevive a fechar o app e a reiniciar o telefone** porque o
cronômetro é relógio de **parede** (`Date`), não monotônico. `ProcessInfo.systemUptime`
e `DispatchTime` zeram no reboot — um jejum começado às 20 h de ontem viraria
"0 h" depois de um reboot às 3 h. Está escrito no cabeçalho do `Jejum.swift`.

A pausa guarda o acumulado em vez de jogar fora: pausar um minuto não apaga
quinze horas.

**Notificações:** abertura e fechamento da janela, disparo único
(`UNTimeIntervalNotificationTrigger`), com dono próprio na `GradeDeLembretes` —
ver a seção 5.

### A quebra do jejum

Esta é a parte que o senhor apontou como diferencial, e ela ficou assim:

1. **A gentileza sai da duração.** Menos de 14 h → prato único, sem cerimônia
   (é um intervalo comum entre refeições). 14–18 h → porção leve antes, 20 min
   de intervalo. 18 h+ → porção leve menor, 30 min.
2. **A porção leve é de fato leve** e tem teto: 250 kcal na faixa moderada,
   200 kcal na cuidadosa. Ela **nunca cresce** com a duração — quem jejua mais
   recebe uma primeira porção *menor*, não maior.
3. **O orçamento calórico vem da meta e do que já foi registrado hoje**, dividido
   pelas refeições que ainda cabem na janela, com piso de 280 e teto de 1.100 kcal.
4. **Sem meta, a tela diz que é porção padrão** — não finge cálculo pessoal.
   Mesma régua do `metaEhEstimada`.
5. **Respeita `dietaryRestrictions`** e, o que é mais importante, **confessa o
   que não soube interpretar**: "Você registrou 'jaracatiá' e eu não sei
   interpretar isso automaticamente. Confira a sugestão antes de registrar."
6. **A proteína puxa mais quando o dia está atrasado nela**; o carboidrato sobe
   ou desce com o objetivo (perder / manter / ganhar).
7. Registra pela **mesma porta do scan de comida** (`AppModel.registrarPrato`),
   com `ComponenteDaRefeicao` editáveis depois na `MealDetailView`.

**Por que sem IA, e a decisão é deliberada:** o caminho de IA deste app passa
por Cloud Function, e esta frente não podia tocar em `functions/src/index.ts`
nem fazer deploy — uma sugestão por IA seria um botão que só sabe falhar (a
lição do B8). Além disso, macro inventado por modelo entraria no `kcalByDay`
da pessoa, que é o bug F2/B8. E função pura é reprovável por mutação; prompt não é.
**Custo:** a sugestão é determinística — mesma entrada, mesmo prato. Mitigado
por não repetir o que já foi comido hoje, e declarado no cabeçalho do arquivo.

### Dicas e o que a literatura observa

Cinco afirmações, cada uma com **rótulo de força** (Consolidado / Resultados
mistos / Preliminar), corpo, citação e URL. A primeira é a que desmonta a
expectativa mágica, de propósito:

| Afirmação | Força | Fonte |
|---|---|---|
| Jejum e restrição calórica dão resultado parecido quando as calorias são iguais | Consolidado | Liu et al., *NEJM* 2022 (RCT, 12 meses, n=139) |
| O efeito medido é modesto, e nem tudo se move | Mistos | *Frontiers in Nutrition* 2025 (revisão sistemática) |
| Nos ensaios, não apareceu mais efeito adverso | Consolidado | Meta-análise de 15 RCTs, n=1.365 |
| "Autofagia começa em X horas" não tem base em humanos | Preliminar | Cleveland Clinic |
| Há associação com comportamento alimentar de risco | Mistos | Ganson et al., *Eating Behaviors* 2022 (transversal, n≈2.700) |
| Por que a primeira refeição importa | Mistos | Revisões de nutrição e glicemia no Ramadã |

**Nenhuma promessa de resultado.** Nada de "emagreça", "cura", "reverte",
"garante", "queima gordura", "detox". Isso é verificado por duas guardas
independentes — ver a seção 4.

Uma escolha que vale destacar: **a síndrome de realimentação NÃO é usada para
assustar.** Ela é real e grave, mas o contexto dela é desnutrição severa sob
acompanhamento (os fatores de risco do NICE são IMC baixo, perda de peso não
intencional, dias sem ingestão). Nada disso descreve alguém fechando uma janela
de 16 h. Emprestar o nome de uma emergência clínica para vender cuidado com uma
janela de 16 h seria a desonestidade que este módulo existe para evitar. Ela
aparece uma vez, na contraindicação de peso muito baixo, e só.

---

## 2. A parte de cuidado

Feita desde o começo, no desenho, não como camada por cima.

| O que foi pedido | Como está no código |
|---|---|
| Não gamificar jejum mais longo sem teto | `Sequencia.dias` conta **dias com janela cumprida**. Um 16/8 vale o mesmo que um OMAD. A tela diz isso por extenso, para quem lê entender que não há ponto extra por jejuar mais. O jejum mais longo aparece no histórico como número seco, sem selo e sem "recorde". |
| Não sugerir estender | **Não existe botão de estender em nenhum estado.** Com a meta atingida a ação principal é "Quebrar o jejum". Quem quiser seguir simplesmente não toca em nada. |
| Caminho para ajuda, discreto e permanente | `AvisoDeApoio` + `ApoioEmCriseView` **reutilizados**, no rodapé de toda a tela do jejum. Mesma tela regionalizada do chat, do humor e do Liberdade (1411 PT / 188 BR). Nenhuma tela nova, nenhum número duplicado. |
| Contraindicações, uma vez, sem drama | Tela mostrada no primeiro acesso, com "Entendi", e depois alcançável em "Saber mais". Gravidez, amamentação, diabetes tipo 1/insulina, transtorno alimentar, adolescentes, peso muito baixo, outras condições. |
| Não perguntar o que o app já sabe | A tela **não pergunta nada**. Usa `FeminineHealthSecureStore.pregnancyMode` e o IMC (quando há peso e altura) só para **subir e destacar** a linha que se aplica, com o rótulo "pode ser o seu caso". Nada sai do aparelho, nada é gravado, e **ninguém é bloqueado** — informar é diferente de barrar. |
| Disclaimer curto | "O jejum aqui é um cronômetro e um registro seu. A Alma é apoio de bem-estar e não substitui a orientação de um médico ou nutricionista." No mesmo formato do que a `GoalEditorView` já tem. |

Duas decisões extras na mesma direção:

- **A lista de protocolos para na OMAD.** Não há 36 h, 48 h ou 72 h. Isto não é
  filtro sobre o usuário — o cronômetro continua contando depois da meta e
  ninguém é interrompido. O que o app não faz é **oferecer** duração longa como
  item de menu, porque oferecer é sugerir.
- **Encerrar é um toque**, sem "tem certeza?" e sem aviso de que a sequência vai
  quebrar. Um app que dificulta parar de jejuar é um app que empurra para
  continuar. A dica "Se passar mal, coma" diz isso com todas as letras.
- Acima de 24 h aparece **uma** linha discreta, sem alarme, lembrando que jejum
  longo costuma pedir acompanhamento e apontando o rodapé. Não é detecção de
  risco e não bloqueia nada.

---

## 3. Build e capturas

**`** BUILD SUCCEEDED **`** — Debug, simulador de iPhone, `DEVELOPMENT_TEAM=CV2V6HLTS2`.
Zero erros, zero avisos novos.

- Script: `_scripts/build_jejum_20260826.sh`
- Capturas: `_scripts/capturar_jejum_20260826.sh` → `_validacao_20260826_jejum/`
- **34 PNGs, 24 do jejum: 12 telas × claro e escuro.**
- Folha de contato pronta para abrir: `_validacao_20260826_jejum/conferencia_visual_jejum_20260826.html`

As imagens vêm do harness que monta a view num `UIWindow` real
(`SmokeTestTelas.conferenciaDoJejum`), e não de screenshot do simulador — o
motivo está no cabeçalho da `conferenciaDeAparencia`: em 04/08, três tentativas
por `simctl launch -corpoAba N` capturaram a Home do Alma porque o
`fullScreenCover` não apresenta a partir de `-corpoAba`.

**Limite honesto das imagens:** `drawHierarchy` não reproduz blur nem o vidro do
iOS, e cada PNG mostra só a **primeira altura de tela** de cada rolagem. O card
de restrições da tela de quebra, por exemplo, aparece cortado no rodapé da J12.

---

## 4. Prova

### Asserções sem simulador — `_scripts/rodar_testes_jejum.sh`
**53 asserções, 53 verdes.** Compila o código de produção com `swiftc` e roda em
segundos. Cobre cronômetro, pausa, relógio para trás, sequência, teto de 24 h,
restrição alimentar, orçamento, invariante do total e conteúdo.

### Mutação — `_scripts/mutacao_jejum.sh`
**12 mutações, 12 vermelhas, 0 furos, 0 não compilaram.** Cada mutação apaga uma
linha que sustenta uma garantia e exige vermelho.

Duas coisas que a mutação **encontrou** e que foram corrigidas:

1. **`orcamentoMaximo` era testado contra si mesmo.** A asserção dizia
   `orcamento <= QuebraDeJejum.orcamentoMaximo` — uma tautologia: nenhum valor
   da constante a faz falhar. Subir o teto de 1.100 para 9.000 passava verde. É
   o mesmo defeito da N2, removida em 04/08 por "testar aritmética, não o app".
   Corrigido com literais.
2. **O teto da porção leve não era a restrição que mordia.** Com meta de 2.000
   e janela de 8 h, os 20 % do orçamento (200 kcal) já ficam abaixo do teto, e
   mexer no teto não mudava nada. Corrigido com um cenário de orçamento grande
   (onde o teto morde) e uma checagem direta das constantes.

Um achado que vale registrar como **boa notícia**: a primeira versão da mutação
M4 acrescentava um `case` de 36 h ao `ProtocoloDeJejum` e **não compilava**. O
enum é percorrido por `switch` exaustivo em cinco lugares, então não é possível
acrescentar protocolo sem passar por cada decisão. O compilador é a primeira
guarda contra a escalada.

### Lint de política de loja — `_scripts/check_promessas_jejum.py`
Varre 345 strings dos seis arquivos e reprova promessa de resultado. Provado por
mutação: 2 violações injetadas → 2 vermelhas; 4 tentativas de cegar o coletor →
4 saídas `CEGO` (exit 2), nenhuma verde.

**Uma cegueira foi encontrada e corrigida no caminho:** com um piso único sobre
o total, apagar a coleta das strings **multilinha** passava verde — porque os
291 literais de uma linha sozinhos superavam o piso. E é dentro das multilinha
que **as afirmações de saúde deste módulo moram quase todas**. Agora são dois
pisos, e cegar metade do coletor fica vermelho.

### Auditoria no app — `_scripts/auditoria_jejum_20260826.sh`
**13 asserções `J*` novas no `AuditoriaBloqueadores`, todas verdes** no
simulador, incluindo as guardas anti-cegueira `J1b`, `J3b` e `J5b`.

`N3`, `R7` e `R7b` também verdes com o dono de lembrete novo.

As **únicas** duas reprovações do auditor são `A26d` e `A27g` — as que o
`CLAUDE.md` documenta como **vermelhas de propósito** (SwiftUI não expõe texto
fora de XCUITest). Pré-existentes, sem relação com este trabalho.

### Guardas de commit
`guarda_a26.sh` verde (nenhum controle de aparência em `Shared/Corpo`).
`check_precos_vivos.py` verde (133 arquivos, nenhum preço escrito à mão).

---

## 5. Notificações — o que mudou fora do módulo

`DonoDoLembrete` ganhou o caso `.jejum`, com prefixo `jejum_`.

**Sem dono próprio isto seria um bug silencioso conhecido:**
`NotificationManager.sync` limpa o dono `.corpo` inteiro toda vez que alguém
mexe no interruptor de água. Se os avisos do jejum usassem prefixo `meal-`,
tocar no interruptor de água apagaria o aviso de fim de jejum, sem erro nenhum —
letra por letra o "bug da fusão" que criou a `GradeDeLembretes`.

`tetoDiario` **continua 9**, e não é descuido: os dois avisos do jejum são de
disparo único, `totalDiario()` só conta `repeats == true`, e eles não podem
furar um teto do qual não fazem parte.

`RotaDaNotificacao` ganhou as duas entradas (`jejum_fim`, `jejum_janela`), as
duas para `.corpoAba(.dieta)`. **Nenhum caso novo em `DestinoDaNotificacao`** —
o jejum é parte da Dieta.

---

## 6. Regras do Firestore de que preciso

**Nenhuma.** O módulo é 100 % local (`UserDefaults`), como o resto da Dieta —
diário, água, peso e suplementos também são. Se o `firestore.rules` for para
produção sem uma linha de mudança, o módulo funciona igual.

A escolha foi deliberada: é o padrão do módulo Corpo; histórico de jejum é
padrão alimentar e portanto dado sensível (LGPD Art. 5º, II), o que faz de
sincronizar uma decisão de produto e de política de privacidade, não
consequência técnica de escrever um cronômetro; e esta frente não podia fazer
deploy, então regra escrita seria regra não testada.

**Se e quando a sincronização for decidida**, o bloco pronto para revisão está
em `_entregas/jejum_firestore_20260826.rules` — comentado, para ninguém colar
sem ler. Duas observações que custam caro se passarem batido estão lá: o
`allow delete` é obrigatório (senão o histórico sobrevive à exclusão de conta,
como o `addiction_*` órfão sobrevivia), e seria preciso um índice composto em
`terminouEm DESC` no `firestore.indexes.json`, que também tem dono nesta rodada.

---

## 7. O que NÃO foi tocado

- `functions/src/index.ts` — intacto
- `firestore.rules` — intacto
- `firestore.indexes.json` — intacto
- Prompts existentes — intactos. **Nenhum prompt novo foi criado**, porque o
  motor da quebra é determinístico e não precisa de um.
- Política, termos e textos de loja (`fastlane/metadata/`) — intactos
- As 24 modificações que já estavam pendentes na árvore — **todas intactas**

---

## 8. O que ficou de fora, e por quê

1. **`project.pbxproj` não foi commitado.** Ele já estava modificado na árvore
   por outra frente (reordenação do Xcode, 229 inserções / 225 remoções de puro
   reposicionamento). Os seis arquivos novos **já estão registrados nele
   localmente** — é por isso que o build compila — mas commitá-lo levaria junto
   o trabalho da outra frente. **Precisa da sua decisão.** Para incluir:
   `git add Alma.App.Oficial.xcodeproj/project.pbxproj && git commit --amend --no-edit`

2. **Nenhuma tela foi vista por asserção.** Todas as `J*` provam aritmética e
   estado; nenhuma prova pixel. Vale a mesma régua do `H*`/`R*` do `CLAUDE.md`:
   isso é XCUITest, que o projeto não tem.

3. **O `JejumStore` não é exercitado** — persistência e agendamento dependem de
   `UserDefaults` e `UNUserNotificationCenter`, que só existem no aparelho. Que
   o estado sobrevive a reiniciar o telefone é consequência do desenho (relógio
   de parede + `Date` gravada), **não é fato medido**. Testar de verdade exige
   um aparelho e um reboot.

4. **A quantidade da proteína no prato principal pode ficar alta** para meta
   calórica grande — 290 g de frango num orçamento de 1.100 kcal. Está dentro
   do limite de porção que o teste verifica e dentro da meta diária de proteína,
   mas é um botão de ajuste caso ache exagerado (`QuebraDeJejum.proteinas`,
   `quantidadeBase` e o fator de reforço).

5. **O 5:2 é tratado como um jejum de 24 h** entre refeições, porque ele é um
   padrão semanal e não uma janela diária. A tela diz isso com todas as letras
   em `ProtocoloDeJejum.detalhe`, mas um 5:2 de verdade mereceria um calendário
   semanal próprio — é projeto separado.

6. **Sem widget, sem Watch, sem Live Activity.** Um jejum em curso é candidato
   óbvio a Live Activity na tela bloqueada, e o app tem alvo de Watch. Nada
   disso foi feito.

7. **A sugestão de quebra não conhece preferência** (só restrição). Não há onde
   a pessoa dizer "não gosto de mamão".

8. **`CLAUDE.md` não foi atualizado.** É arquivo compartilhado e há cinco
   frentes rodando; o texto que entraria está aqui e nos cabeçalhos dos
   arquivos. Diga se quer que eu escreva a entrada.
