import Foundation

enum ModerationAPIService {
    /// Flag content for moderation review
    /// - Parameters:
    ///   - contentType: Type of content being flagged (post, comment, chat_message, etc.)
    ///   - contentId: ID of the content (nil for "other" type)
    ///   - reason: Optional reason for the flag
    static func flagContent(contentType: String, contentId: Int?, reason: String?) async throws {
        let request = FlagRequest(contentType: contentType, contentId: contentId, reason: reason)
        let _: FlagResponse = try await APIClient.shared.request(
            "/api/moderation/flag",
            method: "POST",
            body: request
        )
    }

    /// Block a user
    /// - Parameter userId: ID of the user to block
    static func blockUser(userId: Int) async throws {
        let _: BlockResponse = try await APIClient.shared.request(
            "/api/moderation/block/\(userId)",
            method: "POST"
        )
    }

    /// Unblock a user
    /// - Parameter userId: ID of the user to unblock
    static func unblockUser(userId: Int) async throws {
        let _: BlockResponse = try await APIClient.shared.request(
            "/api/moderation/block/\(userId)",
            method: "DELETE"
        )
    }

    /// Get the current user's block list
    /// - Returns: Array of blocked user IDs
    static func getBlockList() async throws -> [Int] {
        let response: BlockListResponse = try await APIClient.shared.request("/api/moderation/blocks")
        return response.blockedUserIds
    }
}
