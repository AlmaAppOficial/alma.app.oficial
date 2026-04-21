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
- iPad Air 11-inch (M4): `id=8F134E67-0969-49A3-B78A-DA358F06ABD8`
- iPhone 17: `id=75197451-FF89-4589-9D9F-148D501DF5DC`

### Sistema de quotes dinâmicas (projeto futuro)
- Feature planejada: quotes selecionadas por perfil/momento do usuário
- Não bloqueia Apple
- Requer planejamento de produto dedicado antes de implementar
