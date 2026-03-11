import { useState, useRef, useEffect, type FormEvent } from 'react'
import { useAuth } from '../contexts/useAuth'

interface Message {
  id: string
  role: 'user' | 'assistant'
  text: string
}

interface ChatScreenProps {
  onClose: () => void
  initialMessage?: string
}

const FUNCTIONS_BASE_URL = import.meta.env.VITE_FUNCTIONS_BASE_URL ?? ''

export function ChatScreen({ onClose, initialMessage }: ChatScreenProps) {
  const { user } = useAuth()
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      role: 'assistant',
      text: 'Olá! Sou a Alma 💜 Estou aqui para te apoiar. Como você está se sentindo agora?',
    },
  ])
  const [input, setInput] = useState(initialMessage ?? '')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const bottomRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const sendMessage = async (text: string) => {
    if (!text.trim() || sending) return
    setError(null)

    const userMsg: Message = { id: Date.now().toString(), role: 'user', text: text.trim() }
    setMessages((prev) => [...prev, userMsg])
    setInput('')
    setSending(true)

    try {
      if (!user) throw new Error('Not authenticated')
      const token = await user.getIdToken()
      const res = await fetch(`${FUNCTIONS_BASE_URL}/api/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ message: text.trim() }),
      })

      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`)
      }

      const data = (await res.json()) as { reply: string }
      const assistantMsg: Message = {
        id: `${Date.now()}-ai`,
        role: 'assistant',
        text: data.reply,
      }
      setMessages((prev) => [...prev, assistantMsg])
    } catch (err) {
      console.error('Chat error:', err)
      const msg = err instanceof Error ? err.message : String(err)
      if (msg.includes('401') || msg.includes('Not authenticated')) {
        setError('Sessão expirada. Faça login novamente.')
      } else if (msg.startsWith('HTTP')) {
        setError('Erro no servidor. Tente novamente em instantes.')
      } else {
        setError('Não foi possível obter resposta. Verifique sua conexão e tente novamente.')
      }
    } finally {
      setSending(false)
    }
  }

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    void sendMessage(input)
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      void sendMessage(input)
    }
  }

  return (
    <div className="chat-screen">
      {/* Header */}
      <div className="chat-header">
        <div className="chat-header__info">
          <div className="chat-header__avatar" aria-hidden="true">
            <svg width="36" height="36" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <linearGradient id="chatAvatarGrad" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0%" stopColor="#6B46C1" />
                  <stop offset="100%" stopColor="#9F7AEA" />
                </linearGradient>
              </defs>
              <circle cx="32" cy="32" r="30" fill="url(#chatAvatarGrad)" />
              <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
              <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
              <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
            </svg>
          </div>
          <div>
            <p className="chat-header__name">Alma AI</p>
            <p className="chat-header__status">Online • Disponível 24h</p>
          </div>
        </div>
        <button className="chat-header__close" onClick={onClose} aria-label="Fechar chat">✕</button>
      </div>

      {/* Messages */}
      <div className="chat-messages" role="log" aria-live="polite" aria-label="Conversa com Alma">
        {messages.map((msg) => (
          <div key={msg.id} className={`chat-bubble chat-bubble--${msg.role}`}>
            <p>{msg.text}</p>
          </div>
        ))}
        {sending && (
          <div className="chat-bubble chat-bubble--assistant chat-bubble--typing">
            <span className="typing-dot" />
            <span className="typing-dot" />
            <span className="typing-dot" />
          </div>
        )}
        {error && <p className="chat-error" role="alert">{error}</p>}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <form className="chat-input-row" onSubmit={handleSubmit}>
        <textarea
          ref={inputRef}
          className="chat-input"
          placeholder="Digite sua mensagem…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          rows={1}
          disabled={sending}
          aria-label="Mensagem"
        />
        <button
          type="submit"
          className="chat-send-btn"
          disabled={sending || !input.trim()}
          aria-label="Enviar mensagem"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <path d="M22 2L11 13" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M22 2L15 22L11 13L2 9L22 2Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>
      </form>
    </div>
  )
}
