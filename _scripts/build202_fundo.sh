#!/bin/bash
# [2026-08-12] Compila o app inteiro em SEGUNDO PLANO, para a fila da 2.0.2.
#
# Existe porque a sessão de agente conversa por um canal com tempo limitado e o
# build do Alma passa disso. Rodar em primeiro plano derruba a chamada e deixa
# um `xcodebuild` órfão segurando o `.git/index.lock` — o problema que este
# projeto já teve quatro vezes (ver CLAUDE.md).
#
# NÃO apaga DerivedData nem cache do SwiftPM, de propósito: outra sessão pode
# estar viva no mesmo Mac, e limpar cache é a forma mais cara de "consertar"
# um erro que quase nunca vem daí.
#
# Uso:  ./_scripts/build202_fundo.sh          (dispara)
#       tail -f /tmp/alma202_build.log        (acompanha)
cd "$HOME/Desktop/ALMA/alma.app.oficial-main" || exit 1
LOG=/tmp/alma202_build.log
rm -f "$LOG"
# DerivedData PRÓPRIO, e não o padrão do Xcode.
#
# [2026-08-12] A primeira tentativa morreu em "unable to attach DB: database is
# locked — possibly there are two concurrent builds running in the same
# filesystem location": o Xcode do Assis estava aberto no mesmo projeto. A saída
# ERRADA seria apagar o DerivedData compartilhado (é o que a mensagem faz a
# gente querer fazer, e é destruir o trabalho de quem está do outro lado).
# A saída certa é não disputar o mesmo diretório. Este caminho é só desta
# verificação e pode ser apagado à vontade.
nohup /usr/bin/xcodebuild \
  -project Alma.App.Oficial.xcodeproj \
  -scheme "Alma.App.Oficial (iOS)" \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug \
  -derivedDataPath /tmp/alma202_dd \
  build > "$LOG" 2>&1 &
echo "pid=$!  log=$LOG"
