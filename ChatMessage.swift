import Foundation

/// Represents a message in the chat conversation
struct ChatMessage: Identifiable, Codable {
    var id: String
    let text: String
    let isUser: Bool
    let date: Date

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isUser
        case date
    }

    init(id: String, text: String, isUser: Bool, date: Date) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        date = try container.decode(Date.self, forKey: .date)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(isUser, forKey: .isUser)
        try container.encode(date, forKey: .date)
    }
}
