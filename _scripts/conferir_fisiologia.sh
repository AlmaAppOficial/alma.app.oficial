#!/bin/bash
# [2026-08-14] Conferidor das duas plataformas para a mudança de fisiologia.
#
# Existe porque "BUILD SUCCEEDED" e "BUILD SUCCESSFUL" são, os dois, mentiras
# possíveis:
#   • iOS  — hoje de manhã um xcodebuild devolveu SUCCEEDED tendo compilado
#            ZERO arquivos (incremental). Canário: exigir etapas de Swift no log
#            E que cada arquivo mexido apareça nele.
#   • Android — `testDebugUnitTest` devolve sucesso com UP-TO-DATE sem rodar
#            teste nenhum. Canário: `--rerun-tasks` na execução e conferência da
#            IDADE do XML aqui.

L=/tmp/build_honestidade_zero.log

echo "════════ iOS ════════"
if [ ! -f "$L" ]; then echo "log inexistente"; else
  if grep -qE 'BUILD SUCCEEDED|BUILD FAILED' "$L"; then
    grep -E 'BUILD SUCCEEDED|BUILD FAILED' "$L" | tail -2
  else
    echo "AINDA RODANDO (sem linha de resultado)"
  fi
  echo "erros  : $(grep -c 'error:' "$L")"
  grep -n 'error:' "$L" | head -10
  echo "avisos : $(grep -c 'warning:' "$L")"
  passos=$(grep -cE 'SwiftCompile|SwiftDriver|CompileSwift' "$L")
  echo "CANÁRIO 1 — etapas de compilação Swift: $passos"
  [ "$passos" -lt 50 ] && echo "  ⚠️  POUCAS ETAPAS: o verde pode ser de build incremental que não compilou nada."
  echo "CONTROLE POSITIVO — o build viu cada arquivo mexido:"
  for f in RegrasDeSaude NutritionEngine Models OnboardingBiometricsView HomeView UserMemoryManager LocalDataCleanupService; do
    echo "    $f: $(grep -c "$f.swift" "$L")"
  done
  echo "CANÁRIO 2 — arquivo inexistente (a busca discrimina?): $(grep -c 'ArquivoQueNaoExiste.swift' "$L")"
fi

echo
echo "════════ Android ════════"
A=/tmp/android_teste.log
if [ ! -f "$A" ]; then echo "log inexistente"; else
  grep -E 'BUILD SUCCESSFUL|BUILD FAILED|exit=' "$A" | tail -3
  echo "tarefas UP-TO-DATE (deveria ser 0 para o teste): $(grep -c 'UP-TO-DATE' "$A")"
  grep -E "^e: |error: " "$A" | head -15
  XML=~/Desktop/ALMA/alma-android/app/build/test-results/testDebugUnitTest
  if [ -d "$XML" ]; then
    INICIO=$(cat /tmp/android_inicio.txt 2>/dev/null || echo 0)
    echo "CANÁRIO — idade do XML (tem de ser DEPOIS do início da rodada):"
    echo "  início da rodada : $INICIO ($(date -r "$INICIO" '+%H:%M:%S' 2>/dev/null))"
    NOVOS=0; VELHOS=0
    for x in "$XML"/*.xml; do
      [ -e "$x" ] || continue
      M=$(stat -f %m "$x")
      if [ "$M" -ge "$INICIO" ]; then NOVOS=$((NOVOS+1)); else VELHOS=$((VELHOS+1)); fi
    done
    echo "  XML gerados NESTA rodada : $NOVOS"
    echo "  XML velhos (não rodaram) : $VELHOS"
    [ "$VELHOS" -gt 0 ] && echo "  ⚠️  HÁ XML VELHO: parte do verde é de execução anterior."
    echo "  testes/falhas somados:"
    grep -ho 'tests="[0-9]*"' "$XML"/*.xml 2>/dev/null | awk -F'"' '{s+=$2} END {print "    tests  = " s}'
    grep -ho 'failures="[0-9]*"' "$XML"/*.xml 2>/dev/null | awk -F'"' '{s+=$2} END {print "    failures = " s}'
    grep -ho 'errors="[0-9]*"' "$XML"/*.xml 2>/dev/null | awk -F'"' '{s+=$2} END {print "    errors = " s}'
  else
    echo "sem diretório de resultados — nenhum teste chegou a rodar"
  fi
fi
