#!/bin/bash
# Libera espaço em disco antes de build/archive (o Mac vive perto do limite).
set -u
echo "ANTES:"; df -h / | tail -1

du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null
du -sh ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null
du -sh ~/Library/Developer/CoreSimulator/Caches 2>/dev/null

rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null
rm -rf ~/Library/Developer/CoreSimulator/Caches/* 2>/dev/null
rm -rf /tmp/alma_dd /tmp/ca_dd 2>/dev/null

echo "DEPOIS:"; df -h / | tail -1
