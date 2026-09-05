#!/bin/bash
# Validação por MUTAÇÃO do contrato do jejum no pulso (Regra 1 do CLAUDE.md):
# apaga/enfraquece a linha de produção que cada asserção protege, roda, e exige
# VERMELHO com a asserção certa. Depois restaura e exige VERDE de novo.
#
# Se uma mutação sobreviver (teste verde com a regra quebrada), a asserção é
# cega e o script reprova em voz alta.
#
# Uso: ./mutacao_jejum_watch.sh [raiz-do-repo] [pasta-de-evidencias]
set -uo pipefail
RAIZ="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
EVID="${2:-$RAIZ/_validacao_20260829_watch}"
ALVO="$RAIZ/AlmaWatch/JejumNoPulso.swift"
BACKUP=$(mktemp)
mkdir -p "$EVID"
cp "$ALVO" "$BACKUP"

restaurar() { cp "$BACKUP" "$ALVO"; }
trap restaurar EXIT

falhou=0

roda() { "$RAIZ/_scripts/rodar_testes_jejum_watch.sh" "$RAIZ" 2>&1; }

muta() {  # nome  busca  troca  assercao_que_tem_de_ficar_vermelha  arquivo_evidencia
    local nome="$1" busca="$2" troca="$3" esperada="$4" arq="$5"
    restaurar
    if ! grep -qF "$busca" "$ALVO"; then
        echo "✗✗ $nome: o trecho a mutar não existe mais — mutação desatualizada"
        falhou=1; return
    fi
    python3 - "$ALVO" "$busca" "$troca" <<'PY'
import sys
caminho, busca, troca = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(caminho).read()
assert t.count(busca) == 1, f"trecho não-único ({t.count(busca)}x): {busca!r}"
open(caminho, "w").write(t.replace(busca, troca, 1))
PY
    local saida; saida=$(roda); local codigo=$?
    printf '── MUTAÇÃO: %s\n── troca: %s  →  %s\n── exit: %s\n%s\n' \
        "$nome" "$busca" "$troca" "$codigo" "$saida" > "$EVID/$arq"
    if [ "$codigo" -eq 0 ]; then
        echo "✗✗ $nome SOBREVIVEU — asserção cega (evidência em $arq)"
        falhou=1
    elif ! grep -qF "✗ $esperada" <<<"$saida"; then
        echo "✗✗ $nome reprovou, mas NÃO pela asserção esperada '$esperada' (evidência em $arq)"
        falhou=1
    else
        echo "✓ $nome morta pela asserção '$esperada' (exit $codigo)"
    fi
}

echo "═══ Linha de base (sem mutação) — tem de ser VERDE ═══"
base_saida=$(roda); base_codigo=$?
printf '── LINHA DE BASE\n── exit: %s\n%s\n' "$base_codigo" "$base_saida" > "$EVID/00_mutacao_linha_de_base.txt"
if [ "$base_codigo" -ne 0 ]; then
    echo "✗✗ linha de base já está vermelha — mutações não medem nada assim"
    exit 2
fi
echo "✓ linha de base verde"

muta "M1 meta==base passa a valer" \
     "base > 0 && meta > base" \
     "base > 0 && meta >= base" \
     "V2 meta igual à base é inválida" \
     "01_mutacao_M1_meta_igual_base.txt"

muta "M2 some a exigência de base positiva" \
     "base > 0 && meta > base" \
     "meta > base" \
     "V1 base 0 é inválida" \
     "02_mutacao_M2_base_positiva.txt"

muta "M3 fração congelada perde o teto de 1" \
     "return min(1, max(0, pausadoEm.timeIntervalSince(base) / alvo))" \
     "return max(0, pausadoEm.timeIntervalSince(base) / alvo)" \
     "F2 além da meta trava em 1" \
     "03_mutacao_M3_fracao_sem_teto.txt"

muta "M4 decorrido pode ficar negativo" \
     "return max(0, agora.timeIntervalSince(base))" \
     "return agora.timeIntervalSince(base)" \
     "E2 relógio acertado para trás não fica negativo" \
     "04_mutacao_M4_decorrido_negativo.txt"

muta "M5 cronômetro congelado perde o piso de zero" \
     "let t = Int(max(0, segundos))" \
     "let t = Int(segundos)" \
     "T9 cronômetro negativo vira 0:00:00" \
     "06_mutacao_M5_cronometro_negativo.txt"

restaurar
echo "═══ Depois de restaurar — tem de voltar a VERDE ═══"
fim_saida=$(roda); fim_codigo=$?
printf '── RESTAURADO\n── exit: %s\n%s\n' "$fim_codigo" "$fim_saida" > "$EVID/05_mutacao_restaurado.txt"
if [ "$fim_codigo" -ne 0 ]; then
    echo "✗✗ restauração não voltou ao verde — ARQUIVO DE PRODUÇÃO PODE ESTAR SUJO"
    exit 2
fi
echo "✓ restaurado e verde"

if [ "$falhou" -ne 0 ]; then
    echo "RESULTADO: MUTAÇÕES SOBREVIVERAM — asserções cegas, refazer"
    exit 1
fi
echo "RESULTADO: as 5 mutações morreram e a base é verde nas duas pontas"
