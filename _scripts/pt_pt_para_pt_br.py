#!/usr/bin/env python3
"""Converte o conteúdo NARRADO de PT-PT (tuteamento europeu) para PT-BR.

[2026-08-03 — A12 da revisão independente]

A interface do app fala "você"; o áudio das meditações falava "tu": "Deixa o teu
corpo", "Estás seguro", "ecrã". O usuário mudava de país ao apertar play. Havia
ainda erros de concordância no meio disso ("Escuta o teu intuição", "Inspira
pela nariz", "Tu não és apenas aquele que ele és").

O script é conservador de propósito:
  • só toca em literais de string (linhas com aspas), nunca em código;
  • ignora palavras ambíguas em português (ex.: "para", que é preposição e
    imperativo ao mesmo tempo);
  • imprime cada substituição para conferência humana — a saída é o diff que
    vai para revisão.

Uso: python3 pt_pt_para_pt_br.py <arquivo.swift> [--aplicar]
"""
import re
import sys

# ── Imperativo tu → você ────────────────────────────────────────────────────
# Ordem importa: o mais específico primeiro.
VERBOS = {
    "Deixa": "Deixe", "deixa": "deixe",
    "Sente": "Sinta", "sente": "sinta",
    "Observa": "Observe", "observa": "observe",
    "Fecha": "Feche", "fecha": "feche",
    "Abre": "Abra", "abre": "abra",
    "Inspira": "Inspire", "inspira": "inspire",
    "Expira": "Expire", "expira": "expire",
    "Respira": "Respire", "respira": "respire",
    "Permite": "Permita", "permite": "permita",
    "Solta": "Solte", "solta": "solte",
    "Nota": "Note", "nota": "note",
    "Repara": "Repare", "repara": "repare",
    "Traz": "Traga", "traz": "traga",
    "Leva": "Leve", "leva": "leve",
    "Volta": "Volte", "volta": "volte",
    "Continua": "Continue", "continua": "continue",
    "Escuta": "Escute", "escuta": "escute",
    "Imagina": "Imagine", "imagina": "imagine",
    "Lembra": "Lembre", "lembra": "lembre",
    "Descansa": "Descanse", "descansa": "descanse",
    "Relaxa": "Relaxe", "relaxa": "relaxe",
    "Aceita": "Aceite", "aceita": "aceite",
    "Acolhe": "Acolha", "acolhe": "acolha",
    "Segue": "Siga", "segue": "siga",
    "Pousa": "Pouse", "pousa": "pouse",
    "Coloca": "Coloque", "coloca": "coloque",
    "Suaviza": "Suavize", "suaviza": "suavize",
    "Reconhece": "Reconheça", "reconhece": "reconheça",
    "Agradece": "Agradeça", "agradece": "agradeça",
    "Confia": "Confie", "confia": "confie",
    "Entrega": "Entregue", "entrega": "entregue",
    "Percebe": "Perceba", "percebe": "perceba",
    "Experimenta": "Experimente", "experimenta": "experimente",
    "Explora": "Explore", "explora": "explore",
    "Encontra": "Encontre", "encontra": "encontre",
    "Escolhe": "Escolha", "escolhe": "escolha",
    "Repete": "Repita", "repete": "repita",
    "Sorri": "Sorria", "sorri": "sorria",
    "Nomeia": "Nomeie", "nomeia": "nomeie",
    "Regressa": "Volte", "regressa": "volte",
}

# ── Possessivos e pronomes ──────────────────────────────────────────────────
PRONOMES = {
    "teu": "seu", "Teu": "Seu",
    "tua": "sua", "Tua": "Sua",
    "teus": "seus", "Teus": "Seus",
    "tuas": "suas", "Tuas": "Suas",
    "contigo": "com você", "Contigo": "Com você",
    "ti": "você", "Ti": "Você",
    "tu": "você", "Tu": "Você",
}

# ── Ser / estar / ter na 2ª pessoa ──────────────────────────────────────────
CONJUGACOES = {
    "estás": "está", "Estás": "Está",
    "és": "é", "És": "É",
    "tens": "tem", "Tens": "Tem",
    "podes": "pode", "Podes": "Pode",
    "queres": "quer", "Queres": "Quer",
    "sabes": "sabe", "Sabes": "Sabe",
    "precisas": "precisa", "Precisas": "Precisa",
    "sentes": "sente", "Sentes": "Sente",
    "vais": "vai", "Vais": "Vai",
    "vens": "vem", "Vens": "Vem",
    "fazes": "faz", "Fazes": "Faz",
    "dizes": "diz", "Dizes": "Diz",
    "vês": "vê", "Vês": "Vê",
    "estiveres": "estiver", "tiveres": "tiver",
    "fores": "for", "quiseres": "quiser", "puderes": "puder",
    "mereces": "merece", "Mereces": "Merece",
    "consegues": "consegue", "Consegues": "Consegue",
    "respiras": "respira", "existes": "existe",
    "mesclarás": "vai se mesclar", "encontrarás": "vai encontrar",
    # 2ª pessoa no indicativo — o texto alterna imperativo e descrição
    # ("Não a mudas. Apenas observas.")
    "mudas": "muda", "Mudas": "Muda",
    "observas": "observa", "Observas": "Observa",
    "serves": "serve", "Serves": "Serve",
    "sentires": "sentir", "quiseres": "quiser",
    "estiveres": "estiver", "notares": "notar",
    "respirares": "respirar", "voltares": "voltar",
    "acordas": "acorda", "Acordas": "Acorda",
    "carregas": "carrega", "Carregas": "Carrega",
    "guardas": "guarda", "Guardas": "Guarda",
    "mereceres": "merecer",
    "ages": "age", "Ages": "Age",
    "pensas": "pensa", "Pensas": "Pensa",
    "acreditas": "acredita", "Acreditas": "Acredita",
    "escolhes": "escolhe", "Escolhes": "Escolhe",
    "precisares": "precisar",
}

# ── Léxico europeu ──────────────────────────────────────────────────────────
LEXICO = {
    "ecrã": "tela", "Ecrã": "Tela",
    "contacto": "contato", "Contacto": "Contato",
    "facto": "fato", "Facto": "Fato",
    "acção": "ação", "Acção": "Ação",
    "acções": "ações", "actual": "atual", "actualmente": "atualmente",
    "óptimo": "ótimo", "Óptimo": "Ótimo",
    "directo": "direto", "director": "diretor",
    "telemóvel": "celular", "Telemóvel": "Celular",
    "casa de banho": "banheiro",
    "autocarro": "ônibus",
    "pequeno-almoço": "café da manhã",
    "estás bem": "está bem",
}

# Erros de concordância encontrados na revisão — correção literal.
ERROS = {
    "o teu intuição": "a sua intuição",
    "pela nariz": "pelo nariz",
    "aquele que ele és": "aquele que você pensa que é",
    "Não és separado": "Você não está separado",
}


def converter(texto: str) -> tuple[str, list[str]]:
    mudancas = []

    def aplica(mapa, txt):
        for origem, destino in sorted(mapa.items(), key=lambda kv: -len(kv[0])):
            padrao = re.compile(r"\b" + re.escape(origem) + r"\b")
            novo, n = padrao.subn(destino, txt)
            if n:
                mudancas.append(f"{origem} → {destino} ({n}×)")
                txt = novo
        return txt

    # Erros literais primeiro (contêm palavras que os outros mapas tocariam).
    for origem, destino in ERROS.items():
        if origem in texto:
            texto = texto.replace(origem, destino)
            mudancas.append(f"[erro] {origem} → {destino}")

    texto = aplica(LEXICO, texto)
    texto = aplica(CONJUGACOES, texto)
    texto = aplica(PRONOMES, texto)
    texto = aplica(VERBOS, texto)

    # Gerúndio europeu ("o ar a entrar" → "o ar entrando").
    #
    # A primeira versão desta regra usava um padrão genérico `\ba (\w+r)\b` e
    # estragou construções legítimas do PT-BR: "não há nada A FAZER" virou "nada
    # fazendo". Em português "a + infinitivo" é progressivo só depois de um
    # sujeito concreto; depois de "nada", "algo", "muito" etc. é infinitivo puro
    # e continua correto no Brasil.
    #
    # Como distinguir com segurança é difícil, aqui só entram as construções que
    # realmente aparecem nas meditações, uma a uma.
    PROGRESSIVOS = {
        "o ar a entrar": "o ar entrando",
        "o ar a sair": "o ar saindo",
        "a barriga a expandir-se": "a barriga se expandindo",
        "a expandir-se": "se expandindo",
        "a subir e a descer": "subindo e descendo",
        "a respirar": "respirando",
        "a bater": "batendo",
        "a fluir": "fluindo",
        "a passar": "passando",
        "a dissolver-se": "se dissolvendo",
        "a soltar-se": "se soltando",
    }
    for origem, destino in PROGRESSIVOS.items():
        if origem in texto:
            texto = texto.replace(origem, destino)
            mudancas.append(f"[progressivo] {origem} → {destino}")

    # Lista FECHADA de verbos que, nestas meditações, só aparecem em construção
    # progressiva ("o ar fresco a entrar"). "fazer" e "ir" ficam de fora de
    # propósito: "nada a fazer" e "nenhum lugar a ir" são corretos em PT-BR.
    PROGRESSIVO_VERBOS = {
        "entrar": "entrando", "sair": "saindo", "subir": "subindo",
        "descer": "descendo", "bater": "batendo", "fluir": "fluindo",
        "passar": "passando", "pulsar": "pulsando", "vibrar": "vibrando",
        "brilhar": "brilhando", "cair": "caindo", "correr": "correndo",
    }
    for origem, destino in PROGRESSIVO_VERBOS.items():
        padrao = re.compile(r"\ba " + origem + r"\b")
        texto, n = padrao.subn(destino, texto)
        if n:
            mudancas.append(f"[progressivo] a {origem} → {destino} ({n}×)")

    # Ênclise europeia: "acalma-te" → "se acalme". Trata o pronome grudado no
    # verbo, que não existe no português falado brasileiro.
    def enclise(m):
        verbo = m.group(1)
        conjugado = VERBOS.get(verbo, VERBOS.get(verbo.capitalize(), verbo))
        if verbo[0].isupper():
            conjugado = conjugado.capitalize()
        return f"se {conjugado[0].lower() + conjugado[1:]}" if not verbo[0].isupper() else f"Se {conjugado[1:].lower() and conjugado.lower()}"

    texto, n = re.subn(r"\b(\w+)-te\b", lambda m: _enclise_simples(m.group(1)), texto)
    if n:
        mudancas.append(f"[ênclise] verbo-te → se + verbo ({n}×)")

    return texto, mudancas


# Imperativos que aparecem com ênclise nas meditações.
ENCLISE_MAP = {
    "acalma": "se acalme", "Acalma": "Se acalme",
    "senta": "sente-se", "Senta": "Sente-se",
    "deita": "deite-se", "Deita": "Deite-se",
    "permite": "se permita", "Permite": "Se permita",
    "entrega": "se entregue", "Entrega": "Se entregue",
    "solta": "se solte", "Solta": "Se solte",
    "abre": "se abra", "Abre": "Se abra",
    "prepara": "se prepare", "Prepara": "Se prepare",
    "lembra": "se lembre", "Lembra": "Se lembre",
    "liberta": "se liberte", "Liberta": "Se liberte",
    "enche": "se encha", "Enche": "Se encha",
    "move": "se mova", "Move": "Se mova",
    "alonga": "se alongue", "Alonga": "Se alongue",
    "aproxima": "se aproxime", "Aproxima": "Se aproxime",
    "afasta": "se afaste", "Afasta": "Se afaste",
    "senta-se": "sente-se",
}


def _enclise_simples(verbo: str) -> str:
    return ENCLISE_MAP.get(verbo, verbo)


def main():
    caminho = sys.argv[1]
    aplicar = "--aplicar" in sys.argv

    linhas = open(caminho, encoding="utf-8").read().split("\n")
    saida, total = [], 0

    for linha in linhas:
        # Só literais de string: linha precisa ter aspas duplas.
        if '"' not in linha:
            saida.append(linha)
            continue
        nova, mudancas = converter(linha)
        if mudancas:
            total += 1
            if not aplicar:
                print(f"L{len(saida)+1}: {linha.strip()[:100]}")
                print(f"     → {nova.strip()[:100]}")
        saida.append(nova)

    print(f"\n{total} linhas alteradas em {caminho}")
    if aplicar:
        open(caminho, "w", encoding="utf-8").write("\n".join(saida))
        print("APLICADO")


if __name__ == "__main__":
    main()
