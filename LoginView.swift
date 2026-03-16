import SwiftUI
import FirebaseAuth

struct LoginView: View {
    
    @Binding var logged: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 0
    
    // onboarding slides
    let slides: [(icon: String, title: String, subtitle: String)] = [
        ("heart.fill",         "Bem-vindo à Alma",      "O teu espaço seguro para cuidar da saúde mental."),
        ("bubble.left.fill",   "Fala com a Alma IA",    "Uma mentora empática disponível a qualquer hora."),
        ("chart.bar.fill",     "Acompanha o teu humor", "Descobre padrões e evolui dia após dia."),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            Spacer()
            
            // slides de onboarding
            TabView(selection: $currentPage) {
                ForEach(slides.indices, id: \.self) { i in
                    VStack(spacing: 20) {
                        Image(systemName: slides[i].icon)
                            .font(.system(size: 70))
                            .foregroundColor(AlmaTheme.accent)
                        
                        Text(slides[i].title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(slides[i].subtitle)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(height: 360)
            
            Spacer()
            
            VStack(spacing: 12) {
                
                // entrar anonimamente
                Button(action: signInAnonymously) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Começar gratuitamente")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(AlmaTheme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(isLoading)
                
                Text("Sem conta necessária • Grátis para sempre")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // termos
                Text("Ao continuar, aceitas os nossos [Termos de Uso](https://alma.app/terms) e [Política de Privacidade](https://alma.app/privacy).")
                    .font(.caption2)
                    .foregroundColor(.gray)
