#!/usr/bin/env python3
"""
Adiciona Shared/HealthKitManager.swift ao project.pbxproj replicando o padrao
do MainTabView.swift (mesmo target iOS + macOS, mesmo grupo Shared/).

Uso: python3 _scripts/add_healthkit_manager.py

Idempotente. Faz backup em project.pbxproj.bak.
"""
import shutil
import sys
import uuid
from pathlib import Path

PBX = Path("Alma.App.Oficial.xcodeproj/project.pbxproj")
TARGET = "HealthKitManager.swift"

# IDs reais do MainTabView.swift (verificados no pbxproj)
TMPL_BF_IOS = "9ECED0F92F589030009412A7"
TMPL_BF_MAC = "9ECED0FA2F589030009412A7"
TMPL_FILEREF = "9ECED0EB2F58902D009412A7"


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def main() -> int:
    if not PBX.exists():
        print(f"[ERRO] {PBX} nao encontrado.", file=sys.stderr)
        return 1

    content = PBX.read_text()
    if TARGET in content:
        print(f"[OK] {TARGET} ja existe no pbxproj — nada a fazer.")
        return 0

    new_bf_ios = new_id()
    new_bf_mac = new_id()
    new_fr = new_id()

    # 4 blocos a inserir, todos como replace direto apos a linha do MainTabView

    # 1) PBXBuildFile iOS
    old = (f"\t\t{TMPL_BF_IOS} /* MainTabView.swift in Sources */ = "
           f"{{isa = PBXBuildFile; fileRef = {TMPL_FILEREF} /* MainTabView.swift */; }};\n")
    new = old + (f"\t\t{new_bf_ios} /* {TARGET} in Sources */ = "
                 f"{{isa = PBXBuildFile; fileRef = {new_fr} /* {TARGET} */; }};\n")
    if old not in content:
        print(f"[ERRO] Nao achei padrao BuildFile iOS.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # 2) PBXBuildFile macOS
    old = (f"\t\t{TMPL_BF_MAC} /* MainTabView.swift in Sources */ = "
           f"{{isa = PBXBuildFile; fileRef = {TMPL_FILEREF} /* MainTabView.swift */; }};\n")
    new = old + (f"\t\t{new_bf_mac} /* {TARGET} in Sources */ = "
                 f"{{isa = PBXBuildFile; fileRef = {new_fr} /* {TARGET} */; }};\n")
    if old not in content:
        print(f"[ERRO] Nao achei padrao BuildFile macOS.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # 3) PBXFileReference
    old = (f"\t\t{TMPL_FILEREF} /* MainTabView.swift */ = "
           f"{{isa = PBXFileReference; fileEncoding = 4; "
           f"lastKnownFileType = sourcecode.swift; path = MainTabView.swift; "
           f"sourceTree = \"<group>\"; }};\n")
    new = old + (f"\t\t{new_fr} /* {TARGET} */ = "
                 f"{{isa = PBXFileReference; fileEncoding = 4; "
                 f"lastKnownFileType = sourcecode.swift; path = {TARGET}; "
                 f"sourceTree = \"<group>\"; }};\n")
    if old not in content:
        print(f"[ERRO] Nao achei padrao PBXFileReference.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # 4) Grupo da pasta Shared — 4 tabs de indent
    old = f"\t\t\t\t{TMPL_FILEREF} /* MainTabView.swift */,\n"
    new = old + f"\t\t\t\t{new_fr} /* {TARGET} */,\n"
    if old not in content:
        print(f"[ERRO] Nao achei padrao PBXGroup.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # 5) PBXSourcesBuildPhase iOS
    old = f"\t\t\t\t{TMPL_BF_IOS} /* MainTabView.swift in Sources */,\n"
    new = old + f"\t\t\t\t{new_bf_ios} /* {TARGET} in Sources */,\n"
    if old not in content:
        print(f"[ERRO] Nao achei padrao Sources iOS.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # 6) PBXSourcesBuildPhase macOS
    old = f"\t\t\t\t{TMPL_BF_MAC} /* MainTabView.swift in Sources */,\n"
    new = old + f"\t\t\t\t{new_bf_mac} /* {TARGET} in Sources */,\n"
    if old not in content:
        print(f"[ERRO] Nao achei padrao Sources macOS.", file=sys.stderr)
        return 2
    content = content.replace(old, new, 1)

    # Backup + escrever
    shutil.copy(PBX, str(PBX) + ".bak")
    PBX.write_text(content)

    print(f"[OK] {TARGET} inserido em 6 secoes do pbxproj.")
    print(f"     BuildFile iOS:  {new_bf_ios}")
    print(f"     BuildFile mac:  {new_bf_mac}")
    print(f"     FileRef:        {new_fr}")
    print(f"     Backup:         {PBX}.bak")
    return 0


if __name__ == "__main__":
    sys.exit(main())
