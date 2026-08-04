#!/bin/bash
# Libera disco apagando SÓ o que o Xcode regenera sozinho.
#
# NÃO toca: código-fonte, .git, meditation_production (2,6 GB), simuladores
# (11 GB — apagá-los custaria rebaixar/rebaixar runtimes) e, por decisão minha,
# ~/Library/Developer/Xcode/Archives (1,5 GB): são os dSYMs dos builds já
# publicados, única forma de simbolicar crash de produção. Sobra espaço sem eles.
set -u
antes=$(df -k /System/Volumes/Data | awk 'NR==2{print $4}')

apagar() {
  [ -e "$1" ] || return 0
  printf '  %8s  %s\n' "$(du -sh "$1" 2>/dev/null | cut -f1)" "$1"
  rm -rf "$1"
}

echo "===== apagando (tudo regenerável) ====="
# Símbolos de aparelhos já conectados — o Xcode rebaixa quando plugar de novo.
apagar "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
apagar "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
# Produtos intermediários de compilação.
apagar "$HOME/Library/Developer/Xcode/DerivedData"
apagar /tmp/alma_dd
apagar /tmp/alma_rel
apagar /tmp/alma_rel2
# Caches de pacotes e do Xcode.
apagar "$HOME/Library/Caches/org.swift.swiftpm"
apagar "$HOME/Library/Caches/com.apple.dt.Xcode"
apagar "$HOME/Library/Caches/CloudKit"

echo
echo "===== simuladores indisponíveis ====="
xcrun simctl delete unavailable 2>&1 | tail -2

depois=$(df -k /System/Volumes/Data | awk 'NR==2{print $4}')
echo
echo "===== RESULTADO ====="
df -h /System/Volumes/Data | tail -1
awk -v a="$antes" -v d="$depois" 'BEGIN{printf "liberado: %.1f GiB (%.0f MiB -> %.1f GiB livres)\n", (d-a)/1048576, a/1024, d/1048576}'
