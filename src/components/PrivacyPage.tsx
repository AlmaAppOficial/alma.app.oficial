interface PrivacyPageProps {
  onBack: () => void
}

export function PrivacyPage({ onBack }: PrivacyPageProps) {
  return (
    <div className="legal-page">
      <div className="legal-page__header">
        <button className="legal-page__back" onClick={onBack} aria-label="Voltar">
          ← Voltar
        </button>
        <div className="legal-page__logo">
          <svg width="28" height="28" viewBox="0 0 64 64" aria-hidden="true" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="privacyLogoGrad" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stopColor="#6B46C1" />
                <stop offset="100%" stopColor="#9F7AEA" />
              </linearGradient>
            </defs>
            <circle cx="32" cy="32" r="30.5" fill="url(#privacyLogoGrad)" stroke="#4B2C88" strokeWidth="3" />
            <path d="M32 14c-2 0-4 2-4 4s2 4 4 4 4-2 4-4-2-4-4-4z" fill="#F5F3FF" opacity="0.95" />
            <path d="M20 26c0 8 6 18 12 22 6-4 12-14 12-22a12 12 0 0 0-24 0z" fill="#F5F3FF" opacity="0.92" />
            <path d="M26 30c0 4 3 8 6 10 3-2 6-6 6-10a6 6 0 0 0-12 0z" fill="#6B46C1" opacity="0.65" />
          </svg>
          <span>Alma</span>
        </div>
      </div>

      <div className="legal-page__content">
        <h1>Política de Privacidade</h1>
        <p className="legal-page__updated">Última atualização: março de 2026</p>

        <section>
          <h2>1. Controlador dos Dados</h2>
          <p>
            A <strong>Alma App</strong> é o controlador dos seus dados pessoais conforme a Lei Geral
            de Proteção de Dados (LGPD – Lei 13.709/2018) e o Regulamento Geral de Proteção de Dados
            da União Europeia (GDPR – Regulation 2016/679).
          </p>
          <p>
            Contato do Encarregado (DPO):{' '}
            <a href="mailto:alma@almaappoficial.com">alma@almaappoficial.com</a>
          </p>
        </section>

        <section>
          <h2>2. Dados Coletados</h2>
          <h3>2.1 Dados fornecidos por você</h3>
          <ul>
            <li><strong>Conta:</strong> endereço de e-mail e senha (armazenada com hash seguro via Firebase Authentication).</li>
            <li><strong>Conversas com a Alma AI:</strong> mensagens de texto enviadas ao assistente (processadas pela OpenAI e não armazenadas permanentemente por padrão).</li>
            <li><strong>Registro de humor:</strong> opções de humor selecionadas no dashboard.</li>
          </ul>
          <h3>2.2 Dados de saúde (futuros)</h3>
          <p>
            <strong>As integrações com Apple Health e Garmin ainda não estão disponíveis.</strong>{' '}
            Quando implementadas, serão coletadas apenas após consentimento explícito do usuário e
            limitadas às categorias: sono, frequência cardíaca, nível de estresse e passos.
          </p>
          <h3>2.3 Dados técnicos</h3>
          <ul>
            <li>Identificador único de usuário (Firebase UID).</li>
            <li>Logs de erros e desempenho (Firebase Crashlytics / Analytics – anonimizados).</li>
          </ul>
        </section>

        <section>
          <h2>3. Finalidade e Base Legal</h2>
          <table className="legal-table">
            <thead>
              <tr>
                <th>Finalidade</th>
                <th>Base Legal (LGPD)</th>
                <th>Base Legal (GDPR)</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>Autenticação e manutenção da conta</td>
                <td>Execução de contrato (art. 7°, V)</td>
                <td>Execução de contrato (Art. 6(1)(b))</td>
              </tr>
              <tr>
                <td>Assistente de IA (Alma AI)</td>
                <td>Execução de contrato (art. 7°, V)</td>
                <td>Execução de contrato (Art. 6(1)(b))</td>
              </tr>
              <tr>
                <td>Dados de saúde (futuros)</td>
                <td>Consentimento explícito (art. 11, I)</td>
                <td>Consentimento explícito (Art. 9(2)(a))</td>
              </tr>
              <tr>
                <td>Melhoria do serviço</td>
                <td>Legítimo interesse (art. 7°, IX)</td>
                <td>Legítimo interesse (Art. 6(1)(f))</td>
              </tr>
            </tbody>
          </table>
        </section>

        <section>
          <h2>4. Compartilhamento de Dados</h2>
          <p>Seus dados são compartilhados somente com:</p>
          <ul>
            <li>
              <strong>Google Firebase:</strong> autenticação, banco de dados e hospedagem. Consulte a{' '}
              <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener noreferrer">
                Política de Privacidade do Firebase
              </a>.
            </li>
            <li>
              <strong>OpenAI:</strong> processamento de mensagens da Alma AI. As mensagens são
              transmitidas de forma segura via API server-side e processadas conforme a{' '}
              <a href="https://openai.com/enterprise-privacy" target="_blank" rel="noopener noreferrer">
                política de privacidade da OpenAI
              </a>. Não usamos os dados para treinar modelos.
            </li>
          </ul>
          <p>
            <strong>Não vendemos, alugamos ou compartilhamos seus dados com terceiros para fins
            publicitários.</strong>
          </p>
        </section>

        <section>
          <h2>5. Seus Direitos</h2>
          <p>Conforme a LGPD e o GDPR, você tem os seguintes direitos:</p>
          <ul>
            <li><strong>Acesso:</strong> solicitar cópia dos dados que temos sobre você.</li>
            <li><strong>Correção:</strong> corrigir dados incompletos ou inexatos.</li>
            <li><strong>Exclusão:</strong> solicitar a exclusão dos seus dados ("direito ao esquecimento").</li>
            <li><strong>Portabilidade:</strong> receber seus dados em formato estruturado.</li>
            <li><strong>Revogação de consentimento:</strong> revogar consentimentos dados a qualquer momento, sem prejuízo das atividades anteriores.</li>
            <li><strong>Oposição:</strong> se opor ao tratamento baseado em legítimo interesse.</li>
          </ul>
          <p>
            Para exercer seus direitos, envie um e-mail para{' '}
            <a href="mailto:alma@almaappoficial.com">alma@almaappoficial.com</a> com o assunto
            "Direitos LGPD/GDPR".
          </p>
        </section>

        <section>
          <h2>6. Retenção de Dados</h2>
          <p>
            Seus dados são retidos enquanto sua conta estiver ativa. Após a exclusão da conta, os
            dados são removidos em até 30 dias, exceto quando há obrigação legal de retenção.
          </p>
        </section>

        <section>
          <h2>7. Segurança</h2>
          <p>
            Adotamos medidas técnicas e organizacionais para proteger seus dados, incluindo:
            criptografia em trânsito (TLS), autenticação segura via Firebase Auth, e controle de
            acesso baseado em funções.
          </p>
        </section>

        <section>
          <h2>8. Transferência Internacional</h2>
          <p>
            Seus dados podem ser processados nos servidores do Google (Firebase) e da OpenAI,
            localizados nos Estados Unidos. Essas transferências são realizadas com salvaguardas
            adequadas, incluindo Cláusulas Contratuais Padrão (SCCs).
          </p>
        </section>

        <section>
          <h2>9. Cookies e Armazenamento Local</h2>
          <p>
            O Alma usa o armazenamento local do navegador (<code>localStorage</code>) para salvar
            preferências de sessão e consentimento. Não usamos cookies de rastreamento de terceiros.
          </p>
        </section>

        <section>
          <h2>10. Contato</h2>
          <p>
            Para dúvidas, solicitações ou reclamações sobre privacidade:
          </p>
          <p>
            <strong>Alma App — Encarregado de Proteção de Dados (DPO)</strong><br />
            E-mail: <a href="mailto:alma@almaappoficial.com">alma@almaappoficial.com</a>
          </p>
          <p>
            Você também pode registrar uma reclamação junto à Autoridade Nacional de Proteção de
            Dados (ANPD): <a href="https://www.gov.br/anpd" target="_blank" rel="noopener noreferrer">www.gov.br/anpd</a>.
          </p>
        </section>
      </div>
    </div>
  )
}
