#!/usr/bin/env python3
"""Consulta à API do App Store Connect com a AuthKey (Alma iOS).

Uso:
    ./asc_api.py versions        # versões do app e seus estados
    ./asc_api.py builds          # builds recentes + estado de processamento
    ./asc_api.py groups          # grupos de teste do TestFlight
    ./asc_api.py addbuild <buildId> <groupId>   # disponibiliza build no grupo
    ./asc_api.py raw <path>      # GET arbitrário (ex.: v1/apps)

Somente leitura, exceto `addbuild` (TestFlight — não submete nada à App Store).
"""
import json
import sys
import time
import urllib.request

import jwt

KEY_ID = "G345G9MJ9B"
ISSUER = "a052dbae-b7ee-4e05-a3f1-4d618d17fcf4"
KEY_PATH = "/Volumes/felipe 1 tb/Alma_Credentials/AuthKey_G345G9MJ9B.p8"
BUNDLE_ID = "com.almaapp.app"
BASE = "https://api.appstoreconnect.apple.com/"


def token() -> str:
    with open(KEY_PATH, "r") as fh:
        private_key = fh.read()
    now = int(time.time())
    payload = {"iss": ISSUER, "iat": now, "exp": now + 20 * 60, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(path, method="GET", body=None):
    url = path if path.startswith("http") else BASE + path.lstrip("/")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {"status": resp.status}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        print(f"HTTP {exc.code}: {detail[:600]}")
        sys.exit(1)


def app_id() -> str:
    res = call(f"v1/apps?filter[bundleId]={BUNDLE_ID}")
    return res["data"][0]["id"]


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "versions"

    if cmd == "versions":
        aid = app_id()
        res = call(f"v1/apps/{aid}/appStoreVersions?limit=8")
        for v in res["data"]:
            a = v["attributes"]
            print(f"{a['versionString']:10} {a['appStoreState']:28} {a.get('createdDate','')}")

    elif cmd == "builds":
        aid = app_id()
        res = call(f"v1/builds?filter[app]={aid}&limit=8&sort=-version"
                   "&fields[builds]=version,processingState,uploadedDate,expired,usesNonExemptEncryption")
        for b in res["data"]:
            a = b["attributes"]
            print(f"build {a['version']:5} {a['processingState']:12} "
                  f"expirado={str(a.get('expired')):5} cripto={a.get('usesNonExemptEncryption')} "
                  f"{a.get('uploadedDate','')}  id={b['id']}")

    elif cmd == "groups":
        aid = app_id()
        res = call(f"v1/apps/{aid}/betaGroups?limit=10")
        for g in res["data"]:
            a = g["attributes"]
            print(f"{a['name']:30} interno={a.get('isInternalGroup')} id={g['id']}")

    elif cmd == "addbuild":
        build_id, group_id = sys.argv[2], sys.argv[3]
        call(f"v1/betaGroups/{group_id}/relationships/builds", method="POST",
             body={"data": [{"type": "builds", "id": build_id}]})
        print(f"OK: build {build_id} disponibilizado no grupo {group_id}")

    elif cmd == "raw":
        print(json.dumps(call(sys.argv[2]), indent=1)[:3000])

    else:
        print(__doc__)


if __name__ == "__main__":
    main()
