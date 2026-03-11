import { useState } from 'react'
import './App.css'
import { AuthProvider } from './contexts/AuthContext'
import { useAuth } from './contexts/useAuth'
import { AuthScreen } from './components/AuthScreen'
import { ConsentModal } from './components/ConsentModal'
import { ChatScreen } from './components/ChatScreen'
import { TermsPage } from './components/TermsPage'
import { PrivacyPage } from './components/PrivacyPage'
import { firebaseConfigured } from './lib/firebase'

const STREAK_DAYS = 7

type Page = 'home' | 'terms' | 'privacy'

/* ─── Root wrapper ──────────────────────────────────── */
function AppShell() {
  const { user, loading, healthConsent, logout } = useAuth()
  const [showChat, setShowChat] = useState(false)
  const [chatInitialMessage, setChatInitialMessage] = useState<string | undefined>()
  const [page, setPage] = useState<Page>('home')

  // Show consent modal on first login when healthConsent has not been set yet
  const showConsent = user !== null && healthConsent === null

  if (loading) {
    return (
      <div className="app-loading" aria-label="Carregando…">
        <div className="app-loading__spinner" />
      </div>
    )
  }

  // Legal pages are accessible regardless of auth state
  if (page === 'terms') return <TermsPage onBack={() => setPage('home')} />
  if (page === 'privacy') return <PrivacyPage onBack={() => setPage('home')} />

  if (!user) {
    return <AuthScreen onShowTerms={() => setPage('terms')} onShowPrivacy={() => setPage('privacy')} />
  }

  const openChat = (initial?: string) => {
    setChatInitialMessage(initial)
    setShowChat(true)
  }

  return (
    <div className="app">
      {showConsent && (
        <ConsentModal
          onShowTerms={() => setPage('terms')}
          onShowPrivacy={() => setPage('privacy')}
        />
      )}

      {showChat ? (
        <ChatScreen onClose={() => setShowChat(false)} initialMessage={chatInitialMessage} />
      ) : (
        <>
          <Navbar onLogout={logout} onOpenChat={openChat} />
          <main className="dashboard">
            <DashboardHeader />
            <MeditacoesSection />
            <AlmaAISection onOpenChat={openChat} />
            <SaudeSection />
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
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  )
}

/* ─── Firebase Setup Banner (dev only) ──────────────── */
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
        <p className="setup-banner__body">
          Consulte o <strong>FIREBASE_SETUP.md</strong> para um guia completo.
        </p>
      </div>
    </div>
  )
}

/* ─── Navbar ─────────────────────────────────────────────── */
function Navbar({ onLogout, onOpenChat }: { onLogout: () => void; onOpenChat: () => void }) {
  return (
    <nav className="navbar">
      <div className="container navbar__inner">
        <a href="#" className="navbar__logo">
          <svg width="32" height="32" viewBox="0 0 64 64" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="almaGradientNav" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#6B46C1" />
                <stop offset="100%" stopColor="#9F7AEA" />
              </linearGradient>
            </defs>
            <circle cx="32" cy="32" r="30.5" fill="url(#almaGradientNav)" stroke="#4B2C88" strokeWidth="3" />
            <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
            <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
            <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
          </svg>
          <span>Alma</span>
        </a>

        <ul className="navbar__links">
          <li><a href="#meditacoes">Meditações</a></li>
          <li><a href="#alma-ai">Alma AI</a></li>
          <li><a href="#saude">Saúde</a></li>
        </ul>

        <div className="navbar__actions">
          <span className="streak-badge">🔥 {STREAK_DAYS} dias</span>
          <button className="btn btn--ghost btn--sm" onClick={onOpenChat} aria-label="Abrir chat">💬 Chat</button>
          <button className="btn btn--primary btn--sm" onClick={onLogout}>Sair</button>
        </div>
      </div>
    </nav>
  )
}

/* ─── Dashboard Header ───────────────────────────────────── */
function DashboardHeader() {
  return (
    <section className="dash-header">
      <div className="dash-header__bg" aria-hidden="true">
        <span className="dash-circle dash-circle--1" />
        <span className="dash-circle dash-circle--2" />
      </div>
      <div className="container dash-header__inner">
        <div className="dash-header__top">
          <div>
            <p className="dash-header__greeting">Bom dia 🌅</p>
            <h1 className="dash-header__title">
              Como está sua <span className="highlight">alma</span> hoje?
            </h1>
          </div>
          <span className="streak-pill">🔥 {STREAK_DAYS} dias seguidos</span>
        </div>
        <div className="mood-check">
          <p className="mood-check__label">Como você está agora?</p>
          <div className="mood-check__options">
            {(['😔', '😐', '🙂', '😊', '😄'] as const).map((emoji, i) => {
              const labels = ['Muito triste', 'Neutro', 'Bem', 'Feliz', 'Muito feliz']
              return (
                <button key={i} className={`mood-opt${i === 2 ? ' mood-opt--active' : ''}`} aria-label={labels[i]}>
                  {emoji}
                </button>
              )
            })}
          </div>
        </div>
      </div>
    </section>
  )
}

/* ─── Meditações Section ─────────────────────────────────── */
const meditacoesRecomendadas = [
  { emoji: '🌅', title: 'Manhã Tranquila', duration: '8 min', tag: 'Foco', color: '#553C9A' },
  { emoji: '😴', title: 'Sono Profundo', duration: '15 min', tag: 'Sono', color: '#2D3748' },
  { emoji: '💆', title: 'Alívio de Ansiedade', duration: '10 min', tag: 'Ansiedade', color: '#6B46C1' },
  { emoji: '🌿', title: 'Relaxamento Total', duration: '12 min', tag: 'Relaxar', color: '#276749' },
]

const categorias = ['Ansiedade', 'Sono', 'Foco', 'Relaxar', 'Autoestima', 'Respiração', 'Gratidão']

function MeditacoesSection() {
  return (
    <section id="meditacoes" className="dash-section">
      <div className="container">
        <div className="dash-section__header">
          <span className="section-tag">🧘 Meditações</span>
          <a href="#" className="section-link">Ver todas →</a>
        </div>

        <div className="continuar-card">
          <div className="continuar-card__content">
            <span className="continuar-card__badge">Em andamento</span>
            <h2 className="continuar-card__title">Meditação Matinal</h2>
            <p className="continuar-card__meta">10 minutos · Iniciante · Série 3 de 7</p>
            {(() => {
              const progress = 40
              return (
                <div className="progress-row">
                  <div className="progress-bar">
                    <div className="progress-bar__fill" style={{ width: `${progress}%` }} />
                  </div>
                  <span className="progress-bar__label">{progress}%</span>
                </div>
              )
            })()}
            <button className="btn btn--white btn--lg">▶ Continuar</button>
          </div>
          <div className="continuar-card__emoji" aria-hidden="true">🧘‍♀️</div>
        </div>

        <h3 className="cards-row-title">Recomendadas para você</h3>
        <div className="cards-row">
          {meditacoesRecomendadas.map((m) => (
            <div
              key={m.title}
              className="med-card"
              style={{ '--card-color': m.color } as React.CSSProperties}
            >
              <span className="med-card__emoji">{m.emoji}</span>
              <span className="med-card__tag">{m.tag}</span>
              <p className="med-card__title">{m.title}</p>
              <p className="med-card__duration">{m.duration}</p>
              <button className="med-card__btn" aria-label={`Iniciar ${m.title}`}>▶</button>
            </div>
          ))}
        </div>

        <h3 className="cards-row-title">Categorias</h3>
        <div className="categorias-row">
          {categorias.map((cat) => (
            <button key={cat} className="categoria-pill">{cat}</button>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── Alma AI Section ────────────────────────────────────── */
const quickActions = [
  { emoji: '😰', label: 'Estou ansioso' },
  { emoji: '😴', label: 'Quero dormir melhor' },
  { emoji: '🎯', label: 'Preciso de foco' },
  { emoji: '🫁', label: 'Guia de respiração' },
]

function AlmaAISection({ onOpenChat }: { onOpenChat: (msg?: string) => void }) {
  return (
    <section id="alma-ai" className="dash-section dash-section--dark">
      <div className="container">
        <div className="dash-section__header">
          <span className="section-tag section-tag--light">✨ Alma AI</span>
        </div>

        <div className="ai-card">
          <div className="ai-card__icon" aria-hidden="true">
            <svg width="56" height="56" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <linearGradient id="aiIconGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#6B46C1" />
                  <stop offset="100%" stopColor="#9F7AEA" />
                </linearGradient>
              </defs>
              <circle cx="32" cy="32" r="30" fill="url(#aiIconGrad)" opacity="0.2" />
              <circle cx="32" cy="32" r="30" fill="none" stroke="#9F7AEA" strokeWidth="2" />
              <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="white" opacity="0.9" />
              <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="white" opacity="0.85" />
              <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#9F7AEA" opacity="0.6" />
            </svg>
          </div>
          <div className="ai-card__content">
            <h2 className="ai-card__title">Falar com a Alma</h2>
            <p className="ai-card__sub">
              Sua assistente de bem-estar. Conversa em português, sem julgamentos, disponível 24h.
            </p>
            <button className="btn btn--primary btn--lg" onClick={() => onOpenChat()}>
              Iniciar conversa →
            </button>
          </div>
        </div>

        <h3 className="cards-row-title cards-row-title--light">Como posso te ajudar agora?</h3>
        <div className="quick-actions">
          {quickActions.map((a) => (
            <button key={a.label} className="quick-action-btn" onClick={() => onOpenChat(a.label)}>
              <span className="quick-action-btn__emoji">{a.emoji}</span>
              <span>{a.label}</span>
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── Saúde Section ──────────────────────────────────────── */
const healthSources = [
  { icon: '🍎', name: 'Apple Health', available: true },
  { icon: '⌚', name: 'Garmin', available: true },
  { icon: '💪', name: 'Fitbit', available: false },
]

const insightCards = [
  {
    icon: '😴',
    title: 'Qualidade do Sono',
    value: '—',
    desc: 'Conecte uma fonte de dados para ver seus insights de sono.',
    placeholder: true,
  },
  {
    icon: '🧠',
    title: 'Nível de Estresse',
    value: '—',
    desc: 'Conecte uma fonte de dados para acompanhar seu estresse.',
    placeholder: true,
  },
  {
    icon: '🫁',
    title: 'Respiração 4-7-8',
    value: '4 min',
    desc: 'Técnica para reduzir ansiedade agora mesmo.',
    placeholder: false,
  },
]

function SaudeSection() {
  return (
    <section id="saude" className="dash-section">
      <div className="container">
        <div className="dash-section__header">
          <span className="section-tag">❤️ Saúde &amp; Bem-estar</span>
        </div>

        <div className="connect-card">
          <div className="connect-card__icon" aria-hidden="true">📊</div>
          <div className="connect-card__content">
            <h2 className="connect-card__title">Conectar dados de saúde</h2>
            <p className="connect-card__sub">
              Quer que a Alma use seus dados para insights personalizados de sono, estresse e bem-estar?
            </p>
            <div className="health-sources">
              {healthSources.map((src) => (
                <button
                  key={src.name}
                  className={`health-source-btn${!src.available ? ' health-source-btn--soon' : ''}`}
                  disabled={!src.available}
                >
                  <span>{src.icon}</span>
                  <span>{src.name}</span>
                  {!src.available && <span className="soon-badge">Em breve</span>}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="insights-grid">
          {insightCards.map((card) => (
            <div
              key={card.title}
              className={`insight-card${card.placeholder ? ' insight-card--placeholder' : ''}`}
            >
              <div className="insight-card__icon">{card.icon}</div>
              <h3 className="insight-card__title">{card.title}</h3>
              <p className={`insight-card__value${card.placeholder ? ' insight-card__value--empty' : ''}`}>
                {card.value}
              </p>
              <p className="insight-card__desc">{card.desc}</p>
              {!card.placeholder && (
                <button className="btn btn--primary btn--sm insight-card__cta">
                  Iniciar
                </button>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── Footer ─────────────────────────────────────────────── */
function Footer({ onShowTerms, onShowPrivacy }: { onShowTerms: () => void; onShowPrivacy: () => void }) {
  const year = new Date().getFullYear()
  return (
    <footer className="footer">
      <div className="container footer__inner">
        <div className="footer__brand">
          <a href="#" className="navbar__logo">
            <svg width="28" height="28" viewBox="0 0 64 64" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <linearGradient id="almaGradientFooter" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#6B46C1" />
                  <stop offset="100%" stopColor="#9F7AEA" />
                </linearGradient>
              </defs>
              <circle cx="32" cy="32" r="30.5" fill="url(#almaGradientFooter)" stroke="#4B2C88" strokeWidth="3" />
              <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
              <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
              <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
            </svg>
            <span>Alma</span>
          </a>
          <p>Cuide da sua alma todos os dias.</p>
        </div>

        <div className="footer__links">
          <div className="footer__col">
            <h4>App</h4>
            <a href="#meditacoes">Meditações</a>
            <a href="#alma-ai">Alma AI</a>
            <a href="#saude">Saúde &amp; Bem-estar</a>
          </div>
          <div className="footer__col">
            <h4>Empresa</h4>
            <a href="#">Sobre nós</a>
            <a href="#">Blog</a>
            <a href="#">Carreiras</a>
          </div>
          <div className="footer__col">
            <h4>Suporte</h4>
            <a href="#">Central de Ajuda</a>
            <a href="mailto:alma@almaappoficial.com">Contato</a>
            <button type="button" className="footer__link-btn" onClick={onShowPrivacy}>Privacidade</button>
            <button type="button" className="footer__link-btn" onClick={onShowTerms}>Termos de Uso</button>
          </div>
        </div>
      </div>
      <div className="footer__bottom">
        <p>© {year} Alma App. Todos os direitos reservados. Feito com 💜 no Brasil.</p>
      </div>
    </footer>
  )
}

export default App
