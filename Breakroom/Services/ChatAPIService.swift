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
        return try await APIClient.shared.request(
            "/api/chat/rooms",
            method: "POST",
            body: body
        )
    }
}
