# ⛔️ Gate: scan corporal com IA — o que muda ANTES de ligar

**Criado em:** 04/08/2026 · **Origem:** A15 da revisão independente de 03/08
**Estado hoje:** IA do scan **DESLIGADA** (`GeminiConfig.isAvailable == false`, provado pela asserção `B8a` do auditor). Nenhuma foto sai do aparelho.

Este documento existe porque a copy do app e o comportamento do código só batem **enquanto a IA estiver desligada**. No dia em que alguém puser uma key — ou apontar o scan para um backend — o app passa a enviar fotos do corpo e medidas para fora, e três telas passam a mentir.

---

## 1. O que sai do aparelho quando a IA liga

`GeminiService.analyzeBody(input:)` envia:

- as **duas fotos do corpo** (frente e lado);
- **peso, altura, idade, % de gordura estimado e objetivo**.

Hoje esse método é inalcançável: `AIPlanService.make()` só devolve `GeminiAIPlanService` se `GeminiConfig.isAvailable` for verdadeiro; caso contrário cai no `MockAIPlanService`, e a tela mostra "Estimativa por medidas — sem IA".

## 2. A copy — as duas versões

| Onde | Hoje (verdadeiro com a IA desligada) | No dia em que ligar |
|---|---|---|
| `OnboardingBiometricsView` (peso/altura) | "Sem isso, as metas de calorias e água seriam chute. **Fica só no seu aparelho.**" | "Sem isso, as metas de calorias e água seriam chute. Fica no seu aparelho — **se você pedir o plano por foto, suas medidas vão junto com as fotos para a análise.**" |
| `ProfileView` → cartão "Inteligência Artificial" | "Seus dados de saúde são lidos diretamente do Apple Health e **ficam no aparelho**: o que pode acompanhar a conversa é um resumo curto do seu dia — e só das categorias que você autorizar." | Mesma frase **+** "O scan corporal é a única exceção: as fotos e as medidas que você enviar para gerar o plano são analisadas fora do aparelho, com seu aval a cada envio." |
| `BodyScanView` (tela das fotos) | overlay "Estimativa por medidas — sem IA" | "Para gerar o plano, suas duas fotos e suas medidas são enviadas criptografadas para análise e apagadas logo depois. Nada é guardado, nem usado para treinar modelo nenhum. Você decide a cada envio — e pode usar a estimativa por medidas, sem foto." |
| `PrivacyInfo.xcprivacy` + App Privacy no ASC | Health & Fitness declarado (A9, feito em 03/08) | Acrescentar **Photos or Videos** com finalidade de funcionalidade do app, e revisar "Data Not Linked to You" |

## 3. Recomendação de arquitetura — não reativar como está

A implementação atual chama o Gemini **direto do aplicativo, com a key no bundle**. Isso é ruim por três motivos independentes:

1. **A key vaza.** Qualquer pessoa descompacta o IPA e usa a sua cota. O projeto já rotacionou chaves TTS por exposição — é o mesmo erro de novo.
2. **Sem controle.** Não dá para limitar taxa, auditar uso, trocar de modelo ou desligar sem publicar uma versão nova na loja.
3. **Sem regime de consentimento.** O envio acontece dentro do fluxo do scan, sem passar pelos toggles de `HealthContextConsent` que governam todo o resto dos dados de saúde.

**Caminho recomendado — Cloud Function + consentimento por envio:**

- o app manda as fotos para a mesma Cloud Function que já atende o chat (autenticada com Firebase ID token);
- a função fala com o provedor de IA, **a key nunca sai do servidor**;
- nada é persistido: as imagens vivem em memória durante a chamada e são descartadas;
- a tela pede confirmação **a cada envio** ("Enviar estas 2 fotos para análise?"), com a alternativa "usar só as medidas" sempre visível;
- registrar no app um recibo do que foi enviado e quando, visível no Perfil.

**Alternativa (mais privada, mais cara):** análise 100% no aparelho com Vision/CoreML. Elimina o envio e a conversa toda sobre consentimento, mas exige modelo próprio, dá um resultado mais pobre que o de um modelo grande e é trabalho de semanas, não de dias.

**Terceira opção — assumir e não ligar:** manter a estimativa por medidas como o produto, e tirar "com IA" de qualquer promessa. É a opção que não custa nada e não cria risco nenhum; a decisão é do Assis.

## 4. Onde está o lembrete no código

Bloco `⛔️ GATE DE PRIVACIDADE` no topo de `GeminiService.analyzeBody(input:)`. Quem for ligar a IA tropeça nele antes de mexer.
