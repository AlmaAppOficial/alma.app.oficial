# App Privacy no App Store Connect — o que marcar (versão 2.0)

**05/08/2026** · App **Alma** (ID 6761478534)
**Onde:** App Store Connect → Alma → *App Privacy* → **Edit** em "Data Types"

> Este formulário é **web e não tem API** — é a única parte do ASC que eu não
> consigo preencher por você. O resto (novidades, build anexado, metadata) já foi.
>
> A lista abaixo é o espelho exato do `PrivacyInfo.xcprivacy` que vai dentro do
> build 92. Os dois precisam concordar: divergência entre manifesto e formulário
> é motivo de rejeição, e é o tipo de coisa que a Apple confere.

---

## Resposta à primeira pergunta

**"Do you or your third-party partners collect data from this app?"** → **Yes**

---

## Os 9 tipos de dado a marcar

Para **todos** eles, as respostas às três perguntas seguintes são as mesmas:

- *Is this data linked to the user's identity?* → **Yes**
- *Do you use this data for tracking purposes?* → **No**

O que muda entre eles é só a **finalidade** (a última coluna).

| # | Categoria | Tipo | Finalidade a marcar |
|---|---|---|---|
| 1 | Contact Info | **Email Address** | App Functionality |
| 2 | Contact Info | **Name** | App Functionality |
| 3 | Health & Fitness | **Health** | App Functionality |
| 4 | Health & Fitness | **Fitness** | App Functionality |
| 5 | User Content | **Other User Content** | App Functionality · Product Personalization |
| 6 | **User Content** | **Photos or Videos** ⬅ **NOVO no 92** | App Functionality |
| 7 | Identifiers | **User ID** | App Functionality · Analytics |
| 8 | Identifiers | **Device ID** | Analytics |
| 9 | Usage Data | **Product Interaction** | Analytics · Product Personalization |

---

## Por que o item 6 entrou agora

O build 92 liga a análise de foto por IA (corpo e comida). A foto sai do
aparelho, então **tem de ser declarada** — mesmo sendo efêmera.

O que acontece de fato, para você responder com segurança se a Apple perguntar:

- a pessoa autoriza **a cada envio**, num diálogo que explica o que acontece;
- no scan corporal existe a alternativa **"Gerar só com minhas medidas"**, que
  não envia foto nenhuma;
- a foto vai para a nossa Cloud Function `analisarFoto`, que a repassa ao
  provedor de IA e **não a persiste** — nem em Storage, nem em Firestore, nem
  em disco. O que fica gravado é um recibo com tipo, data e se deu certo;
- o provedor pode reter a imagem por **até 30 dias** para prevenção de abuso, e
  não a usa para treinar modelos. Isso está escrito na tela, no ponto do
  consentimento — não escondido na política.

**Linked = Yes** porque o envio é autenticado com o Firebase ID token, então é
atribuível à conta. **Tracking = No** porque nada disso alimenta publicidade nem
sai para terceiros além do provedor que processa a imagem.

---

## Uma coisa para você decidir depois (não bloqueia a submissão)

A tela **Perfil → Privacidade** ainda diz que os dados do Apple Saúde
"NUNCA saem do seu dispositivo". Isso já era impreciso antes de hoje — o chat
envia um resumo curto do dia quando você autoriza — e continua sendo. Não é
sobre o scan e não muda o formulário, mas é uma frase que eu reescreveria antes
da próxima submissão. Me avise se quer que eu ajuste.
