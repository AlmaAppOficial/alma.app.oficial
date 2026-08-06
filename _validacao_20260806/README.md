# Validação do conserto do entitlement — 06/08/2026

Quem lê isto quer saber uma coisa: **o que foi provado de verdade e o que não foi.**

## Como reproduzir

```bash
cd functions && ./roda_testes_ciclo.sh          # 26 asserções contra o emulador
# bateria de mutação (sobe o emulador uma vez e muta 7 vezes):
firebase emulators:exec --only firestore --project demo-alma \
  "python3 functions/_mutacao_entitlement.py"
```

O emulador roda com `--project demo-alma`. O prefixo `demo-` faz o firebase-tools
trabalhar offline e recusar conexão com projeto real: **nenhum dado de produção é
tocado**, nem por acidente. O teste também aborta se `FIRESTORE_EMULATOR_HOST`
não estiver definido.

## ✅ Provado por mutação (execução, não leitura)

Cada linha abaixo foi apagada/neutralizada no código de produção, o projeto foi
recompilado, o teste rodou, e a asserção indicada **ficou vermelha**. Depois a
linha voltou e tudo ficou verde de novo (`99_restaurado.txt`).

| Mutação | O que foi neutralizado | Asserção que acusou | Evidência |
|---|---|---|---|
| M1 | guarda de ordem em `aplicarEvento` | C10 — renovação antiga reentregue depois do reembolso não devolve acesso | `M1_mutado_C10.txt` |
| M2 | exceção `REFUND`/`REVOKE` vencem fora de ordem | C11 — reembolso atrasado corta assim mesmo | `M2_mutado_C11.txt` |
| M3 | checagem de data em `ehAssinante` | C4 — `active:true` com data vencida não é assinante | `M3_mutado_C4.txt` |
| M4 | junção da tolerância do RenewalInfo | T1 — `DID_FAIL_TO_RENEW/GRACE_PERIOD` enxerga a tolerância | `M4_mutado_T1.txt` |
| M5 | lista de produtos de assinatura | C19 — produto estranho não vira Premium | `M5_mutado_C19.txt` |
| M6 | `export { vincularAssinatura }` no `index.ts` | C20 — o export existe no compilado | `M6_mutado_C20.txt` |
| M7 | exigência de vínculo antes de gravar | C12 — sem vínculo a notificação fica pendente | `M7_mutado_C12.txt` |

O harness carrega um **canário** (`TelaVaziaDePropósito` do mundo do servidor): ao
final, um caso que TEM de reprovar é rodado e o teste exige que o detector o
acuse. Se o canário passar, o resultado inteiro é descartado com `exit 3`.

## ⚠️ Provado só por leitura de código — NÃO por execução

Declarado em vez de escondido, conforme a Regra 3 do CLAUDE.md:

1. **A verificação criptográfica do JWS.** Nenhuma assinatura real da Apple foi
   verificada nesta sessão. Não há conta de sandbox disponível aqui e o endpoint
   não está implantado. O que foi exercitado é tudo o que vem **depois** da
   verificação. A verificação em si é a mesma biblioteca oficial que já estava
   em uso desde 04/08 e que a Apple já validou uma vez em produção (evidência
   antiga: notificação de teste real aceita, payload forjado rejeitado com 401).
2. **O corpo do `appleNotifications`** (o handler HTTP). Ele exige um JWS válido
   para chegar na parte testada. O que o teste cobre é a função que ele chama
   (`aplicarEvento`) e o formato de documento que ele grava — este último por
   simetria: o teste grava o mesmo shape e prova que `reprocessarPendentes` o
   encontra. Se alguém mudar o shape só no webhook, o teste **não pega**.
3. **`validateAndroidPurchase`.** A chamada à Google Play Developer API precisa
   de credencial. A gravação em `entitlements/{uid}` que foi acrescentada segue o
   mesmo formato provado nos testes, mas não foi executada.
4. **O cliente iOS.** Nenhum código Swift foi compilado ou rodado nesta sessão —
   não há Xcode aqui. O `AlmaEntitlementBridge` foi escrito e revisado, não
   exercitado.

## Arquivos de rodadas anteriores (mantidos de propósito)

- `M1_inconclusiva.txt`, `M3_inconclusiva.txt`, `M5_inconclusiva.txt` — primeira
  versão da bateria apagava o bloco inteiro e três mutações deixavam de compilar.
  O script marcou "inconclusiva" e **não** contou como prova, que é o
  comportamento certo: sem compilar, a asserção não chega a ser exercitada.
- `M7_mutado_C13.txt` — a bateria apontava para C13 ("ninguém vira assinante por
  acidente") e ela **continuou verde** com a mutação aplicada: o entitlement foi
  gravado num uid inventado, e C13 só olha o uid do caso. A bateria encontrou uma
  fraqueza da própria asserção. O alvo passou a ser C12, que exige
  `pendente === true`. Fica registrado porque é exatamente o tipo de cegueira que
  a Regra 1 existe para caçar.
