import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

/**
 * Firebase client configuration.
 * Values come from VITE_FIREBASE_* environment variables set in GitHub Actions
 * repository variables (Settings → Secrets and variables → Actions → Variables).
 *
 * These are NOT secret — Firebase client config is a public project identifier.
 * The actual secret (OPENAI_API_KEY) lives only in Firebase Functions secrets.
 */
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY ?? '',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN ?? '',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID ?? '',
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET ?? '',
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '',
  appId: import.meta.env.VITE_FIREBASE_APP_ID ?? '',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);

/**
 * Base URL for the Firebase Cloud Function chat endpoint.
 * Set VITE_FIREBASE_FUNCTIONS_URL in GitHub Actions variables to the full URL,
 * e.g. https://southamerica-east1-<project-id>.cloudfunctions.net/chat
 */
export const FUNCTIONS_CHAT_URL =
  import.meta.env.VITE_FIREBASE_FUNCTIONS_URL ?? '';
