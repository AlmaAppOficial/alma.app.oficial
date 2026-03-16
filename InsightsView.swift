import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MoodEntry: Identifiable {
    let id: String
    let text: String
    let date: Date
}

struct InsightsView: View {
    
    @State private var moods: [MoodEntry] = []
    @State private var isLoading = true
    
    let db = Firestore.firestore()
    
    private var userId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("A carregar...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                } else if moods.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Ainda sem registos")
                            .font(.title3)
                        Text("Faz o teu primeiro check-in emocional no início do dia.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            
                            // resumo no topo
                            HStack(spacing: 12) {
                                StatCard(value: "\(moods.count)", label: "Check-ins")
                                StatCard(value: "\(currentStreak())", label: "Sequência")
                                StatCard(value: "\(thisWeekCount())", label: "Esta semana")
                            }
                            .padding()
                            
                            Divider()
                            
                            // lista de moods
                            ForEach(moods) { entry
