diff --git a/src/components/ChatScreen.tsx b/src/components/ChatScreen.tsx
--- a/src/components/ChatScreen.tsx
+++ b/src/components/ChatScreen.tsx
@@ -1,12 +1,20 @@
 import React, { useState } from 'react';
 
-const ChatScreen: React.FC = () => {
+type ChatScreenProps = {
+  onClose?: () => void;
+  initialMessage?: string;
+};
+
+const ChatScreen: React.FC<ChatScreenProps> = ({ onClose, initialMessage }) => {
   const FUNCTIONS_BASE_URL = import.meta.env.VITE_FUNCTIONS_BASE_URL;
   const chatEnabled = Boolean(FUNCTIONS_BASE_URL);
 
   const [errorMessage, setErrorMessage] = useState<string | null>(null);
-  const [message, setMessage] = useState<string>('');
+  const [message, setMessage] = useState<string>(initialMessage ?? '');
@@ -16,6 +24,10 @@
       setErrorMessage('Chat temporariamente inativo no momento.');
       return;
     }
     // Add logic to send message when chat is enabled
   };
 
   return (
     <div>
+      {onClose && (
+        <button type="button" onClick={onClose}>
+          Fechar
+        </button>
+      )}
       {!chatEnabled && (
         <div className="inactive-notice">Chat temporariamente inativo no momento.</div>
       )}
