#!/bin/bash
# Prova de qual áudio realmente toca no app, antes de apagar qualquer artefato.
# "Confia e confere": não se apaga nada sem saber o que é.
set -u
cd /Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main || exit 1
APP=/tmp/alma_rel/Build/Products/Release-iphoneos/Alma.App.Oficial.app

echo "=== md5 do meditation_01.m4a em cada lugar ==="
echo "no BUNDLE compilado : $(md5 -q "$APP/meditation_01.m4a" 2>/dev/null)"
echo "em Meditations/     : $(md5 -q Meditations/meditation_01.m4a 2>/dev/null)"
echo "em Meditations.bak/ : $(md5 -q Meditations.bak.20260513/meditation_01.m4a 2>/dev/null)"

echo
echo "=== tamanho e data ==="
for f in "$APP/meditation_01.m4a" Meditations/meditation_01.m4a Meditations.bak.20260513/meditation_01.m4a; do
  [ -f "$f" ] && echo "$(stat -f '%z bytes  %Sm  ' -t '%Y-%m-%d' "$f")$f"
done

echo
echo "=== duração (bak vs vivo) — a versão PT-BR foi reescrita para 5 min reais ==="
for f in Meditations/meditation_01.m4a Meditations.bak.20260513/meditation_01.m4a; do
  [ -f "$f" ] && echo "$f: $(afinfo "$f" 2>/dev/null | grep -m1 'estimated duration' | tr -s ' ')"
done

echo
echo "=== quantos arquivos em cada pasta de artefato ==="
for d in Meditations Meditations.bak.20260513 meditation_production; do
  [ -d "$d" ] && echo "$d: $(find "$d" -type f | wc -l | tr -d ' ') arquivos, $(du -sh "$d" 2>/dev/null | cut -f1)"
done
