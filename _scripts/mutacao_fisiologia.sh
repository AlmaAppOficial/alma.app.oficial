#!/bin/bash
# [2026-08-14] MUTAÇÃO — Regra 1 do CLAUDE.md.
#
# "Um teste que nunca reprova não é teste — é papel pintado."
#
# Para cada mutação: planta o defeito no código de PRODUÇÃO, **confirma que
# compilou**, roda as asserções, exige VERMELHO, restaura, e confere a
# restauração por md5.
#
# ⚠️ A CONFIRMAÇÃO DE COMPILAÇÃO NÃO É ZELO — É O CENTRO.
# Uma mutação que não compila produz "falhou", e um script ingênuo contaria
# isso como asserção-enxergando. Seria o mesmo modo de falha do `strings` no
# `.apk` comprimido (mediu o nada e deu 0 nas duas variantes) e do
# BUILD SUCCEEDED com zero arquivos compilados desta manhã. Aqui, mutação que
# não compila é reportada como INVÁLIDA e não conta a favor de nada.

set -u
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 3

ALVO="Shared/RegrasDeSaude.swift"
BACKUP=$(mktemp)
cp "$ALVO" "$BACKUP"
MD5_ORIGINAL=$(md5 -q "$ALVO")

TMP=$(mktemp -d)
cp _scripts/teste_fisiologia.swift "$TMP/main.swift"

ok=0; cegas=0; invalidas=0

restaurar() {
    cp "$BACKUP" "$ALVO"
    if [ "$(md5 -q "$ALVO")" != "$MD5_ORIGINAL" ]; then
        echo "☠️  RESTAURAÇÃO FALHOU — o arquivo NÃO voltou ao original. PARE."
        exit 9
    fi
}

mutar() {
    local nome="$1" de="$2" para="$3"

    # `python3` em vez de `sed` porque os alvos têm acento, parênteses e `?`.
    python3 - "$ALVO" "$de" "$para" <<'PY'
import sys
caminho, de, para = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(caminho, encoding='utf-8').read()
if s.count(de) != 1:
    print(f"ALVO_AMBIGUO:{s.count(de)}")
    sys.exit(7)
open(caminho, 'w', encoding='utf-8').write(s.replace(de, para))
PY
    if [ $? -ne 0 ]; then
        echo "  ⚠️  $nome — ALVO NÃO ENCONTRADO OU AMBÍGUO (mutação inválida)"
        invalidas=$((invalidas+1)); restaurar; return
    fi

    # 1) TEM de compilar. Sem isto, o vermelho abaixo não significa nada.
    if ! xcrun swiftc -O "$ALVO" "$TMP/main.swift" -o "$TMP/t" 2>"$TMP/e"; then
        echo "  ⚠️  $nome — A MUTAÇÃO NÃO COMPILOU → INVÁLIDA, não conta."
        sed 's/^/       /' "$TMP/e" | head -4
        invalidas=$((invalidas+1)); restaurar; return
    fi

    # 2) E as asserções TÊM de reprovar.
    saida=$("$TMP/t" 2>&1); codigo=$?
    vermelhas=$(echo "$saida" | grep -c '✗✗')
    if [ "$codigo" -ne 0 ] && [ "$vermelhas" -gt 0 ]; then
        echo "  ✓ $nome — compilou E ficou VERMELHO ($vermelhas asserções, exit $codigo)"
        echo "$saida" | grep '✗✗' | head -2 | sed 's/^/       /'
        ok=$((ok+1))
    else
        echo "  ✗✗ $nome — COMPILOU E PASSOU VERDE. ASSERÇÃO CEGA."
        cegas=$((cegas+1))
    fi
    restaurar
}

echo "════ MUTAÇÕES EM $ALVO ════"
echo

echo "── Grupo A: o mapeamento da migração ──"
mutar "M1 ausência vira masculino (o defeito original)" \
      'default:          return nil' \
      'default:          return .masculino'
mutar "M2 'Feminino' mapeado errado" \
      'case "Feminino":  return .feminino' \
      'case "Feminino":  return .masculino'

echo
echo "── Grupo B: o termo da Mifflin ──"
mutar "M3 termo feminino errado" \
      'case .feminino:  return -161' \
      'case .feminino:  return -78'
mutar "M4 não-informado volta a ser masculino (o defeito de meses)" \
      'case nil:        return -78' \
      'case nil:        return 5'

echo
echo "── Grupo C: o portão da saúde feminina ──"
mutar "M5 portão perde o premium (vazamento de recurso pago)" \
      'ehPremium && sexoEfetivo == .feminino' \
      'sexoEfetivo == .feminino'
mutar "M6 portão aceita 'não é masculino' (nil abriria a porta)" \
      'ehPremium && sexoEfetivo == .feminino' \
      'ehPremium && sexoEfetivo != .masculino'

echo
echo "── Grupo D: a ordem de precedência ──"
mutar "M7 gênero legado passa à frente da escolha explícita" \
      'escolhidoNaDieta ?? informadoNoOnboarding ?? sexoDoGeneroLegado(generoLegado)' \
      'sexoDoGeneroLegado(generoLegado) ?? escolhidoNaDieta ?? informadoNoOnboarding'
mutar "M8 onboarding ignorado" \
      'escolhidoNaDieta ?? informadoNoOnboarding ?? sexoDoGeneroLegado(generoLegado)' \
      'escolhidoNaDieta ?? sexoDoGeneroLegado(generoLegado)'

echo
echo "── Grupo E: o rótulo de estimativa (o 2º lado da fronteira) ──"
mutar "M9 nunca é estimativa (o rótulo some da tela)" \
      'sex == nil || activity == nil' \
      'false'
mutar "M10 só o sexo conta, atividade volta a ser chute calado" \
      'sex == nil || activity == nil' \
      'sex == nil'
mutar "M11 o que falta deixa de nomear a atividade" \
      'if activity == nil { faltando.append("seu nível de atividade") }' \
      'if false { faltando.append("seu nível de atividade") }'

echo
echo "── Grupo F: o fator de atividade ──"
mutar "M12 fator assumido muda a meta de todo mundo calado" \
      'activity?.factor ?? fatorQuandoNaoInformado' \
      'activity?.factor ?? 1.2'

echo
echo "════════════════════════════════════════════════════"
echo "mutações que a bateria ACUSOU : $ok"
echo "asserções CEGAS encontradas   : $cegas"
echo "mutações inválidas (não comp.): $invalidas"
echo "md5 final do alvo: $(md5 -q "$ALVO")  (original: $MD5_ORIGINAL)"
rm -f "$BACKUP"; rm -rf "$TMP"
[ "$cegas" -eq 0 ] && [ "$invalidas" -eq 0 ] && echo "RESULTADO: a bateria enxerga." && exit 0
echo "RESULTADO: há cegueira ou mutação inválida — investigar."
exit 1
