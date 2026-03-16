import React, { useState } from 'react';

export const ChatScreen: React.FC = () => {
  // ... (o resto igual)
};

const ChatScreen: React.FC = () => {
    const FUNCTIONS_BASE_URL = import.meta.env.VITE_FUNCTIONS_BASE_URL;
    const chatEnabled = Boolean(FUNCTIONS_BASE_URL);
    const [errorMessage, setErrorMessage] = useState<string | null>(null);
    const [message, setMessage] = useState<string>('');

    const handleSendMessage = () => {
        if (!chatEnabled) {
            setErrorMessage('Chat temporariamente inativo no momento.');
            return;
        }
        // Add logic to send message when chat is enabled
    };

    return (
        <div>
            {!chatEnabled && <div className="inactive-notice">Chat temporariamente inativo no momento.</div>}
            <div className="status-line">
                {chatEnabled ? 'Online • Disponível 24h' : 'Inativo no momento'}
            </div>
            <textarea
                disabled={!chatEnabled}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder={chatEnabled ? 'Digite sua mensagem...' : 'Chat não disponível'}
            />
            <button onClick={handleSendMessage} disabled={!chatEnabled}>
                Enviar
            </button>
            {errorMessage && <div className="error-message">{errorMessage}</div>}
        </div>
    );
};

export default ChatScreen;
