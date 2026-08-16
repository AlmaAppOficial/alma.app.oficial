import SwiftUI
import FirebaseAuth
import CryptoKit
import Foundation
import Security

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

    // MARK: - Fisiologia (sexo biológico)
    //
    // [2026-08-14] Substitui a pergunta de identidade do onboarding. Decisão do
    // Assis: *"não deveria ser como se identifica, e sim sua fisiologia, homem
    // ou mulher"*.
    //
    // **Chave NOVA, e o `alma_user_gender` acima fica intacto.** Não é apego a
    // dado velho: é o que permite migrar na LEITURA. Quem já respondeu
    // "Feminino" continua tendo o gênero gravado, `RegrasDeSaude.sexoEfetivo`
    // o traduz na próxima abertura, e ninguém refaz onboarding nem perde o
    // portão da saúde feminina. Reaproveitar a mesma chave apagaria a única
    // pista que temos sobre quem já usa o app.
    //
    // ⚠️ Este dado é de OUTRA natureza que o de cima. O comentário do `gender`
    // diz "não encriptada, não sensível", e para identidade isso era defensável.
    // Sexo biológico coletado para calcular metabolismo é **dado de saúde**
    // (LGPD Art. 11). Fica em `UserDefaults` local como o resto do perfil
    // corporal (peso, altura, idade, que moram no `AppModel`), **nunca sai do
    // aparelho**, e a tela promete exatamente isso.

    /// Chave do `UserDefaults`. Pública para o `LocalDataCleanupService` e para
    /// as asserções — que assim citam a constante em vez de repetir o literal e
    /// ficarem cegas no dia em que ele mudar.
    static let chaveSexoBiologico = "alma_user_biological_sex"

    /// A resposta CRUA à pergunta de fisiologia, incluindo a recusa.
    ///
    /// Três estados, e os três importam:
    /// - ausente/`""` — nunca perguntado (instalação anterior a 14/08);
    /// - `"Feminino"` / `"Masculino"` — informou;
    /// - `"Prefiro não informar"` — **respondeu, e recusou**.
    ///
    /// O terceiro é o motivo de guardar a string em vez de só o enum. Recusa e
    /// silêncio dão o mesmo resultado no cálculo (estimativa, sem número
    /// pessoal), mas são coisas diferentes na hora de perguntar de novo: quem
    /// recusou já respondeu, e reperguntar seria não ouvir.
    var sexoBiologicoBruto: String {
        get { UserDefaults.standard.string(forKey: Self.chaveSexoBiologico) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.chaveSexoBiologico) }
    }

    /// O sexo utilizável pela fórmula. `nil` para recusa E para silêncio.
    var sexoBiologico: BiologicalSex? { BiologicalSex(rawValue: sexoBiologicoBruto) }

    /// `true` quando a pessoa já viu a pergunta e respondeu alguma coisa —
    /// inclusive "Prefiro não informar". Serve para não reperguntar.
    var respondeuFisiologia: Bool { !sexoBiologicoBruto.isEmpty }

    /// Rótulo canônico da recusa. Um literal só, num lugar só.
    static let recusaFisiologia = "Prefiro não informar"

    /// Monta a cadeia de `RegrasDeSaude.sexoEfetivo` a partir de um `UserDefaults`.
    ///
    /// **Existe para haver UMA montagem só.** Dois consumidores precisam do
    /// sexo efetivo — o `AppModel.init` (para a fórmula) e a `HomeView` (para o
    /// portão da saúde feminina) — e a `HomeView` deliberadamente não tem um
    /// `AppModel` (ver o comentário dela em :40-49, sobre a instância que era
    /// recriada a cada redesenho). Se cada uma montasse a própria cadeia, elas
    /// poderiam divergir, e o app voltaria a ter duas verdades sobre a mesma
    /// pessoa — exatamente o defeito que hoje corrige, com o portão dizendo
    /// "mulher" e a fórmula calculando "homem".
    ///
    /// Recebe o `store` em vez de usar `.standard` fixo para que os harnesses
    /// exercitem a cadeia inteira numa suíte isolada — sem tocar no
    /// `UserDefaults` real de ninguém.
    static func sexoEfetivo(em store: UserDefaults) -> BiologicalSex? {
        RegrasDeSaude.sexoEfetivo(
            escolhidoNaDieta:      BiologicalSex(rawValue: store.string(forKey: "sexBiological") ?? ""),
            informadoNoOnboarding: BiologicalSex(rawValue: store.string(forKey: chaveSexoBiologico) ?? ""),
            generoLegado:          store.string(forKey: "alma_user_gender")
        )
    }

    // Salt fixo LEGADO — mantido apenas para descriptografar dados antigos
    // (derivação antiga: SHA256(UID + salt fixo)). Novos dados usam HKDF
    // com salt aleatório de 32 bytes guardado no Keychain (ver deriveKey()).
    private let appSalt = "alma_app_official_2026"
    private let hkdfInfo = "alma_user_memory_v2"
    private let saltKeychainService = "com.almaapp.app.memory-key-salt"
    private var currentUserUID: String?
    private var userDataPrefix: String { currentUserUID ?? "guest" }

    // Mantém o singleton em sincronia com a conta ativa. Sem este listener,
    // os dados de A continuavam em memória (e currentUserUID = A) após o
    // logout — o usuário B via o histórico/nascimento de A e o onboarding de
    // B sobrescrevia o blob criptografado de A.
    private var authListener: AuthStateDidChangeListenerHandle?

    // MARK: - Initialization
    private init() {
        loadForCurrentUser()
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if user?.uid != self.currentUserUID {
                self.loadForCurrentUser()
            }
        }
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
            // Zera o UID ANTES do reset: um save() tardio (ex.: closure
            // pendente) não pode mais escrever no blob do usuário anterior.
            currentUserUID = nil
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

    /// [2026-08-03 — A4 da revisão independente]
    /// Campo vazio deixou de sobrescrever valor existente. O onboarding pode ser
    /// reaberto pelo card "Complete seu perfil" com os `@State` em branco, e
    /// esta função gravava tudo incondicionalmente: quem voltasse só para
    /// informar o peso apagava cidade, país e horário de nascimento que já tinha
    /// preenchido. `birthDate` já tinha essa guarda; os outros três não.
    func setIdentity(gender: String, birthDate: Date?, birthTimeSlot: String, birthCity: String, birthCountry: String) {
        func preencher(_ novo: String, _ atual: inout String) {
            let limpo = novo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !limpo.isEmpty else { return }   // vazio não apaga o que existe
            atual = limpo
        }
        preencher(gender, &self.gender)
        preencher(birthTimeSlot, &self.birthTimeSlot)
        preencher(birthCity, &self.birthCity)
        preencher(birthCountry, &self.birthCountry)
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

    /// Derivação atual: HKDF<SHA256> com o UID como input key material e
    /// salt aleatório de 32 bytes (SecRandomCopyBytes) persistido no Keychain
    /// por usuário.
    private func deriveKey() -> SymmetricKey {
        guard let userUID = currentUserUID,
              let uidData = userUID.data(using: .utf8) else {
            return SymmetricKey(size: .bits256)
        }

        let salt = keySalt(for: userUID)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: uidData),
            salt: salt,
            info: Data(hkdfInfo.utf8),
            outputByteCount: 32
        )
    }

    /// Derivação LEGADA (SHA256(UID + salt fixo)) — usada apenas como fallback
    /// de leitura para dados criptografados antes da migração para HKDF.
    private func legacyDeriveKey() -> SymmetricKey {
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

    /// Lê (ou gera e persiste) o salt aleatório de 32 bytes do usuário no Keychain.
    private func keySalt(for uid: String) -> Data {
        let readQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: saltKeychainService,
            kSecAttrAccount as String: uid,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(readQuery as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, !data.isEmpty {
            return data
        }

        // Gera salt aleatório de 32 bytes
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard result == errSecSuccess else {
            // Fallback improvável: salt determinístico (equivale a não ter salt aleatório,
            // mas mantém a chave estável entre execuções)
            return Data(SHA256.hash(data: Data((uid + appSalt).utf8)))
        }
        let salt = Data(bytes)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: saltKeychainService,
            kSecAttrAccount as String: uid,
            kSecValueData as String: salt,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ UserMemoryManager: falha ao salvar salt no Keychain: \(status)")
        }
        return salt
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
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)

        // 1) Tenta a chave nova (HKDF + salt aleatório)
        do {
            return try AES.GCM.open(sealedBox, using: deriveKey())
        } catch {
            // 2) Fallback: chave legada. Se funcionar, re-criptografa com a nova
            //    para migrar sem perder dados de usuários existentes.
            let plaintext = try AES.GCM.open(sealedBox, using: legacyDeriveKey())
            reencryptWithCurrentKey(plaintext)
            return plaintext
        }
    }

    /// Re-persiste o blob criptografado com a chave nova após decrypt legado bem-sucedido.
    private func reencryptWithCurrentKey(_ plaintext: Data) {
        guard let userUID = currentUserUID else { return }
        do {
            let encrypted = try encrypt(plaintext)
            UserDefaults.standard.set(encrypted, forKey: "alma_user_\(userUID)_data")
        } catch {
            print("Error re-encrypting user data: \(error.localizedDescription)")
        }
    }
}
