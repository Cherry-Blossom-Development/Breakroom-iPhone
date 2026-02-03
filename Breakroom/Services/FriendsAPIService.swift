import Foundation

enum FriendsAPIService {
    // MARK: - Fetch Lists

    static func getFriends() async throws -> [Friend] {
        let response: FriendsListResponse = try await APIClient.shared.request("/api/friends")
        return response.friends
    }

    static func getRequests() async throws -> [FriendRequest] {
        let response: FriendRequestsResponse = try await APIClient.shared.request("/api/friends/requests")
        return response.requests
    }

    static func getSentRequests() async throws -> [FriendRequest] {
        let response: SentRequestsResponse = try await APIClient.shared.request("/api/friends/sent")
        return response.sent
    }

    static func getBlocked() async throws -> [BlockedUser] {
        let response: BlockedUsersResponse = try await APIClient.shared.request("/api/friends/blocked")
        return response.blocked
    }

    // MARK: - Actions

    static func sendRequest(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/request/\(userId)",
            method: "POST"
        )
    }

    static func acceptRequest(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/accept/\(userId)",
            method: "POST"
        )
    }

    static func declineRequest(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/decline/\(userId)",
            method: "POST"
        )
    }

    static func cancelRequest(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/request/\(userId)",
            method: "DELETE"
        )
    }

    static func removeFriend(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/\(userId)",
            method: "DELETE"
        )
    }

    static func blockUser(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/block/\(userId)",
            method: "POST"
        )
    }

    static func unblockUser(userId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/friends/block/\(userId)",
            method: "DELETE"
        )
    }
}
