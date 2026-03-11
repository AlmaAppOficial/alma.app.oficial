import { useEffect, useState, type ReactNode } from 'react'
import {
  onAuthStateChanged,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth'
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore'
import { auth, db, firebaseConfigured } from '../lib/firebase'
import { AuthContext, type HealthConsent } from './auth-context'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<import('firebase/auth').User | null>(null)
  // If Firebase isn't configured, start with loading=false so the UI renders immediately
  const [loading, setLoading] = useState(firebaseConfigured)
  const [healthConsent, setHealthConsentState] = useState<HealthConsent>(null)

  useEffect(() => {
    if (!firebaseConfigured || !auth) return

    // Safety timeout: if Firebase never responds (e.g. network error), stop blocking the UI
    const timeout = setTimeout(() => setLoading(false), 8000)

    const unsub = onAuthStateChanged(
      auth,
      async (firebaseUser) => {
        clearTimeout(timeout)
        setUser(firebaseUser)
        if (firebaseUser) {
          // Try Firestore first, fall back to localStorage
          let consent: HealthConsent = null
          try {
            if (db) {
              const snap = await getDoc(doc(db, 'users', firebaseUser.uid, 'consents', 'health'))
              if (snap.exists()) {
                const data = snap.data()
                consent =
                  data.status === 'granted' || data.status === 'denied' ? data.status : null
              }
            } else {
              throw new Error('Firestore not initialized')
            }
          } catch {
            // Firestore unavailable — fall back to localStorage
            const stored = localStorage.getItem(`healthConsent:${firebaseUser.uid}`)
            consent = stored === 'granted' || stored === 'denied' ? stored : null
          }
          setHealthConsentState(consent)
        } else {
          setHealthConsentState(null)
        }
        setLoading(false)
      },
      (error) => {
        // Firebase Auth error (e.g. network issue)
        clearTimeout(timeout)
        console.error('Firebase Auth error:', error)
        setLoading(false)
      },
    )

    return () => {
      clearTimeout(timeout)
      unsub()
    }
  }, [])

  const register = async (email: string, password: string) => {
    if (!auth) throw new Error('Firebase not configured')
    await createUserWithEmailAndPassword(auth, email, password)
  }

  const login = async (email: string, password: string) => {
    if (!auth) throw new Error('Firebase not configured')
    await signInWithEmailAndPassword(auth, email, password)
  }

  const logout = async () => {
    if (!auth) throw new Error('Firebase not configured')
    await signOut(auth)
  }

  const setHealthConsent = (consent: HealthConsent) => {
    setHealthConsentState(consent)
    if (user && consent !== null) {
      // Persist in localStorage (always available)
      localStorage.setItem(`healthConsent:${user.uid}`, consent)
      // Persist in Firestore (best-effort — network may be unavailable)
      if (db) {
        const uid = user.uid
        setDoc(doc(db, 'users', uid, 'consents', 'health'), {
          status: consent,
          updatedAt: serverTimestamp(),
        }).catch((err) => console.warn('Firestore consent write failed:', err))
      }
    }
  }

  return (
    <AuthContext.Provider
      value={{ user, loading, healthConsent, register, login, logout, setHealthConsent }}
    >
      {children}
    </AuthContext.Provider>
  )
}
