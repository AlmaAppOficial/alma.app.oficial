import { initializeApp, type FirebaseApp } from 'firebase/app'
import { getAuth, type Auth } from 'firebase/auth'
import { getFirestore, type Firestore } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY as string | undefined,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN as string | undefined,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID as string | undefined,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET as string | undefined,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID as string | undefined,
  appId: import.meta.env.VITE_FIREBASE_APP_ID as string | undefined,
  measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID as string | undefined,
}

/** True when all required env vars are present */
export const firebaseConfigured = Boolean(
  firebaseConfig.apiKey && firebaseConfig.projectId && firebaseConfig.appId,
)

// Initialize Firebase only when the config is present.
// When not configured the app renders a setup guide instead of crashing.
export let app: FirebaseApp | undefined
export let auth: Auth | undefined
export let db: Firestore | undefined

if (firebaseConfigured) {
  app = initializeApp(firebaseConfig)
  auth = getAuth(app)
  db = getFirestore(app)
}

/**
 * Full URL of the Firebase Cloud Function /chat endpoint.
 * Accepts both env var names for backward compatibility:
 *   VITE_FUNCTIONS_BASE_URL      → append /chat   (legacy name)
 *   VITE_FIREBASE_FUNCTIONS_URL  → use as-is      (GitHub Actions variable)
 *
 * Production value:
 *   https://southamerica-east1-alma-app-7dae6.cloudfunctions.net/chat
 */
const _baseUrl =
  (import.meta.env.VITE_FIREBASE_FUNCTIONS_URL as string | undefined) ??
  (import.meta.env.VITE_FUNCTIONS_BASE_URL as string | undefined) ??
  ''

export const FUNCTIONS_CHAT_URL = _baseUrl
  ? _baseUrl.endsWith('/chat')
    ? _baseUrl
    : `${_baseUrl.replace(/\/\/$/, '')}/chat`
  : ''
