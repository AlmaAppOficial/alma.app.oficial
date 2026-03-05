# Alma App — Cuide da sua Alma 💜

Aplicativo de bem-estar mental com meditações guiadas, exercícios de respiração, rastreio de humor e muito mais.

[![Live Preview](https://img.shields.io/badge/👁%20Ver%20ao%20Vivo-GitHub%20Pages-6B46C1?style=for-the-badge)](https://felipeassislara170.github.io/alma.app.oficial/)
[![iOS Build](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/ios.yml/badge.svg)](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/ios.yml)
[![Android Build](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/android.yml/badge.svg)](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/android.yml)
[![Pages Deploy](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/static.yml/badge.svg)](https://github.com/felipeassislara170/alma.app.oficial/actions/workflows/static.yml)

## 👁 Ver o app ao vivo

**URL:** **https://felipeassislara170.github.io/alma.app.oficial/**

> Abra no celular para ver exatamente como vai parecer no app!

**Ativar uma única vez** (Settings → Pages → Source → **GitHub Actions**):

```
1. Acesse: github.com/felipeassislara170/alma.app.oficial/settings/pages
2. Em "Source" selecione: GitHub Actions
3. Clique Save
4. Aguarde ~2 minutos → acesse a URL acima
```

Após isso, **cada push para `main`** atualiza o preview automaticamente em ~2 minutos.

---

> 🚀 **Pronto para publicar?** Leia o **[DEPLOY.md](./DEPLOY.md)** — guia completo para App Store e Google Play, mesmo com MacBook antigo.

| Plataforma | Bundle ID | Status |
|------------|-----------|--------|
| iOS (SwiftUI) | `AlmaOficial.Alma` | Pronto para App Store |
| Android (Capacitor) | `AlmaOficial.Alma` | Pronto para Google Play |
| Landing page | GitHub Pages | [Ver ao vivo ↗](https://felipeassislara170.github.io/alma.app.oficial/) |

---

## 📱 iOS (SwiftUI)

### Compilar sem Xcode local (recomendado se seu Mac for antigo)

Push para `main` → GitHub Actions usa **macOS 14 + Xcode 15** (grátis) → upload automático para TestFlight.  
Veja o workflow em [`.github/workflows/ios.yml`](.github/workflows/ios.yml).

### Abrir localmente (requer macOS 13+ e Xcode 15+)

### Pré-requisitos
- macOS 13+ com **Xcode 15+** instalado
- Simulador ou dispositivo iOS 17+

### Como abrir no Xcode

```bash
# Na pasta raiz do repositório:
open ios/Alma.xcodeproj
```

Depois de abrir:
1. Selecione o scheme **Alma** no topo
2. Escolha um simulador iPhone (ex.: iPhone 15 Pro)
3. Pressione **⌘ R** para compilar e rodar

### Configurar sua conta de desenvolvedor (para rodar num dispositivo real)
1. Xcode → Settings → Accounts → adicione seu Apple ID
2. No target **Alma** → Signing & Capabilities → selecione seu **Team**
3. Mude o **Bundle Identifier** para algo único (ex.: `com.seunome.alma`)

### Estrutura iOS (`ios/`)

```
ios/
├── Alma.xcodeproj/          ← Abra este arquivo no Xcode
├── Alma/
│   ├── AlmaApp.swift        ← Entry point (@main)
│   ├── ContentView.swift    ← Tab-bar principal (5 abas)
│   ├── Extensions/
│   │   └── Color+Alma.swift ← Paleta de cores da marca
│   ├── Models/
│   │   ├── Meditation.swift ← Modelo + dados de exemplo
│   │   ├── MoodEntry.swift  ← Registro de humor
│   │   └── UserProfile.swift
│   ├── ViewModels/
│   │   ├── UserViewModel.swift
│   │   ├── MeditationViewModel.swift ← Timer da meditação
│   │   └── MoodViewModel.swift       ← Persistência do humor
│   ├── Views/
│   │   ├── OnboardingView.swift  ← Boas-vindas + nome do usuário
│   │   ├── HomeView.swift        ← Início com recomendações
│   │   ├── MeditationListView.swift ← Catálogo por categoria
│   │   ├── MeditationPlayerView.swift ← Player com timer
│   │   ├── BreatheView.swift     ← Exercício 4-7-8 animado
│   │   ├── MoodTrackerView.swift ← Registro diário de humor
│   │   └── ProfileView.swift     ← Estatísticas e configurações
│   └── Assets.xcassets/
└── AlmaTests/
    └── AlmaTests.swift       ← Testes unitários
```

### Funcionalidades

| Tela | O que faz |
|------|-----------|
| **Onboarding** | Introdução ao app + captura do nome |
| **Início** | Saudação personalizada, sequência, meditação em destaque |
| **Meditar** | Catálogo filtrado por categoria + player com anel de progresso |
| **Respirar** | Exercício 4-7-8 com círculo animado e contagem regressiva |
| **Humor** | Registro diário com emoji, nota e histórico |
| **Perfil** | Estatísticas, configurações e reset do onboarding |

---

## 🤖 Android (Capacitor)

O app Android é gerado envolvendo o **React web app** com [Capacitor](https://capacitorjs.com/) — sem precisar reescrever nada.

### Build local (requer Node 20+, Java 17, Android Studio)

```bash
npm install
npm run build:android   # compila React → sincroniza com Capacitor Android
npx cap open android    # abre Android Studio
```

### Build via GitHub Actions (recomendado)

Push para `main` → GitHub Actions usa Ubuntu + Java 17 + Gradle → gera AAB assinado → sobe para Play Console (Internal Track).  
Veja o workflow em [`.github/workflows/android.yml`](.github/workflows/android.yml).

---

## 🌐 Web (React + TypeScript)

Landing page do Alma, também incluída neste repositório.

### Executar localmente

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # build de produção em /dist
npm run preview    # pré-visualizar o build
```

### Deploy (Vercel / Netlify)
Conecte o repositório e o deploy será feito automaticamente a partir da raiz.

---

## 🛠 Tecnologias

| Plataforma | Stack |
|------------|-------|
| iOS        | Swift 5.9 · SwiftUI · Xcode 15 · iOS 17 |
| Android    | Capacitor 7 · React 19 · Gradle · Java 17 |
| Web        | React 19 · TypeScript · Vite 7 |

---

## 📄 Licença

Copyright © 2025 Alma App. Todos os direitos reservados.
