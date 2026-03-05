import SwiftUI

struct ContentView: View {
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var moodViewModel = MoodViewModel()

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(userViewModel)
                .tabItem { Label("Início",   systemImage: "house.fill") }

            MeditationListView()
                .environmentObject(userViewModel)
                .tabItem { Label("Meditar",  systemImage: "sparkles") }

            BreatheView()
                .tabItem { Label("Respirar", systemImage: "wind") }

            MoodTrackerView()
                .environmentObject(moodViewModel)
                .tabItem { Label("Humor",    systemImage: "heart.fill") }

            ProfileView()
                .environmentObject(userViewModel)
                .tabItem { Label("Perfil",   systemImage: "person.fill") }
        }
        .tint(.almaPrimary)
    }
}

#Preview {
    ContentView()
}
