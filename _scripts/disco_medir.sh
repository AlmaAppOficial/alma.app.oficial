#!/bin/bash
# Mede o disco e os candidatos a limpeza. NÃO apaga nada.
echo "===== ESPAÇO ====="
df -h / /System/Volumes/Data 2>/dev/null
echo
echo "===== CANDIDATOS (regeneráveis) ====="
for p in \
  "$HOME/Library/Developer/Xcode/DerivedData" \
  "$HOME/Library/Developer/Xcode/Archives" \
  "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
  "$HOME/Library/Developer/Xcode/watchOS DeviceSupport" \
  "$HOME/Library/Developer/CoreSimulator/Caches" \
  "$HOME/Library/Caches/org.swift.swiftpm" \
  "$HOME/Library/Caches/com.apple.dt.Xcode" \
  "$HOME/Library/Caches/CloudKit" \
  "$HOME/Library/Developer/CoreSimulator/Devices" \
  "/tmp/alma_dd" "/tmp/alma_rel" "/tmp/alma_rel2" \
  ; do
  [ -e "$p" ] && printf '%8s  %s\n' "$(du -sh "$p" 2>/dev/null | cut -f1)" "$p"
done
echo
echo "===== NÃO TOCAR (referência) ====="
for p in \
  "/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/meditation_production" \
  "/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/.git" \
  ; do
  [ -e "$p" ] && printf '%8s  %s\n' "$(du -sh "$p" 2>/dev/null | cut -f1)" "$p"
done
echo
echo "===== simuladores indisponíveis ====="
xcrun simctl list devices unavailable 2>/dev/null | head -12
