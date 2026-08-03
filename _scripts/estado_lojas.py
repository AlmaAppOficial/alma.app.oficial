#!/usr/bin/env python3
"""Estado real dos dois apps no App Store Connect: o que está PUBLICADO.

Existe porque "fundido no código" e "fundido e no ar" são coisas diferentes, e o
Assis vai fazer uma afirmação pública sobre a fusão.
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asc_api  # reusa token/JWT já configurados


def get(path):
    return asc_api.request(path) if hasattr(asc_api, "request") else asc_api.api_get(path)


# Descobre o nome da função de GET do módulo, seja qual for.
_fn = None
for nome in ("request", "api_get", "get", "fetch", "chamar"):
    if hasattr(asc_api, nome) and callable(getattr(asc_api, nome)):
        _fn = getattr(asc_api, nome)
        break

if _fn is None:
    # Fallback: monta a chamada na mão com o token do módulo.
    import urllib.request

    def _fn(path):
        req = urllib.request.Request(
            asc_api.BASE + path,
            headers={"Authorization": f"Bearer {asc_api.token()}"},
        )
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())


apps = _fn("v1/apps?limit=50")["data"]

print("=" * 72)
print("ESTADO REAL NO APP STORE CONNECT")
print("=" * 72)

for a in apps:
    at = a["attributes"]
    print(f"\n■ {at['name']}")
    print(f"  bundleId : {at['bundleId']}")
    print(f"  appId    : {a['id']}")

    try:
        vers = _fn(f"v1/apps/{a['id']}/appStoreVersions?limit=8")["data"]
        if not vers:
            print("  versões  : nenhuma")
        for v in vers[:5]:
            va = v["attributes"]
            estado = va.get("appStoreState") or va.get("state") or "?"
            print(f"  versão   : {va['versionString']:<8} {estado}")
    except Exception as e:
        print(f"  versões  : ERRO {str(e)[:70]}")

    try:
        bs = _fn(f"v1/builds?filter[app]={a['id']}&limit=5&sort=-uploadedDate")["data"]
        for b in bs[:4]:
            ba = b["attributes"]
            print(f"  build    : {str(ba.get('version')):<5} "
                  f"{str(ba.get('processingState')):<12} "
                  f"expirado={ba.get('expired')} "
                  f"{str(ba.get('uploadedDate'))[:10]}")
    except Exception as e:
        print(f"  builds   : ERRO {str(e)[:70]}")
