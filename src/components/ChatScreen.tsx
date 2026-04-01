/**
 * ChatScreen — thin wrapper around ChatPage.
 *
 * App.tsx uses <ChatScreen onClose={...} initialMessage={...} />.
 * ChatPage handles all Firebase auth, message state, and API calls.
 */
import React from 'react'
import ChatPage from './ChatPage'

type ChatScreenProps = {
  onClose?: () => void
  initialMessage?: string
}

const ChatScreen: React.FC<ChatScreenProps> = ({ onClose, initialMessage }) => {
  return (
    <ChatPage
      onBack={onClose ?? (() => {})}
      initialMessage={initialMessage}
    />
  )
}

export default ChatScreen
