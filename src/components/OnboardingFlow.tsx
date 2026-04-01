/**
 * OnboardingFlow — Questionário inicial da ALMA
 *
 * Coleta o perfil do usuário de forma conversacional, não como formulário.
 * Dados salvos no Firestore em users/{uid}/profile
 */
import { useState } from 'react'
import { doc, setDoc } from 'firebase/firestore'
import { db } from '../lib/firebase'
import { useAuth } from '../contexts/useAuth'
import './OnboardingFlow.css'

interface Step {
  id: string
  question: string
  subtitle?: string
  type: 'options' | 'text' | 'multiselect'
  options?: Array<{ value: string; label: string; emoji: string }>
  placeholder?: string
  optional?: boolean
}

const STEPS: Step[] = [
  {
    id: 'intention',
    question: 'O que te trouxe até aqui?',
    subtitle: 'Não há resposta certa. Apenas a sua verdade.',
    type: 'options',
    options: [
      { value: 'ansiedade', label: 'Ansiedade ou estresse', emoji: '😰' },
      { value: 'sono',      label: 'Problemas para dormir', emoji: '😴' },
      { value: 'perdido',   label: 'Me sinto perdido(a)', emoji: '🌫️' },
      { value: 'crescimento', label: 'Quero crescer internamente', emoji: '🌱' },
      { value: 'paz',       label: 'Busco mais paz', emoji: '🕊️' },
      { value: 'curiosidade', label: 'Curiosidade', emoji: '✨' },
    ],
  },
  {
    id: 'mainChallenge',
    question: 'O que está pesando mais em você agora?',
    subtitle: 'A Alma vai guardar isso com cuidado.',
    type: 'text',
    placeholder: 'Pode ser qualquer coisa — um sentimento, uma situação...',
    optional: true,
  },
  {
    id: 'relationship',
    question: 'Como está sua vida afetiva?',
    subtitle: 'Isso ajuda a Alma a entender seu contexto emocional.',
    type: 'options',
    options: [
      { value: 'solteiro',     label: 'Solteiro(a)',            emoji: '🌿' },
      { value: 'relacionamento', label: 'Em relacionamento',    emoji: '💛' },
      { value: 'casado',       label: 'Casado(a)',              emoji: '💍' },
      { value: 'separado',     label: 'Separado(a) / Divorciado(a)', emoji: '🍂' },
      { value: 'prefiro_nao_dizer', label: 'Prefiro não dizer', emoji: '🤍' },
    ],
  },
  {
    id: 'children',
    question: 'Você tem filhos?',
    type: 'options',
    options: [
      { value: 'nao',    label: 'Não',           emoji: '🌙' },
      { value: 'sim_1',  label: 'Sim, 1 filho',  emoji: '👶' },
      { value: 'sim_2+', label: 'Sim, 2 ou mais', emoji: '👨‍👩‍👧‍👦' },
    ],
  },
  {
    id: 'occupation',
    question: 'Como está sua vida profissional?',
    type: 'options',
    options: [
      { value: 'trabalhando_bem',     label: 'Trabalhando — me sinto bem nisso', emoji: '✅' },
      { value: 'trabalhando_estresse', label: 'Trabalhando — mas é uma fonte de estresse', emoji: '😤' },
      { value: 'procurando',          label: 'Procurando emprego',               emoji: '🔍' },
      { value: 'estudante',           label: 'Estudante',                        emoji: '📚' },
      { value: 'empreendedor',        label: 'Empreendedor(a)',                  emoji: '🚀' },
      { value: 'outro',               label: 'Outra situação',                   emoji: '🌀' },
    ],
  },
  {
    id: 'spirituality',
    question: 'Como você se relaciona com espiritualidade?',
    subtitle: 'A Alma respeita todos os caminhos.',
    type: 'options',
    options: [
      { value: 'nao_religioso',  label: 'Não me identifico com religião', emoji: '🔬' },
      { value: 'espiritualizado', label: 'Sou espiritualizado(a)',         emoji: '🌌' },
      { value: 'religioso',      label: 'Tenho fé religiosa',             emoji: '🙏' },
      { value: 'explorando',     label: 'Estou explorando',               emoji: '🌱' },
      { value: 'prefiro_nao_dizer', label: 'Prefiro não dizer',           emoji: '🤍' },
    ],
  },
  {
    id: 'name',
    question: 'Como posso te chamar?',
    subtitle: 'Apenas seu primeiro nome, ou como preferir.',
    type: 'text',
    placeholder: 'Seu nome...',
    optional: true,
  },
]

interface OnboardingFlowProps {
  onComplete: () => void
}

export default function OnboardingFlow({ onComplete }: OnboardingFlowProps) {
  const { user } = useAuth()
  const [currentStep, setCurrentStep] = useState(0)
  const [answers, setAnswers] = useState<Record<string, string>>({})
  const [textValue, setTextValue] = useState('')
  const [saving, setSaving] = useState(false)

  const step = STEPS[currentStep]
  const progress = ((currentStep) / STEPS.length) * 100

  const handleOption = (value: string) => {
    const newAnswers = { ...answers, [step.id]: value }
    setAnswers(newAnswers)
    setTimeout(() => advance(newAnswers), 300)
  }

  const handleTextNext = () => {
    const newAnswers = { ...answers, [step.id]: textValue.trim() }
    setAnswers(newAnswers)
    setTextValue('')
    advance(newAnswers)
  }

  const handleSkip = () => {
    setTextValue('')
    advance(answers)
  }

  const advance = async (currentAnswers: Record<string, string>) => {
    if (currentStep < STEPS.length - 1) {
      setCurrentStep((s) => s + 1)
    } else {
      await saveProfile(currentAnswers)
    }
  }

  const saveProfile = async (finalAnswers: Record<string, string>) => {
    if (!user || !db) {
      onComplete()
      return
    }
    setSaving(true)
    try {
      await setDoc(
        doc(db, 'users', user.uid),
        {
          profile: {
            ...finalAnswers,
            onboardedAt: new Date().toISOString(),
          },
          onboarded: true,
        },
        { merge: true },
      )
    } catch (e) {
      console.warn('[onboarding] save failed (non-fatal):', e)
    } finally {
      setSaving(false)
      onComplete()
    }
  }

  if (saving) {
    return (
      <div className="onboarding-loading">
        <div className="onboarding-loading__icon">🌙</div>
        <p>A Alma está guardando sua essência…</p>
      </div>
    )
  }

  return (
    <div className="onboarding">
      {/* Progress bar */}
      <div className="onboarding__progress-bar">
        <div
          className="onboarding__progress-fill"
          style={{ width: `${progress}%` }}
        />
      </div>

      <div className="onboarding__inner">
        {/* Step counter */}
        <p className="onboarding__step-label">
          {currentStep + 1} de {STEPS.length}
        </p>

        {/* ALMA avatar */}
        <div className="onboarding__avatar">🌙</div>

        {/* Question */}
        <h2 className="onboarding__question">{step.question}</h2>
        {step.subtitle && (
          <p className="onboarding__subtitle">{step.subtitle}</p>
        )}

        {/* Options */}
        {step.type === 'options' && step.options && (
          <div className="onboarding__options">
            {step.options.map((opt) => (
              <button
                key={opt.value}
                className={`onboarding__option${
                  answers[step.id] === opt.value ? ' onboarding__option--selected' : ''
                }`}
                onClick={() => handleOption(opt.value)}
                type="button"
              >
                <span className="onboarding__option-emoji">{opt.emoji}</span>
                <span>{opt.label}</span>
              </button>
            ))}
          </div>
        )}

        {/* Text input */}
        {step.type === 'text' && (
          <div className="onboarding__text-area">
            <textarea
              className="onboarding__textarea"
              placeholder={step.placeholder}
              value={textValue}
              onChange={(e) => setTextValue(e.target.value)}
              rows={3}
              maxLength={300}
              autoFocus
            />
            <div className="onboarding__text-actions">
              <button
                className="btn btn--primary"
                onClick={handleTextNext}
                disabled={!textValue.trim() && !step.optional}
                type="button"
              >
                Continuar →
              </button>
              {step.optional && (
                <button
                  className="onboarding__skip"
                  onClick={handleSkip}
                  type="button"
                >
                  Pular
                </button>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
