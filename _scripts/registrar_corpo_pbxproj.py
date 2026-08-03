#!/usr/bin/env python3
"""Registra os arquivos do módulo Corpo no project.pbxproj do Alma.

Insere, para cada .swift de Shared/Corpo/ (mais o exercises_v2.json como
resource), as quatro entradas que o Xcode espera: PBXBuildFile, PBXFileReference,
o item no grupo Shared e o item na fase de Sources (target iOS).

Idempotente: se o arquivo já estiver registrado, pula.
"""
import hashlib
import os
import re

PROJ = "/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Alma.App.Oficial.xcodeproj/project.pbxproj"
CORPO = "/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo"

with open(PROJ) as f:
    proj = f.read()

swift_files = sorted(x for x in os.listdir(CORPO) if x.endswith(".swift"))
resources = ["exercises_v2.json"]

# Âncoras: reaproveita as entradas de um arquivo já registrado do Shared/
ANCHOR_BUILD = "\t\tDD018001DD018001DD018001 /* CorpoModuleView.swift in Sources */ = {isa = PBXBuildFile; fileRef = DD018000DD018000DD018000 /* CorpoModuleView.swift */; };"
ANCHOR_REF = '\t\tDD018000DD018000DD018000 /* CorpoModuleView.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = CorpoModuleView.swift; sourceTree = "<group>"; };'
ANCHOR_GROUP = "\t\t\t\tDD018000DD018000DD018000 /* CorpoModuleView.swift */,"
ANCHOR_SOURCES = "\t\t\t\tDD018001DD018001DD018001 /* CorpoModuleView.swift in Sources */,"

for a in (ANCHOR_BUILD, ANCHOR_REF, ANCHOR_GROUP, ANCHOR_SOURCES):
    if a not in proj:
        raise SystemExit(f"âncora não encontrada no pbxproj:\n{a[:80]}")

builds, refs, groups, sources = [], [], [], []
added = 0

for i, name in enumerate(swift_files):
    if f"Corpo/{name}" in proj:
        continue
    # UID de pbxproj: EXATAMENTE 24 caracteres hex e único no arquivo inteiro.
    #
    # Duas armadilhas já custaram builds inteiros aqui:
    #
    # 1. TAMANHO. A versão anterior montava a string à mão e produzia 23
    #    caracteres. O `[:24]` truncava, mas nunca preenchia. O Xcode ignorava a
    #    entrada em silêncio e o erro aparecia longe da causa, como
    #    "cannot find type ... in scope".
    #
    # 2. COLISÃO. O UID vinha do índice `i` da lista. Em execuções diferentes o
    #    mesmo índice caía em arquivos diferentes: CorpoContextSnapshot (i=7 numa
    #    rodada) recebeu o UID que já era do CorpoInsightsEngine (i=7 na rodada
    #    anterior). Dois arquivos, um UID — o Xcode compila só um.
    #    Agora o UID deriva do NOME, então é estável entre execuções e não
    #    depende da ordem em que o script varre a pasta.
    uid_ref = hashlib.sha1(f"ref:{name}".encode()).hexdigest()[:24].upper()
    uid_bld = hashlib.sha1(f"bld:{name}".encode()).hexdigest()[:24].upper()
    assert len(uid_ref) == 24 and len(uid_bld) == 24, f"UID fora de 24 chars para {name}"
    assert uid_ref not in proj and uid_bld not in proj, f"UID colidiu para {name}"
    refs.append(f'\t\t{uid_ref} /* {name} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = "Corpo/{name}"; sourceTree = "<group>"; }};')
    builds.append(f"\t\t{uid_bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {uid_ref} /* {name} */; }};")
    groups.append(f"\t\t\t\t{uid_ref} /* {name} */,")
    sources.append(f"\t\t\t\t{uid_bld} /* {name} in Sources */,")
    added += 1

# Recurso JSON: entra na fase de Resources
res_lines_ref, res_lines_bld, res_group, res_phase = [], [], [], []
for j, name in enumerate(resources):
    if f"Corpo/{name}" in proj:
        continue
    uid_ref = f"FA8{j:03d}00FA8{j:03d}00FA8{j:03d}0"
    uid_bld = f"FA8{j:03d}01FA8{j:03d}01FA8{j:03d}1"
    res_lines_ref.append(f'\t\t{uid_ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = "Corpo/{name}"; sourceTree = "<group>"; }};')
    res_lines_bld.append(f"\t\t{uid_bld} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {uid_ref} /* {name} */; }};")
    res_group.append(f"\t\t\t\t{uid_ref} /* {name} */,")
    res_phase.append(f"\t\t\t\t{uid_bld} /* {name} in Resources */,")

proj = proj.replace(ANCHOR_BUILD, ANCHOR_BUILD + "\n" + "\n".join(builds + res_lines_bld), 1)
proj = proj.replace(ANCHOR_REF, ANCHOR_REF + "\n" + "\n".join(refs + res_lines_ref), 1)
proj = proj.replace(ANCHOR_GROUP, ANCHOR_GROUP + "\n" + "\n".join(groups + res_group), 1)
proj = proj.replace(ANCHOR_SOURCES, ANCHOR_SOURCES + "\n" + "\n".join(sources), 1)

# Fase de Resources do target iOS (a primeira PBXResourcesBuildPhase do arquivo)
if res_phase:
    m = re.search(r"(/\* Begin PBXResourcesBuildPhase section \*/.*?files = \(\n)", proj, re.S)
    if m:
        proj = proj[:m.end(1)] + "\n".join(res_phase) + "\n" + proj[m.end(1):]

with open(PROJ, "w") as f:
    f.write(proj)

print(f"registrados: {added} arquivos Swift + {len(res_lines_ref)} recurso(s)")
