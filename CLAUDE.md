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
