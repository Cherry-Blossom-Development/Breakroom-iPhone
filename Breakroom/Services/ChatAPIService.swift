import Foundation

enum ChatAPIService {
    private static let messageLimit = 50

    static func getRooms() async throws -> [ChatRoom] {
        let response: ChatRoomsResponse = try await APIClient.shared.request("/api/chat/rooms")
        return response.rooms
    }

    /// Fetch messages for a room with limit-based pagination.
    /// - Parameters:
    ///   - roomId: The chat room ID
    ///   - limit: Maximum number of messages to fetch (default 50)
    ///   - before: Fetch messages older than this timestamp (ISO date). Omit for most recent messages.
    /// - Returns: Tuple of (messages, hasMore) where hasMore indicates older messages exist
    static func getMessages(roomId: Int, limit: Int? = nil, before: String? = nil) async throws -> (messages: [ChatMessage], hasMore: Bool) {
        let effectiveLimit = limit ?? messageLimit
        var path = "/api/chat/rooms/\(roomId)/messages?limit=\(effectiveLimit)"
        if let before {
            path += "&before=\(before.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? before)"
        }
        let response: ChatMessagesResponse = try await APIClient.shared.request(path)
        return (response.messages, response.hasMore ?? false)
    }

    static func sendMessage(roomId: Int, message: String) async throws -> ChatMessage {
        let body = SendMessageRequest(message: message)
        let response: ChatMessageResponse = try await APIClient.shared.request(
            "/api/chat/rooms/\(roomId)/messages",
            method: "POST",
            body: body
        )
        return response.message
    }

    static func editMessage(roomId: Int, messageId: Int, message: String) async throws -> ChatMessage {
        let body = EditMessageRequest(message: message)
        let response: ChatMessageResponse = try await APIClient.shared.request(
            "/api/chat/rooms/\(roomId)/messages/\(messageId)",
            method: "PUT",
            body: body
        )
        return response.message
    }

    static func deleteMessage(roomId: Int, messageId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(roomId)/messages/\(messageId)",
            method: "DELETE"
        )
    }

    static func createRoom(name: String, description: String?) async throws -> ChatRoom {
        let body = CreateRoomRequest(name: name, description: description)
        let response: ChatRoomResponse = try await APIClient.shared.request(
            "/api/chat/rooms",
            method: "POST",
            body: body
        )
        return response.room
    }

    static func updateRoom(id: Int, name: String, description: String?) async throws -> ChatRoom {
        let body = UpdateRoomRequest(name: name, description: description)
        let response: ChatRoomResponse = try await APIClient.shared.request(
            "/api/chat/rooms/\(id)",
            method: "PUT",
            body: body
        )
        return response.room
    }

    static func deleteRoom(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(id)",
            method: "DELETE"
        )
    }

    /// Leave a room (removes membership; for default room, records opt-out)
    static func leaveRoom(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(id)/leave",
            method: "DELETE"
        )
    }

    // MARK: - Discoverable Rooms

    /// Get discoverable rooms the user has NOT yet joined
    static func getDiscoverableRooms() async throws -> [ChatRoom] {
        let response: ChatRoomsResponse = try await APIClient.shared.request("/api/chat/rooms/discoverable")
        return response.rooms
    }

    /// Self-join a discoverable room
    static func joinRoom(id: Int) async throws -> ChatRoom {
        let response: ChatRoomResponse = try await APIClient.shared.request(
            "/api/chat/rooms/\(id)/join",
            method: "POST"
        )
        return response.room
    }

    // MARK: - Invites

    static func getInvites() async throws -> [ChatInvite] {
        let response: ChatInvitesResponse = try await APIClient.shared.request("/api/chat/invites")
        return response.invites
    }

    static func acceptInvite(roomId: Int) async throws -> ChatRoom {
        let response: AcceptInviteResponse = try await APIClient.shared.request(
            "/api/chat/invites/\(roomId)/accept",
            method: "POST"
        )
        return response.room
    }

    static func declineInvite(roomId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/invites/\(roomId)/decline",
            method: "POST"
        )
    }

    // MARK: - Members

    static func getMembers(roomId: Int) async throws -> [ChatMember] {
        let response: ChatMembersResponse = try await APIClient.shared.request(
            "/api/chat/rooms/\(roomId)/members"
        )
        return response.members
    }

    static func inviteUser(roomId: Int, userId: Int) async throws {
        let body = InviteUserRequest(userId: userId)
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(roomId)/invite",
            method: "POST",
            body: body
        )
    }

    // MARK: - Users & Permissions

    static func getAllUsers() async throws -> [User] {
        let response: AllUsersResponse = try await APIClient.shared.request("/api/user/all")
        return response.users
    }

    static func canCreateRoom() async throws -> Bool {
        let response: PermissionResponse = try await APIClient.shared.request("/api/auth/can/create_room")
        return response.hasPermission
    }

    // MARK: - Unread Summary

    /// Get rooms with unread messages for the summary widget
    static func getUnreadSummary() async throws -> [UnreadRoomSummary] {
        try await APIClient.shared.request("/api/chat/rooms/unread-summary")
    }

    /// Get recent messages from all joined rooms (for "all done" state)
    static func getRecentRooms() async throws -> [RecentRoomMessage] {
        try await APIClient.shared.request("/api/chat/rooms/recent")
    }

    /// Mark a room as read (sets last_read_at = NOW)
    static func markRoomRead(roomId: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/chat/rooms/\(roomId)/mark-read",
            method: "POST"
        )
    }

    // MARK: - Media Upload

    static func uploadImage(roomId: Int, imageData: Data, filename: String) async throws -> ChatMessage {
        let response: ChatMessageResponse = try await APIClient.shared.uploadMultipart(
            "/api/chat/rooms/\(roomId)/image",
            fileData: imageData,
            fieldName: "image",
            filename: filename,
            mimeType: "image/jpeg"
        )
        return response.message
    }

    static func uploadVideo(roomId: Int, videoData: Data, filename: String) async throws -> ChatMessage {
        let response: ChatMessageResponse = try await APIClient.shared.uploadMultipart(
            "/api/chat/rooms/\(roomId)/video",
            fileData: videoData,
            fieldName: "video",
            filename: filename,
            mimeType: "video/mp4"
        )
        return response.message
    }

    // MARK: - Scheduled Messages

    /// Get all pending/active scheduled messages for the current user
    static func getScheduledMessages() async throws -> [ScheduledMessage] {
        let response: ScheduledMessagesResponse = try await APIClient.shared.request("/api/scheduled-messages")
        return response.scheduledMessages
    }

    /// Create a new scheduled message
    static func createScheduledMessage(
        roomId: Int,
        messageText: String,
        scheduledAt: Date,
        warningMinutes: Int = 10,
        indicatorText: String = "- sent via scheduled message"
    ) async throws -> ScheduledMessage {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let body = CreateScheduledMessageRequest(
            roomId: roomId,
            messageText: messageText,
            scheduledAt: formatter.string(from: scheduledAt),
            warningMinutes: warningMinutes,
            indicatorText: indicatorText
        )
        let response: ScheduledMessageResponse = try await APIClient.shared.request(
            "/api/scheduled-messages",
            method: "POST",
            body: body
        )
        return response.scheduledMessage
    }

    /// Update a scheduled message
    static func updateScheduledMessage(
        id: Int,
        roomId: Int? = nil,
        messageText: String? = nil,
        scheduledAt: Date? = nil,
        warningMinutes: Int? = nil,
        indicatorText: String? = nil
    ) async throws -> ScheduledMessage {
        var scheduledAtString: String?
        if let scheduledAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            scheduledAtString = formatter.string(from: scheduledAt)
        }

        let body = UpdateScheduledMessageRequest(
            roomId: roomId,
            messageText: messageText,
            scheduledAt: scheduledAtString,
            warningMinutes: warningMinutes,
            indicatorText: indicatorText
        )
        let response: ScheduledMessageResponse = try await APIClient.shared.request(
            "/api/scheduled-messages/\(id)",
            method: "PUT",
            body: body
        )
        return response.scheduledMessage
    }

    /// Cancel (delete) a scheduled message
    static func cancelScheduledMessage(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/scheduled-messages/\(id)",
            method: "DELETE"
        )
    }

    /// Confirm a scheduled message (proceed with sending)
    static func confirmScheduledMessage(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/scheduled-messages/\(id)/confirm",
            method: "POST"
        )
    }

    /// Pause a scheduled message for editing
    static func pauseScheduledMessage(id: Int) async throws {
        try await APIClient.shared.requestVoid(
            "/api/scheduled-messages/\(id)/pause-edit",
            method: "POST"
        )
    }

    // MARK: - Direct Messages

    /// Get all DM threads for the current user
    static func getDms() async throws -> [ChatDm] {
        let response: DmsResponse = try await APIClient.shared.request("/api/chat/dms")
        return response.dms
    }

    /// Start or resume a DM with a user (find-or-create)
    static func startDm(userId: Int) async throws -> DmRoomInfo {
        let body = StartDmRequest(userId: userId)
        let response: StartDmResponse = try await APIClient.shared.request(
            "/api/chat/dm",
            method: "POST",
            body: body
        )
        return response.room
    }
}
