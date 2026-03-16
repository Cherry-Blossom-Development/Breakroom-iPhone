import Foundation

// MARK: - Flag Request/Response

struct FlagRequest: Encodable {
    let contentType: String
    let contentId: Int?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
        case reason
    }
}

struct FlagResponse: Decodable {
    let message: String
}

// MARK: - Block Request/Response

struct BlockResponse: Decodable {
    let blocked: Bool?
    let unblocked: Bool?
    let message: String?
}

struct BlockListResponse: Decodable {
    let blockedUserIds: [Int]
}

// MARK: - Content Types

enum ModerationContentType: String, CaseIterable {
    case post
    case comment
    case chatMessage = "chat_message"
    case artwork
    case lyrics
    case user
    case profile
    case other

    var displayName: String {
        switch self {
        case .post: return "Blog Post"
        case .comment: return "Comment"
        case .chatMessage: return "Chat Message"
        case .artwork: return "Artwork"
        case .lyrics: return "Lyrics"
        case .user: return "User"
        case .profile: return "Profile"
        case .other: return "Other"
        }
    }

    var requiresReason: Bool {
        self == .other
    }
}
