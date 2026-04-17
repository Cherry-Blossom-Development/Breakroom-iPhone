import Foundation

/// App-level store holding notification badge counts.
/// Uses @Observable so any SwiftUI view reading from it will update when counts change.
@MainActor
@Observable
final class BadgeStore {
    /// Per-room unread message counts: [roomId: count]
    private(set) var chatUnread: [Int: Int] = [:]

    /// Unseen incoming friend requests
    private(set) var friendRequestsUnread: Int = 0

    /// Number of the author's posts that have new comments (distinct post count)
    private(set) var blogCommentsUnread: Int = 0

    /// Per-post unread comment counts: [postId: count]
    private(set) var blogUnreadByPost: [Int: Int] = [:]

    /// True when a new badge has arrived since the menu was last opened
    private(set) var hasUnseenBadges: Bool = false

    // MARK: - Computed Properties

    /// Total of all chat room unread counts
    var totalChatUnread: Int {
        chatUnread.values.reduce(0, +)
    }

    /// Total of all non-chat badges
    var totalNonChat: Int {
        friendRequestsUnread + blogCommentsUnread
    }

    /// Any unread content at all
    var hasAny: Bool {
        totalChatUnread > 0 || totalNonChat > 0
    }

    // MARK: - Initialization

    /// Fetch all badge counts from the server
    func fetchAll() async {
        do {
            let response = try await BadgeAPIService.getBadgeCounts()
            chatUnread = response.chatUnread
            friendRequestsUnread = response.friendRequestsUnread
            blogCommentsUnread = response.blogCommentsUnread
            blogUnreadByPost = response.blogUnreadByPost
        } catch {
            #if DEBUG
            print("[BadgeStore] Failed to fetch badge counts: \(error)")
            #endif
        }
    }

    /// Clear all badge state (on logout)
    func clear() {
        chatUnread = [:]
        friendRequestsUnread = 0
        blogCommentsUnread = 0
        blogUnreadByPost = [:]
        hasUnseenBadges = false
    }

    // MARK: - Mark-read Actions

    /// Mark a chat room as read
    func markRoomRead(_ roomId: Int) async {
        guard chatUnread[roomId] != nil else { return }
        chatUnread.removeValue(forKey: roomId)
        do {
            try await BadgeAPIService.markRoomRead(roomId: roomId)
        } catch {
            #if DEBUG
            print("[BadgeStore] Failed to mark room read: \(error)")
            #endif
        }
    }

    /// Mark all chat rooms as read
    func markAllRoomsRead() async {
        chatUnread = [:]
        do {
            try await BadgeAPIService.markAllRoomsRead()
        } catch {
            #if DEBUG
            print("[BadgeStore] Failed to mark all rooms read: \(error)")
            #endif
        }
    }

    /// Mark friend requests as seen
    func markFriendsRead() async {
        guard friendRequestsUnread > 0 else { return }
        friendRequestsUnread = 0
        do {
            try await BadgeAPIService.markFriendsSeen()
        } catch {
            #if DEBUG
            print("[BadgeStore] Failed to mark friends seen: \(error)")
            #endif
        }
    }

    /// Mark a blog post's comments as read
    func markBlogPostRead(_ postId: Int) async {
        guard blogUnreadByPost[postId] != nil else { return }
        blogUnreadByPost.removeValue(forKey: postId)
        blogCommentsUnread = blogUnreadByPost.count
        do {
            try await BadgeAPIService.markBlogPostRead(postId: postId)
        } catch {
            #if DEBUG
            print("[BadgeStore] Failed to mark blog post read: \(error)")
            #endif
        }
    }

    // MARK: - Socket Event Handlers

    /// Called when a new chat message arrives (from socket)
    func onChatBadgeUpdate(roomId: Int) {
        chatUnread[roomId] = (chatUnread[roomId] ?? 0) + 1
        hasUnseenBadges = true
    }

    /// Called when a new friend request arrives (from socket)
    func onFriendBadgeUpdate() {
        friendRequestsUnread += 1
        hasUnseenBadges = true
    }

    /// Called when a new blog comment arrives (from socket)
    func onBlogBadgeUpdate(postId: Int) {
        let wasZero = blogUnreadByPost[postId] == nil
        blogUnreadByPost[postId] = (blogUnreadByPost[postId] ?? 0) + 1
        if wasZero {
            blogCommentsUnread += 1
        }
        hasUnseenBadges = true
    }

    /// Called when the menu is opened
    func onMenuOpen() {
        hasUnseenBadges = false
    }
}
