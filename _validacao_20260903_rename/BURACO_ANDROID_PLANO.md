# O buraco de paridade: o plano gerado não existe no Android

*Levantado em 2026-09-03, ao investigar o print do plano do Assis.*

## Para mostrar ao Assis, em um parágrafo

O defeito que você viu — "Crucifixo" e "Tríceps corda" saindo como *Peso corporal*, com
o boneco genérico — é do **iOS e só do iOS**, porque a funcionalidade inteira é do iOS e
só do iOS. No iPhone, o scan corporal termina gerando um plano de semana e oferecendo
"aplicar": os sete dias viram sete treinos na lista "Meus treinos", com nome
`Plano · Segunda — Peito e tríceps`. No Android isso não existe em lugar nenhum: o scan
analisa a foto, mostra o resultado e para ali. Não há gerador de plano, não há botão de
aplicar, não há treino de plano na lista. Então não é o caso de "corrigir nos dois" —
no Android não há o que corrigir, há o que **construir**. As duas plataformas
compartilham o catálogo (os mesmos 1.095 exercícios e as mesmas 605 ilustrações, byte a
byte), e é só isso que hoje está em paridade nessa área.

## A evidência

Enumeração no `alma-android/app/src/main`, não grep solto:

| Símbolo procurado | iOS | Android |
|---|---|---|
| `PlannedDay` / `DiaPlanejado` | `AIBodyScan.swift:199` | **nenhuma ocorrência** |
| `GeneratedPlan` / `PlanoGerado` | `AIBodyScan.swift:206` | **nenhuma ocorrência** |
| `applyPlan` (aplicar o plano) | `Models.swift:977` | **nenhuma ocorrência** |
| Treino com prefixo `"Plano · "` | `Models.swift`, `TreinoView` | **nenhuma ocorrência** |
| Catálogo `exercises_v2` (1.095) | `Shared/Corpo/exercises_v2.json` | `data/catalogo/ExerciciosParte*.kt` ✅ |
| Ilustrações RepDB | 605 webp em `ExerciciosFotos/` | 605 webp em `assets/exercicios/` ✅ |

O `ScanCorporal.kt` do Android tem a análise e as observações, e nenhuma função que
monte semana de treino.

## Tamanho aproximado do porte, se o Assis quiser

Estimativa grosseira, para ele decidir — não é compromisso:

1. **Modelo + gerador** (`PlanoGerado`, `DiaPlanejado`, `semanaPara(objetivo)`): tradução
   quase mecânica de `AIBodyScan.week(for:)`. Pequeno.
2. **Resolução de nome → exercício**: precisa da mesma tabela `NomesDePlano` e da mesma
   regra "não inventa" que acabou de entrar no iOS. **Se for portado sem isso, o Android
   nasce com o bug de hoje do iOS.** Pequeno, mas é o passo que não pode ser pulado.
3. **Aplicar o plano** (virar treinos na lista, mexer na meta calórica e no diário):
   é o pedaço grande, porque encosta em persistência. Médio, e com o cuidado do
   `DataRepository.kt:159-184` — mesmo risco do `try?` do iOS.
4. **Telas**: reaproveitam `WorkoutDetail`/`SessaoDeTreino` que já existem. Pequeno.

O item 3 é o que decide o prazo. Os outros três são acessórios dele.

## Recomendação

Não comecei o porte, por instrução do Assis (03/09). Se ele mandar tocar, o pedido é
fazer **na ordem acima**, e escrever a tabela de nomes ANTES do gerador — pela mesma
razão que o iOS aprendeu hoje: um gerador que emite nome livre contra um resolvedor
tolerante produz dado fabricado que ninguém vê até virar print de usuário.
