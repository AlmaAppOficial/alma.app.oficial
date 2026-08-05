## Controle de sessões (adicionado 2026-04-20)

Este projeto é trabalhado através de sessões de Claude Code ou Claude Desktop
iniciadas manualmente por Felipe Assis Lara. Felipe ocasionalmente tem múltiplas
sessões em paralelo por esquecimento — se detectar outras sessões ativas, avisar
antes de fazer modificações.

Regras invioláveis:
- Strings de UI em PT-BR (não PT-PT)
- NÃO fazer git push em nenhuma circunstância
- NÃO commitar sem aprovação explícita na conversa atual
- PARAR e perguntar se encontrar ambiguidade
- Se rodando com --allow-dangerously-skip-permissions, adicionar pausa manual
  antes de escrever QUALQUER arquivo fora da tarefa explicitamente pedida

## Regra inviolável de produto

O Alma está em refatoração para alinhar UI com posicionamento de "autoconhecimento
por IA". O motor interno usa framework numerológico/cabalístico, mas a UI NÃO
deve expor vocabulário técnico desse framework.

Código novo desta fase deve:
- Usar nomes neutros para tipos e propriedades expostas à UI
  (evitar 'KabbalisticInsight', preferir 'GuidanceInsight' ou similar)
- Não mostrar labels como "Missão X", "Destino Y", "Ano Pessoal Z" ao usuário
- Manter camada de cálculo interna, isolando-a da apresentação

Submissão à Apple está PAUSADA até refatoração completa.

## Deploy log

### 2026-04-20 — Cloud Functions
- onUserDeletionRequested deployada em produção
  - Region: southamerica-east1
  - Runtime: Node.js 20
  - Trigger: Firestore document write em users/{uid}
  - Estado: ACTIVE
  - Primeira função 2nd gen do projeto (provisionou Eventarc + Pub/Sub)

## Pendências técnicas conhecidas

- Migrar Cloud Functions de Node 20 para Node 22 antes de 30/10/2026
- Atualizar firebase-functions package (warning de versão antiga ao deployar)
- **Fronteira do `fullScreenCover` × `preferredColorScheme`** (aberta em
  05/08/2026, build 93). Mudança de aparência feita COM o módulo Corpo em tela
  não chega à tela, nos dois sentidos, mesmo com escritor e leitor corretos.
  Contornado no 93 removendo os controles de aparência de dentro do Corpo.
  Diagnóstico completo, o que está provado, as duas hipóteses que sobraram e o
  experimento que as separa: cabeçalho de `Shared/AparenciaDoApp.swift`, seção
  "DÍVIDA CONHECIDA". Não bloqueia Apple. Custa uma tarde com calma.
  O invariante ("nenhum controle de aparência dentro de `Shared/Corpo/`") está
  garantido por **`_scripts/guarda_a26.sh`**, instalado como hook de
  `pre-commit`. Provado por mutação em 05/08: reprova o controle de volta E
  reprova quando fica cego.

  **Por que NÃO é fase de build, que era o plano:** o projeto tem
  `ENABLE_USER_SCRIPT_SANDBOXING = YES` (pbxproj, linhas 1407 e 1471). Uma fase
  de script não consegue ler `Shared/Corpo` — `grep` morre com
  `Operation not permitted`, e declarar o diretório em `inputPaths` não resolve.
  A primeira versão da fase engolia esse erro com `2>/dev/null` e aprovava tudo:
  guarda cega, o mesmo modo de falha que A26d denuncia, cometido pela própria
  guarda. A fase foi REMOVIDA e o pbxproj está idêntico ao commit `bfd05fd`.

  **Decisão pendente:** para voltar a ser fase de build seria preciso
  `ENABLE_USER_SCRIPT_SANDBOXING = NO` no target iOS — é afrouxar uma
  configuração de segurança deliberada, então fica para o Assis decidir.

  **Limitação do hook:** `.git/hooks/` não é versionado. Depois de um clone
  novo, rodar `_scripts/instalar_hook_a26.sh` para reinstalar.

- **PRIORIDADE — preço morto e errado em arquivo compilado.** `Shared/PaywallView.swift`
  e `Shared/DynamicPricingManager.swift` não são alcançados por nenhuma tela
  (`PaywallView(` só aparece nos próprios `#Preview`, linhas 352 e 359; o
  `DynamicPricingManager` só é referenciado de `PaywallView.swift:312`), **mas
  os dois estão no target e viajam dentro do IPA**. Carregam `R$ 24,99`
  (`PaywallView:338,341`; `DynamicPricingManager:200,203,310,313`) e
  `"Apenas R$ 399 para sempre"` (`DynamicPricingManager:284,285`) — valores que
  NÃO existem no App Store Connect. O preço real do BRA é R$ 24,90 hoje e
  R$ 49,90 a partir de 06/08/2026. É mina terrestre: no dia em que alguém
  religar aquela tela, o app volta a anunciar preço errado. Conserto: tirar os
  dois do target (ou apagar). Não mexer junto de um build que vai para revisão.

- **XCUITest ausente.** Nenhuma asserção do projeto consegue ler a tela de
  verdade. `AuditoriaBloqueadores.textosDaTela` foi a tentativa e falhou por
  motivo estrutural: SwiftUI não constrói `UILabel` e só monta a árvore de
  acessibilidade com tecnologia assistiva ativa. A26d e A27g estão vermelhas
  documentando isso. Enquanto não houver alvo de UI test, asserção de AUSÊNCIA
  em tela não é possível — use checagem de fonte em build phase, como a
  "Guarda A26".

- **OS LEMBRETES DE HÁBITO NÃO EXISTEM — e é provável que se ache que existem.**
  `Shared/HabitNotificationManager.swift` tem ~500 linhas de lógica completa
  (manhã, noite, horário personalizado, sequência em risco, marcos) e **não
  está no `project.pbxproj`**: `grep -c HabitNotificationManager` no pbxproj
  devolve `0`. Nunca foi compilado, nunca foi instanciado, nunca agendou nada.
  Ele também declara um `UNUserNotificationCenterDelegate` próprio
  (`HabitNotificationManager.swift:445`) que nunca foi registrado.

  O que o app REALMENTE agenda hoje são 12 notificações, todas fora desse
  arquivo: 4 de água + 3 de refeição + treino + suplemento
  (`Corpo/NotificationManager.swift`), 2 de meditação (`LembretesDaAlma.swift`),
  5 marcos de vício (`AddictionFreeView.swift`, disparo único) e o push de feed
  da Cloud Function. **Não há notificação de "falar com a Alma"** — a rota para
  o chat existe em `RotaDaNotificacao`, pronta, mas ninguém agenda nada para
  ela.

  **Decisão de 05/08: NÃO registrar o arquivo agora.** Incluir 500 linhas que
  nunca passaram pelo compilador num build é criar recurso novo sem teste — o
  mesmo erro que a lição do dia denuncia. Se for para existir, entra por
  planejamento de produto, com asserção, não por um `add` no pbxproj.

## Lição de método (05/08/2026) — asserção prova a peça, não o elo

Dois bugs no mesmo dia com a mesma forma: a auditoria estava verde e a tela
estava quebrada.

- Modo escuro: `A24b` chamava `alternar()` e exigia que o esquema virasse.
  Virava — no modelo. Na tela do aparelho o botão não fazia nada, porque
  nenhuma asserção jamais olhou uma tela.
- HealthKit: nada verificava se a abertura fria buscava dado. "Toda abertura
  começa desconectada" viveu meses invisível.

Contramedida adotada: `AuditoriaBloqueadores.textosDaTela(_:)` hospeda a view
numa `UIWindow` real e devolve o texto que a tela expõe de fato. **Toda
asserção de AUSÊNCIA feita com ele exige uma guarda anti-cegueira ao lado**
(ver `A26d`): um coletor que não enxerga nada faz qualquer asserção de ausência
passar para sempre — o pior tipo de verde.

Desfecho: o coletor NÃO funciona (SwiftUI não expõe texto fora de XCUITest), e
a A26d provou isso contra a própria autora, na primeira execução, antes de
qualquer mutação. A26a/A26b foram confirmadas cegas por experimento — passaram
verdes com o botão da lua de volta. O invariante migrou para a fase de build
"Guarda A26". **A26d e A27g ficam vermelhas de propósito**: vermelho
documentado vale mais que verde cego.

## Onde a prova termina (05/08/2026) — rotas de notificação e scan honesto

Nota curta para quem ler daqui a um mês e precisar saber até onde ir de graça.

**PROVADO, rodando de verdade** (asserções no `AuditoriaBloqueadores`, DEBUG):

- `H2` — o número que a tela CALCULA e o número que o `AppModel` GRAVA são o
  mesmo: 250 g a 208 kcal/100 g dão 520 kcal exibidos e 520 kcal no diário.
  Só é possível porque as duas pontas passam por `AppModel.escalarPor100`;
  divergir exigiria chamá-la com gramas diferentes.
- `R5` — um destino roteado sem nenhum observador (o que acontece na partida
  fria, antes de existir view) continua lá quando a primeira tela nasce.
- `R2` — o mapa identificador → destino, um a um.
- Guardas anti-cegueira ao lado de cada uma: `R0`, `H1b`, `H2b`.

**NÃO PROVADO, e a distinção importa:**

- `H2` **não prova o que a View DESENHOU**. Ela compara dois cálculos, não dois
  pixels. Se alguém trocar o `Text` do tile por um literal, `H2` continua verde
  e a tela mente. O que cobre esse elo é o lint `H-W2` — verificação de FONTE,
  não de tela.
- Nada prova que o iOS chama o delegate ao tocar na notificação, nem que a aba
  muda na tela. Isso é XCUITest, que o projeto não tem (ver "XCUITest ausente").

Regra prática: `H*` e `R*` provam a ARITMÉTICA e o ESTADO. Os lints `H-W*` e
`R-W*` prendem as LINHAS que ligam isso à interface. Ninguém aqui viu uma tela.
Os testes de mutação (`_scripts/mutacao_notificacoes.sh`,
`_scripts/mutacao_scan_honesto.sh`) listam ao final, por escrito, o que não
executam — 15 mutações, 15 vermelhas, 0 furos, e a cegueira declarada embaixo.

## Impacto em dados já gravados (05/08/2026) — apurado, não estimado

O bug da porção fixa (`grams: 100`) grava caloria errada no diário. Pergunta
certa: quantas refeições reais foram afetadas? Respondida na FONTE, pelos
recibos de `users/{uid}/scans` que a Cloud Function grava a cada análise:

- **6 recibos no total, desde que a função existe (04/08).**
- **comida: 1 sucesso** (05/08 06:55Z) **e 4 falhas** (`foto_ilegivel`).
- **corpo: 1 falha** (`foto_ilegivel`). Nenhum sucesso.

Falha nunca vira número — o app mostra erro. Então o teto do estrago é **uma
refeição**, e o único sucesso é de 06:55Z = 07:55 local, um minuto depois do
commit do build 92 (07:54): foi a verificação do próprio caminho recém-ligado.

Cicatrização: `meals` é diário (`loadMealsForToday` devolve templates vazios se
`mealsDate` não for hoje) e `kcalByDay[hoje]` é reescrito como `kcalConsumed` a
cada mudança. Corrigir o diário de hoje conserta o histórico de hoje sozinho.
Depois da virada do dia, o valor daquele dia congela e não há tela para editá-lo.

**O que NÃO dá para descartar daqui:** entradas de `kcalByDay` anteriores a
03/08, quando o scan de comida ainda caía num mock que inventava macros (bug
F2/B8). Aquilo era resultado fabricado, não só porção errada. Verificar exigiria
ler o `UserDefaults` do aparelho.

## Lição de método (05/08/2026) — verifique a premissa, não só o código

Alarme de preço: um print mostrava "$3.99/mês" numa tela em português e a
conclusão natural era "preço chumbado, moeda errada, bug grave". Estava tudo
errado nessa conclusão.

O que a verificação na fonte mostrou: a tela lê `Product.displayPrice`
(`SubscriptionView.swift:199` e `:242`) e o caminho de reserva não tem dígito
nenhum. Logo o "3.99" só podia vir do StoreKit — e a API do App Store Connect
confirmou: **USD 3,99 é o preço americano real e vigente**, equivalente aos
R$ 24,90 brasileiros. O simulador estava num storefront não-brasileiro porque
esta máquina roda em fuso de Londres.

Regra: quando um número na tela parece errado, pergunte à FONTE que o produz
(aqui, a loja pela API) antes de acusar o código. E note o efeito colateral
útil: foi essa checagem que revelou a divergência real — o preço vigente hoje
é R$ 24,90, não os R$ 49,90 que se supunha.

---

## Follow-ups pendentes (adicionado 2026-04-21)

### Strings PT-PT → PT-BR (pré-existente, não bloqueia Apple)
- ProfileView: `"Utilizador"` → `"Usuário"`
- ProfileView: `"Feito com ❤ em Portugal"` → revisar
- InsightsView: `"Check-in registado!"` → `"registrado!"`
- InsightsView: `"Liga o Apple Health para veres os teus dados"` → `"ver seus dados"`

### NavigationView → NavigationStack em modals/sheets (baixa prioridade)
Não causam split view (são sheets, não raízes de tab). Mas convém migrar para consistência:
- `FeedView.swift:34, 306`
- `LoginView.swift:123`
- `ProfileView.swift:311, 375`
- `DeleteAccountView.swift:16`
- `AddictionFreeView.swift:441`
- `InsightShareSheet.swift:15`
- `FeminineHealthView.swift:385, 416`

### Builds locais no simulador iPad/iPhone
Requer override de team ID na linha de comando — NUNCA commitar no `.pbxproj`:
```
xcodebuild -scheme "Alma.App.Oficial (iOS)" \
  -destination "platform=iOS Simulator,id=<DEVICE_ID>" \
  -configuration Debug \
  DEVELOPMENT_TEAM=CV2V6HLTS2 \
  build
```
- Motivo: `.pbxproj` tem `DEVELOPMENT_TEAM = J9U729KYR7` (produção/Fastlane), sem cert local.
  `CV2V6HLTS2` = cert "Apple Development: alma.app.oficial@gmail.com" presente nesta máquina.

**NÃO anote `<DEVICE_ID>` aqui — descubra em tempo de execução.** [2026-08-05]
Este arquivo listava `iPhone 17` e `iPad Air 11-inch (M4)` com UUIDs fixos, e os
dois já não existem: o Xcode trocou os simuladores e o build morreu com
"Unable to find a device matching the provided destination specifier".
Documento que mente custa mais caro que documento ausente — no mesmo dia um
relatório de julho descreveu um app que não existe mais.

Um UUID novo escrito aqui morre na próxima máquina ou na próxima atualização do
Xcode. Descubra assim:
```
xcrun simctl list devices available | grep -E '^\s+iPhone' | head -1 \
  | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
```
`_scripts/build_e_auditar_20260805.sh` e `_scripts/rodar_auditoria_20260805.sh`
já fazem isso sozinhos e abortam com mensagem clara se não houver simulador.
(`_scripts/rodar_auditoria.sh`, de 03/08, ainda tem `DEV=` chumbado — quando ele
falhar, é por isso.)

### Sistema de quotes dinâmicas (projeto futuro)
- Feature planejada: quotes selecionadas por perfil/momento do usuário
- Não bloqueia Apple
- Requer planejamento de produto dedicado antes de implementar
