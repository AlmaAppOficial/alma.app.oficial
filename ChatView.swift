
import SwiftUI
import FirebaseFirestore

struct ChatView: View {
    
    @State private var text = ""
    @State private var messages: [String] = []
    
    let db = Firestore.firestore()
    let ai = OpenAIService()
    
    var body: some View {
        
        VStack {
            
            ScrollView {
                ForEach(messages, id: \.self) { msg in
                    MessageBubble(message: msg, isUser: msg == messages.last)
                }
            }
            
            HStack {
                
                TextField("Fale com Alma...", text: $text)
                    .textFieldStyle(.roundedBorder)
                
                Button("Enviar") {
                    send()
                }
            }
            .padding()
        }
        .onAppear {
            listen()
        }
    }
    
    func guard manager.isPremium else {
    showSubscription = true
    return
}send() {
        
        guard !text.isEmpty else { return }
        
        db.collection("chat").addDocument(data: [
            "text": text,
            "date": Date()
        ])
        
        ai.sendMessage(message: text) { reply in
            
            DispatchQueue.main.async {
                
                db.collection("chat").addDocument(data: [
                    "text": reply,
                    "date": Date()
                ])
                
            }
        }
        
        text = ""
    }
    
    func listen() {
        
        db.collection("chat")
            .order(by: "date")
            .addSnapshotListener { snap, error in
                
                guard let docs = snap?.documents else { return }
                
                messages = docs.compactMap { $0["text"] as? String }
            }
    }
}
