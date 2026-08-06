#!/usr/bin/env python3
"""
Bateria de MUTAÇÃO do entitlement — CLAUDE.md, Regra 1.

"Um teste que nunca reprova não é teste — é papel pintado."

Para cada defesa do código, esta bateria APAGA a linha de produção que a
implementa, recompila, roda o teste de ciclo e exige que a asserção
correspondente fique VERMELHA. Depois restaura o arquivo e confirma que volta ao
verde. Uma asserção que continua verde sem a linha que ela deveria proteger é
cega, e a bateria acusa isso como FALHA DA BATERIA — não do código.

Roda de dentro do emulador (o teste precisa do Firestore):
    firebase emulators:exec --only firestore --project demo-alma \
        "python3 functions/_mutacao_entitlement.py"

Evidências ficam em _validacao_20260806/.
"""
import pathlib
import re
import subprocess
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SRC = RAIZ / "functions" / "src"
EVID = RAIZ / "_validacao_20260806"
EVID.mkdir(exist_ok=True)

# (id, arquivo, trecho original, asserção que TEM de reprovar, o que protege, substituto)
#
# POR QUE NEUTRALIZAR A CONDIÇÃO EM VEZ DE APAGAR O BLOCO
# A primeira versão desta bateria apagava o bloco inteiro. Três das seis
# mutações passaram a não compilar (variável declarada e não usada, import órfão)
# e o script as marcou "inconclusivas" — corretamente: se não compila, a asserção
# não chegou a ser exercitada e nada foi provado. Neutralizar a CONDIÇÃO deixa
# o código compilando e é uma mutação mais precisa: prova que a asserção enxerga
# a REGRA, não a mera presença de linhas.
MUTACOES = [
    (
        "M1",
        "entitlementApply.ts",
        "if (!cortePrioritario && anteriorMs !== null && novoMs !== null && novoMs <= anteriorMs) {",
        "C10",
        "guarda de ordem: renovação antiga reentregue depois do reembolso",
        "if (!cortePrioritario && anteriorMs !== null && novoMs !== null && novoMs < 0) {",
    ),
    (
        "M2",
        "entitlementApply.ts",
        "const cortePrioritario = evento.tipo === 'REFUND' || evento.tipo === 'REVOKE';",
        "C11",
        "exceção que faz reembolso atrasado vencer a guarda de ordem",
        "const cortePrioritario = false;",
    ),
    (
        "M3",
        "entitlementLeitura.ts",
        "if (expira && expira.toMillis() < Date.now()) return false;",
        "C4",
        "ehAssinante: entitlement ativo mas com data vencida",
        "if (expira && expira.toMillis() < 0) return false;",
    ),
    (
        "M4",
        "appleEvento.ts",
        "gracePeriodExpiresDateMs: renovacao?.gracePeriodExpiresDate ?? null,",
        "T1",
        "junção da tolerância do RenewalInfo com a transação",
        "gracePeriodExpiresDateMs: null,",
    ),
    # Mutada na LISTA e não na condição: neutralizar o `||` da condição faz o
    # TypeScript estreitar `productId` para `undefined` no segundo operando e o
    # arquivo deixa de compilar. Um Set que aceita tudo tem o mesmo efeito
    # semântico — "o filtro não filtra" — e compila.
    (
        "M5",
        "appleVerificador.ts",
        """export const PRODUTOS_DE_ASSINATURA: ReadonlySet<string> = new Set([
  'com.almaapp.app.premium_monthly',
  'com.almaapp.app.premium_annual',
]);""",
        "C19",
        "filtro que impede produto estranho de virar Premium",
        "export const PRODUTOS_DE_ASSINATURA: ReadonlySet<string> = "
        "{ has: () => true } as unknown as ReadonlySet<string>;",
    ),
    (
        "M6",
        "index.ts",
        "export { vincularAssinatura } from './entitlementApply';",
        "C20",
        "o export que faz o código sair do repositório e ir para produção",
        "",
    ),
    # Alvo é C12, não C13 — e a primeira versão desta bateria errou justamente
    # isso, o que vale registrar. C13 ("ninguém vira assinante por acidente")
    # continuou VERDE com a mutação aplicada, porque o entitlement foi parar num
    # uid inventado e C13 só olha o uid do caso. Ou seja: C13 sozinha NÃO cobre
    # "conceder acesso à pessoa errada" — quem cobre é C12, que exige
    # `pendente === true`. A bateria descobriu a fraqueza da própria asserção.
    (
        "M7",
        "entitlementApply.ts",
        "const uid = await uidDaTransacao(db, tx);",
        "C12",
        "exigência de vínculo antes de gravar entitlement para alguém",
        "const uid = await uidDaTransacao(db, tx) ?? 'uid-inventado';",
    ),
    # O alerta serve para gritar quando alguém pagou e não recebeu. Se o corte
    # de tempo sumir, ele passa a acusar TODA pendência — inclusive a de dois
    # minutos atrás, que é normal — e vira ruído diário. Alerta que grita sem
    # motivo é alerta que se aprende a ignorar, o que é o mesmo que não ter.
    # Mutado o SINAL do corte, não a cláusula: tirar o `.where` deixa a variável
    # `corte` órfã e o arquivo não compila (mesma lição de M5). Empurrar o corte
    # para o futuro faz toda pendência entrar, que é exatamente o defeito temido.
    (
        "M8",
        "alertaEntitlement.ts",
        "const corte = admin.firestore.Timestamp.fromMillis(agoraMs - dias * DIA_MS);",
        "C26",
        "corte de tempo que impede o alerta de virar ruído diário",
        "const corte = admin.firestore.Timestamp.fromMillis(agoraMs + dias * DIA_MS);",
    ),
]


def build():
    r = subprocess.run(
        ["npm", "run", "build"], cwd=RAIZ / "functions", capture_output=True, text=True
    )
    return r.returncode == 0, (r.stdout + r.stderr)


def roda_teste():
    r = subprocess.run(
        ["node", "testes_entitlement_ciclo.mjs"],
        cwd=RAIZ / "functions",
        capture_output=True,
        text=True,
    )
    return r.returncode, (r.stdout + r.stderr)


def estado_da_assercao(saida, ident):
    """Devolve 'verde', 'vermelho' ou 'ausente' para uma asserção."""
    if re.search(rf"^\s*✓ {ident} ", saida, re.M):
        return "verde"
    if re.search(rf"^\s*✗ {ident} ", saida, re.M):
        return "vermelho"
    return "ausente"


def main():
    print("═══ BATERIA DE MUTAÇÃO — entitlement ═══\n")

    ok, log = build()
    if not ok:
        print("✗ build limpo falhou; abortando\n" + log)
        return 2
    codigo, base = roda_teste()
    (EVID / "00_baseline.txt").write_text(base)
    if codigo != 0:
        print(f"✗ baseline não está verde (exit {codigo}) — corrigir antes de mutar")
        print(base[-2000:])
        return 2
    print("✓ baseline verde — todas as asserções passam com o código íntegro\n")

    problemas = []

    for mut in MUTACOES:
        ident, arquivo, trecho, assercao, protege = mut[:5]
        substituto = mut[5] if len(mut) > 5 else ""

        caminho = SRC / arquivo
        original = caminho.read_text()

        if trecho not in original:
            print(f"✗ {ident}: trecho não encontrado em {arquivo} — mutação inválida")
            problemas.append(f"{ident} trecho não encontrado")
            continue

        print(f"── {ident}: apagando de {arquivo} → {protege}")
        caminho.write_text(original.replace(trecho, substituto, 1))
        try:
            compilou, logbuild = build()
            if not compilou:
                # Não conta como prova: se nem compila, a asserção não foi exercitada.
                print(f"   ⚠ não compila sem o trecho — mutação inconclusiva")
                (EVID / f"{ident}_inconclusiva.txt").write_text(logbuild)
                problemas.append(f"{ident} não compila (inconclusiva)")
                continue

            _, saida = roda_teste()
            estado = estado_da_assercao(saida, assercao)
            (EVID / f"{ident}_mutado_{assercao}.txt").write_text(
                f"MUTAÇÃO {ident} — apagado de {arquivo}:\n{trecho}\n"
                f"{'=' * 70}\nESPERADO: {assercao} VERMELHA\nOBSERVADO: {assercao} {estado}\n{'=' * 70}\n\n"
                + saida
            )
            if estado == "vermelho":
                print(f"   ✓ {assercao} ficou VERMELHA — a asserção enxerga")
            elif estado == "verde":
                print(f"   ✗✗ {assercao} continuou VERDE — ASSERÇÃO CEGA")
                problemas.append(f"{ident}/{assercao} cega")
            else:
                print(f"   ✗✗ {assercao} sumiu do relatório — harness quebrou")
                problemas.append(f"{ident}/{assercao} ausente")
        finally:
            caminho.write_text(original)

    ok, _ = build()
    codigo, final = roda_teste()
    (EVID / "99_restaurado.txt").write_text(final)
    if codigo != 0:
        print("\n✗✗ o código NÃO voltou ao verde depois das mutações — restauração falhou")
        return 3
    print("\n✓ código restaurado e verde de novo")

    print("\n═══ RESULTADO DA BATERIA ═══")
    if problemas:
        print(f"PROBLEMAS ({len(problemas)}):")
        for p in problemas:
            print(f"   ✗ {p}")
        return 1
    print(f"{len(MUTACOES)} mutações, {len(MUTACOES)} asserções provadas por mutação.")
    print(f"evidências em {EVID.relative_to(RAIZ)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
