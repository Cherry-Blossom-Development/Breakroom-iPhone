import Foundation

struct Friend: Codable, Identifiable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let friendsSince: String?

    enum CodingKeys: String, CodingKey {
        case id, handle
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
        case friendsSince = "friends_since"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }
}

struct FriendRequest: Codable, Identifiable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let requestedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, handle
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
        case requestedAt = "requested_at"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }

    var photoURL: URL? {
        guard let photoPath, !photoPath.isEmpty else { return nil }
        return URL(string: "\(APIClient.shared.baseURL)/api/uploads/\(photoPath)")
    }
}

struct BlockedUser: Codable, Identifiable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let blockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, handle
        case firstName = "first_name"
        case lastName = "last_name"
        case blockedAt = "blocked_at"
    }

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }
}

// MARK: - Response Types

struct FriendsListResponse: Decodable {
    let friends: [Friend]
}

struct FriendRequestsResponse: Decodable {
    let requests: [FriendRequest]
}

struct SentRequestsResponse: Decodable {
    let sent: [FriendRequest]
}

struct BlockedUsersResponse: Decodable {
    let blocked: [BlockedUser]
}
