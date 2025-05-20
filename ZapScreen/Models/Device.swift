import Foundation

struct Device: Identifiable, Codable {
    let uuid: UUID = UUID()
    let id: String // Not used for Identifiable anymore, but kept for backend mapping
    let name: String
    let model: String
    let lastSeen: Date
    let isOnline: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case model
        case lastSeen = "last_seen"
        case isOnline = "is_online"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        model = try container.decode(String.self, forKey: .model)
        isOnline = try container.decode(Bool.self, forKey: .isOnline)
        
        // Handle date decoding with custom date formatter
        let dateString = try container.decode(String.self, forKey: .lastSeen)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = formatter.date(from: dateString) {
            lastSeen = date
        } else {
            // Fallback to current date if parsing fails
            lastSeen = Date()
        }
    }
} 