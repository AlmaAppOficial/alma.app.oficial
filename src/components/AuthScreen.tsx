import { useState, type FormEvent } from 'react'
import { useAuth } from '../contexts/useAuth'

type Mode = 'login' | 'register'

interface AuthScreenProps {
  onShowTerms: () => void
  onShowPrivacy: () => void
}

export function AuthScreen({ onShowTerms, onShowPrivacy }: AuthScreenProps) {
  const { login, register } = useAuth()
  const [mode, setMode] = useState<Mode>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const validate = (): string | null => {
    if (!email.trim()) return 'Informe um e-mail.'
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return 'E-mail inválido.'
    if (password.length < 6) return 'Senha deve ter ao menos 6 caracteres.'
    if (mode === 'register' && password !== confirm) return 'As senhas não coincidem.'
    return null
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    const validationError = validate()
    if (validationError) { setError(validationError); return }
    setError(null)
    setBusy(true)
    try {
      if (mode === 'login') {
        await login(email, password)
      } else {
        await register(email, password)
      }
    } catch (err: unknown) {
      const code = (err as { code?: string }).code ?? ''
      if (code === 'auth/user-not-found' || code === 'auth/wrong-password' || code === 'auth/invalid-credential') {
        setError('E-mail ou senha incorretos.')
      } else if (code === 'auth/email-already-in-use') {
        setError('E-mail já cadastrado. Faça login.')
      } else if (code === 'auth/too-many-requests') {
        setError('Muitas tentativas. Tente novamente mais tarde.')
      } else {
        setError('Ocorreu um erro. Tente novamente.')
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-card__logo">
          <svg width="48" height="48" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <defs>
              <linearGradient id="authLogoGrad" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#6B46C1" />
                <stop offset="100%" stopColor="#9F7AEA" />
              </linearGradient>
            </defs>
            <circle cx="32" cy="32" r="30.5" fill="url(#authLogoGrad)" stroke="#4B2C88" strokeWidth="3" />
            <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
            <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
            <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
          </svg>
          <span className="auth-card__brand">Alma</span>
        </div>

        <h1 className="auth-card__title">
          {mode === 'login' ? 'Bem-vindo de volta' : 'Crie sua conta'}
        </h1>
        <p className="auth-card__sub">
          {mode === 'login'
            ? 'Entre para continuar cuidando da sua alma.'
            : 'Comece gratuitamente, sem cartão de crédito.'}
        </p>

        <form className="auth-form" onSubmit={handleSubmit} noValidate>
          <div className="auth-form__field">
            <label htmlFor="auth-email">E-mail</label>
            <input
              id="auth-email"
              type="email"
              autoComplete="email"
              placeholder="seu@email.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={busy}
              required
            />
          </div>

          <div className="auth-form__field">
            <label htmlFor="auth-password">Senha</label>
            <input
              id="auth-password"
              type="password"
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              placeholder="Mínimo 6 caracteres"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={busy}
              required
            />
          </div>

          {mode === 'register' && (
            <div className="auth-form__field">
              <label htmlFor="auth-confirm">Confirmar senha</label>
              <input
                id="auth-confirm"
                type="password"
                autoComplete="new-password"
                placeholder="Repita a senha"
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
                disabled={busy}
                required
              />
            </div>
          )}

          {error && <p className="auth-form__error" role="alert">{error}</p>}

          <button type="submit" className="btn btn--primary btn--lg auth-form__submit" disabled={busy}>
            {busy ? 'Aguarde…' : mode === 'login' ? 'Entrar' : 'Criar conta'}
          </button>
        </form>

        <p className="auth-card__switch">
          {mode === 'login' ? 'Ainda não tem conta?' : 'Já tem uma conta?'}
          {' '}
          <button
            type="button"
            className="auth-card__switch-btn"
            onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setError(null) }}
          >
            {mode === 'login' ? 'Cadastre-se' : 'Faça login'}
          </button>
        </p>
        <p className="auth-card__legal">
          Ao criar uma conta, você concorda com nossos{' '}
          <button type="button" className="auth-card__switch-btn" onClick={onShowTerms}>
            Termos de Uso
          </button>{' '}
          e{' '}
          <button type="button" className="auth-card__switch-btn" onClick={onShowPrivacy}>
            Política de Privacidade
          </button>.
        </p>
      </div>
    </div>
  )
}
