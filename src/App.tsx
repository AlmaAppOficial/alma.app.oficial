import { useState, useEffect, Component, type ReactNode, type ErrorInfo } from 'react'
import './App.css'

import { AuthProvider } from './contexts/AuthContext'
import { useAuth } from './contexts/useAuth'
import { AuthScreen } from './components/AuthScreen'
import { ConsentModal } from './components/ConsentModal'
import ChatScreen from './components/ChatScreen'
import { TermsPage } from './components/TermsPage'
import { PrivacyPage } from './components/PrivacyPage'
import OnboardingFlow from './components/OnboardingFlow'
import { firebaseConfigured, db } from './lib/firebase'
import { doc, getDoc } from 'firebase/firestore'

// ── Error Boundary ────────────────────────────────────────────────────────────
interface ErrorBoundaryState { hasError: boolean }
class ErrorBoundary extends Component<{ children: ReactNode }, ErrorBoundaryState> {
  constructor(props: { children: ReactNode }) {
    super(props)
    this.state = { hasError: false }
  }
  static getDerivedStateFromError(): ErrorBoundaryState { return { hasError: true } }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('[ErrorBoundary]', error, info)
  }
  render() {
    if (this.state.hasError) {
      return (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', padding: '2rem', textAlign: 'center', background: '#0f0a1e', color: '#e9d5ff' }}>
          <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>🌙</div>
          <h2 style={{ marginBottom: '0.5rem', color: '#c4b5fd' }}>Algo deu errado</h2>
          <p style={{ marginBottom: '1.5rem', opacity: 0.7 }}>Aconteceu um erro inesperado. Por favor, recarregue a página.</p>
          <button onClick={() => window.location.reload()} style={{ background: '#7c3aed', color: 'white', border: 'none', borderRadius: '0.5rem', padding: '0.75rem 1.5rem', cursor: 'pointer', fontSize: '1rem' }}>
            Recarregar página
          </button>
        </div>
      )
    }
    return this.props.children
  }
}

const STREAK_DAYS = 7

type Page = 'home' | 'terms' | 'privacy'

type Mood = 0 | 1 | 2 | 3 | 4

const MOOD_LABELS = ['Muito difícil', 'Pesado', 'Neutro', 'Bem', 'Ótimo']
const MOOD_EMOJIS = ['😔', '😐', '🙂', '😊', '😄']

const MOOD_AI_RESPONSES: Record<Mood, { message: string; suggestion: string; meditation: string }> = {
  0: {
    message: 'Sinto isso com você. Dias assim pesam.',
    suggestion: 'A Alma sugere começar com 5 minutos de respiração consciente.',
    meditation: 'Alívio de Ansiedade · 10 min',
  },
  1: {
    message: 'Tudo bem não estar bem. Você veio aqui — isso já é coragem.',
    suggestion: 'Uma meditação de enraizamento pode ajudar a te ancorar.',
    meditation: 'Raízes · 7 min',
  },
  2: {
    message: 'Equilíbrio é um bom ponto de partida para se aprofundar.',
    suggestion: 'Que tal explorar sua alma com uma sessão de presença?',
    meditation: 'Ondas de Presença · 7 min',
  },
  3: {
    message: 'Que boa energia. Vamos aprofundar isso.',
    suggestion: 'Aproveite este momento de leveza para praticar gratidão.',
    meditation: 'Gratidão · 8 min',
  },
  4: {
    message: 'Você está irradiando. A alma está em sintonia.',
    suggestion: 'Ótimo dia para expandir sua consciência interior.',
    meditation: 'A Luz que Habitas · 9 min',
  },
}

function AppShell() {
  const { user, loading, healthConsent, logout } = useAuth()
  const [showChat, setShowChat] = useState(false)
  const [chatInitialMessage, setChatInitialMessage] = useState<string | undefined>()
  const [page, setPage] = useState<Page>('home')
  const [selectedMood, setSelectedMood] = useState<Mood | null>(null)
  const [onboarded, setOnboarded] = useState<boolean | null>(null)

  // Check if user has completed onboarding
  useEffect(() => {
    if (!user || !db) {
      Promise.resolve().then(() => setOnboarded(true))
      return
    }
    getDoc(doc(db, 'users', user.uid)).then((snap) => {
      setOnboarded(snap.data()?.onboarded === true)
    }).catch(() => setOnboarded(true))
  }, [user])

  const showConsent = user !== null && healthConsent === null

  if (loading || (user && onboarded === null)) {
    return (
      <div className="app-loading" aria-label="Carregando…">
        <div className="app-loading__spinner" />
      </div>
    )
  }

  if (page === 'terms') return <TermsPage onBack={() => setPage('home')} />
  if (page === 'privacy') return <PrivacyPage onBack={() => setPage('home')} />

  if (!user) {
    return <AuthScreen onShowTerms={() => setPage('terms')} onShowPrivacy={() => setPage('privacy')} />
  }

  // New user → onboarding
  if (onboarded === false) {
    return <OnboardingFlow onComplete={() => setOnboarded(true)} />
  }

  const openChat = (initial?: string) => {
    setChatInitialMessage(initial)
    setShowChat(true)
  }

  return (
    <div className="app">
      {showConsent && (
        <ConsentModal onShowTerms={() => setPage('terms')} onShowPrivacy={() => setPage('privacy')} />
      )}

      {showChat ? (
        <ChatScreen onClose={() => setShowChat(false)} initialMessage={chatInitialMessage} />
      ) : (
        <>
          <Navbar onLogout={logout} onOpenChat={openChat} />
          <main className="dashboard">
            <DashboardHeader
              selectedMood={selectedMood}
              onSelectMood={setSelectedMood}
              onOpenChat={openChat}
            />
            <MeditacoesSection selectedMood={selectedMood} />
            <JornadaSection onOpenChat={openChat} />
          </main>
          <Footer onShowTerms={() => setPage('terms')} onShowPrivacy={() => setPage('privacy')} />
        </>
      )}
    </div>
  )
}

function App() {
  if (!firebaseConfigured) {
    return <FirebaseSetupBanner />
  }

  return (
    <ErrorBoundary>
      <AuthProvider>
        <AppShell />
      </AuthProvider>
    </ErrorBoundary>
  )
}

function FirebaseSetupBanner() {
  return (
    <div className="setup-banner">
      <div className="setup-banner__card">
        <div className="setup-banner__icon" aria-hidden="true">🔧</div>
        <h1 className="setup-banner__title">Firebase não configurado</h1>
        <p className="setup-banner__body">
          As variáveis de ambiente do Firebase estão faltando. Para rodar o Alma localmente:
        </p>
        <ol className="setup-banner__steps">
          <li>Copie o arquivo de exemplo: <code>cp .env.example .env.local</code></li>
          <li>Preencha as variáveis <code>VITE_FIREBASE_*</code> com suas credenciais.</li>
          <li>Reinicie o servidor de desenvolvimento: <code>npm run dev</code></li>
        </ol>
        <p className="setup-banner__body">Consulte o <strong>FIREBASE_SETUP.md</strong> para um guia completo.</p>
      </div>
    </div>
  )
}

function Navbar({
  onLogout,
  onOpenChat,
}: {
  onLogout: () => void
  onOpenChat: (initial?: string) => void
}) {
  return (
    <nav className="navbar">
      <div className="container navbar__inner">
        <a href="#" className="navbar__logo">
          <span className="navbar__logo-icon">🌙</span>
          <span>Alma</span>
        </a>

        <div className="navbar__actions">
          <span className="streak-badge">🔥 {STREAK_DAYS} dias</span>
          <button
            className="btn btn--alma btn--sm"
            onClick={() => onOpenChat()}
            aria-label="Conversar com a Alma"
            type="button"
          >
            ✨ Alma AI
          </button>
          <button className="btn btn--ghost btn--sm" onClick={onLogout} type="button">
            Sair
          </button>
        </div>
      </div>
    </nav>
  )
}

function DashboardHeader({
  selectedMood,
  onSelectMood,
  onOpenChat,
}: {
  selectedMood: Mood | null
  onSelectMood: (m: Mood) => void
  onOpenChat: (msg?: string) => void
}) {
  const moodData = selectedMood !== null ? MOOD_AI_RESPONSES[selectedMood] : null

  return (
    <section className="dash-header">
      <div className="dash-header__glow" aria-hidden="true" />
      <div className="container dash-header__inner">
        <div className="dash-header__top">
          <div>
            <p className="dash-header__greeting">Boa tarde</p>
            <h1 className="dash-header__title">
              Como está sua <span className="highlight">alma</span> hoje?
            </h1>
          </div>
          <span className="streak-pill">🔥 {STREAK_DAYS} dias seguidos</span>
        </div>

        {/* Mood check */}
        <div className="mood-check">
          <p className="mood-check__label">Como você está agora?</p>
          <div className="mood-check__options">
            {(MOOD_EMOJIS as string[]).map((emoji, i) => (
              <button
                key={i}
                className={`mood-opt${selectedMood === i ? ' mood-opt--active' : ''}`}
                aria-label={MOOD_LABELS[i]}
                onClick={() => onSelectMood(i as Mood)}
                type="button"
              >
                {emoji}
              </button>
            ))}
          </div>
        </div>

        {/* AI response to mood */}
        {moodData && (
          <div className="alma-response" role="alert">
            <div className="alma-response__avatar">🌙</div>
            <div className="alma-response__body">
              <p className="alma-response__message">"{moodData.message}"</p>
              <p className="alma-response__suggestion">{moodData.suggestion}</p>
              <div className="alma-response__actions">
                <button
                  className="btn btn--primary btn--sm"
                  onClick={() => onOpenChat(`Estou me sentindo ${MOOD_LABELS[selectedMood!].toLowerCase()}. Pode me ajudar?`)}
                  type="button"
                >
                  Conversar com a Alma →
                </button>
                <span className="alma-response__med">🎧 {moodData.meditation}</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}

// Compact meditation list
const meditacoes = [
  { emoji: '🌅', title: 'Manhã Tranquila', duration: '8 min', tag: 'Foco' },
  { emoji: '😴', title: 'Sono Profundo', duration: '15 min', tag: 'Sono' },
  { emoji: '💆', title: 'Alívio de Ansiedade', duration: '10 min', tag: 'Ansiedade' },
  { emoji: '🌿', title: 'Relaxamento Total', duration: '12 min', tag: 'Relaxar' },
  { emoji: '🌊', title: 'Ondas de Presença', duration: '7 min', tag: 'Presença' },
  { emoji: '🌳', title: 'Raízes', duration: '7 min', tag: 'Equilíbrio' },
  { emoji: '🙏', title: 'Gratidão', duration: '8 min', tag: 'Gratidão' },
  { emoji: '✨', title: 'A Luz que Habitas', duration: '9 min', tag: 'Expansão' },
]

function MeditacoesSection({ selectedMood }: { selectedMood: Mood | null }) {
  const recommended = selectedMood !== null ? MOOD_AI_RESPONSES[selectedMood].meditation.split(' · ')[0] : null

  return (
    <section id="meditacoes" className="dash-section">
      <div className="container">
        <div className="dash-section__header">
          <span className="section-tag">🎧 Meditações</span>
          <a href="#" className="section-link">Ver todas →</a>
        </div>

        <div className="med-list">
          {meditacoes.map((m) => (
            <div
              key={m.title}
              className={`med-item${recommended === m.title ? ' med-item--recommended' : ''}`}
            >
              <span className="med-item__emoji">{m.emoji}</span>
              <div className="med-item__info">
                <span className="med-item__title">{m.title}</span>
                {recommended === m.title && (
                  <span className="med-item__rec-badge">✨ recomendada para você</span>
                )}
              </div>
              <span className="med-item__tag">{m.tag}</span>
              <span className="med-item__duration">{m.duration}</span>
              <button className="med-item__play" aria-label={`Iniciar ${m.title}`} type="button">
                ▶
              </button>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

const quickActions = [
  { emoji: '😰', label: 'Estou ansioso', prompt: 'Estou ansioso e preciso de ajuda para acalmar.' },
  { emoji: '😴', label: 'Quero dormir melhor', prompt: 'Tenho dificuldade para dormir. O que posso fazer?' },
  { emoji: '🎯', label: 'Preciso de foco', prompt: 'Preciso melhorar meu foco e concentração.' },
  { emoji: '🫁', label: 'Me guia na respiração', prompt: 'Pode me guiar numa respiração consciente agora?' },
  { emoji: '🪞', label: 'Autoconhecimento', prompt: 'Quero me conhecer melhor. Por onde começo?' },
  { emoji: '💜', label: 'Só quero conversar', prompt: 'Quero apenas conversar e ser ouvido.' },
]

const almaInsights = [
  '🌙 Você medita melhor à noite',
  '💜 Ansiedade foi seu tema mais frequente',
  '🔥 7 dias seguidos — você está em ritmo',
  '🌱 Sua alma está em crescimento',
]

function JornadaSection({ onOpenChat }: { onOpenChat: (msg?: string) => void }) {
  return (
    <section id="jornada" className="dash-section dash-section--dark">
      <div className="container">
        {/* Main AI Card */}
        <div className="jornada-card">
          <div className="jornada-card__text">
            <div className="section-tag section-tag--light" style={{ marginBottom: 16, display: 'inline-flex' }}>
              ✨ Alma AI
            </div>
            <h2 className="jornada-card__title">A Alma está aprendendo quem você é</h2>
            <p className="jornada-card__sub">
              Cada conversa, cada humor registrado e cada meditação concluída ajuda a Alma a
              entender sua jornada interior — e a guiar você com mais precisão.
            </p>
            <button
              className="btn btn--alma btn--lg"
              onClick={() => onOpenChat()}
              type="button"
            >
              Conversar com a Alma →
            </button>
          </div>

          {/* What Alma knows about you */}
          <div className="jornada-insights">
            <p className="jornada-insights__label">O que a Alma percebeu sobre você:</p>
            <ul className="jornada-insights__list">
              {almaInsights.map((insight) => (
                <li key={insight} className="jornada-insights__item">{insight}</li>
              ))}
            </ul>
          </div>
        </div>

        {/* Quick actions */}
        <h3 className="cards-row-title cards-row-title--light" style={{ marginTop: 36 }}>
          Como posso te ajudar agora?
        </h3>
        <div className="quick-actions">
          {quickActions.map((a) => (
            <button
              key={a.label}
              className="quick-action-btn"
              onClick={() => onOpenChat(a.prompt)}
              type="button"
            >
              <span className="quick-action-btn__emoji">{a.emoji}</span>
              <span>{a.label}</span>
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}

function Footer({ onShowTerms, onShowPrivacy }: { onShowTerms: () => void; onShowPrivacy: () => void }) {
  const year = new Date().getFullYear()
  return (
    <footer className="footer">
      <div className="container footer__inner">
        <div className="footer__brand">
          <a href="#" className="navbar__logo">
            <span className="navbar__logo-icon">🌙</span>
            <span>Alma</span>
          </a>
          <p>Cuide da sua alma todos os dias.</p>
        </div>

        <div className="footer__links">
          <div className="footer__col">
            <h4>App</h4>
            <a href="#meditacoes">Meditações</a>
            <a href="#jornada">Alma AI</a>
          </div>
          <div className="footer__col">
            <h4>Suporte</h4>
            <a href="mailto:alma@almaappoficial.com">Contato</a>
            <button type="button" className="footer__link-btn" onClick={onShowPrivacy}>Privacidade</button>
            <button type="button" className="footer__link-btn" onClick={onShowTerms}>Termos de Uso</button>
          </div>
        </div>
      </div>

      <div className="footer__social">
        <a href="https://www.instagram.com/almaappoficial" target="_blank" rel="noopener noreferrer" aria-label="Instagram" className="footer__social-link">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
        </a>
        <a href="https://www.facebook.com/almaappoficial" target="_blank" rel="noopener noreferrer" aria-label="Facebook" className="footer__social-link">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
        </a>
        <a href="https://www.tiktok.com/@almaappoficial" target="_blank" rel="noopener noreferrer" aria-label="TikTok" className="footer__social-link">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1V9.01a6.33 6.33 0 00-.79-.05 6.34 6.34 0 00-6.34 6.34 6.34 6.34 0 006.34 6.34 6.34 6.34 0 006.33-6.34V8.69a8.15 8.15 0 004.77 1.52V6.75a4.85 4.85 0 01-1-.06z"/></svg>
        </a>
      </div>

      <div className="footer__bottom">
        <p>© {year} Alma App. Todos os direitos reservados.</p>
      </div>
    </footer>
  )
}

export default App
