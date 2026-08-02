#!/bin/bash
# O Alma declara Color.init?(hex:) FAILABLE; o Corpo declarava init(hex:) não
# failable. Coexistir dá "invalid redeclaration"; usar a do Alma dá "must be
# unwrapped". Solução: o módulo Corpo ganha um helper próprio, com outro nome.
set -u
CORPO="/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo"
cd "$CORPO" || exit 1

/usr/bin/python3 - <<'PY'
import pathlib, re

theme = pathlib.Path("/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo/CorpoTheme.swift")
src = theme.read_text()

bloco = '''
// [Fusão 2026-08-02] O Alma declara `Color.init?(hex:)` (failable) em
// Shared/Theme.swift. Manter outra `init(hex:)` aqui dava "invalid
// redeclaration"; usar a do Alma exigiria desembrulhar opcional em ~60 lugares.
// O módulo Corpo passa a ter o próprio helper, com nome distinto.
extension Color {
    /// Cor adaptável a claro/escuro a partir de dois hex (uso interno do Corpo).
    init(light: String, dark: String) {
        self = Color(UIColor { trait in
            UIColor(Color.corpoHex(trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// Hex -> Color, não-failable (equivalente ao init original do Corpo & Alma).
    static func corpoHex(_ hex: String) -> Color {
        let s = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var rgb: UInt64 = 0
        s.scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
'''

marcador = "// [Fusão] extension Color.init(hex:) removida"
if marcador in src:
    idx = src.index(marcador)
    fim = src.index("\n", src.index("\n", idx) + 1) + 1
    src = src[:idx] + bloco.lstrip() + src[fim:]
else:
    src += "\n" + bloco
theme.write_text(src)
print("CorpoTheme: helper corpoHex instalado")

# Troca os usos Color(hex: "...") do módulo por Color.corpoHex("...")
alterados = 0
for p in pathlib.Path("/Users/almaappoficial/Desktop/ALMA/alma.app.oficial-main/Shared/Corpo").glob("*.swift"):
    t = p.read_text()
    novo = re.sub(r'Color\(hex:\s*', 'Color.corpoHex(', t)
    if novo != t:
        p.write_text(novo)
        alterados += 1
print(f"arquivos com Color(hex:) trocados: {alterados}")
PY

echo "=== conferência ==="
echo -n "Color(hex: restante no Corpo: "; grep -rc 'Color(hex:' *.swift | grep -v ':0' | wc -l
echo -n "corpoHex declarado: "; grep -c 'static func corpoHex' CorpoTheme.swift
