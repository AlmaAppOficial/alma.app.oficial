import { useAuth } from '../contexts/useAuth'

interface ConsentModalProps {
  onShowTerms: () => void
  onShowPrivacy: () => void
}

export function ConsentModal({ onShowTerms, onShowPrivacy }: ConsentModalProps) {
  const { setHealthConsent } = useAuth()

  return (
    <div className="consent-overlay" role="dialog" aria-modal="true" aria-labelledby="consent-title">
      <div className="consent-modal">
        <div className="consent-modal__icon" aria-hidden="true">🔒</div>
        <h2 id="consent-title" className="consent-modal__title">Uso dos seus dados de saúde</h2>
        <p className="consent-modal__body">
          A <strong>Alma</strong> gostaria de acessar seus dados de saúde (Apple Health, Garmin e
          similares) para oferecer insights personalizados de sono, estresse e bem-estar.
        </p>
        <p className="consent-modal__body">
          Seus dados são tratados pela <strong>Alma App</strong> com segurança, nunca são vendidos e
          podem ser revogados a qualquer momento, em conformidade com a <strong>LGPD</strong> e o{' '}
          <strong>GDPR</strong>.
        </p>
        <p className="consent-modal__body consent-modal__body--note">
          📌 <strong>Nota:</strong> as integrações com Apple Health e Garmin são funcionalidades
          futuras. Seu consentimento será utilizado quando estiverem disponíveis.
        </p>
        <div className="consent-modal__actions">
          <button
            type="button"
            className="btn btn--primary btn--lg consent-modal__btn"
            onClick={() => setHealthConsent('granted')}
          >
            ✅ Aceitar e continuar
          </button>
          <button
            type="button"
            className="btn btn--ghost btn--lg consent-modal__btn"
            onClick={() => setHealthConsent('denied')}
          >
            Agora não
          </button>
        </div>
        <p className="consent-modal__legal">
          Ao aceitar, você concorda com nossos{' '}
          <button type="button" className="consent-modal__link" onClick={onShowTerms}>
            Termos de Uso
          </button>{' '}
          e{' '}
          <button type="button" className="consent-modal__link" onClick={onShowPrivacy}>
            Política de Privacidade
          </button>.
        </p>
        <p className="consent-modal__note">
          Você pode alterar essa preferência a qualquer momento em Configurações → Privacidade.
        </p>
      </div>
    </div>
  )
}
