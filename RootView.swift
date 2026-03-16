import SwiftUI
import FirebaseAuth

struct RootView: View {
    
    @State private var logged = false
    @State private var isLoading = true  // evita flash de LoginView no arranque
    
    var body: some View {
        Group {
            if isLoading {
                // ecrã de splash enquanto verifica auth
                ZStack {
                    Color(AlmaTheme.background).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(AlmaTheme.accent)
                        Text("Alma")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
            } else {
                NavigationStack {
                    if logged {
                        MainTabView()
                    } else {
                        LoginView(logged: $logged)
                    }
                }
            }
        }
        .onAppear {
            // listener que reage a qualquer mudança de auth em tempo real
            Auth.auth().addStateDidChangeListener { _, user in
                logged = user != nil
                isLoading = false
            }
        }
    }
}
