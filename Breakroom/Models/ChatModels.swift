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

struct ChatMessage: Codable, Identifiable, Hashable {
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

    init(id: Int, roomId: Int?, userId: Int?, handle: String?, message: String?, imagePath: String?, videoPath: String?, createdAt: String?) {
        self.id = id
        self.roomId = roomId
        self.userId = userId
        self.handle = handle
        self.message = message
        self.imagePath = imagePath
        self.videoPath = videoPath
        self.createdAt = createdAt
    }
}

// MARK: - API Response Wrappers

struct ChatRoomsResponse: Decodable {
    let rooms: [ChatRoom]
}

struct ChatMessagesResponse: Decodable {
    let messages: [ChatMessage]
    let hasMore: Bool?
}

struct ChatMessageResponse: Decodable {
    let message: ChatMessage
}

// MARK: - Request Types

struct SendMessageRequest: Encodable {
    let message: String
}

struct EditMessageRequest: Encodable {
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

// MARK: - Unread Summary Types

struct UnreadRoomSummary: Codable, Identifiable {
    let id: Int
    let name: String
    let lastReadAt: String?
    let unreadCount: Int
    let latestUnreadAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case lastReadAt = "last_read_at"
        case unreadCount = "unread_count"
        case latestUnreadAt = "latest_unread_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        lastReadAt = try container.decodeIfPresent(String.self, forKey: .lastReadAt)
        latestUnreadAt = try container.decodeIfPresent(String.self, forKey: .latestUnreadAt)

        // MariaDB COUNT returns BIGINT which may serialize as string
        if let intValue = try? container.decode(Int.self, forKey: .unreadCount) {
            unreadCount = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .unreadCount),
                  let parsed = Int(stringValue) {
            unreadCount = parsed
        } else {
            unreadCount = 0
        }
    }
}

struct RecentRoomMessage: Codable, Identifiable {
    let roomId: Int
    let roomName: String
    let messageId: Int?  // Optional - not used in UI, just for completeness
    var message: String?
    var handle: String
    var createdAt: String
    var unreadCount: Int

    var id: Int { roomId }

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case roomName = "room_name"
        case messageId = "message_id"
        case message
        case handle
        case createdAt = "created_at"
        case unreadCount = "unread_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try container.decode(Int.self, forKey: .roomId)
        roomName = try container.decode(String.self, forKey: .roomName)
        messageId = try container.decodeIfPresent(Int.self, forKey: .messageId)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        handle = try container.decode(String.self, forKey: .handle)
        createdAt = try container.decode(String.self, forKey: .createdAt)

        // MariaDB COUNT returns BIGINT which may serialize as string
        if let intValue = try? container.decode(Int.self, forKey: .unreadCount) {
            unreadCount = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .unreadCount),
                  let parsed = Int(stringValue) {
            unreadCount = parsed
        } else {
            unreadCount = 0
        }
    }

    // Memberwise init for manual creation/updates
    init(roomId: Int, roomName: String, messageId: Int? = nil, message: String?, handle: String, createdAt: String, unreadCount: Int) {
        self.roomId = roomId
        self.roomName = roomName
        self.messageId = messageId
        self.message = message
        self.handle = handle
        self.createdAt = createdAt
        self.unreadCount = unreadCount
    }
}

// MARK: - Scheduled Messages

struct ScheduledMessage: Codable, Identifiable {
    let id: Int
    let userId: Int
    let roomId: Int
    let messageText: String
    let scheduledAt: String
    let warningMinutes: Int
    let indicatorText: String?
    let status: String
    let isEditing: Bool
    let roomName: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case roomId = "room_id"
        case messageText = "message_text"
        case scheduledAt = "scheduled_at"
        case warningMinutes = "warning_minutes"
        case indicatorText = "indicator_text"
        case status
        case isEditing = "is_editing"
        case roomName = "room_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decode(Int.self, forKey: .userId)
        roomId = try container.decode(Int.self, forKey: .roomId)
        messageText = try container.decode(String.self, forKey: .messageText)
        scheduledAt = try container.decode(String.self, forKey: .scheduledAt)
        warningMinutes = try container.decode(Int.self, forKey: .warningMinutes)
        indicatorText = try container.decodeIfPresent(String.self, forKey: .indicatorText)
        status = try container.decode(String.self, forKey: .status)
        roomName = try container.decodeIfPresent(String.self, forKey: .roomName)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)

        // Handle boolean/int for is_editing
        if let boolValue = try? container.decode(Bool.self, forKey: .isEditing) {
            isEditing = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isEditing) {
            isEditing = intValue != 0
        } else {
            isEditing = false
        }
    }
}

struct ScheduledMessagesResponse: Decodable {
    let scheduledMessages: [ScheduledMessage]

    enum CodingKeys: String, CodingKey {
        case scheduledMessages = "scheduled_messages"
    }
}

struct ScheduledMessageResponse: Decodable {
    let scheduledMessage: ScheduledMessage

    enum CodingKeys: String, CodingKey {
        case scheduledMessage = "scheduled_message"
    }
}

struct CreateScheduledMessageRequest: Encodable {
    let roomId: Int
    let messageText: String
    let scheduledAt: String
    let warningMinutes: Int
    let indicatorText: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case messageText = "message_text"
        case scheduledAt = "scheduled_at"
        case warningMinutes = "warning_minutes"
        case indicatorText = "indicator_text"
    }
}

struct UpdateScheduledMessageRequest: Encodable {
    let roomId: Int?
    let messageText: String?
    let scheduledAt: String?
    let warningMinutes: Int?
    let indicatorText: String?

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case messageText = "message_text"
        case scheduledAt = "scheduled_at"
        case warningMinutes = "warning_minutes"
        case indicatorText = "indicator_text"
    }
}

// Socket event data for scheduled message warnings
struct ScheduledMessageWarning {
    let id: Int
    let roomName: String
    let messagePreview: String
    let minutesRemaining: Int
}

struct ScheduledMessageMissed {
    let id: Int
    let messagePreview: String
}
