#!/usr/bin/env python3
"""Lê um .ips do simulador e imprime exceção + stack da thread que falhou."""
import glob
import json
import os
import sys

padrao = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Library/Logs/DiagnosticReports/Alma*.ips")
arquivos = sorted(glob.glob(padrao), key=os.path.getmtime, reverse=True)
if not arquivos:
    raise SystemExit("nenhum crash log encontrado")

caminho = arquivos[0]
print("arquivo:", os.path.basename(caminho))
raw = open(caminho).read()
# .ips = uma linha de cabeçalho JSON + o corpo JSON
corpo = raw.split("\n", 1)[1]
d = json.loads(corpo)

print("exceção:", json.dumps(d.get("exception", {})))
if "termination" in d:
    print("termination:", json.dumps(d["termination"])[:500])
if "asi" in d:
    print("asi:", json.dumps(d["asi"])[:700])
if "lastExceptionBacktrace" in d:
    print("TEM lastExceptionBacktrace")

imgs = d.get("usedImages", [])
ft = d.get("faultingThread", 0)
threads = d.get("threads", [])
if ft < len(threads):
    th = threads[ft]
    print(f"\n=== thread {ft} (queue: {th.get('queue','?')}) ===")
    for f in th.get("frames", [])[:25]:
        idx = f.get("imageIndex", 0)
        nome = imgs[idx].get("name", "?") if idx < len(imgs) else "?"
        sym = f.get("symbol", "")
        off = f.get("imageOffset", "")
        print(f"  {nome:24} {sym[:95]}" if sym else f"  {nome:24} +{off}")
