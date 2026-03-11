  return (
    <div className="app">
      <Navbar onOpenChat={() => setShowChat(true)} />
      <main>
        <Hero onOpenChat={() => setShowChat(true)} />
        <Stats />
        <Features />
        <HowItWorks />
        <Testimonials />
        <DownloadCTA onOpenChat={() => setShowChat(true)} />
      </main>
      <Footer />
import { AuthProvider } from './contexts/AuthContext'
import { useAuth } from './contexts/useAuth'
import { AuthScreen } from './components/AuthScreen'
import { ConsentModal } from './components/ConsentModal'
import { ChatScreen } from './components/ChatScreen'
import { TermsPage } from './components/TermsPage'
import { PrivacyPage } from './components/PrivacyPage'
import { firebaseConfigured } from './lib/firebase'
