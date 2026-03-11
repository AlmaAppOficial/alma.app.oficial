interface TermsPageProps {
  onBack: () => void
}

export function TermsPage({ onBack }: TermsPageProps) {
  return (
    <div className="legal-page">
      <div className="legal-page__header">
        <button className="legal-page__back" onClick={onBack} aria-label="Voltar">
          ← Voltar
        </button>
        <div className="legal-page__logo">
          <svg width="28" height="28" viewBox="0 0 64 64" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="termsLogoGrad" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#6B46C1" />
                <stop offset="100%" stopColor="#9F7AEA" />
              </linearGradient>
            </defs>
            <circle cx="32" cy="32" r="30.5" fill="url(#termsLogoGrad)" stroke="#4B2C88" strokeWidth="3" />
            <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
            <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
            <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
          </svg>
          <span>Alma</span>
        </div>
      </div>

      <div className="legal-page__content">
        <h1>Termos de Uso</h1>
        <p className="legal-page__updated">Última atualização: março de 2026</p>

        <section>
          <h2>1. Aceitação dos Termos</h2>
          <p>
            Ao acessar ou usar o aplicativo <strong>Alma</strong> ("Serviço"), você concorda em ficar
            vinculado a estes Termos de Uso. Se você não concordar com qualquer parte dos termos, não
            poderá usar o Serviço.
          </p>
        </section>

        <section>
          <h2>2. Descrição do Serviço</h2>
          <p>
            O Alma é um aplicativo de bem-estar mental que oferece meditações guiadas, conversa com
            assistente de IA e ferramentas de acompanhamento emocional. O Serviço é fornecido por
            <strong> Alma App</strong> ("Controlador").
          </p>
          <p>
            <strong>Importante:</strong> O Alma <em>não</em> substitui tratamento psicológico ou
            psiquiátrico profissional. Em situações de crise, procure imediatamente um profissional
            de saúde mental ou ligue para o CVV: <strong>188</strong>.
          </p>
        </section>

        <section>
          <h2>3. Conta e Autenticação</h2>
          <p>
            Para usar o Serviço, você precisa criar uma conta com e-mail e senha. Você é responsável
            por manter a confidencialidade de suas credenciais e por todas as atividades realizadas
            sob sua conta.
          </p>
        </section>

        <section>
          <h2>4. Dados de Saúde (Apple Health / Garmin)</h2>
          <p>
            <strong>As integrações com Apple Health e Garmin são funcionalidades futuras</strong> e
            ainda não estão implementadas. Quando disponíveis, você será solicitado a dar
            consentimento explícito antes de qualquer acesso a dados de saúde. Você poderá revogar
            esse consentimento a qualquer momento.
          </p>
        </section>

        <section>
          <h2>5. Propriedade Intelectual</h2>
          <p>
            Todo o conteúdo do Serviço, incluindo textos, meditações, logotipos e interface, é
            propriedade da Alma App e protegido por direitos autorais. Você não pode reproduzir,
            distribuir ou criar obras derivadas sem autorização prévia e por escrito.
          </p>
        </section>

        <section>
          <h2>6. Limitação de Responsabilidade</h2>
          <p>
            O Serviço é fornecido "como está". A Alma App não garante que o Serviço estará
            disponível ininterruptamente ou livre de erros. Em nenhum caso a Alma App será
            responsável por danos indiretos, incidentais ou consequenciais.
          </p>
        </section>

        <section>
          <h2>7. Alterações dos Termos</h2>
          <p>
            Podemos atualizar estes Termos periodicamente. Quando o fizermos, revisaremos a data de
            "Última atualização" acima. O uso continuado do Serviço após as alterações constitui
            aceitação dos novos termos.
          </p>
        </section>

        <section>
          <h2>8. Lei Aplicável</h2>
          <p>
            Estes Termos são regidos pelas leis da República Federativa do Brasil. Fica eleito o foro
            da comarca de São Paulo – SP para dirimir quaisquer conflitos.
          </p>
        </section>

        <section>
          <h2>9. Contato</h2>
          <p>
            Dúvidas sobre estes Termos? Fale conosco:
          </p>
          <p>
            <strong>Alma App</strong><br />
            E-mail: <a href="mailto:alma@almaappoficial.com">alma@almaappoficial.com</a>
          </p>
        </section>
      </div>
    </div>
  )
}
