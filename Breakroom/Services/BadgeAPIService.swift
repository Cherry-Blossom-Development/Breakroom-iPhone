import Foundation

// MARK: - Response Models

struct BadgeCountsResponse: Decodable {
    let chatUnread: [Int: Int]
    let friendRequestsUnread: Int
    let blogCommentsUnread: Int
    let blogUnreadByPost: [Int: Int]

    enum CodingKeys: String, CodingKey {
        case chatUnread
        case friendRequestsUnread
        case blogCommentsUnread
        case blogUnreadByPost
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        friendRequestsUnread = try container.decodeIfPresent(Int.self, forKey: .friendRequestsUnread) ?? 0
        blogCommentsUnread = try container.decodeIfPresent(Int.self, forKey: .blogCommentsUnread) ?? 0

        // Decode chatUnread - keys come as strings from JSON
        let chatUnreadStrings = try container.decodeIfPresent([String: Int].self, forKey: .chatUnread) ?? [:]
        chatUnread = Dictionary(uniqueKeysWithValues: chatUnreadStrings.compactMap { key, value in
            guard let intKey = Int(key) else { return nil }
            return (intKey, value)
        })

        // Decode blogUnreadByPost - keys come as strings from JSON
        let blogUnreadStrings = try container.decodeIfPresent([String: Int].self, forKey: .blogUnreadByPost) ?? [:]
        blogUnreadByPost = Dictionary(uniqueKeysWithValues: blogUnreadStrings.compactMap { key, value in
            guard let intKey = Int(key) else { return nil }
            return (intKey, value)
        })
    }
}

// MARK: - API Service

enum BadgeAPIService {
    /// Fetch all badge counts for the current user
    static func getBadgeCounts() async throws -> BadgeCountsResponse {
        try await APIClient.shared.request("/api/user/badge-counts")
    }

    /// Mark a chat room as read
    static func markRoomRead(roomId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(roomId)/mark-read",
            method: "POST"
        )
    }

    /// Mark all chat rooms as read
    static func markAllRoomsRead() async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/mark-all-read",
            method: "POST"
        )
    }

    /// Mark friend requests as seen
    static func markFriendsSeen() async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/mark-seen",
            method: "POST"
        )
    }

    /// Mark a blog post's comments as read
    static func markBlogPostRead(postId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/comments/posts/\(postId)/mark-read",
            method: "POST"
        )
    }
}
