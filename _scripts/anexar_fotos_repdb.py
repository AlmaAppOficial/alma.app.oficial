#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Anexa as fotos do RepDB ao catálogo `exercises_v2.json` — e SÓ isso.

    python3 _scripts/anexar_fotos_repdb.py \
        --acervo   /caminho/repdb_migracao/imagens_reenquadradas \
        --mapa     /caminho/repdb_migracao/MAPA_SEMANTICO.csv \
        --repdb    /caminho/repdb_migracao/repdb_ptbr.json \
        --catalogo Shared/Corpo/exercises_v2.json \
        --destino  Shared/Corpo/ExerciciosFotos

═══════════════════════════════════════════════════════════════════════════
O QUE ESTE SCRIPT **NÃO** FAZ — e por que a lista importa
═══════════════════════════════════════════════════════════════════════════

Não substitui os 1.095 pelos 601 do RepDB. Não apaga exercício. Não renomeia
nada. Não mexe em `instructions`, `namePTBR`, `id`, `media`, `defaultSets` nem
em qualquer outro dos 15 campos que já existiam. **Acrescenta um campo novo
(`fotos`) a quem casou, e ponto.**

Cada uma dessas abstenções tem um motivo concreto:

• **`id` intocado** — o histórico de séries (`RegistroDeSeries.swift`) é
  indexado pelo slug do NOME. Renomear um exercício órfã a carga que a pessoa
  registrou nele. O nome exibido é a chave de fato; mexer nele apaga passado.

• **`media` intocado** — `ExerciseV2.displaySymbol` lê `media.sfSymbolName`, e
  `asLegacyExercise()` grava esse símbolo dentro de `customWorkouts`, que é
  FORMATO PERSISTIDO. Trocar `media` mudaria, de tabela, o que fica gravado no
  aparelho de quem monta um treino novo. A foto entra num campo à parte
  justamente para não encostar nesse caminho.

• **campo NOVO e OPCIONAL** — `Exercise` e `CustomWorkout` (os tipos
  persistidos) não ganham campo nenhum; quem ganha é `ExerciseV2`, que só é
  lido do bundle. E ainda assim como opcional, porque `AppModel.init`
  decodifica `customWorkouts` com `try?`: campo obrigatório novo em tipo
  persistido = `keyNotFound` = treino da pessoa some em silêncio. Ver o
  cabeçalho de `Exercicio.swift` e a asserção L1 de `_scripts/testes_series.swift`.

• **só as faixas A_EXATO e B_EQUIVALENTE** — as 320 de `C_REVISAR` esperam olho
  humano (`PRECISA_DE_OLHO.csv`), e as 261 órfãs continuam exatamente como
  estão. Órfão sai da busca por imagem, nunca do catálogo: quem tem um deles no
  treino continua tendo, e continua podendo re-adicionar.

Nada regride porque hoje NENHUM exercício tem imagem no app: o piso é zero.

═══════════════════════════════════════════════════════════════════════════
LICENÇA — LEIA ANTES DE MEXER NAS IMAGENS
═══════════════════════════════════════════════════════════════════════════
Fonte: RepDB free tier (`@repdb/exercises`), https://repdb.co

  • termo 2 — atribuição obrigatória, como LINK VISÍVEL. Está em
    `SettingsView.swift` (tela de Ajustes) e no site. Texto exato, em inglês
    de propósito: "Exercise data by RepDB (repdb.co)".
  • termo 3 — PROIBIDO republicar o acervo como dataset/repositório/API. É por
    isso que estas imagens vão NO BUNDLE e não por URL pública, como o catálogo
    faz hoje com `raw.githubusercontent.com`. Nada de hotlink.
  • termo 4 — redimensionar, cortar, recolorir e REMOVER O FUNDO é permitido,
    e o texto cita a remoção de fundo por escrito.
  • termo 5 — PROIBIDO usar estas imagens como entrada de modelo generativo.
    Sem img2img, sem upscaler neural, sem remoção de fundo por IA. A chave de
    fundo usada aqui é aritmética sobre o pixel; nenhum modelo entra no caminho.
    "Melhorar" as fotos com IA viola o termo 5 e, pelo próprio texto da
    licença, contamina o resultado como dataset derivado sob o termo 3.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import sys

CREDITO_REPDB = "RepDB (repdb.co)"
FAIXAS_SEGURAS = ("A_EXATO", "B_EQUIVALENTE")


def ler_mapa(caminho: str) -> list[dict]:
    with open(caminho, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--acervo", required=True, help="pasta com os .webp reenquadrados")
    p.add_argument("--mapa", required=True, help="MAPA_SEMANTICO.csv")
    p.add_argument("--repdb", required=True, help="repdb_ptbr.json")
    p.add_argument("--catalogo", required=True, help="exercises_v2.json (editado no lugar)")
    p.add_argument("--destino", required=True, help="pasta de imagens dentro do app")
    p.add_argument("--relatorio", default=None, help="CSV com quem ficou sem foto")
    a = p.parse_args()

    mapa = ler_mapa(a.mapa)
    repdb = {e["repdb_id"]: e for e in json.load(open(a.repdb, encoding="utf-8"))["exercicios"]}
    catalogo = json.load(open(a.catalogo, encoding="utf-8"))

    por_alma = {r["alma_id"]: r for r in mapa if r["faixa"] in FAIXAS_SEGURAS}

    # ── Controle positivo do próprio script ────────────────────────────────
    # Um casamento que não casa com nada produziria "0 fotos" em silêncio e o
    # relatório diria, com toda a calma, que ninguém tinha imagem. Aqui isso é
    # erro barulhento.
    ids = {e["id"] for e in catalogo}
    orfaos_do_mapa = [i for i in por_alma if i not in ids]
    if orfaos_do_mapa:
        print(f"ERRO: {len(orfaos_do_mapa)} alma_id do mapa não existem no catálogo: "
              f"{orfaos_do_mapa[:5]}", file=sys.stderr)
        return 2
    if not por_alma:
        print("ERRO: o mapa não trouxe nenhuma linha segura. Arquivo errado?", file=sys.stderr)
        return 2

    os.makedirs(a.destino, exist_ok=True)

    usados: set[str] = set()
    com_foto = 0
    sem_foto: list[tuple[str, str, str]] = []

    for ex in catalogo:
        linha = por_alma.get(ex["id"])
        if linha is None:
            faixa = next((r["faixa"] for r in mapa if r["alma_id"] == ex["id"]), "FORA_DO_MAPA")
            sem_foto.append((ex["id"], ex["namePTBR"], faixa))
            continue
        fonte = repdb.get(linha["repdb_id"])
        imagens = (fonte or {}).get("imagens") or {}
        # Ordem cronológica do movimento: início antes do pico.
        arquivos = [imagens[k] for k in ("start", "peak", "main") if k in imagens]
        arquivos = [f for f in arquivos if os.path.exists(os.path.join(a.acervo, f))]
        if not arquivos:
            sem_foto.append((ex["id"], ex["namePTBR"], linha["faixa"] + "_SEM_ARQUIVO"))
            continue

        ex["fotos"] = arquivos
        # O crédito exibido no detalhe passa a dizer a verdade: a foto é do
        # RepDB mesmo quando o texto veio de outra fonte.
        if CREDITO_REPDB not in ex["sourceAttribution"]:
            ex["sourceAttribution"] = f'{ex["sourceAttribution"]} + {CREDITO_REPDB}'
        usados.update(arquivos)
        com_foto += 1

    for nome in sorted(usados):
        shutil.copyfile(os.path.join(a.acervo, nome), os.path.join(a.destino, nome))

    with open(a.catalogo, "w", encoding="utf-8") as f:
        json.dump(catalogo, f, ensure_ascii=False, indent=1)
        f.write("\n")

    if a.relatorio:
        with open(a.relatorio, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["alma_id", "nome", "motivo"])
            w.writerows(sem_foto)

    peso = sum(os.path.getsize(os.path.join(a.destino, n)) for n in usados)
    print(f"catálogo........: {len(catalogo)} exercícios")
    print(f"com foto........: {com_foto}")
    print(f"sem foto........: {len(sem_foto)}")
    print(f"arquivos........: {len(usados)}  ({peso / 1048576:.2f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
