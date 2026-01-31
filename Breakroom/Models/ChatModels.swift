import Foundation

struct ChatRoom: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let ownerId: Int?
    let isActive: Bool?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case ownerId = "owner_id"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: Int
    let roomId: Int?
    let userId: Int?
    let handle: String?
    let message: String?
    let imagePath: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case handle
        case message
        case imagePath = "image_path"
        case createdAt = "created_at"
    }
}

struct SendMessageRequest: Encodable {
    let message: String
}

struct CreateRoomRequest: Encodable {
    let name: String
    let description: String?
}
