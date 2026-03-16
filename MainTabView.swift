import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showSubscription = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            // chat só para premium
            Group {
                if subscriptionManager.isPremium {
                    ChatView()
                } else {
                    LockedView(
                        icon: "bubble.left.and.bubble.right",
                        title: "Conversar com Alma",
                        message: "Activa o Premium para falar com a Alma IA.",
                        onUnlock: { showSubscription = true }
                    )
                }
            }
            .tabItem {
                Label("Alma", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(1)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person")
                }
                .tag(3)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(subscriptionManager)
        }
        .onAppear {
            Task { await subscriptionManager.checkSubscriptionStatus() }
        }
    }
}

// ecrã de bloqueio para funcionalidades premium
struct LockedView: View {
    let icon: String
    let title: String
    let message: String
    let onUnlock: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(AlmaTheme.accent)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onUnlock) {
                Text("Ver planos Premium")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AlmaTheme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(AlmaTheme.background)
    }
}
