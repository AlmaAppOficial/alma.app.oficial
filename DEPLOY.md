# 🚀 Guia de Publicação — Alma App

> **Situação:** Você tem um MacBook Pro 2014 com Big Sur (macOS 11). O Xcode 15 exige macOS 13+.  
> **Solução:** Tudo é feito pelo **GitHub Actions** — você não precisa compilar nada no seu computador.

---

## Sumário

0. [Checklist rápido (do zero até publicar)](#-checklist-rápido-do-zero-até-publicar)
1. [Custos e contas necessárias](#-custos-e-contas-necessárias)
2. [iOS → App Store](#-ios--app-store)
3. [Android → Google Play](#-android--google-play)
4. [Fluxo de trabalho diário](#-fluxo-de-trabalho-diário)
5. [Dúvidas frequentes](#-dúvidas-frequentes)

---

## 🧭 Checklist rápido (do zero até publicar)

1) **Acessos e permissões**

- Conta **Admin** no App Store Connect e na Google Play Console
- Repositório GitHub com permissão para criar **Secrets** e habilitar **Pages**
- Apple Developer Program e Google Play Dev criados (veja custos abaixo)

2) **Conectar CI/CD**

- Web: GitHub → Settings → **Pages → Source: GitHub Actions**. O workflow `Deploy static content to Pages` já compila o Vite com `VITE_BASE_URL=/alma.app.oficial/` e publica o **dist/** automaticamente.
- Fez fork? Crie uma variável de repositório `VITE_BASE_URL` com `/<seu-repo>/` (Settings → Secrets and variables → Actions → Variables) ou ajuste o fallback no `.github/workflows/static.yml`.
- iOS: cadastre os secrets `APPLE_ID`, `APPLE_APP_SPECIFIC_PASSWORD`, `BUILD_CERTIFICATE_BASE64`, `BUILD_CERTIFICATE_PASSWORD`, `PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD` (tabela completa abaixo).
- Android: cadastre `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- Acesse **Actions** e rode manualmente cada workflow (`iOS Build`, `Android Build`, `Deploy static content to Pages`) para validar credenciais e conexões.

3) **Permissões no app**

- iOS/Android: o app não pede permissões sensíveis (sem câmera, sem localização). Tudo funciona offline; use apenas rede para recursos externos opcionais.
- Políticas de privacidade/termos devem ser publicados nas lojas (veja seção dedicada).

4) **Deploy**

- Push em `main` → iOS/TestFlight + Android/Internal + Web/Pages saem automaticamente. Monitore a aba **Actions** para ver se há erros de credencial ou de build.

---

## 💰 Custos e contas necessárias

| Item | Custo | Onde criar |
|------|-------|-----------|
| Apple Developer Program | **US$ 99/ano** | [developer.apple.com/enroll](https://developer.apple.com/enroll/) |
| Google Play Developer | **US$ 25 (único)** | [play.google.com/console](https://play.google.com/console/) |
| GitHub (CI/CD) | **Grátis** (2.000 min/mês para repos públicos) | já tem |
| Conta de email para suporte | Grátis | Gmail/Outlook |

> **Total no 1º ano:** ~US$ 124 (~R$ 640)  
> **A partir do 2º ano:** ~US$ 99 (~R$ 510) só pela Apple

---

## 🍎 iOS → App Store

### Passo 1 — Criar conta Apple Developer

1. Acesse [developer.apple.com/account](https://developer.apple.com/account) e entre com seu Apple ID
2. Inscreva-se no **Apple Developer Program** (US$ 99/ano)
3. Aguarde aprovação (geralmente 24-48h)

### Passo 2 — Criar o App ID no App Store Connect

1. Acesse [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. **Apps → "+" → Nova App**
3. Preencha:
   - **Plataformas:** iOS
   - **Nome:** Alma – Meditação & Bem-estar
   - **Idioma padrão:** Português (Brasil)
   - **Bundle ID:** `AlmaOficial.Alma` ← já configurado no projeto
   - **SKU:** `alma-app-v1`

### Passo 3 — Criar certificado de distribuição

> Você fará isso no site da Apple — sem precisar do Xcode no seu Mac.

1. Acesse [developer.apple.com → Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Clique em **"+"** → escolha **"Apple Distribution"**
3. Você precisará de um **CSR** (Certificate Signing Request). Use uma dessas opções:
   - **Opção A (fácil):** use um computador amigo com Mac + Xcode para gerar
   - **Opção B (online):** use [csrgen.net](https://csrgen.net/) para gerar online
4. Faça upload do CSR, baixe o `.cer`, converta para `.p12`:
   ```bash
   # No Terminal (Mac de um amigo):
   security import distribution.cer -k ~/Library/Keychains/login.keychain
   # Então exporte a chave privada como .p12 pelo Keychain Access
   ```
5. **Converta para base64** para salvar no GitHub:
   ```bash
   base64 -i distribution.p12 | pbcopy
   ```

### Passo 4 — Criar Provisioning Profile

1. [developer.apple.com → Profiles](https://developer.apple.com/account/resources/profiles/list)
2. **"+"** → **App Store** → selecione o App ID `AlmaOficial.Alma`
3. Selecione o certificado criado no Passo 3
4. Baixe o `.mobileprovision`
5. **Converta para base64:**
   ```bash
   base64 -i Alma_AppStore.mobileprovision | pbcopy
   ```

### Passo 5 — Configurar GitHub Secrets

No GitHub, acesse: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Valor |
|--------|-------|
| `APPLE_ID` | seu-email@example.com |
| `APPLE_APP_SPECIFIC_PASSWORD` | Gere em [appleid.apple.com](https://appleid.apple.com) → Segurança → App-specific passwords |
| `BUILD_CERTIFICATE_BASE64` | base64 do `.p12` (Passo 3) |
| `BUILD_CERTIFICATE_PASSWORD` | senha do `.p12` |
| `PROVISION_PROFILE_BASE64` | base64 do `.mobileprovision` (Passo 4) |
| `KEYCHAIN_PASSWORD` | qualquer senha aleatória, ex: `Alma2025!` |

### Passo 6 — Fazer o build via GitHub Actions

1. Faça commit de qualquer mudança e push para `main`
2. Acesse **GitHub → Actions → iOS Build & TestFlight**
3. Aguarde ~15-20 min — o workflow vai:
   - Compilar o app no macOS 14 (Xcode 15)
   - Assinar com seu certificado
   - Fazer upload para o TestFlight automaticamente

### Passo 7 — Testar no TestFlight

1. Abra o App Store Connect → seu app → TestFlight
2. O build aparecerá em alguns minutos
3. Adicione seu email como testador
4. Instale o app **TestFlight** no seu iPhone e aceite o convite

### Passo 8 — Submeter para revisão

1. App Store Connect → seu app → **"+"** na versão → adicione o build do TestFlight
2. Preencha:
   - Screenshots (necessário: iPhone 6.5" e iPhone 5.5")
   - Classificação etária
   - Privacidade (o app não coleta dados)
3. Clique **"Enviar para Revisão"**
4. Aguarde 1-3 dias úteis

---

## 🤖 Android → Google Play

### Passo 1 — Criar conta Google Play

1. Acesse [play.google.com/console](https://play.google.com/console)
2. Pague a taxa única de **US$ 25**
3. Complete a verificação de identidade

### Passo 2 — Criar o app no Play Console

1. **"Criar app"**
2. Nome: **Alma – Meditação & Bem-estar**
3. Idioma padrão: Português (Brasil)
4. Tipo: App | Grátis
5. Complete as declarações de conformidade

### Passo 3 — Criar a keystore de assinatura

> Este é o passo mais importante! Guarde os arquivos em local seguro — se perder, não consegue atualizar o app.

```bash
# Rode este comando (num Mac, Linux ou WSL no Windows):
keytool -genkey -v \
  -keystore alma-release.jks \
  -alias alma \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

# Quando perguntar, preencha:
# First and last name: Felipe Lara (ou seu nome)
# Organizational unit: Alma App
# Organization: Alma App
# City: São Paulo
# State: SP
# Country: BR
```

**Anote e salve em lugar seguro:**
- O arquivo `alma-release.jks`
- Senha da keystore (store password)
- Senha da chave (key password)
- Nome do alias: `alma`

**Converta para base64:**
```bash
# macOS:
base64 -i alma-release.jks | tr -d '\n'

# Linux / WSL:
base64 -w 0 alma-release.jks
```

### Passo 4 — Configurar GitHub Secrets para Android

| Secret | Valor |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | base64 da `alma-release.jks` |
| `ANDROID_KEY_ALIAS` | `alma` |
| `ANDROID_KEY_PASSWORD` | sua senha da chave |
| `ANDROID_STORE_PASSWORD` | sua senha da keystore |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON da service account (passo 5) |

### Passo 5 — Service Account para upload automático

1. Play Console → Setup → **API access**
2. Clique em **"Criar novo projeto de serviço"**
3. No Google Cloud Console → IAM → **Criar conta de serviço**
4. Baixe o JSON da chave
5. De volta ao Play Console → conceda acesso à conta de serviço com papel **"Gerenciador de versões"**
6. Cole o conteúdo do JSON no secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

### Passo 6 — Primeiro upload (manual)

> O Google Play exige que o **primeiro** upload seja feito manualmente.

1. Faça push para `main` — o GitHub Actions vai gerar o `.aab`
2. Baixe o artefato `Alma-*.aab` na aba Actions
3. Play Console → seu app → **Production → Create new release → Upload**
4. Faça upload do `.aab` e envie para revisão

> **Nota sobre changelogs:** Para cada versão, crie um arquivo numerado em `fastlane/metadata/android/pt-BR/changelogs/<versionCode>.txt`. Por exemplo, para a versão 1 do app crie `1.txt` (já existe). Para a versão 2 crie `2.txt`. O número deve ser igual ao `versionCode` configurado no `android/app/build.gradle`.

### Passo 7 — Uploads seguintes (automático)

A partir do 2º upload, o GitHub Actions envia automaticamente para o **Internal Track** sempre que você fizer push para `main`.

---

## 🔄 Fluxo de trabalho diário

```
1. Edite o código no VS Code
2. git add . && git commit -m "sua mensagem"
3. git push origin main
4. GitHub Actions compila automaticamente iOS e Android
5. iOS vai direto para TestFlight
6. Android vai para Internal Track no Play Console
7. Quando satisfeito, promova para produção nas consoles
```

---

## 📱 Screenshots necessárias para publicar

### App Store (obrigatório)
| Tamanho | Dispositivo |
|---------|------------|
| 1290 × 2796 px | iPhone 15 Pro Max (6.7") |
| 1242 × 2208 px | iPhone 8 Plus (5.5") |

**Dica gratuita:** Use o [Canva](https://canva.com) ou [AppMockUp](https://app-mockup.com) para criar screenshots bonitas com moldura de iPhone sem precisar de um iPhone físico.

### Google Play (obrigatório)
| Tipo | Tamanho |
|------|---------|
| Ícone | 512 × 512 px |
| Feature graphic | 1024 × 500 px |
| Screenshots (mín. 2) | mín. 320px, máx. 3840px |

---

## 🛡 Política de privacidade (obrigatória em ambas as lojas)

O app não coleta dados pessoais nem usa internet — tudo é salvo localmente no dispositivo. Crie uma política simples:

1. Acesse [app-privacy-policy-generator.nisrulnaim.me](https://app-privacy-policy-generator.nisrulnaim.me/) (grátis)
2. Preencha "Alma App" como nome, marque que NÃO coleta dados
3. Hospede o HTML no GitHub Pages (grátis):
   ```bash
   # No seu repositório, crie o arquivo docs/privacy-policy.html
   # Depois em Settings → Pages → source: /docs
   # URL: https://felipeassislara170.github.io/alma.app.oficial/privacy-policy.html
   ```

---

## ❓ Dúvidas frequentes

**"Não tenho Mac para gerar o certificado — o que faço?"**  
Peça a um amigo com Mac para abrir o Keychain Access e gerar o CSR, ou use o serviço online [csrgen.net](https://csrgen.net). Todo o build é feito no GitHub Actions — você não precisa do Mac para compilar.

**"Quanto tempo demora a aprovação?"**  
- App Store: 1-3 dias úteis na primeira submissão  
- Google Play: 1-7 dias úteis na primeira submissão; atualizações geralmente em horas

**"O app vai ser cobrado ou grátis?"**  
Comece grátis para ganhar usuários. Monetize depois com:  
- In-app purchase de plano premium (mais meditações)  
- Assinatura mensal/anual  
Ambas as lojas cobram 15-30% de comissão.

**"Como atualizar o app?"**  
Apenas faça push para `main` com as mudanças. O GitHub Actions cria o build automaticamente e envia para TestFlight/Play Internal. Você só precisa clicar "Promover para Produção" nas consoles.

**"Posso ter o app em inglês também?"**  
Sim! Adicione traduções em `fastlane/metadata/ios/en-US/` (inglês americano) com os mesmos arquivos `.txt`. No Play Store, adicione em `fastlane/metadata/android/en-US/`.

---

## 📞 Suporte

Dúvidas sobre a publicação? Abra uma [issue no GitHub](https://github.com/felipeassislara170/alma.app.oficial/issues).

---

*Feito com 💜 para o Alma App*
