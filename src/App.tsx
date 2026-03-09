import { useEffect, useMemo, useState } from 'react'
import './App.css'

function App() {
  return (
    <div className="app">
      <Navbar />
      <main>
        <Hero />
        <InteractiveDemo />
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
          <img src="/alma-icon.svg" alt="Alma" width={32} height={32} />
          <span>Alma</span>
        </a>

        <ul className="navbar__links">
          <li><a href="#demo">Demo interativo</a></li>
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
            <a href="#demo" className="btn btn--ghost btn--lg">
              ▶ Testar agora
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

/* ─── Interactive Demo ───────────────────────────────────── */
type ChatMessage = { role: 'user' | 'assistant'; content: string }
const MAX_MEDITATION_SECONDS = 10 * 60
const PLACEHOLDER_KEYS = ['SEU_TOKEN', 'YOUR_API_KEY']
const formatTime = (seconds: number) => {
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

function InteractiveDemo() {
  const moods = useMemo(() => ['😔', '😐', '🙂', '😊', '😄'], [])
  const breathSequence = useMemo(
    () => [
      { label: 'Inspire', seconds: 4 },
      { label: 'Segure', seconds: 7 },
      { label: 'Expire', seconds: 8 },
    ],
    [],
  )

  const [selectedMood, setSelectedMood] = useState(moods[3])
  const [moodHistory, setMoodHistory] = useState<string[]>([moods[3]])
  const [isMeditating, setIsMeditating] = useState(false)
  const [meditationSeconds, setMeditationSeconds] = useState(0)

  const [isBreathing, setIsBreathing] = useState(true)
  const [breathStepIndex, setBreathStepIndex] = useState(0)
  const [breathRemaining, setBreathRemaining] = useState(breathSequence[0].seconds)

  const [aiMessages, setAiMessages] = useState<ChatMessage[]>([
    { role: 'assistant', content: 'Oi! Sou sua coach com IA. Pergunte sobre rotina, ansiedade ou sono que eu ajudo.' },
  ])
  const [aiInput, setAiInput] = useState('')
  const [aiLoading, setAiLoading] = useState(false)

  // ⚠️ VITE_* fica visível no bundle (visible in client bundle); use proxy/backend para chaves sensíveis.
  const aiEndpoint = import.meta.env.VITE_AI_ENDPOINT
  const aiKey = import.meta.env.VITE_AI_KEY
  const hasRealKey = Boolean(aiKey && !PLACEHOLDER_KEYS.includes(aiKey.trim().toUpperCase()))
  const aiEnabled = Boolean(aiEndpoint && hasRealKey)

  useEffect(() => {
    if (!isMeditating) return
    const id = setInterval(() => {
      setMeditationSeconds((prev) => Math.min(prev + 1, MAX_MEDITATION_SECONDS))
    }, 1000)
    return () => clearInterval(id)
  }, [isMeditating])

  useEffect(() => {
    if (!isBreathing) return
    const id = setInterval(() => {
      setBreathRemaining((prev) => {
        if (prev > 1) return prev - 1
        setBreathStepIndex((idx) => {
          const next = (idx + 1) % breathSequence.length
          setBreathRemaining(breathSequence[next].seconds)
          return next
        })
        return prev
      })
    }, 1000)
    return () => clearInterval(id)
  }, [isBreathing, breathSequence])

  const handleMood = (mood: string) => {
    setSelectedMood(mood)
    setMoodHistory((prev) => [...prev.slice(-5), mood])
  }

  const toggleMeditation = () => {
    setIsMeditating((v) => !v)
    if (isMeditating) {
      setMeditationSeconds(0)
    }
  }

  const sendAiMessage = async () => {
    if (!aiInput.trim()) return
    const userMessage: ChatMessage = { role: 'user', content: aiInput.trim() }
    setAiMessages((prev) => [...prev, userMessage])
    setAiInput('')
    setAiLoading(true)

    const finishWith = (text: string) => {
      setAiMessages((prev) => [...prev, { role: 'assistant', content: text }])
      setAiLoading(false)
    }

    const moodHint =
      selectedMood === '😔'
        ? 'Percebi que você marcou um humor mais baixo. Que tal tentar a respiração 4-7-8 agora?'
        : selectedMood === '😐' || selectedMood === '🙂'
          ? 'Bora manter a consistência? Uma sessão curta de meditação guiada já ajuda.'
          : 'Ótima energia! Registre seu humor e faça uma meditação curta para manter o ritmo.'

    try {
      if (aiEnabled) {
        const response = await fetch(aiEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${aiKey}`,
          },
          body: JSON.stringify({
            message: userMessage.content,
            mood: selectedMood,
            context: 'Alma app preview',
          }),
        })

        if (!response.ok) {
          throw new Error(`Erro ${response.status}`)
        }

        const data = await response.json()
        const reply = data.reply || data.message || JSON.stringify(data)
        return finishWith(reply)
      }
    } catch (error) {
      console.error(error)
    }

    finishWith(`(Modo demonstração) ${moodHint}`)
  }

  const meditationLabel = isMeditating ? 'Encerrar sessão' : 'Iniciar sessão'
  const meditationProgress = Math.min(meditationSeconds / MAX_MEDITATION_SECONDS, 1)
  const breathStep = breathSequence[breathStepIndex]
  const formattedTime = formatTime(meditationSeconds).split(':')
  const maxMeditationMinutes = Math.round(MAX_MEDITATION_SECONDS / 60)

  return (
    <section id="demo" className="section section--alt">
      <div className="container">
        <div className="section-header">
          <span className="section-tag">Teste agora</span>
          <h2 className="section-title">Demo interativa sem publicar na loja</h2>
          <p className="section-sub">
            Experimente as principais rotinas (meditação, respiração, humor e IA) direto no navegador.
            Ideal para QA antes de enviar para App Store/Play Store.
          </p>
        </div>

        <div className="demo-grid">
          <div className="demo-card">
            <div className="demo-card__header">
              <div>
                <h3>Meditação guiada</h3>
                <p>Timer de foco + progresso semanal</p>
              </div>
              <span className="pill pill--primary">{isMeditating ? 'Ao vivo' : 'Pronto'}</span>
            </div>
            <div className="demo-meditation">
            <div className="demo-meditation__timer">
              <span>{formattedTime[0]}</span>
              <span>:</span>
              <span>{formattedTime[1]}</span>
            </div>
              <div className="progress">
                <div className="progress__bar" style={{ width: `${meditationProgress * 100}%` }} />
              </div>
              <div className="demo-meditation__actions">
                <button className="btn btn--primary btn--lg" onClick={toggleMeditation}>
                  {meditationLabel}
                </button>
                <button className="btn btn--ghost btn--lg" onClick={() => setMeditationSeconds(0)}>
                  Resetar
                </button>
              </div>
              <p className="demo-helper">
                Dica: deixe rodando 1–2 min para ver o progresso inicial (o timer vai até {maxMeditationMinutes} min).
              </p>
            </div>
          </div>

          <div className="demo-card">
            <div className="demo-card__header">
              <div>
                <h3>Respiração 4-7-8</h3>
                <p>Loop automático para reduzir ansiedade</p>
              </div>
              <span className="pill pill--outline">{isBreathing ? 'Rodando' : 'Pausado'}</span>
            </div>
            <div className="demo-breath">
              <div className="demo-breath__step">
                <strong>{breathStep.label}</strong>
                <span>{breathRemaining}s</span>
              </div>
              <div className="progress progress--segments">
                {breathSequence.map((step, idx) => (
                  <div
                    key={step.label}
                    className={`progress__segment${idx === breathStepIndex ? ' progress__segment--active' : ''}`}
                    style={{ width: `${(step.seconds / breathSequence.reduce((t, s) => t + s.seconds, 0)) * 100}%` }}
                  />
                ))}
              </div>
              <div className="demo-actions">
                <button className="btn btn--primary btn--sm" onClick={() => setIsBreathing((v) => !v)}>
                  {isBreathing ? 'Pausar' : 'Retomar'}
                </button>
                <button
                  className="btn btn--ghost btn--sm"
                  onClick={() => {
                    setBreathStepIndex(0)
                    setBreathRemaining(breathSequence[0].seconds)
                    setIsBreathing(true)
                  }}
                >
                  Reiniciar
                </button>
              </div>
            </div>
          </div>

          <div className="demo-card">
            <div className="demo-card__header">
              <div>
                <h3>Humor e consistência</h3>
                <p>Registre e veja as últimas entradas</p>
              </div>
              <span className="pill pill--neutral">{moodHistory.length} logs</span>
            </div>
            <div className="demo-mood">
              <div className="demo-mood__buttons">
                {moods.map((mood) => (
                  <button
                    key={mood}
                    className={`mood-chip${mood === selectedMood ? ' mood-chip--active' : ''}`}
                    onClick={() => handleMood(mood)}
                  >
                    {mood}
                  </button>
                ))}
              </div>
              <div className="demo-mood__history">
                {moodHistory.slice(-6).map((m, idx) => (
                  <span key={`${m}-${idx}`} className="pill pill--tiny">
                    {m}
                  </span>
                ))}
              </div>
              <p className="demo-helper">Para testar, selecione humores diferentes e veja o histórico atualizar.</p>
            </div>
          </div>

          <div className="demo-card demo-card--ai">
            <div className="demo-card__header">
              <div>
                <h3>Coach com IA</h3>
                <p>{aiEnabled ? 'API conectada com memória' : 'Modo demonstração local'}</p>
              </div>
              <span className={`pill ${aiEnabled ? 'pill--primary' : 'pill--outline'}`}>
                {aiEnabled ? 'Ativa' : 'Demo'}
              </span>
            </div>
            <div className="demo-ai">
              <div className="demo-ai__messages" role="log" aria-live="polite">
                {aiMessages.map((m, idx) => (
                  <div key={idx} className={`ai-bubble ai-bubble--${m.role}`}>
                    {m.content}
                  </div>
                ))}
                {aiLoading && <div className="ai-bubble ai-bubble--assistant">Digitando...</div>}
              </div>
              <div className="demo-ai__input">
                <input
                  type="text"
                  placeholder="Pergunte sobre ansiedade, sono ou foco"
                  value={aiInput}
                  onChange={(e) => setAiInput(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && sendAiMessage()}
                />
                <button className="btn btn--primary btn--sm" onClick={sendAiMessage} disabled={aiLoading}>
                  Enviar
                </button>
              </div>
              {!aiEnabled && (
                <p className="demo-helper">
                  Para usar sua API real, defina <code>VITE_AI_ENDPOINT</code> e <code>VITE_AI_KEY</code> em <code>.env.local</code>.
                </p>
              )}
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
            <img src="/alma-icon.svg" alt="Alma" width={28} height={28} />
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
