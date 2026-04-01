/**
 * Legacy re-export shim.
 *
 * All Firebase initialization lives in ./lib/firebase so that only ONE
 * Firebase app instance is ever created, regardless of which import path
 * a component uses.
 *
 * New code should import directly from './lib/firebase'.
 */
export { auth, db, app, firebaseConfigured, FUNCTIONS_CHAT_URL } from './lib/firebase'
