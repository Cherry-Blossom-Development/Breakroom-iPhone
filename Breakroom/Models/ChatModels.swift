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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        ownerId = try container.decodeIfPresent(Int.self, forKey: .ownerId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)

        // MariaDB returns BOOLEAN as TINYINT(1), which serializes as 0/1
        // instead of true/false. Handle both types.
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isActive) {
            isActive = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .isActive) {
            isActive = intValue != 0
        } else {
            isActive = nil
        }
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: Int
    let roomId: Int?
    let userId: Int?
    let handle: String?
    let message: String?
    let imagePath: String?
    let videoPath: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case handle
        case message
        case imagePath = "image_path"
        case videoPath = "video_path"
        case createdAt = "created_at"
    }
}

// MARK: - API Response Wrappers

struct ChatRoomsResponse: Decodable {
    let rooms: [ChatRoom]
}

struct ChatMessagesResponse: Decodable {
    let messages: [ChatMessage]
}

struct ChatMessageResponse: Decodable {
    let message: ChatMessage
}

// MARK: - Request Types

struct SendMessageRequest: Encodable {
    let message: String
}

struct CreateRoomRequest: Encodable {
    let name: String
    let description: String?
}

struct UpdateRoomRequest: Encodable {
    let name: String
    let description: String?
}

struct InviteUserRequest: Encodable {
    let userId: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

// MARK: - Invite Types

struct ChatInvite: Codable, Identifiable {
    let roomId: Int
    let roomName: String
    let roomDescription: String?
    let invitedByHandle: String
    let invitedAt: String

    var id: Int { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case roomName = "room_name"
        case roomDescription = "room_description"
        case invitedByHandle = "invited_by_handle"
        case invitedAt = "invited_at"
    }
}

struct ChatInvitesResponse: Decodable {
    let invites: [ChatInvite]
}

// MARK: - Member Types

struct ChatMember: Codable, Identifiable {
    let id: Int
    let handle: String
    let role: String?
    let joinedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case handle
        case role
        case joinedAt = "joined_at"
    }
}

struct ChatMembersResponse: Decodable {
    let members: [ChatMember]
}

// MARK: - Permission Types

struct PermissionResponse: Decodable {
    let hasPermission: Bool

    enum CodingKeys: String, CodingKey {
        case hasPermission = "has_permission"
    }
}

// MARK: - Wrapped Response Types

struct ChatRoomResponse: Decodable {
    let room: ChatRoom
}

struct AcceptInviteResponse: Decodable {
    let message: String
    let room: ChatRoom
}

struct AllUsersResponse: Decodable {
    let users: [User]
}
