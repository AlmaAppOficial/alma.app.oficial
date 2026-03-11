# 🔥 Firebase Setup — Alma App

Guia passo a passo para configurar o Firebase para o Alma App (Auth + Firestore + Cloud Functions) e fazer deploy na plataforma desejada.

---

## 📋 Pré-requisitos

- Conta Google
- [Firebase CLI](https://firebase.google.com/docs/cli) instalada: `npm install -g firebase-tools`
- Node.js 20+

---

## 1. Criar o projeto Firebase

1. Acesse [console.firebase.google.com](https://console.firebase.google.com) e clique em **Adicionar projeto**.
2. Dê um nome ao projeto (ex: `alma-app-prod`).
3. Habilite o Google Analytics (opcional).
4. Aguarde a criação e clique em **Continuar**.

---

## 2. Configurar Authentication (Email/Senha)

1. No Console Firebase, acesse **Authentication → Método de login**.
2. Clique em **Email/Senha**, habilite-o e salve.
3. Opcionalmente, habilite **Link de e-mail (login sem senha)** para uma experiência sem senha.

---

## 3. Configurar Firestore

1. Acesse **Firestore Database → Criar banco de dados**.
2. Escolha **Modo de produção** (recomendado).
3. Selecione a região mais próxima de seus usuários (ex: `us-central1` ou `southamerica-east1`).
4. Configure as **Regras de Segurança**:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own consent document
    match /users/{uid}/consents/{document} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }

    // Rate limits — only Cloud Functions (admin) can write
    match /rateLimits/{uid} {
      allow read, write: if false; // Only accessible by Cloud Functions (admin SDK)
    }
  }
}
```

---

## 4. Criar o Web App e obter as credenciais

1. Na página inicial do projeto, clique em **`</>`** (Web).
2. Dê um apelido (ex: `alma-pwa`).
3. Marque **"Configure o Firebase Hosting"** se quiser usar Firebase Hosting.
4. Clique em **Registrar app**.
5. Copie o objeto `firebaseConfig` exibido:

```js
const firebaseConfig = {
  apiKey: "...",
  authDomain: "seu-projeto.firebaseapp.com",
  projectId: "seu-projeto",
  storageBucket: "seu-projeto.appspot.com",
  messagingSenderId: "...",
  appId: "...",
  measurementId: "G-..." // opcional
}
```

---

## 5. Configurar variáveis de ambiente locais

1. Copie o arquivo de exemplo:
   ```bash
   cp .env.example .env.local
   ```
2. Preencha com os valores do passo 4:
   ```
   VITE_FIREBASE_API_KEY=seu_api_key
   VITE_FIREBASE_AUTH_DOMAIN=seu-projeto.firebaseapp.com
   VITE_FIREBASE_PROJECT_ID=seu-projeto
   VITE_FIREBASE_STORAGE_BUCKET=seu-projeto.appspot.com
   VITE_FIREBASE_MESSAGING_SENDER_ID=seu_sender_id
   VITE_FIREBASE_APP_ID=seu_app_id
   VITE_FIREBASE_MEASUREMENT_ID=G-XXXXXXXXXX

   # URL base das Cloud Functions
   VITE_FUNCTIONS_BASE_URL=https://us-central1-seu-projeto.cloudfunctions.net
   ```

---

## 6. Configurar variáveis no GitHub Actions (GitHub Pages)

Para fazer deploy no GitHub Pages com as variáveis corretas:

1. No GitHub, acesse: **Settings → Secrets and variables → Actions → Variables**.
2. Adicione cada variável como uma **Variable** (não Secret, pois são públicas no bundle JS):

| Nome | Valor |
|------|-------|
| `VITE_FIREBASE_API_KEY` | seu_api_key |
| `VITE_FIREBASE_AUTH_DOMAIN` | seu-projeto.firebaseapp.com |
| `VITE_FIREBASE_PROJECT_ID` | seu-projeto |
| `VITE_FIREBASE_STORAGE_BUCKET` | seu-projeto.appspot.com |
| `VITE_FIREBASE_MESSAGING_SENDER_ID` | seu_sender_id |
| `VITE_FIREBASE_APP_ID` | seu_app_id |
| `VITE_FIREBASE_MEASUREMENT_ID` | G-XXXXXXXXXX (opcional) |
| `VITE_FUNCTIONS_BASE_URL` | https://us-central1-seu-projeto.cloudfunctions.net |

> **Importante:** Estas variáveis ficam **embutidas no JavaScript** do bundle. Isso é seguro para chaves do Firebase Client SDK (são restritas por domínio/projeto). A chave da OpenAI **nunca** vai para o cliente — ela fica nas Cloud Functions.

3. No workflow `.github/workflows/static.yml`, garanta que o passo de build passe as variáveis:
   ```yaml
   - name: Build
     run: npm ci && npm run build
     env:
       VITE_FIREBASE_API_KEY: ${{ vars.VITE_FIREBASE_API_KEY }}
       VITE_FIREBASE_AUTH_DOMAIN: ${{ vars.VITE_FIREBASE_AUTH_DOMAIN }}
       VITE_FIREBASE_PROJECT_ID: ${{ vars.VITE_FIREBASE_PROJECT_ID }}
       VITE_FIREBASE_STORAGE_BUCKET: ${{ vars.VITE_FIREBASE_STORAGE_BUCKET }}
       VITE_FIREBASE_MESSAGING_SENDER_ID: ${{ vars.VITE_FIREBASE_MESSAGING_SENDER_ID }}
       VITE_FIREBASE_APP_ID: ${{ vars.VITE_FIREBASE_APP_ID }}
       VITE_FIREBASE_MEASUREMENT_ID: ${{ vars.VITE_FIREBASE_MEASUREMENT_ID }}
       VITE_FUNCTIONS_BASE_URL: ${{ vars.VITE_FUNCTIONS_BASE_URL }}
   ```

---

## 7. Configurar e fazer deploy das Cloud Functions

### 7.1 Configurar o secret da OpenAI

```bash
# Faça login no Firebase CLI
firebase login

# Configure o secret OPENAI_API_KEY no Firebase Secret Manager
firebase functions:secrets:set OPENAI_API_KEY
# Quando solicitado, cole sua chave da OpenAI (começa com sk-)
```

> A chave ficará armazenada no **Google Cloud Secret Manager** e só será acessível pelas Cloud Functions — nunca no cliente.

### 7.2 Atualizar o `.firebaserc`

Edite `.firebaserc` e substitua `YOUR_FIREBASE_PROJECT_ID` pelo ID do seu projeto:

```json
{
  "projects": {
    "default": "seu-projeto-id"
  }
}
```

### 7.3 Instalar dependências das Functions

```bash
cd functions
npm install
cd ..
```

### 7.4 Testar localmente com o emulador

```bash
# Na raiz do projeto:
firebase emulators:start --only functions,firestore,auth

# Em outro terminal, inicie o servidor de desenvolvimento:
npm run dev
```

O emulador estará disponível em:
- Functions: `http://127.0.0.1:5001`
- Auth: `http://127.0.0.1:9099`
- Firestore: `http://127.0.0.1:8080`

### 7.5 Fazer deploy das Cloud Functions

```bash
firebase deploy --only functions
```

### 7.6 Fazer deploy do frontend (Firebase Hosting)

```bash
npm run build
firebase deploy --only hosting
```

---

## 8. Testar o PWA no iPhone (Adicionar à Tela de Início)

1. Abra o Safari no iPhone.
2. Acesse a URL do seu PWA (ex: `https://felipeassislara170.github.io/alma.app.oficial/` ou `https://seu-projeto.web.app`).
3. Toque no botão de **Compartilhar** (ícone de seta para cima).
4. Role para baixo e toque em **"Adicionar à Tela de Início"**.
5. Confirme o nome "Alma" e toque em **Adicionar**.
6. O app aparecerá na tela inicial como um ícone nativo.

> **Dica:** Para uma experiência de PWA ideal no iOS, verifique se o `manifest.webmanifest` tem `display: "standalone"` e os ícones corretos.

---

## 9. Variáveis de ambiente — referência rápida

| Variável | Onde definir | Sensível? |
|----------|-------------|-----------|
| `VITE_FIREBASE_*` | `.env.local` (local), GitHub Variables (CI) | ⚠️ Sim para produção, mas visível no bundle |
| `VITE_FUNCTIONS_BASE_URL` | `.env.local`, GitHub Variables | Não |
| `OPENAI_API_KEY` | Firebase Secret Manager (`firebase functions:secrets:set`) | 🔒 Sim — NUNCA no client |

---

## 10. Segurança — checklist

- [ ] Regras do Firestore configuradas (não usar modo de teste em produção)
- [ ] Domínios autorizados no Firebase Auth (Autenticação → Configurações → Domínios autorizados)
- [ ] OPENAI_API_KEY configurada via `firebase functions:secrets:set` (não no `.env`)
- [ ] Nenhuma chave de API no código-fonte ou em variáveis de ambiente do cliente que não sejam as do Firebase Client SDK
- [ ] GitHub Pages habilitado com HTTPS
- [ ] Regras de restrição de API Key no Google Cloud Console (opcional mas recomendado)

---

## 📚 Recursos úteis

- [Documentação do Firebase](https://firebase.google.com/docs)
- [Firebase Authentication — Web](https://firebase.google.com/docs/auth/web/start)
- [Cloud Functions para Firebase](https://firebase.google.com/docs/functions)
- [Firebase Secret Manager](https://firebase.google.com/docs/functions/config-env#secret-manager)
- [LGPD — ANPD](https://www.gov.br/anpd)
- [OpenAI API Reference](https://platform.openai.com/docs)
