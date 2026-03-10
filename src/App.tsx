import { useState } from 'react'
import './App.css'
import ChatPage from './components/ChatPage'

function App() {
  const [showChat, setShowChat] = useState(false)

  if (showChat) {
    return <ChatPage onBack={() => setShowChat(false)} />
  }

  return (
    <div className="app">
      <Navbar onOpenChat={() => setShowChat(true)} />
      <main>
        <Hero onOpenChat={() => setShowChat(true)} />
        <Stats />
        <Features />
        <HowItWorks />
        <Testimonials />
        <DownloadCTA onOpenChat={() => setShowChat(true)} />
      </main>
      <Footer />
    </div>
  )
}

/* ─── Navbar ─────────────────────────────────────────────── */
function Navbar({ onOpenChat }: { onOpenChat: () => void }) {
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
          <li><a href="#funcionalidades">Funcionalidades</a></li>
          <li><a href="#como-funciona">Como Funciona</a></li>
          <li><a href="#depoimentos">Depoimentos</a></li>
        </ul>

        <button className="btn btn--primary btn--sm" onClick={onOpenChat}>
          Conversar com Alma
        </button>
      </div>
    </nav>
  )
}

/* ─── Hero ───────────────────────────────────────────────── */
function Hero({ onOpenChat }: { onOpenChat: () => void }) {
  return (
    <section className="hero">
      <div className="hero__bg-circles" aria-hidden="true">
        <span className="circle circle--1" />
        <span className="circle circle--2" />
        <span className="circle circle--3" />
      </div>
      <div className="container hero__inner">
        <div className="hero__text">
          <span className="badge">✨ Novo — Versão 2.0 disponível</span>
          <h1 className="hero__title">
            Cuide da sua <span className="highlight">Alma</span> todos os dias
          </h1>
          <p className="hero__subtitle">
            Meditações guiadas, exercícios de respiração e acompanhamento do
            bem-estar emocional — tudo em um só lugar, na palma da sua mão.
          </p>
          <div className="hero__actions">
            <button className="btn btn--primary btn--lg" onClick={onOpenChat}>
              💜 Conversar com Alma
            </button>
            <a href="#como-funciona" className="btn btn--ghost btn--lg">
              ▶ Ver como funciona
            </a>
          </div>
          <p className="hero__note">Grátis para sempre no plano básico · Sem cartão de crédito</p>
        </div>

        <div className="hero__visual" aria-hidden="true">
          <div className="phone-mockup">
            <div className="phone-mockup__screen">
              <div className="mock-ui">
                <div className="mock-ui__header">
                  <span className="mock-ui__greeting">Bom dia, Maria 🌅</span>
                  <span className="mock-ui__streak">🔥 7 dias</span>
                </div>
                <div className="mock-ui__card">
                  <div className="mock-ui__card-icon">🧘</div>
                  <p className="mock-ui__card-title">Meditação Matinal</p>
                  <p className="mock-ui__card-sub">10 minutos · Iniciante</p>
                  <button className="mock-ui__play">▶ Iniciar</button>
                </div>
                <div className="mock-ui__mood-row">
                  <span>Como você está?</span>
                  <div className="mock-ui__moods">
                    {'😔 😐 🙂 😊 😄'.split(' ').map((e, i) => (
                      <button key={i} className={`mood-btn${i === 3 ? ' mood-btn--active' : ''}`}>{e}</button>
                    ))}
                  </div>
                </div>
                <div className="mock-ui__progress">
                  <span>Progresso semanal</span>
                  <div className="mock-ui__bars">
                    {[60, 80, 40, 90, 70, 85, 50].map((h, i) => (
                      <div key={i} className="bar-col">
                        <div className="bar" style={{ height: `${h}%` }} />
                      </div>
                    ))}
                  </div>
                  <div className="mock-ui__days">
                    {'S T Q Q S S D'.split(' ').map((d, i) => (
                      <span key={i}>{d}</span>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ─── Stats ──────────────────────────────────────────────── */
const statsData = [
  { value: '500K+', label: 'Usuários Ativos' },
  { value: '4.9★', label: 'Avaliação nas Lojas' },
  { value: '200+', label: 'Meditações Guiadas' },
  { value: '98%', label: 'Taxa de Satisfação' },
]

function Stats() {
  return (
    <section className="stats">
      <div className="container stats__grid">
        {statsData.map((s) => (
          <div key={s.label} className="stat-card">
            <span className="stat-card__value">{s.value}</span>
            <span className="stat-card__label">{s.label}</span>
          </div>
        ))}
      </div>
    </section>
  )
}

/* ─── Features ───────────────────────────────────────────── */
const featuresData = [
  {
    icon: '🧘',
    title: 'Meditações Guiadas',
    desc: 'Mais de 200 meditações para todos os níveis, do iniciante ao avançado.',
  },
  {
    icon: '🌬️',
    title: 'Exercícios de Respiração',
    desc: 'Técnicas de respiração comprovadas para reduzir ansiedade em minutos.',
  },
  {
    icon: '📊',
    title: 'Rastreio de Humor',
    desc: 'Registre e acompanhe seu bem-estar emocional ao longo do tempo.',
  },
  {
    icon: '😴',
    title: 'Sons para Dormir',
    desc: 'Sons da natureza e músicas relaxantes para melhorar a qualidade do sono.',
  },
  {
    icon: '📓',
    title: 'Diário de Gratidão',
    desc: 'Pratique a gratidão diariamente e transforme sua perspectiva de vida.',
  },
  {
    icon: '🔔',
    title: 'Lembretes Inteligentes',
    desc: 'Notificações personalizadas para manter sua prática de forma consistente.',
  },
]

function Features() {
  return (
    <section id="funcionalidades" className="section">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">Funcionalidades</span>
          <h2 className="section-title">Tudo que você precisa para<br />cuidar da sua saúde mental</h2>
          <p className="section-sub">
            Ferramentas simples e eficazes, respaldadas pela ciência, para te ajudar a se sentir melhor todos os dias.
          </p>
        </div>
        <div className="features-grid">
          {featuresData.map((f) => (
            <div key={f.title} className="feature-card">
              <span className="feature-card__icon">{f.icon}</span>
              <h3 className="feature-card__title">{f.title}</h3>
              <p className="feature-card__desc">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── How It Works ───────────────────────────────────────── */
const stepsData = [
  {
    num: '01',
    title: 'Baixe o Aplicativo',
    desc: 'Disponível gratuitamente para iOS e Android. Crie sua conta em menos de 30 segundos.',
  },
  {
    num: '02',
    title: 'Personalize sua Experiência',
    desc: 'Diga-nos seus objetivos — menos ansiedade, melhor sono ou mais foco — e montamos sua jornada.',
  },
  {
    num: '03',
    title: 'Pratique Todo Dia',
    desc: 'Apenas 10 minutos por dia podem transformar a sua saúde mental. Acompanhe seu progresso em tempo real.',
  },
]

function HowItWorks() {
  return (
    <section id="como-funciona" className="section section--alt">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">Como Funciona</span>
          <h2 className="section-title">Comece em 3 passos simples</h2>
          <p className="section-sub">Sem complicação. Sem compromisso. Só bem-estar.</p>
        </div>
        <div className="steps">
          {stepsData.map((s) => (
            <div key={s.num} className="step">
              <span className="step__num">{s.num}</span>
              <div>
                <h3 className="step__title">{s.title}</h3>
                <p className="step__desc">{s.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── Testimonials ───────────────────────────────────────── */
const testimonialsData = [
  {
    name: 'Ana Paula S.',
    role: 'Professora · São Paulo',
    avatar: '👩‍🏫',
    text: 'O Alma mudou completamente a minha rotina. Em 3 semanas já sentia menos ansiedade e dormia muito melhor. Recomendo para todos!',
  },
  {
    name: 'Carlos M.',
    role: 'Desenvolvedor · Curitiba',
    avatar: '👨‍💻',
    text: 'Nunca achei que 10 minutos de meditação fariam tanta diferença. Hoje é a primeira coisa que faço ao acordar. App incrível!',
  },
  {
    name: 'Juliana R.',
    role: 'Médica · Rio de Janeiro',
    avatar: '👩‍⚕️',
    text: 'Como profissional de saúde, recomendo o Alma para os meus pacientes. É baseado em evidências e fácil de usar. Nota 10!',
  },
]

function Testimonials() {
  return (
    <section id="depoimentos" className="section">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">Depoimentos</span>
          <h2 className="section-title">O que nossos usuários dizem</h2>
          <p className="section-sub">Mais de 500 mil pessoas já transformaram suas vidas com o Alma.</p>
        </div>
        <div className="testimonials-grid">
          {testimonialsData.map((t) => (
            <div key={t.name} className="testimonial-card">
              <p className="testimonial-card__text">"{t.text}"</p>
              <div className="testimonial-card__author">
                <span className="testimonial-card__avatar">{t.avatar}</span>
                <div>
                  <strong>{t.name}</strong>
                  <span>{t.role}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

/* ─── Download CTA ───────────────────────────────────────── */
function DownloadCTA({ onOpenChat }: { onOpenChat: () => void }) {
  return (
    <section id="download" className="section cta-section">
      <div className="cta-bg" aria-hidden="true">
        <span className="cta-circle cta-circle--1" />
        <span className="cta-circle cta-circle--2" />
      </div>
      <div className="container cta-inner">
        <h2 className="cta-title">Comece sua jornada de bem-estar hoje</h2>
        <p className="cta-sub">
          Gratuito para sempre no plano básico. Sem cartão de crédito necessário.
        </p>
        <div className="store-buttons">
          <button className="store-btn" onClick={onOpenChat}>
            <span style={{ fontSize: '1.5rem' }}>💜</span>
            <div>
              <small>Experimente agora</small>
              <strong>Conversar com Alma</strong>
            </div>
          </button>
          <a href="#" className="store-btn" aria-label="Baixar na App Store">
            <svg viewBox="0 0 24 24" width="24" fill="currentColor" aria-hidden="true">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98l-.09.06c-.22.14-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.77M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            <div>
              <small>Disponível na</small>
              <strong>App Store</strong>
            </div>
          </a>
          <a href="#" className="store-btn" aria-label="Baixar no Google Play">
            <svg viewBox="0 0 24 24" width="24" fill="currentColor" aria-hidden="true">
              <path d="M3 20.5v-17c0-.83 1-.83 1.5-.5l15 8.5c.5.28.5 1-.0 1.28l-15 8.5C3.5 21.5 3 21.5 3 20.5M5 6.5v11l9.3-5.5L5 6.5z"/>
            </svg>
            <div>
              <small>Disponível no</small>
              <strong>Google Play</strong>
            </div>
          </a>
        </div>
        <p className="cta-note">🔒 Seus dados são privados e protegidos · LGPD compliant</p>
      </div>
    </section>
  )
}

/* ─── Footer ─────────────────────────────────────────────── */
function Footer() {
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
            <h4>Produto</h4>
            <a href="#funcionalidades">Funcionalidades</a>
            <a href="#como-funciona">Como Funciona</a>
            <a href="#download">Download</a>
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
            <a href="#">Contato</a>
            <a href="#">Privacidade</a>
            <a href="#">Termos de Uso</a>
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
