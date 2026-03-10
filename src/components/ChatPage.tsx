import { useState, useEffect, useRef, type FormEvent } from 'react';
import { type User, signInAnonymously, signOut } from 'firebase/auth';
import { auth, FUNCTIONS_CHAT_URL } from '../firebase';
import './ChatPage.css';

interface Message {
  role: 'user' | 'alma';
  text: string;
}

interface ChatPageProps {
  onBack: () => void;
}

export default function ChatPage({ onBack }: ChatPageProps) {
  const [user, setUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [authError, setAuthError] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      role: 'alma',
      text: 'Olá! Sou a Alma, sua mentora emocional. Como você está se sentindo hoje? 💜',
    },
  ]);
  const [input, setInput] = useState('');
  const [sending, setSending] = useState(false);
  const [chatError, setChatError] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Auto-sign-in anonymously
  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(async (u) => {
      if (u) {
        setUser(u);
        setAuthLoading(false);
      } else {
        try {
          await signInAnonymously(auth);
        } catch (err) {
          console.error('[ChatPage] anonymous sign-in failed:', err);
          setAuthError('Não foi possível iniciar a sessão. Recarregue a página.');
          setAuthLoading(false);
        }
      }
    });
    return unsubscribe;
  }, []);

  // Scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, sending]);

  async function submitMessage() {
    const text = input.trim();
    if (!text || sending || !user) return;

    setChatError('');
    setInput('');
    setMessages((prev) => [...prev, { role: 'user', text }]);
    setSending(true);

    try {
      if (!FUNCTIONS_CHAT_URL) {
        throw new Error('VITE_FIREBASE_FUNCTIONS_URL não configurada.');
      }
      const idToken = await user.getIdToken();
      const resp = await fetch(FUNCTIONS_CHAT_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${idToken}`,
        },
        body: JSON.stringify({ message: text }),
      });

      if (!resp.ok) {
        const errorBody = (await resp.json().catch(() => ({}))) as { error?: string };
        throw new Error(errorBody.error ?? `Erro ${resp.status}`);
      }

      const data = (await resp.json()) as { reply: string };
      setMessages((prev) => [...prev, { role: 'alma', text: data.reply }]);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Erro desconhecido.';
      setChatError(msg);
      // Remove the optimistic user message on error
      setMessages((prev) => prev.slice(0, -1));
      setInput(text);
    } finally {
      setSending(false);
    }
  }

  function handleFormSubmit(e: FormEvent) {
    e.preventDefault();
    void submitMessage();
  }

  async function handleSignOut() {
    await signOut(auth);
    onBack();
  }

  if (authLoading) {
    return (
      <div className="chat-loading">
        <span className="chat-spinner" aria-label="Carregando…" />
        <p>Iniciando sessão…</p>
      </div>
    );
  }

  if (authError) {
    return (
      <div className="chat-loading chat-loading--error">
        <p>{authError}</p>
        <button className="btn btn--primary" onClick={() => window.location.reload()}>
          Tentar novamente
        </button>
      </div>
    );
  }

  return (
    <div className="chat-page">
      {/* Header */}
      <header className="chat-header">
        <button className="chat-back" onClick={onBack} aria-label="Voltar">
          ←
        </button>
        <div className="chat-header__info">
          <span className="chat-header__avatar">💜</span>
          <div>
            <strong>Alma</strong>
            <span className="chat-header__status">Mentora emocional</span>
          </div>
        </div>
        <button className="chat-signout" onClick={handleSignOut} title="Encerrar sessão">
          Sair
        </button>
      </header>

      {/* Messages */}
      <div className="chat-messages" role="log" aria-live="polite" aria-label="Conversa com Alma">
        {messages.map((m, i) => (
          <div key={i} className={`chat-bubble chat-bubble--${m.role}`}>
            {m.role === 'alma' && (
              <span className="chat-bubble__avatar" aria-hidden="true">
                💜
              </span>
            )}
            <p className="chat-bubble__text">{m.text}</p>
          </div>
        ))}
        {sending && (
          <div className="chat-bubble chat-bubble--alma chat-bubble--typing">
            <span className="chat-bubble__avatar" aria-hidden="true">💜</span>
            <span className="chat-typing" aria-label="Alma está digitando">
              <span /><span /><span />
            </span>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Error banner */}
      {chatError && (
        <div className="chat-error" role="alert">
          {chatError}
          <button onClick={() => setChatError('')} aria-label="Fechar erro">×</button>
        </div>
      )}

      {/* Input */}
      <form className="chat-input-bar" onSubmit={handleFormSubmit}>
        <textarea
          className="chat-input"
          placeholder="Escreva sua mensagem…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault();
              void submitMessage();
            }
          }}
          maxLength={1000}
          rows={1}
          aria-label="Mensagem para a Alma"
          disabled={sending}
        />
        <button
          type="submit"
          className="chat-send"
          disabled={sending || !input.trim()}
          aria-label="Enviar mensagem"
        >
          {sending ? <span className="chat-spinner chat-spinner--sm" /> : '➤'}
        </button>
      </form>
    </div>
  );
}
