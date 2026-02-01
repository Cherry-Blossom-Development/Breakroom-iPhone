import Foundation

enum ChatAPIService {
    static func getRooms() async throws -> [ChatRoom] {
        let response: ChatRoomsResponse = try await APIClient.shared.request("/api/chat/rooms")
        return response.rooms
    }

    static func getMessages(roomId: Int, limit: Int = 50, before: Int? = nil) async throws -> [ChatMessage] {
        var path = "/api/chat/rooms/\(roomId)/messages?limit=\(limit)"
        if let before {
            path += "&before=\(before)"
        }
        let response: ChatMessagesResponse = try await APIClient.shared.request(path)
        return response.messages
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
}
