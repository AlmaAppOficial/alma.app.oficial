#!/bin/bash
# [2026-08-31] Mutação das regras do Áudio do dia (Regra 1 do CLAUDE.md):
# apaga/inverte cada linha de produção protegida, roda o harness e exige
# VERMELHO. Mutação que não compila é INVÁLIDA (não provou nada) e mutação
# que fica verde é asserção CEGA — as duas abortam com o nome na tela.
#
# Evidência: _validacao_20260831/NN_mutacao_*.txt (com e sem a linha).
# Uso:  bash _scripts/mutacao_audio_do_dia.sh

set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

ARQ="Shared/AudioDoDiaRegras.swift"
EVID="_validacao_20260831"
mkdir -p "$EVID"

cp "$ARQ" "/tmp/AudioDoDiaRegras.original.swift"
restaurar() { cp "/tmp/AudioDoDiaRegras.original.swift" "$ARQ"; }
trap restaurar EXIT

rodar() { bash _scripts/rodar_teste_audio_do_dia.sh; }

echo "══ BASELINE (produção intacta — tem de ser VERDE) ══"
rodar | tee "$EVID/00_baseline_verde.txt"
BASE=${PIPESTATUS[0]}
if [ "$BASE" -ne 0 ]; then
    echo "ABORTADO: baseline não está verde (código $BASE). Mutação sem baseline verde não mede nada."
    exit 9
fi

N=0
FALHOU=0

muta() {
    local NOME="$1" BUSCA="$2" TROCA="$3" ESPERA_VERMELHO_EM="$4"
    N=$((N+1))
    local TAG
    TAG=$(printf '%02d' "$N")
    echo
    echo "══ M$N ($NOME) — espera vermelho em: $ESPERA_VERMELHO_EM ══"
    restaurar
    if ! grep -qF "$BUSCA" "$ARQ"; then
        echo "✗✗ M$N INVÁLIDA: alvo não encontrado no arquivo ('$BUSCA')"
        FALHOU=1
        return
    fi
    python3 - "$ARQ" "$BUSCA" "$TROCA" <<'PY'
import sys
arq, busca, troca = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(arq, encoding='utf-8').read()
assert t.count(busca) == 1, f'alvo não-único ({t.count(busca)}x): {busca}'
open(arq, 'w', encoding='utf-8').write(t.replace(busca, troca, 1))
PY
    rodar | tee "$EVID/${TAG}_mutacao_M${N}_${NOME}.txt"
    local COD=${PIPESTATUS[0]}
    if [ "$COD" -eq 3 ]; then
        echo "✗✗ M$N INVÁLIDA (não compilou — não provou nada)"
        FALHOU=1
    elif [ "$COD" -eq 0 ]; then
        echo "✗✗ M$N CEGA (continuou verde sem a linha — a asserção não protege)"
        FALHOU=1
    else
        echo "✓ M$N detectada (vermelho, código $COD)"
    fi
}

#      nome                     alvo (único no arquivo)                                     mutação                          onde deve doer
muta "ligado_eq_true"          "valorNoDoc != false"                                        "valorNoDoc == true"             "A1"
muta "elegivel_nil_vira_false" "else { return true }"                                       "else { return false }"          "B1/B2"
muta "elegivel_inverte"        "return dia <= hojeLocalISO"                                 "return dia >= hojeLocalISO"     "B3/B5"
muta "elegivel_sempre_sim"     "return dia <= hojeLocalISO"                                 "return true"                    "B5/B6 (e o canário segue vivo)"
muta "fuso_ignorado"           "cal.timeZone = fuso"                                        "_ = fuso"                       "C1 ou C2/C3 (a máquina não está em todos os fusos ao mesmo tempo)"
muta "data_sem_zeros"          "%04d-%02d-%02d"                                             "%d-%d-%d"                       "C4"
muta "aceita_qualquer_esquema" "parsed.scheme == \"https\" || parsed.scheme == \"http\""    "parsed.scheme != nil"           "D4"
muta "titulo_padrao_some"      "?? tituloPadrao"                                            "?? \"\""                        "D6/D7"
muta "duracao_sem_clamp"       "duracaoSeg: max(0, duracao)"                                "duracaoSeg: duracao"            "D8"
muta "duracao_as_double"       "(dados[\"duracaoSeg\"] as? NSNumber)?.doubleValue ?? 0"     "(dados[\"duracaoSeg\"] as? Double) ?? 0"  "D5c (o Int 312 não passa no as? Double)"
muta "mmss_divisor"            "s / 60, s % 60"                                             "s / 100, s % 60"                "E1/E5"
muta "decodifica_nada"         "let duracao = (dados"                                       "return nil; let duracao = (dados"  "D5a (o doc bom vira nil)"

restaurar
echo
echo "══ PÓS-RESTAURAÇÃO (tem de voltar a VERDE) ══"
rodar | tee "$EVID/99_pos_restauracao_verde.txt"
POS=${PIPESTATUS[0]}

echo
if [ "$FALHOU" -eq 0 ] && [ "$POS" -eq 0 ]; then
    echo "RESULTADO: $N/$N mutações detectadas, 0 cegas, 0 inválidas, produção restaurada verde."
    exit 0
else
    echo "RESULTADO: HÁ MUTAÇÃO CEGA/INVÁLIDA (ou a restauração não voltou a verde). Ver acima."
    exit 1
fi
