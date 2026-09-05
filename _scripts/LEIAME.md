# LEIAME — `_scripts/`

## Defeito conhecido: DerivedData dentro da worktree

**Regra: nenhum script daqui pode escrever saída de build dentro da worktree.**
Isso inclui `-derivedDataPath`, `-resultBundlePath`, `xcresult`, `.build/` e qualquer
diretório de artefato. Se o caminho é relativo e o script faz `cd` para a raiz da
worktree antes, o resultado é escrito dentro da worktree — mesmo que o autor não
tenha pensado nisso.

### O que aconteceu

`lancar_build_watch.sh` usava:

```bash
cd "$RAIZ"
xcodebuild ... -derivedDataPath build_watch_dd build
```

`build_watch_dd` é caminho **relativo**, e o `cd "$RAIZ"` logo acima o ancora na
raiz da worktree. O DerivedData passou a viver em
`alma-jejum-watch-wt/build_watch_dd/`.

Em 2026-08-29 esse diretório chegou a **4,58 GiB**. Para comparação: as outras 15
worktrees do projeto somadas não chegavam a 15 MB.

### Por que isso é armadilha, e não questão de estilo

Três propriedades se combinam, e é a combinação que faz o estrago:

1. **Escapa de toda limpeza.** Todo mundo — Xcode, scripts de manutenção, os
   utilitários de "liberar espaço", a intuição de quem procura — olha em
   `~/Library/Developer/Xcode/DerivedData`. Um DerivedData fora dali não é
   encontrado por ninguém. Ele não é grande *e conhecido*; ele é grande *e
   invisível*.
2. **Reenche sozinho.** Não adianta apagar. É saída de build: o próximo build
   recria tudo. Limpar sem corrigir o script resolve por um dia.
3. **Multiplica por worktree.** O script é copiado nas quatro worktrees iOS.
   Cada uma que rodar o build ganha seu próprio DerivedData multi-GB, no lugar
   errado, sem que ninguém perceba.

O efeito prático foi o Mac sair de ~20 GB livres para 3 GB **em um dia**, sem
causa aparente. Descobrir isso custou uma varredura do disco inteiro. Escrever a
linha certa custa nada.

### A forma correta

```bash
DD_BASE="$HOME/Library/Developer/Xcode/DerivedData"
DD="$DD_BASE/$(basename "$RAIZ")_watch_dd"
mkdir -p "$DD"

xcodebuild ... -derivedDataPath "$DD" build
```

Três escolhas deliberadas:

- **Caminho absoluto.** Imune a `cd`, imune a de onde o script foi chamado.
- **Dentro do DerivedData padrão do Xcode.** Volta a ser alcançado por qualquer
  limpeza normal, incluindo o "Delete Derived Data" do próprio Xcode.
- **Sufixo com o nome da worktree** (`$(basename "$RAIZ")`). As quatro worktrees
  compartilham o mesmo `Alma.App.Oficial.xcodeproj`; sem o sufixo elas
  disputariam o mesmo DerivedData e invalidariam o cache uma da outra a cada
  troca de branch.

### Acoplamento: quem *lê* o DerivedData também precisa mudar

`instalar_ios_sim.sh` monta o caminho do `.app` a partir do DerivedData:

```bash
xcrun simctl install "$P" "$DD/Build/Products/Debug-iphonesimulator/Alma.App.Oficial.app"
```

Os dois scripts precisam derivar `$DD` da **mesma** expressão. Se você mudar o
caminho em um e não no outro, o build passa e a instalação falha depois — com
"arquivo não encontrado", longe da causa. Ao mexer em um, confira o outro.

Foi por isso que se optou por um caminho previsível em vez de deixar o Xcode
escolher: o padrão do Xcode inclui um hash (`Alma.App.Oficial-abc123xyz/`) que
nenhum script consegue montar sem consultar `xcodebuild -showBuildSettings`.

### Ao escrever um script de build novo, confira

- [ ] Todo caminho de saída é absoluto e começa fora da worktree.
- [ ] Depois de rodar o build uma vez:
      `find <worktree> -name 'Build' -o -name '*_dd' -o -name '*.xcresult'`
      não retorna nada.
- [ ] Se outro script consome esses artefatos, ele deriva o caminho da mesma
      expressão.
- [ ] O `-destination` foi conferido contra
      `xcrun simctl list devices available` — nomes de simulador mudam a cada
      versão do Xcode e viram falha de build enganosa.

---

## Armadilhas ativas nestes scripts (identificadores fixos que envelhecem)

Duas coisas estão escritas na mão e **quebram sozinhas** quando o Xcode
atualiza. Nenhuma tem a ver com o defeito do DerivedData; foram encontradas ao
validar a correção, em 2026-09-04.

**1. `lancar_build_watch.sh` — destino padrão inexistente.**
O padrão é `Apple Watch Series 11 (46mm)`. Nesta máquina só existe o **42mm**.
Quem rodar sem argumento leva erro de destino e vai achar que o build está
quebrado. Passe o destino explicitamente, conferindo antes com
`xcrun simctl list devices available`.

**2. `instalar_ios_sim.sh` — UDID de simulador morto.**
`P=C6E2BF1F-9ECF-4D63-B8B2-9BEC56F4405F` não corresponde a nenhum simulador
existente hoje. UDIDs são recriados quando o simulador é apagado ou o Xcode é
atualizado. Preferível resolver o simulador em tempo de execução — pelo que
estiver `Booted`, ou por nome — em vez de fixar o UDID.

Nenhuma das duas foi corrigida aqui: estão fora do escopo da correção do
DerivedData, e mexer nelas sem decisão sua seria inventar comportamento.

---

## Nota sobre `_validacao_*/`

As pastas `_validacao_<data>_<assunto>/` são registro do que foi feito naquele
dia. Alguns dos scripts ali dentro ainda contêm o caminho antigo
`build_watch_dd` — **isso é correto e não deve ser consertado**. Elas
documentam o estado da época; reescrevê-las apagaria a história que elas
existem para guardar. Se um `grep` por `build_watch_dd` bater nelas, o resultado
esperado é este arquivo, não um patch.

---

_Última atualização: 2026-09-04 — correção aplicada nas quatro worktrees iOS
(`alma.app.oficial-main`, `alma-ios-fotos`, `alma-jejum-watch-wt`,
`alma-ios-padrao-wt`)._
