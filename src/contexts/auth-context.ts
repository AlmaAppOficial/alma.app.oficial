import { createContext } from 'react'
import type { User } from 'firebase/auth'

export type HealthConsent = 'granted' | 'denied' | null

export interface AuthContextValue {
  user: User | null
  loading: boolean
  healthConsent: HealthConsent
  register: (email: string, password: string) => Promise<void>
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  setHealthConsent: (consent: HealthConsent) => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)
