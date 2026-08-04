#!/usr/bin/env python3
"""Verifica que as CHAMADAS críticas existem no código de produção.

[2026-08-04 — resposta à reauditoria]

A revisora aplicou quatro mutações e o harness continuou 40/40. Duas delas
(M2 e M3) foram dentro de uma View — apagar `model.registrarTreinoConcluido()`
do botão, e reintroduzir `if hasPremiumAccess` no botão de água.

Nenhuma asserção em runtime pega isso sem renderizar a tela E simular o toque.
Mover a lógica para o AppModel, como fiz ontem, NÃO resolveu: fez a View e o
harness chamarem o mesmo método, não fez o harness exercitar a chamada da View.
A revisora está certa: o defeito foi movido um nível, não corrigido.

O que pega é isto: um lint que afirma que a chamada existe (ou não existe) no
arquivo certo. É uma "fitness function" de arquitetura — verificação estática,
mas que FICA VERMELHA sob exatamente a mutação que o runtime não vê.

Cada regra abaixo tem um campo `mutacao`: a edição que deve deixá-la vermelha.
É assim que este lint se prova — ver `_scripts/mutacao.sh`.
"""
import re
import sys
from pathlib import Path

RAIZ = Path(sys.argv[1] if len(sys.argv) > 1 else ".")

REGRAS = [
    {
        "id": "W1",
        "desc": "concluir treino GRAVA o dia (bug B3)",
        "arquivo": "Shared/Corpo/WorkoutSessionView.swift",
        "precisa": r"model\.registrarTreinoConcluido\(\)",
        "mutacao": "comentar a chamada em registrarTreinoConcluido() da View",
    },
    {
        "id": "W2",
        "desc": "exclusão de conta chama a limpeza local (bug B9/LGPD)",
        "arquivo": "Shared/AccountDeletionService.swift",
        "precisa": r"Self\.executarLimpezaLocal\(\)",
        "mutacao": "comentar a chamada de limpeza na requestDeletion",
    },
    {
        "id": "W3",
        "desc": "limpeza local realmente apaga (bug B9/LGPD)",
        "arquivo": "Shared/AccountDeletionService.swift",
        "precisa": r"LocalDataCleanupService\.clearAll\(\)",
        "mutacao": "comentar clearAll() dentro de executarLimpezaLocal",
    },
    {
        "id": "W4",
        "desc": "limpeza interrompida é retomada no boot (D-1)",
        "arquivo": "Shared/AlmaApp.swift",
        "precisa": r"retomarLimpezaPendenteSeNecessario\(\)",
        "mutacao": "remover a chamada do .task da RootView",
    },
    {
        "id": "W5",
        "desc": "o perfil em memória é zerado na limpeza (D-2)",
        "arquivo": "Shared/LocalDataCleanupService.swift",
        "precisa": r"UserProfileStore\.resetar\(\)",
        "mutacao": "remover a chamada de clearAll()",
    },
    {
        "id": "W6",
        "desc": "água NÃO tem gate de premium no botão (bug B11)",
        "arquivo": "Shared/Corpo/CorpoHomeView.swift",
        "proibe": r"hasPremiumAccess\s*\{\s*\n?\s*model\.addWater",
        "mutacao": "reintroduzir `if model.hasPremiumAccess` no botão de água",
    },
    {
        "id": "W7",
        "desc": "o didSet de waterMl grava no disco (bug B4)",
        "arquivo": "Shared/Corpo/Models.swift",
        "precisa": r"store\.set\(waterMl,\s*forKey:\s*\"waterMl\"\)",
        "mutacao": "esvaziar o didSet de waterMl",
    },
    {
        "id": "W8",
        "desc": "o token FCM não recria users/{uid} durante a exclusão (D-5)",
        "arquivo": "Shared/AlmaApp.swift",
        "precisa": r"temLimpezaPendente",
        "mutacao": "remover a guarda antes do setData do fcmToken",
    },
]


def main() -> int:
    falhas = []
    print("═════ LINT DE WIRING ═════")
    for r in REGRAS:
        caminho = RAIZ / r["arquivo"]
        if not caminho.exists():
            falhas.append(f"{r['id']} arquivo não encontrado: {r['arquivo']}")
            print(f"✗ {r['id']} {r['desc']} — ARQUIVO NÃO ENCONTRADO")
            continue

        texto = caminho.read_text(encoding="utf-8")
        # Linhas comentadas não contam como wiring: comentar a chamada É a mutação.
        vivo = "\n".join(
            l for l in texto.split("\n") if not l.lstrip().startswith("//")
        )

        if "precisa" in r:
            ok = re.search(r["precisa"], vivo) is not None
            obs = "presente" if ok else "AUSENTE"
        else:
            ok = re.search(r["proibe"], vivo, re.MULTILINE) is None
            obs = "ausente (correto)" if ok else "PRESENTE — gate reintroduzido"

        if ok:
            print(f"✓ {r['id']} {r['desc']} — {obs}")
        else:
            falhas.append(f"{r['id']} {r['desc']}")
            print(f"✗ {r['id']} {r['desc']} — {obs}  [{r['arquivo']}]")

    print("═════ RESULTADO ═════")
    print(f"regras: {len(REGRAS)} · falhas: {len(falhas)}")
    for f in falhas:
        print(f"   ✗ {f}")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
