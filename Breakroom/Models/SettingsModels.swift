import Foundation

// MARK: - Notification Settings

struct NotificationSettings: Codable {
    var notificationsEnabled: Bool
    var notifyChatMessages: Bool
    var notifyFriendRequests: Bool
    var notifyBlogComments: Bool

    enum CodingKeys: String, CodingKey {
        case notificationsEnabled = "notifications_enabled"
        case notifyChatMessages = "notify_chat_messages"
        case notifyFriendRequests = "notify_friend_requests"
        case notifyBlogComments = "notify_blog_comments"
    }

    init(
        notificationsEnabled: Bool = true,
        notifyChatMessages: Bool = true,
        notifyFriendRequests: Bool = true,
        notifyBlogComments: Bool = true
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.notifyChatMessages = notifyChatMessages
        self.notifyFriendRequests = notifyFriendRequests
        self.notifyBlogComments = notifyBlogComments
    }
}

// MARK: - Account Deletion

struct DeletionRequestResponse: Codable {
    let message: String
}
