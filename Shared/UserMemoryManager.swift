import SwiftUI
import FirebaseAuth
import CryptoKit
import Foundation

// MARK: - MoodEntry (Codable replacement for tuple)
struct MoodEntry: Codable, Identifiable {
    var id = UUID()
    let emoji: String
    let date: Date
}

class UserMemoryManager: ObservableObject {
    static let shared = UserMemoryManager()

    @Published var birthDate: Date?
    @Published var moodHistory: [MoodEntry] = []
    @Published var meditationMinutes: Int = 0
    @Published var sessionsCompleted: Int = 0
    @Published var healthConnected: Bool = false
    @Published var lastMoodDate: Date?

    // Identidade — lida/escrita directamente em UserDefaults (não encriptada, não sensível)
    // gender: "Feminino" | "Masculino" | "Não binário" | "Prefiro não dizer"
    var gender: String {
        get { UserDefaults.standard.string(forKey: "alma_user_gender") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "alma_user_gender") }
    }
    // birthTimeSlot: "Madrugada (0h-6h)" | "Manhã (6h-12h)" | "Tarde (12h-18h)" | "Noite (18h-24h)" | "Não sei"
    var birthTimeSlot: String {
        get { UserDefaults.standard.string(forKey: "alma_user_birthTimeSlot") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "alma_user_birthTimeSlot") }
    }
    var birthCity: String {
        get { UserDefaults.standard.string(forKey: "alma_user_birthCity") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "alma_user_birthCity") }
    }
    var birthCountry: String {
        get { UserDefaults.standard.string(forKey: "alma_user_birthCountry") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "alma_user_birthCountry") }
    }

    // Compatibilidade retroativa com código que usa isFemale (FeminineHealthView, etc.)
    var isFemale: Bool {
        get { gender == "Feminino" }
        set { gender = newValue ? "Feminino" : "Masculino" }
    }
    var genderSet: Bool { !gender.isEmpty }

    private let appSalt = "alma_app_official_2026"
    private var currentUserUID: String?
    private var userDataPrefix: String { currentUserUID ?? "guest" }

    // MARK: - Initialization
    private init() {
        loadForCurrentUser()
    }

    // MARK: - User Data Struct (Codable)
    struct UserData: Codable {
        var birthDate: Date?
        var moodHistory: [MoodEntry]
        var meditationMinutes: Int
        var sessionsCompleted: Int
        var healthConnected: Bool
        var lastMoodDate: Date?
    }

    // MARK: - Public Methods
    func loadForCurrentUser() {
        if let user = Auth.auth().currentUser {
            currentUserUID = user.uid
            loadUserData()
        } else {
            reset()
        }
    }

    func save() {
        guard let userUID = currentUserUID else { return }

        let userData = UserData(
            birthDate: birthDate,
            moodHistory: moodHistory,
            meditationMinutes: meditationMinutes,
            sessionsCompleted: sessionsCompleted,
            healthConnected: healthConnected,
            lastMoodDate: lastMoodDate
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(userData)
            let encryptedData = try encrypt(jsonData)

            let key = "alma_user_\(userUID)_data"
            UserDefaults.standard.set(encryptedData, forKey: key)
        } catch {
            print("Error saving user data: \(error.localizedDescription)")
        }
    }

    func recordMood(_ emoji: String) {
        let today = Calendar.current.startOfDay(for: Date())

        // Prevent duplicate mood entries on same day
        if let lastMood = lastMoodDate, Calendar.current.isDate(lastMood, inSameDayAs: today) {
            return
        }

        let moodEntry = MoodEntry(emoji: emoji, date: Date())
        moodHistory.append(moodEntry)
        lastMoodDate = Date()

        save()
    }

    func recordMeditationSession(minutes: Int) {
        meditationMinutes += minutes
        sessionsCompleted += 1
        save()
    }

    func setBirthDate(_ date: Date) {
        birthDate = date
        save()
    }

    func setIdentity(gender: String, birthDate: Date?, birthTimeSlot: String, birthCity: String, birthCountry: String) {
        self.gender = gender
        self.birthTimeSlot = birthTimeSlot
        self.birthCity = birthCity
        self.birthCountry = birthCountry
        if let date = birthDate {
            self.birthDate = date
        }
        save()
    }

    func setHealthConnected(_ connected: Bool) {
        healthConnected = connected
        save()
    }

    func logout() {
        currentUserUID = nil
        reset()
    }

    // MARK: - Private Methods
    private func reset() {
        DispatchQueue.main.async {
            self.birthDate = nil
            self.moodHistory = []
            self.meditationMinutes = 0
            self.sessionsCompleted = 0
            self.healthConnected = false
            self.lastMoodDate = nil
        }
    }

    private func loadUserData() {
        guard let userUID = currentUserUID else { return }

        let key = "alma_user_\(userUID)_data"

        if let encryptedData = UserDefaults.standard.data(forKey: key) {
            do {
                let jsonData = try decrypt(encryptedData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let userData = try decoder.decode(UserData.self, from: jsonData)

                DispatchQueue.main.async {
                    self.birthDate = userData.birthDate
                    self.moodHistory = userData.moodHistory
                    self.meditationMinutes = userData.meditationMinutes
                    self.sessionsCompleted = userData.sessionsCompleted
                    self.healthConnected = userData.healthConnected
                    self.lastMoodDate = userData.lastMoodDate
                }
            } catch {
                print("Error loading user data: \(error.localizedDescription)")
                reset()
            }
        }
    }

    // MARK: - Encryption/Decryption (AES-GCM with derived key)
    private func deriveKey() -> SymmetricKey {
        guard let userUID = currentUserUID else {
            return SymmetricKey(size: .bits256)
        }

        let combined = userUID + appSalt
        guard let data = combined.data(using: .utf8) else {
            return SymmetricKey(size: .bits256)
        }

        let digest = SHA256.hash(data: data)
        let keyData = Data(digest)
        return SymmetricKey(data: keyData)
    }

    private func encrypt(_ data: Data) throws -> Data {
        let key = deriveKey()
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw NSError(domain: "EncryptionError", code: -1, userInfo: nil)
        }

        return combined
    }

    private func decrypt(_ encryptedData: Data) throws -> Data {
        let key = deriveKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
