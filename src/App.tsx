import './App.css'

function App() {
  return (
    <div className="app">
      <Navbar />
      <main>
        <Hero />
        <Stats />
        <Features />
        <HowItWorks />
        <Testimonials />
        <DownloadCTA />
      </main>
      <Footer />
    </div>
  )
}

/* ─── Navbar ─────────────────────────────────────────────── */
function Navbar() {
  return (
    <nav className="navbar">
      <div className="container navbar__inner">
        <a href="#" className="navbar__logo">
          <svg width="32" height="32" viewBox="0 0 64 64" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <circle cx="32" cy="32" r="30.5" fill="#c9a862" stroke="#0e0f12" strokeWidth="3" />
            <circle cx="32" cy="32" r="23" fill="#d8bd7a" opacity="0.16" />
            <path d="M32 17.75c1.35 0.66 2.5 2.14 2.5 3.85-1.62-1.08-3.42-1.64-5.3-1.68 0.6-1.62 1.7-2.63 2.8-3.17z" fill="#0e0f12" />
            <path d="M24.5 24.5c1.4-3.2 5-5.6 8.9-5.6 5.8 0 10.6 4.5 10.6 10.4S39 39.5 32.7 39.5c-3.3 0-6.2-1.6-7.8-4" fill="none" stroke="#0e0f12" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M27.4 27.8c1.4-2.6 4.3-4.4 7.6-4.4 4.8 0 8.6 3.7 8.6 8.3 0 4.5-3.9 8-8.8 8-2.8 0-5.1-1.3-6.3-3.4" fill="none" stroke="#0e0f12" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M30.8 30.8c0.95-1.08 2.3-1.76 3.8-1.76 2.5 0 4.6 1.9 4.6 4.2 0 2.3-1.9 4.1-4.3 4.1-1.9 0-3.5-1.1-3.5-2.7 0-1.2 1-2.1 2.2-2.1 1.1 0 1.9 0.8 1.9 1.8 0 0.9-0.6 1.6-1.5 1.8" fill="none" stroke="#0e0f12" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M18.5 28.5v14.8c0 .92.56 1.74 1.43 2.08l9.9 3.8c.7.27 1.46.27 2.16 0l9.9-3.8c.87-.34 1.43-1.16 1.43-2.08V28.5" fill="none" stroke="#0e0f12" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
            <path d="M18.5 39.2c4-3.1 8.8-4.7 13.9-4.7s9.9 1.6 13.9 4.7" fill="none" stroke="#0e0f12" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span>Alma</span>
        </a>

        <ul className="navbar__links">
          <li><a href="#funcionalidades">Funcionalidades</a></li>
          <li><a href="#como-funciona">Como Funciona</a></li>
          <li><a href="#depoimentos">Depoimentos</a></li>
        </ul>

        <a href="#download" className="btn btn--primary btn--sm">
          Baixar Grátis
        </a>
      </div>
    </nav>
  )
}

/* ─── Hero ───────────────────────────────────────────────── */
function Hero() {
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
            <a href="#download" className="btn btn--primary btn--lg">
              📱 Baixar Gratuitamente
            </a>
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
function DownloadCTA() {
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
              <circle cx="32" cy="32" r="30.5" fill="#c9a862" stroke="#0e0f12" strokeWidth="3" />
              <circle cx="32" cy="32" r="23" fill="#d8bd7a" opacity="0.16" />
              <path d="M32 17.75c1.35 0.66 2.5 2.14 2.5 3.85-1.62-1.08-3.42-1.64-5.3-1.68 0.6-1.62 1.7-2.63 2.8-3.17z" fill="#0e0f12" />
              <path d="M24.5 24.5c1.4-3.2 5-5.6 8.9-5.6 5.8 0 10.6 4.5 10.6 10.4S39 39.5 32.7 39.5c-3.3 0-6.2-1.6-7.8-4" fill="none" stroke="#0e0f12" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M27.4 27.8c1.4-2.6 4.3-4.4 7.6-4.4 4.8 0 8.6 3.7 8.6 8.3 0 4.5-3.9 8-8.8 8-2.8 0-5.1-1.3-6.3-3.4" fill="none" stroke="#0e0f12" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M30.8 30.8c0.95-1.08 2.3-1.76 3.8-1.76 2.5 0 4.6 1.9 4.6 4.2 0 2.3-1.9 4.1-4.3 4.1-1.9 0-3.5-1.1-3.5-2.7 0-1.2 1-2.1 2.2-2.1 1.1 0 1.9 0.8 1.9 1.8 0 0.9-0.6 1.6-1.5 1.8" fill="none" stroke="#0e0f12" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M18.5 28.5v14.8c0 .92.56 1.74 1.43 2.08l9.9 3.8c.7.27 1.46.27 2.16 0l9.9-3.8c.87-.34 1.43-1.16 1.43-2.08V28.5" fill="none" stroke="#0e0f12" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
              <path d="M18.5 39.2c4-3.1 8.8-4.7 13.9-4.7s9.9 1.6 13.9 4.7" fill="none" stroke="#0e0f12" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
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
