import Foundation

// MARK: - RecommendedSound
// [Build 77 — 12/05/2026] Substitui o BinauralTrack antigo (que gerava tons sinteticos
// abaixo do limiar auditivo humano e na pratica nao tocava nada audivel).
// Agora cada track aponta pra um MP3 real no bundle do app.

struct RecommendedSound: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let iconName: String
    let bundleFilename: String
    let category: SoundCategory
    let durationSeconds: Int

    enum SoundCategory: String {
        case music
        case sleep
    }
}

// MARK: - SmartPlaylistEngine
// Recomenda 4 sons baseado em sinais biologicos (stress, sono, batimentos).
// Sem dados, retorna mix variado como fallback.

enum SmartPlaylistEngine {

    static let library: [RecommendedSound] = [
        // Musica classica (ja bundlada em ClassicalMusic/)
        RecommendedSound(id: "bach_goldberg",
                         title: "Bach",
                         subtitle: "Variações Goldberg",
                         iconName: "music.note",
                         bundleFilename: "bach_goldberg.mp3",
                         category: .music,
                         durationSeconds: 1535),
        RecommendedSound(id: "beethoven_pastoral",
                         title: "Beethoven",
                         subtitle: "Sinfonia Pastoral",
                         iconName: "music.note",
                         bundleFilename: "beethoven_pastoral.mp3",
                         category: .music,
                         durationSeconds: 1212),
        RecommendedSound(id: "mozart_k467",
                         title: "Mozart",
                         subtitle: "Concerto Piano nº 21",
                         iconName: "music.note",
                         bundleFilename: "mozart_k467.mp3",
                         category: .music,
                         durationSeconds: 1196),
        RecommendedSound(id: "pachelbel_canon",
                         title: "Pachelbel",
                         subtitle: "Canon em Ré",
                         iconName: "music.note",
                         bundleFilename: "pachelbel_canon.mp3",
                         category: .music,
                         durationSeconds: 1800),

        // Sons pra dormir (ja bundlados em SleepSounds/)
        RecommendedSound(id: "sleep_water",
                         title: "Água Corrente",
                         subtitle: "Riacho calmo",
                         iconName: "drop.fill",
                         bundleFilename: "sleep_water.mp3",
                         category: .sleep,
                         durationSeconds: 300),
        RecommendedSound(id: "sleep_forest",
                         title: "Floresta Noturna",
                         subtitle: "Vento e grilos",
                         iconName: "tree",
                         bundleFilename: "sleep_forest.mp3",
                         category: .sleep,
                         durationSeconds: 300),
        RecommendedSound(id: "sleep_fireplace",
                         title: "Lareira",
                         subtitle: "Fogo crepitando",
                         iconName: "flame",
                         bundleFilename: "sleep_fireplace.mp3",
                         category: .sleep,
                         durationSeconds: 300),
        RecommendedSound(id: "sleep_pink_noise",
                         title: "Ruído Rosa",
                         subtitle: "Sono profundo",
                         iconName: "waveform",
                         bundleFilename: "sleep_pink_noise.mp3",
                         category: .sleep,
                         durationSeconds: 300)
    ]

    /// Gera ate 4 sons recomendados baseado em sinais bio.
    /// Aceita Double opcionais pra ficar compativel com HealthKitManager (que
    /// pode ainda nao ter carregado dados na primeira render).
    static func generate(stressLevel: Double? = nil,
                         sleepHours: Double? = nil,
                         heartRate: Double? = nil) -> [RecommendedSound] {
        var recommended: [RecommendedSound] = []

        // Estresse alto → musica contemplativa
        if let stress = stressLevel, stress > 0.6 {
            recommended.append(contentsOf: library.filter {
                $0.id == "bach_goldberg" || $0.id == "pachelbel_canon"
            })
        }

        // FC alta → Mozart (estudos sugerem efeito relaxante)
        if let hr = heartRate, hr > 80 {
            recommended.append(contentsOf: library.filter { $0.id == "mozart_k467" })
        }

        // Sono ruim → sleep sounds
        if let sleep = sleepHours, sleep > 0, sleep < 6 {
            recommended.append(contentsOf: library.filter { $0.category == .sleep }.prefix(2))
        }

        // Fallback: mix variado (2 musicas + 2 sleep)
        if recommended.isEmpty {
            recommended = [
                library[0],   // Bach
                library[2],   // Mozart
                library[4],   // Agua
                library[5]    // Floresta
            ]
        }

        // Dedup mantendo ordem + limitar 4
        var seen = Set<String>()
        return recommended.filter { seen.insert($0.id).inserted }.prefix(4).map { $0 }
    }
}
