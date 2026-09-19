import Foundation

struct Friend: Codable, Identifiable, PresenceHydratable {
    let id: Int
    let handle: String
    let firstName: String?
    let lastName: String?
    let photoPath: String?
    let friendsSince: String?
    let isOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case id, handle
        case firstName = "first_name"
        case lastName = "last_name"
        case photoPath = "photo_path"
        case friendsSince = "friends_since"
        case isOnline = "is_online"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        handle = try container.decode(String.self, forKey: .handle)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        photoPath = try container.decodeIfPresent(String.self, forKey: .photoPath)
        friendsSince = try container.decodeIfPresent(String.self, forKey: .friendsSince)
        // Backend may send 0/1 or true/false
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isOnline) {
            isOnline = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .isOnline) {
            isOnline = intValue == 1
        } else {
            isOnline = nil
        }
    }

    // Memberwise init for manual construction
    init(id: Int, handle: String, firstName: String?, lastName: String?, photoPath: String?, friendsSince: String?, isOnline: Bool? = nil) {
        self.id = id
        self.handle = handle
        self.firstName = firstName
        self.lastName = lastName
        self.photoPath = photoPath
        self.friendsSince = friendsSince
        self.isOnline = isOnline
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
